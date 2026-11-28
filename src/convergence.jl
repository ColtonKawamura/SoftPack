# ---------------------------------------------------------------------------
#  Convergence (design §5). The option decides rest at the current box; the
#  pressure band is checked by the compression protocol after every minimization.
# ---------------------------------------------------------------------------

"""
    RunState{D,NR}

A read-only view of the run handed to a user convergence or rattler function
(design §11): per particle `positions`, `velocities`, `rotations`, `spins`, `diameters`,
`masses`, `forces` and `torques` (elastic only); per contact `contact_first`,
`contact_second` (0 for a wall), `overlaps`, `normal_forces` and `tangential_forces`; the
box `box_side` and `boundary`; the run `pressure`, `step` and `settings`.

PROVISIONAL T-1x2y: the design says a write to a `RunState` throws; this build hands out
the arrays themselves, so changing them is possible but unsupported.
"""
struct RunState{D,NR,B,S}
    positions::Vector{SVector{D,Float64}}
    velocities::Vector{SVector{D,Float64}}
    rotations::Vector{SVector{NR,Float64}}
    spins::Vector{SVector{NR,Float64}}
    diameters::Vector{Float64}
    masses::Vector{Float64}
    moments_of_inertia::Vector{Float64}
    forces::Vector{SVector{D,Float64}}
    torques::Vector{SVector{NR,Float64}}
    contact_first::Vector{Int}
    contact_second::Vector{Int}
    overlaps::Vector{Float64}
    normal_forces::Vector{Float64}
    tangential_forces::Vector{SVector{D,Float64}}
    box_side::Float64
    boundary::B
    pressure::Float64
    step::Int
    settings::S
end

"""
    run_state(system, pressure, step, settings)

A `RunState` on the system's live arrays.
"""
run_state(s::System{D,NR}, pressure::Float64, step::Int, settings) where {D,NR} =
    RunState{D,NR,typeof(s.boundary),typeof(settings)}(
        s.positions, s.velocities, s.rotations, s.spins, s.diameters, s.masses,
        s.moments, s.forces, s.torques, s.table.first, s.table.second, s.table.overlaps,
        s.table.normal_forces, s.table.tangential_forces, s.side, s.boundary, pressure,
        step, settings)

"""
    ConvergenceContext

The scales the convergence tests use: the force floor, the mean diameter (torque scale),
the target pressure and the reference diameter (`KineticEnergy`), and the stiffness,
mass reference and dimension (`LeidenAcceleration`).
"""
struct ConvergenceContext
    force_floor::Float64
    mean_diameter::Float64
    target::Float64
    diameter_ref::Float64
    stiffness::Float64
    mass_ref::Float64
    dimension::Int
end

"""
    force_scale(state, force_floor)

The force scale of `RelativeForce`: the mean normal contact force, but never below
`force_floor = P_target * d_ref^(D-1) / 10`, so that a minimization with no or few
contacts can end (design §2, "Force floor").
"""
force_scale(state::RunState, force_floor::Float64) =
    isempty(state.normal_forces) ? force_floor :
    max(sum_in_order(state.normal_forces) / length(state.normal_forces), force_floor)

"""
    force_floor_for(pressure_target, diameter_ref, dimension)

`P_target d_ref^(D-1) / 10`, the floor of the force scale during the compression (design §2).
"""
force_floor_for(pressure_target::Float64, diameter_ref::Float64, dimension::Int) =
    pressure_target * (dimension == 2 ? diameter_ref : diameter_ref * diameter_ref) / 10

"""
    largest_force(forces)

`max_i |F_i|` over all particles.
"""
largest_force(forces::Vector{<:SVector}) =
    isempty(forces) ? 0.0 : sqrt(maximum(f -> dot_in_order(f, f), forces))

"""
    largest_torque(torques)

`max_i |T_i|` over all particles.
"""
largest_torque(torques::Vector{<:SVector}) =
    isempty(torques) ? 0.0 : sqrt(maximum(t -> dot_in_order(t, t), torques))

"""
    mean_kinetic_energy(state)

The mean kinetic energy per particle, translation and rotation together.
"""
function mean_kinetic_energy(state::RunState)
    total = 0.0
    @inbounds for i in eachindex(state.positions)
        total += 0.5 * state.masses[i] * dot_in_order(state.velocities[i], state.velocities[i])
        total += 0.5 * state.moments_of_inertia[i] *
                 dot_in_order(state.spins[i], state.spins[i])
    end
    return total / length(state.positions)
end

