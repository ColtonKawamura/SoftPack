# ---------------------------------------------------------------------------
#  Isotropic compression to the target pressure (design §2).
# ---------------------------------------------------------------------------

"""
    CompressionOutcome

How the compression ended. `status` is `:converged`, `:steps_max`, `:uphill_max`,
`:strain_step_min`, `:pressure_left_band`, `:restart_test` or `:packing_fraction_max`.
"""
struct CompressionOutcome
    status::Symbol
    steps::Int
    accepted::Int
    rejected::Int
    strain_step::Float64
end

"""
    run_minimization!(system, algorithm, timestep, test, context, control, drag_on,
                      steps_left) -> (status, steps)

Dispatch one minimization or relaxation to the algorithm. The algorithm counts its steps
in the control and records restart files, snapshots and movie frames after every step.
"""
function run_minimization!(s::System{D}, algorithm::FIRE, timestep::Float64, test, ctx,
                           control::RunControl{D}, drag_on::Bool,
                           steps_left::Int) where {D}
    return minimize!(s, algorithm, timestep, test, ctx, control, drag_on, steps_left)
end

function run_minimization!(s::System{D}, algorithm::DampedDynamics, timestep::Float64,
                           test, ctx, control::RunControl{D}, drag_on::Bool,
                           steps_left::Int) where {D}
    return relax!(s, algorithm, timestep, test, ctx, control, drag_on, steps_left)
end

"""
    compress!(system, params, control, timestep, context) -> CompressionOutcome

From the accepted state (initially the start), repeat: shrink the box and every position
by `1 - strain_step`, minimize from rest, read the pressure. Within the band
`|P - P_target| <= pressure_tolerance * P_target` the trial is the packing. Below it the
trial is accepted; above it the trial is rejected and the strain step halves (it never
grows back). Every step counts toward `steps_max`. With
`StokesDrag(during = :compression)` the trial runs with drag on until the pressure first
lies in the band, then once more with drag off (design §2); `RestartTest` runs its watch
once, on the trial that lies in the band (design §5).
"""
function compress!(s::System{D}, params::PackParams, control::RunControl{D},
                   timestep::Float64, ctx::ConvergenceContext) where {D}
    target = params.target.value
    band = params.pressure_tolerance * target
    compression = control.compression
    drag = params.algorithm isa FIRE ? params.algorithm.drag : params.algorithm.drag
    drag_mode = drag === nothing ? :none : drag.during
    zero_translation = zero(SVector{D,Float64})
    zero_rotation = zero(eltype(s.spins))
    total = 0
    while true
        factor = 1 - compression.strain
        s.side = factor * compression.accepted_side
        @inbounds for i in eachindex(s.positions)
            s.positions[i] = factor * compression.accepted_positions[i]
            s.velocities[i] = zero_translation
            s.spins[i] = zero_rotation
            s.accelerations[i] = zero_translation
            s.angular_accelerations[i] = zero_rotation
        end
        copyto!(s.last_positions, s.positions)
        copyto!(s.last_rotations, s.rotations)
        # A packing fraction of 1 puts more particle volume in the box than the box holds;
        # past it the overlaps exceed the particle diameter and the contact model no longer
        # describes a packing. Treat such a trial like an over-pressure one: reject it and
        # halve the strain, so a large strain_step still works. Only when the step can no
        # longer shrink does the run end with converged = false, on the last accepted state
        # (this also keeps the neighbor list's nearest-image guard from firing with a
        # misleading "use more particles" error).
        if total_volume(s.diameters, D) / s.side^D >= 1
            compression.rejected += 1
            compression.strain /= 2
            if compression.strain < 1e-14
                s.side = compression.accepted_side
                @inbounds for i in eachindex(s.positions)
                    s.positions[i] = compression.accepted_positions[i]
                end
                copyto!(s.last_positions, s.positions)
                evaluate_forces!(s)
                return CompressionOutcome(:packing_fraction_max, total, compression.accepted,
                                          compression.rejected, compression.strain)
            end
            continue
        end
        compression.mid_trial = true
        steps_left = control.steps_max - (control.step - control.step_at_start)
        steps_left <= 0 &&
            return CompressionOutcome(:steps_max, total, compression.accepted,
                                      compression.rejected, compression.strain)
        status, taken = run_minimization!(s, params.algorithm, timestep,
                                          params.convergence, ctx, control,
                                          drag_mode !== :none, steps_left)
        total += taken
        status === :converged ||
            return CompressionOutcome(status, total, compression.accepted,
                                      compression.rejected, compression.strain)
        pressure = contact_pressure(s.table, s.side, D)
        if drag_mode === :compression && abs(pressure - target) <= band
            steps_left = control.steps_max - (control.step - control.step_at_start)
            status, more = run_minimization!(s, params.algorithm, timestep,
                                             params.convergence, ctx, control, false,
                                             steps_left)
            total += more
            status === :converged ||
                return CompressionOutcome(status, total, compression.accepted,
                                          compression.rejected, compression.strain)
            pressure = contact_pressure(s.table, s.side, D)
            if abs(pressure - target) > band
                return CompressionOutcome(:pressure_left_band, total,
                                          compression.accepted, compression.rejected,
                                          compression.strain)
            end
        end
        if abs(pressure - target) <= band
            if params.convergence isa RestartTest
                passed, watch_steps = restart_watch!(s, params, control, timestep, ctx)
                total += watch_steps
                passed || return CompressionOutcome(:restart_test, total,
                                                    compression.accepted,
                                                    compression.rejected,
                                                    compression.strain)
            end
            compression.mid_trial = false
            return CompressionOutcome(:converged, total, compression.accepted,
                                      compression.rejected, compression.strain)
        elseif pressure < target
            compression.accepted += 1
            copyto!(compression.accepted_positions, s.positions)
            compression.accepted_side = s.side
        else
            compression.rejected += 1
            compression.strain /= 2
            compression.strain < 1e-14 &&
                return CompressionOutcome(:strain_step_min, total, compression.accepted,
                                          compression.rejected, compression.strain)
        end
        compression.mid_trial = false
    end
    return CompressionOutcome(:steps_max, total, compression.accepted,
                              compression.rejected, compression.strain)
