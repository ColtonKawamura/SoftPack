# ---------------------------------------------------------------------------
#  FIRE 2.0 (design §14), one minimization at a fixed box.
#
#  The step rules are Algorithm 2 of the wiki's FIRE settings page, adopted with
#  card T-vcne (option 1). They match LAMMPS `min_fire.cpp` (develop, read
#  2026-11-26): the step grows only after MORE than `delay` downhill steps; the
#  mixing coefficient shrinks on every such step, also once the step sits at its
#  maximum; every counted uphill step resets the mixing coefficient and shrinks
#  the step, unless the shrink would go below the minimum, in which case it is
#  skipped (not clamped); uphill steps inside the initial delay change neither;
#  the run stops after MORE than `uphill_max` consecutive uphill steps. The three
#  LAMMPS details: the mixing acts on the kicked velocity, its magnitude is |v|
#  from before the kick, and the forces are evaluated again after the half step
#  back.
# ---------------------------------------------------------------------------

"""
    FireState

FIRE's adaptive state: the current step, its limits, the mixing coefficient and the
downhill and uphill counters.
"""
mutable struct FireState
    timestep::Float64
    timestep_max::Float64
    timestep_min::Float64
    mixing::Float64
    downhill_count::Int
    uphill_count::Int
end

FireState(fire::FIRE, timestep_start::Float64) = FireState(timestep_start,
    fire.timestep_max * timestep_start, fire.timestep_min * timestep_start,
    fire.mixing_coefficient, 0, 0)

"""
    downhill!(state, fire)

Power `F . v > 0`: count it, and after more than `delay` of them in a row grow the step
(up to its maximum) and shrink the mixing coefficient.
"""
function downhill!(st::FireState, fire::FIRE)
    st.downhill_count += 1
    st.uphill_count = 0
    if st.downhill_count > fire.delay
        st.timestep = min(fire.timestep_grow * st.timestep, st.timestep_max)
        st.mixing *= fire.mixing_shrink
    end
    return st
end

"""
    uphill!(state, fire, step) -> Bool

Power `F . v <= 0`: count it and, outside the initial delay, shrink the step (skipped if
it would go below the minimum) and reset the mixing coefficient. Returns `true` when more
than `uphill_max` uphill steps have come in a row, which ends the run.
"""
function uphill!(st::FireState, fire::FIRE, step::Int)
    st.downhill_count = 0
    st.uphill_count += 1
    st.uphill_count > fire.uphill_max && return true
    if !(fire.delay_initial && step < fire.delay)
        shrunk = fire.timestep_shrink * st.timestep
        if shrunk >= st.timestep_min
            st.timestep = shrunk
        end
        st.mixing = fire.mixing_coefficient
    end
    return false
end

"""
    minimize!(system, fire, timestep_start, test, force_floor, steps_left)
        -> (status, steps)

Minimize the energy at the current box with FIRE, from rest with every counter reset,
until `test` holds (`status = :converged`), more than `uphill_max` uphill steps come in a
row (`:uphill_max`), or `steps_left` steps have been taken (`:steps_max`). The integrator
is the semi-implicit Euler scheme. The convergence test runs after every step.
"""
function minimize!(s::System{D}, fire::FIRE, timestep_start::Float64, test,
                   force_floor::Float64, steps_left::Int) where {D}
    st = FireState(fire, timestep_start)
    positions, velocities, forces, masses = s.positions, s.velocities, s.forces, s.masses
    fill!(velocities, zero(SVector{D,Float64}))
    evaluate_forces!(s)
    step = 0
    while step < steps_left
        step += 1
        power = 0.0
        @inbounds for i in eachindex(forces)
            power += dot_in_order(forces[i], velocities[i])
        end
        if power > 0
            downhill!(st, fire)
            mix = true
            speed = sqrt(sum_in_order(v -> dot_in_order(v, v), velocities))   # |v| before the kick
        else
            uphill!(st, fire, step) && return (:uphill_max, step)
            if fire.inertia_correction                       # half step back, new step size
                half = st.timestep / 2
                @inbounds for i in eachindex(positions)
                    positions[i] -= half * velocities[i]
                end
            end
            fill!(velocities, zero(SVector{D,Float64}))
            evaluate_forces!(s)
            mix = false
            speed = 0.0
        end
        dt = st.timestep
        @inbounds for i in eachindex(velocities)             # kick
            velocities[i] += (dt / masses[i]) * forces[i]
        end
        if mix
            force_norm = sqrt(sum_in_order(f -> dot_in_order(f, f), forces))
            keep = 1 - st.mixing
            # PROVISIONAL T-vcne (F = 0 case): the force term is dropped only when the net
            # force is exactly zero. LAMMPS drops it below |F|^2 = 1e-20, a cutoff in its own
            # units that at SoftPack's pressures would act near convergence.
            steer = force_norm > 0 ? st.mixing * speed / force_norm : 0.0
            @inbounds for i in eachindex(velocities)
                velocities[i] = keep * velocities[i] + steer * forces[i]
            end
        end
        @inbounds for i in eachindex(positions)               # drift
            positions[i] += dt * velocities[i]
        end
        evaluate_forces!(s)
        is_converged(test, s, force_floor) && return (:converged, step)
    end
    return (:steps_max, step)
end