"""
    forces_at_rest(state, tolerance, force_floor, mean_diameter) -> Bool

The `RelativeForce` test (design §5): `max_i |F_i| < tolerance * scale`, and with a
frictional packing the same for the torques with `scale * <d>`.
"""
function forces_at_rest(state::RunState, tolerance::Float64, force_floor::Float64,
                        mean_diameter::Float64)
    scale = tolerance * force_scale(state, force_floor)
    largest_force(state.forces) < scale || return false
    if !isempty(state.torques) && any(!iszero, state.torques)
        largest_torque(state.torques) < scale * mean_diameter || return false
    end
    return true
end

"""
    is_converged(test, state, context) -> Bool

The option's rest test at the current box (design §5). A `true` ends the current
minimization; the pressure band is checked by the protocol afterwards.
"""
is_converged(test::RelativeForce, state::RunState, ctx::ConvergenceContext) =
    forces_at_rest(state, test.tolerance, ctx.force_floor, ctx.mean_diameter)

# The Leiden rule: every particle's acceleration below the tolerance, in reduced units
# (a unit = stiffness * d_ref / m_ref). PROVISIONAL T-ksjz: the design fixes the number
# 1e-10 for Leiden units; this conversion is my reading.
function is_converged(test::LeidenAcceleration, state::RunState, ctx::ConvergenceContext)
    unit = ctx.stiffness * ctx.diameter_ref / ctx.mass_ref
    threshold = test.tolerance * unit
    @inbounds for i in eachindex(state.forces)
        sqrt(dot_in_order(state.forces[i], state.forces[i])) / state.masses[i] < threshold ||
            return false
        if !iszero(state.torques[i])
            # a rotational acceleration times d_ref, in the same units
            sqrt(dot_in_order(state.torques[i], state.torques[i])) /
                state.moments_of_inertia[i] * ctx.diameter_ref < threshold || return false
        end
    end
    return true
end

function is_converged(test::KineticEnergy, state::RunState, ctx::ConvergenceContext)
    forces_at_rest(state, 1e-8, ctx.force_floor, ctx.mean_diameter) || return false
    energy_scale = ctx.target * ctx.diameter_ref^ctx.dimension
    return mean_kinetic_energy(state) < test.tolerance * energy_scale
end

is_converged(test::RestartTest, state::RunState, ctx::ConvergenceContext) =
    forces_at_rest(state, 1e-8, ctx.force_floor, ctx.mean_diameter)

is_converged(test::Function, state::RunState, ctx::ConvergenceContext) = test(state) === true

"""
    float64_floor_warning(params, diameters, diameter_ref)

Warn at run start when `Float64` positions cannot reach the force test (card T-2brz,
option 1). Near a coordinate `x` positions move in steps of `eps(x)`, so the residual
force cannot fall much below `2 k eps(L)`, with `L` the box side (wiki, Convergence
criterion, "Floating-point floor"). Two thresholds are checked:

- at the target, `tolerance * <f_n>`, with the side and the mean force estimated from
  `phi = 0.84` (2D) or `0.64` (3D) and `z = 2D` contacts per particle;
- during the compression, `tolerance * f_floor` with `f_floor = P_target d_ref^(D-1) / 10`
  (design §2). A compression step can leave contacts whose overlaps are pure round-off, at
  any packing fraction; only this floor then sets the test, and when it is out of reach
  the minimization stalls until `steps_max` (seen at `P_target = 1e-6`, `N = 256`: 5 of 5
  seeds, some at packing fraction 0.67).
"""
function float64_floor_warning(p::PackParams, diameters::Vector{Float64},
                               diameter_ref::Float64)
    hasproperty(p.convergence, :tolerance) || return nothing
    dimension = p.dimension
    count = length(diameters)
    tolerance = p.convergence.tolerance
    packing_fraction_jamming = dimension == 2 ? 0.84 : 0.64
    volume = total_volume(diameters, dimension) / packing_fraction_jamming
    side = box_side_for(volume, 1.0, dimension)
    diameter_mean = sum_in_order(diameters) / count
    contacts_per_particle = 2 * dimension
    # P = sum_c f l / (D V) with N z / 2 contacts of length <d>  =>  <f> = 2 D V P / (N z <d>)
    force_mean = 2 * dimension * volume * p.target.value /
                 (count * contacts_per_particle * diameter_mean)
    force_floor = force_floor_for(p.target.value, diameter_ref, dimension)
    stiffness = p.contact.stiffness
    if p.contact isa Hertzian
        overlap = expected_overlap(p.contact, stiffness, p.target.value, diameter_ref,
                                   dimension, packing_fraction_jamming)
        stiffness = contact_stiffness(p.contact, overlap)
    end
    floor_estimate = 2 * stiffness * eps(side)
    if tolerance * force_mean < floor_estimate
        @warn "The force tolerance is probably out of reach of Float64 positions: at the " *
              "target it asks for net forces below " *
              (@sprintf "%.1e" tolerance * force_mean) *
              ", and positions near the box side $(round(side; sigdigits = 3)) can only " *
              "reach about " * (@sprintf "%.1e" floor_estimate) * ". Expect the run to stop " *
              "at steps_max with converged = false; a looser tolerance or a higher " *
              "target pressure avoids it."
    elseif tolerance * force_floor < floor_estimate
        @warn "The compression's force floor is probably out of reach of Float64 positions: " *
              "a compression step that leaves contacts with round-off overlaps must bring " *
              "every net force below " * (@sprintf "%.1e" tolerance * force_floor) *
              " (tolerance times P_target d_ref^(D-1)/10), and positions near the box side " *
              "$(round(side; sigdigits = 3)) can only reach about " *
              (@sprintf "%.1e" floor_estimate) * ". Such a step stalls until steps_max " *
              "and the run returns converged = false; a looser tolerance or a higher " *
              "target pressure avoids it."
    end
    return nothing