end

"""
    restart_watch!(system, params, control, timestep, context) -> (passed, steps)

The `RestartTest` (design §5): with the trial in the band and drag off, zero the
velocities and relax for up to 2000 steps; the packing passes when the mean kinetic energy
stays below the `KineticEnergy` scale and the unbalanced forces do not double.

Card T-2brz: the design fixes the watch (Agnolin's observation) but not its length or
thresholds, so they are keywords of `RestartTest` with the values the first implementation
hard-coded: 2000 steps, growth 2 and the `KineticEnergy` default 1e-8.
"""
function restart_watch!(s::System{D}, params::PackParams, control::RunControl{D},
                        timestep::Float64, ctx::ConvergenceContext) where {D}
    test = params.convergence::RestartTest
    before_force = largest_force(s.forces)
    fill!(s.velocities, zero(SVector{D,Float64}))
    fill!(s.spins, zero(eltype(s.spins)))
    evaluate_forces!(s)
    steps_left = min(test.watch, control.steps_max - (control.step - control.step_at_start))
    steps_left <= 0 && return true, 0
    _, steps = run_minimization!(s, params.algorithm, timestep, _ -> false, ctx, control,
                                 false, steps_left)
    state = run_state(s, contact_pressure(s.table, s.side, D), control.step, params)
    energy_limit = test.energy_tolerance * params.target.value * ctx.diameter_ref^D
    passed = mean_kinetic_energy(state) <= energy_limit &&
             largest_force(s.forces) <= max(test.growth * before_force, ctx.force_floor)
    return passed, steps
end
