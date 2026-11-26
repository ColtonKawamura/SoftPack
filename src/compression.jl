# ---------------------------------------------------------------------------
#  Isotropic compression to the target pressure (design §2).
# ---------------------------------------------------------------------------

"""
    CompressionOutcome

How the compression ended. `status` is `:converged`, `:steps_max`, `:uphill_max` or
`:strain_step_min` (the strain step fell below 1e-14).
"""
struct CompressionOutcome
    status::Symbol
    steps::Int
    accepted::Int
    rejected::Int
    strain_step::Float64
end

"""
    compress!(system, params, timestep_start, force_floor) -> CompressionOutcome

From the accepted state (initially the start), repeat: shrink the box and every position
by `1 - strain_step`, minimize from rest, read the pressure. Within the band
`|P - P_target| <= pressure_tolerance * P_target` the trial is the packing. Below it the
trial is accepted; above it the trial is rejected and the strain step halves (it never
grows back). Every minimization step counts toward `steps_max`. The system is left at the
last trial.
"""
function compress!(s::System{D}, p::PackParams, timestep_start::Float64,
                   force_floor::Float64) where {D}
    target = p.target.value
    band = p.pressure_tolerance * target
    accepted_positions = copy(s.positions)
    accepted_side = s.side
    strain = p.protocol.strain_step
    accepted = 0
    rejected = 0
    steps = 0
    while true
        factor = 1 - strain
        s.side = factor * accepted_side
        @inbounds for i in eachindex(s.positions)
            s.positions[i] = factor * accepted_positions[i]
        end
        status, taken = minimize!(s, p.algorithm, timestep_start, p.convergence,
                                  force_floor, p.steps_max - steps)
        steps += taken
        status === :converged ||
            return CompressionOutcome(status, steps, accepted, rejected, strain)
        pressure = contact_pressure(s.table, s.side, D)
        if abs(pressure - target) <= band
            return CompressionOutcome(:converged, steps, accepted, rejected, strain)
        elseif pressure < target
            accepted += 1
            copyto!(accepted_positions, s.positions)
            accepted_side = s.side
        else
            rejected += 1
            strain /= 2
            strain < 1e-14 &&
                return CompressionOutcome(:strain_step_min, steps, accepted, rejected, strain)
        end
        steps < p.steps_max ||
            return CompressionOutcome(:steps_max, steps, accepted, rejected, strain)
    end
end
