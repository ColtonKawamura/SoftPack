# ---------------------------------------------------------------------------
#  Damped molecular dynamics (design §8): the three integrators differ in which
#  velocity the dashpot uses. Centered velocity Verlet (default) solves for the
#  end-of-step velocity, the lagged form uses the half-step velocity, the
#  semi-implicit Euler the previous one.
# ---------------------------------------------------------------------------

"""
    total_forces!(total_force, total_torque, system, algorithm, velocities, spins, drag_on)

Copy the elastic forces and torques and add every dissipative channel that is on.
"""
function total_forces!(total_force, total_torque, s::System, algorithm::Algorithm,
                       velocities, spins, drag_on::Bool)
    copyto!(total_force, s.forces)
    copyto!(total_torque, s.torques)
    add_dissipation!(total_force, total_torque, s, algorithm.damping, algorithm.drag,
                     velocities, spins, drag_on)
    return nothing
end

"""
    relax!(system, algorithm, timestep, test, context, steps_left, drag_on)
        -> (status, steps)

Relax the packing with `DampedDynamics` at the current box until `test` holds
(`status = :converged`) or `steps_left` steps are taken (`:steps_max`). The convergence
test runs after every step (design §5).
"""
function relax!(s::System{D,NR}, algorithm::DampedDynamics, timestep::Float64, test,
                ctx::ConvergenceContext, control::RunControl{D}, drag_on::Bool,
                steps_left::Int) where {D,NR}
    evaluate_forces!(s)
    total_force = similar(s.forces)
    total_torque = similar(s.torques)
    if algorithm.integrator === :semi_implicit_euler
        return relax_euler!(s, algorithm, timestep, test, ctx, control, steps_left,
                            drag_on, total_force, total_torque)
    elseif algorithm.integrator === :lagged_velocity_verlet
        return relax_lagged!(s, algorithm, timestep, test, ctx, control, steps_left,
                             drag_on, total_force, total_torque)
    end
    return relax_centered!(s, algorithm, timestep, test, ctx, control, steps_left,
                           drag_on, total_force, total_torque)
end

function relax_euler!(s::System{D,NR}, algorithm::DampedDynamics, timestep::Float64, test,
                      ctx::ConvergenceContext, control::RunControl{D}, steps_left::Int,
                      drag_on::Bool, total_force, total_torque) where {D,NR}
    step = 0
    while step < steps_left
        step += 1
        control.step += 1
        total_forces!(total_force, total_torque, s, algorithm, s.velocities, s.spins,
                      drag_on)
        dt = timestep
        @inbounds for i in eachindex(s.positions)
            s.velocities[i] += (dt / s.masses[i]) * total_force[i]
            s.spins[i] += (dt / s.moments[i]) * total_torque[i]
            s.positions[i] += dt * s.velocities[i]
            s.rotations[i] += dt * s.spins[i]
        end
        evaluate_forces!(s)
        record_step!(control, s)
        converged_now(test, s, ctx, contact_pressure(s.table, s.side, D), control.step,
                      control.params) && return (:converged, step)
    end
    return (:steps_max, step)
end

function relax_lagged!(s::System{D,NR}, algorithm::DampedDynamics, timestep::Float64, test,
                       ctx::ConvergenceContext, control::RunControl{D}, steps_left::Int,
                       drag_on::Bool, total_force, total_torque) where {D,NR}
    dt = timestep
    half_velocities = similar(s.velocities)
    half_spins = similar(s.spins)
    step = 0
    while step < steps_left
        step += 1
        control.step += 1
        @inbounds for i in eachindex(s.positions)
            s.positions[i] += dt * s.velocities[i] + 0.5 * dt^2 * s.accelerations[i]
            s.rotations[i] += dt * s.spins[i] + 0.5 * dt^2 * s.angular_accelerations[i]
            half_velocities[i] = s.velocities[i] + 0.5 * dt * s.accelerations[i]
            half_spins[i] = s.spins[i] + 0.5 * dt * s.angular_accelerations[i]
        end
        evaluate_forces!(s)
        total_forces!(total_force, total_torque, s, algorithm, half_velocities, half_spins,
                      drag_on)
        @inbounds for i in eachindex(s.positions)
            new_acceleration = total_force[i] / s.masses[i]
            new_angular = total_torque[i] / s.moments[i]
            s.velocities[i] += 0.5 * dt * (s.accelerations[i] + new_acceleration)
            s.spins[i] += 0.5 * dt * (s.angular_accelerations[i] + new_angular)
            s.accelerations[i] = new_acceleration
            s.angular_accelerations[i] = new_angular
        end
        record_step!(control, s)
        converged_now(test, s, ctx, contact_pressure(s.table, s.side, D), control.step,
                      control.params) && return (:converged, step)
    end
    return (:steps_max, step)