end

"""
    converged_now(test, system, context, pressure, step, settings) -> Bool

The same rest test as [`is_converged`](@ref), read straight from the system: the built-in
tests avoid building a `RunState` every step, and only a user function gets one.
"""
function converged_now(test, s::System, ctx::ConvergenceContext, pressure::Float64,
                       step::Int, settings)
    return is_converged(test, run_state(s, pressure, step, settings), ctx)
end

function converged_now(test::RelativeForce, s::System, ctx::ConvergenceContext,
                       pressure::Float64, step::Int, settings)
    return forces_at_rest(s, test.tolerance, ctx.force_floor, ctx.mean_diameter)
end

function converged_now(test::LeidenAcceleration, s::System, ctx::ConvergenceContext,
                       pressure::Float64, step::Int, settings)
    unit = ctx.stiffness * ctx.diameter_ref / ctx.mass_ref
    threshold = test.tolerance * unit
    @inbounds for i in eachindex(s.forces)
        sqrt(dot_in_order(s.forces[i], s.forces[i])) / s.masses[i] < threshold ||
            return false
        if !iszero(s.torques[i])
            sqrt(dot_in_order(s.torques[i], s.torques[i])) / s.moments[i] *
                ctx.diameter_ref < threshold || return false
        end
    end
    return true
end

function converged_now(test::KineticEnergy, s::System, ctx::ConvergenceContext,
                       pressure::Float64, step::Int, settings)
    forces_at_rest(s, 1e-8, ctx.force_floor, ctx.mean_diameter) || return false
    energy_scale = ctx.target * ctx.diameter_ref^ctx.dimension
    return mean_kinetic_energy(s) < test.tolerance * energy_scale
end

function converged_now(test::RestartTest, s::System, ctx::ConvergenceContext,
                       pressure::Float64, step::Int, settings)
    return forces_at_rest(s, 1e-8, ctx.force_floor, ctx.mean_diameter)
end

"""
    forces_at_rest(system, tolerance, force_floor, mean_diameter)

The `RelativeForce` test on the live system (design §5).
"""
function forces_at_rest(s::System, tolerance::Float64, force_floor::Float64,
                        mean_diameter::Float64)
    scale = tolerance * force_scale(s.table, force_floor)
    largest_force(s.forces) < scale || return false
    if any(!iszero, s.torques)
        largest_torque(s.torques) < scale * mean_diameter || return false
    end
    return true
end

"""
    force_scale(table, force_floor)

The mean normal contact force, never below the floor (design §2).
"""
force_scale(table::ContactTable, force_floor::Float64) =
    isempty(table.normal_forces) ? force_floor :
    max(sum_in_order(table.normal_forces) / length(table.normal_forces), force_floor)

"""
    mean_kinetic_energy(system)

The mean kinetic energy per particle of the live system, translation and rotation.
"""
function mean_kinetic_energy(s::System)
    total = 0.0
    @inbounds for i in eachindex(s.positions)
        total += 0.5 * s.masses[i] * dot_in_order(s.velocities[i], s.velocities[i])
        total += 0.5 * s.moments[i] * dot_in_order(s.spins[i], s.spins[i])
    end
    return total / length(s.positions)
end