end

function relax_centered!(s::System{D,NR}, algorithm::DampedDynamics, timestep::Float64,
                         test, ctx::ConvergenceContext, control::RunControl{D},
                         steps_left::Int, drag_on::Bool,
                         total_force, total_torque) where {D,NR}
    dt = timestep
    per_particle = D + NR
    half_velocities = similar(s.velocities)
    half_spins = similar(s.spins)
    step = 0
    while step < steps_left
        step += 1
        control.step += 1
        @inbounds for i in eachindex(s.positions)
            s.positions[i] += dt * s.velocities[i] + 0.5 * dt^2 * s.accelerations[i]
            s.rotations[i] += dt * s.spins[i] + 0.5 * dt^2 * s.angular_accelerations[i]
            half_velocities[i] = s.velocities[i] + 0.5 * dt * s.accelerations[i]
            half_spins[i] = s.spins[i] + 0.5 * dt * s.angular_accelerations[i]
        end
        evaluate_forces!(s)
        solve_centered!(s, algorithm, dt, half_velocities, half_spins, drag_on)
        total_forces!(total_force, total_torque, s, algorithm, s.velocities, s.spins,
                      drag_on)
        @inbounds for i in eachindex(s.positions)
            s.accelerations[i] = total_force[i] / s.masses[i]
            s.angular_accelerations[i] = total_torque[i] / s.moments[i]
        end
        record_step!(control, s)
        converged_now(test, s, ctx, contact_pressure(s.table, s.side, D), control.step,
                      control.params) && return (:converged, step)
    end
    return (:steps_max, step)
end

"""
    solve_centered!(system, algorithm, dt, half_velocities, half_spins, drag_on)

The implicit half of the centered velocity Verlet (design §8):
`(M + dt/2 Gamma) v_{n+1} = M v_{n+1/2} + dt/2 F`, with `Gamma` from the contact table and,
with drag on, `a_v M` and `a_s I` on the diagonal. Without a damping model and drag the
matrix is diagonal and the solve is skipped.
"""
function solve_centered!(s::System{D,NR}, algorithm::DampedDynamics, dt::Float64,
                         half_velocities, half_spins, drag_on::Bool) where {D,NR}
    per_particle = D + NR
    count = length(s.positions)
    gamma = damping_matrix(s, algorithm.damping, algorithm.drag, drag_on)
    if nnz(gamma) == 0
        @inbounds for i in eachindex(s.positions)
            s.velocities[i] = half_velocities[i] + 0.5 * dt * s.forces[i] / s.masses[i]
            s.spins[i] = half_spins[i] + 0.5 * dt * s.torques[i] / s.moments[i]
        end
        return nothing
    end
    size_dof = per_particle * count
    diagonal = zeros(size_dof)
    @inbounds for i in 1:count
        base = dof_base(i, per_particle)
        for a in 1:D
            diagonal[base + a] = s.masses[i]
        end
        for a in 1:NR
            diagonal[base + D + a] = s.moments[i]
        end
    end
    matrix = (0.5 * dt) * gamma + Diagonal(diagonal)
    rhs = zeros(size_dof)
    @inbounds for i in 1:count
        base = dof_base(i, per_particle)
        for a in 1:D
            rhs[base + a] = s.masses[i] * half_velocities[i][a] +
                            0.5 * dt * s.forces[i][a]
        end
        for a in 1:NR
            rhs[base + D + a] = s.moments[i] * half_spins[i][a] +
                                0.5 * dt * s.torques[i][a]
        end
    end
    solution = cholesky(Symmetric(sparse(matrix))) \ rhs
    @inbounds for i in 1:count
        base = dof_base(i, per_particle)
        s.velocities[i] = SVector{D,Float64}(ntuple(a -> solution[base + a], Val(D)))
        s.spins[i] = SVector{NR,Float64}(ntuple(a -> solution[base + D + a], Val(NR)))
    end
    return nothing
end
