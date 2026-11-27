# ---------------------------------------------------------------------------
#  Damping (design §8): the algorithm forms the dashpot coefficients from its
#  damping setting, the contact table's stiffnesses and the masses and moments of
#  inertia it holds. The force model never sees a velocity (§7).
# ---------------------------------------------------------------------------

"""
    dashpot_coefficients(damping, table, c, masses, moments, dimension) -> (gamma_n, gamma_t)

The normal and tangential dashpot coefficients of contact `c`.

- `ContactDamping`: each direction is its fraction of its own critical value,
  `gamma_n = 2 zeta_n sqrt(k_n M_n)` and `gamma_t = 2 zeta_t sqrt(k_t M_t)`, with `M_n` the
  reduced mass of the pair (the particle's mass at a wall) and `M_t` the sliding mass that
  includes the rotation (`tangential_mass = :with_rotation`) or `M_n` (`:pair`).
- `ViscousRate`: `gamma = M_n * rate` in both directions, the LAMMPS convention.
"""
function dashpot_coefficients(damping::ContactDamping, table::ContactTable{D}, c::Int,
                              masses, moments, dimension::Int) where {D}
    i = table.first[c]
    j = table.second[c]
    mass_normal = j == 0 ? masses[i] : 1 / (1 / masses[i] + 1 / masses[j])
    if j == 0
        inverse_tangential = 1 / masses[i] + table.levers_first[c]^2 / moments[i]
    else
        inverse_tangential = 1 / masses[i] + 1 / masses[j] +
                             table.levers_first[c]^2 / moments[i] +
                             table.levers_second[c]^2 / moments[j]
    end
    mass_tangential = damping.tangential_mass === :pair ?
        mass_normal : 1 / inverse_tangential
    gamma_normal = 2 * damping.normal * sqrt(table.normal_stiffnesses[c] * mass_normal)
    gamma_tangential = table.tangential_stiffnesses[c] > 0 ?
        2 * damping.tangential *
        sqrt(table.tangential_stiffnesses[c] * mass_tangential) : 0.0
    return gamma_normal, gamma_tangential
end

function dashpot_coefficients(damping::ViscousRate, table::ContactTable{D}, c::Int,
                              masses, moments, dimension::Int) where {D}
    i = table.first[c]
    j = table.second[c]
    mass_normal = j == 0 ? masses[i] : 1 / (1 / masses[i] + 1 / masses[j])
    gamma_normal = mass_normal * damping.normal
    gamma_tangential = table.tangential_stiffnesses[c] > 0 ?
        mass_normal * damping.tangential : 0.0
    return gamma_normal, gamma_tangential
end

"""
    contact_velocity(table, c, velocities, spins)

The relative velocity of the two contact points, `u_i - u_j`, with the lever arms of the
table (the wall does not move).
"""
@inline function contact_velocity(table::ContactTable{D}, c::Int, velocities, spins) where {D}
    i = table.first[c]
    j = table.second[c]
    n = table.normals[c]
    radius_first = -table.levers_first[c] * n
    u = velocities[i] + spin_cross(spins[i], radius_first)
    if j != 0
        radius_second = table.levers_second[c] * n
        u -= velocities[j] + spin_cross(spins[j], radius_second)
    end
    return u
end

"""
    add_contact_dashpots!(forces, torques, system, damping, velocities, spins)

Add the contact dashpots of `damping` to `forces` and `torques`, evaluated on the given
velocities and spins. `attractive = false` clips the normal dashpot so the total normal
force never pulls, and a sliding contact has its tangential dashpot off (design §8).
"""
function add_contact_dashpots!(forces, torques, s::System{D,NR}, damping::DampingModel,
                               velocities, spins) where {D,NR}
    table = s.table
    @inbounds for c in eachindex(table.first)
        i = table.first[c]
        j = table.second[c]
        n = table.normals[c]
        u = contact_velocity(table, c, velocities, spins)
        normal_speed = dot_in_order(u, n)
        tangential_speed = u - normal_speed * n
        gamma_normal, gamma_tangential =
            dashpot_coefficients(damping, table, c, s.masses, s.moments, D)
        f_normal = -gamma_normal * normal_speed
        if !damping.attractive && table.normal_forces[c] + f_normal < 0
            f_normal = -table.normal_forces[c]
        end
        f_tangential = (table.sliding[c] || gamma_tangential == 0) ?
            zero(SVector{D,Float64}) : -gamma_tangential * tangential_speed
        increment = f_normal * n + f_tangential
        forces[i] += increment
        torques[i] += position_cross(-table.levers_first[c] * n, f_tangential)
        if j != 0
            forces[j] -= increment
            torques[j] += position_cross(table.levers_second[c] * n, -f_tangential)
        end
    end
    return nothing
end

"""
    add_relative_velocity_dashpots!(forces, torques, system, damping, velocities, spins)

The `RelativeVelocityDamping` model: one dashpot `-gamma (v_i - v_j)` on the centers'
relative velocity, with `gamma = M_n rate`. It applies no torque (design §8).
"""
function add_relative_velocity_dashpots!(forces, torques, s::System{D}, damping::RelativeVelocityDamping,
                                         velocities, spins) where {D}
    table = s.table
    @inbounds for c in eachindex(table.first)
        i = table.first[c]
        j = table.second[c]
        j == 0 && continue                       # the wall does not move; handled as a pair
        relative = velocities[i] - velocities[j]
        mass_normal = 1 / (1 / s.masses[i] + 1 / s.masses[j])
        increment = -mass_normal * damping.rate * relative
        if !damping.attractive
            n = table.normals[c]
            normal = dot_in_order(increment, n)
            if table.normal_forces[c] + normal < 0
                increment += (-table.normal_forces[c] - normal) * n
            end
        end
        forces[i] += increment
        forces[j] -= increment
    end
    return nothing
end

"""
    add_drag!(forces, torques, system, drag, velocities, spins)

Stokes drag: `-velocity m v` on the translation and `-spin I omega` on the rotation
(design §8).
"""
function add_drag!(forces, torques, s::System{D}, drag::StokesDrag, velocities, spins) where {D}
    @inbounds for i in eachindex(forces)
        forces[i] += -drag.velocity * s.masses[i] * velocities[i]
        torques[i] += -drag.spin * s.moments[i] * spins[i]
    end
    return nothing
end

"""
    add_dissipation!(forces, torques, system, damping, drag, velocities, spins, drag_on)

Elastic forces are already in `forces`/`torques`; add every dissipative channel that is on.
"""
function add_dissipation!(forces, torques, s::System, damping, drag, velocities, spins,
                          drag_on::Bool)
    if damping isa ContactDamping || damping isa ViscousRate
        add_contact_dashpots!(forces, torques, s, damping, velocities, spins)
    elseif damping isa RelativeVelocityDamping
        add_relative_velocity_dashpots!(forces, torques, s, damping, velocities, spins)
    end
    drag_on && drag !== nothing && add_drag!(forces, torques, s, drag, velocities, spins)
    return nothing
end

# --- The damping matrix of the centered velocity Verlet (§8, "Integrator") ---

@inline dof_base(i::Int, per_particle::Int) = (i - 1) * per_particle

"""
    damping_matrix(system, damping, drag, dimension, drag_on)

The matrix `Gamma` of the centered velocity Verlet's solve,
`(M + dt/2 Gamma) v = M v_half + dt/2 F`. Each contact contributes
`gamma_n g_n g_n' + gamma_t (g_t1 g_t1' + g_t2 g_t2')`, with `g` the gradient of the
contact point's relative velocity with respect to the degrees of freedom; the drag adds
`a_v M` on translations and `a_s I` on rotations (design §8).
"""
function damping_matrix(s::System{D,NR}, damping, drag, drag_on::Bool) where {D,NR}
    per_particle = D + NR
    count = length(s.positions)
    size_dof = per_particle * count
    rows = Int[]
    columns = Int[]
    values = Float64[]
    zero_radius = zero(SVector{D,Float64})
    @inbounds for c in eachindex(s.table.first)
        i = s.table.first[c]
        j = s.table.second[c]
        n = s.table.normals[c]
        gamma_normal = 0.0
        gamma_tangential = 0.0
        rotating = true
        if damping isa ContactDamping || damping isa ViscousRate
            gamma_normal, gamma_tangential =
                dashpot_coefficients(damping, s.table, c, s.masses, s.moments, D)
            s.table.sliding[c] && (gamma_tangential = 0.0)
        elseif damping isa RelativeVelocityDamping
            mass_normal = j == 0 ? s.masses[i] :
                1 / (1 / s.masses[i] + 1 / s.masses[j])
            gamma_normal = mass_normal * damping.rate
            gamma_tangential = gamma_normal
            rotating = false                          # no torque from this model
        end
        (gamma_normal == 0 && gamma_tangential == 0) && continue
        radius_first = rotating ? -s.table.levers_first[c] * n : zero_radius
        radius_second = rotating && j != 0 ? s.table.levers_second[c] * n : zero_radius
        dofs = j == 0 ? collect(dof_base(i, per_particle) .+ (1:per_particle)) :
            vcat(collect(dof_base(i, per_particle) .+ (1:per_particle)),
                 collect(dof_base(j, per_particle) .+ (1:per_particle)))
        local_size = length(dofs)
        pair = j != 0
        accumulate = (direction, gamma) -> begin
            gamma == 0 && return nothing
            gradient = contact_gradient(dofs, direction, radius_first, radius_second,
                                        NR, pair)
            for a in 1:local_size
                gradient[a] == 0 && continue
                for b in 1:local_size
                    value = gamma * gradient[a] * gradient[b]
                    value == 0 && continue
                    push!(rows, dofs[a])
                    push!(columns, dofs[b])
                    push!(values, value)
                end
            end
            return nothing
        end
        accumulate(n, gamma_normal)
        for t in tangent_basis(n)
            accumulate(t, gamma_tangential)
        end
    end
    if drag_on && drag !== nothing
        for i in 1:count
            base = dof_base(i, per_particle)
            for a in 1:D
                push!(rows, base + a); push!(columns, base + a)
                push!(values, drag.velocity * s.masses[i])
            end
            for a in 1:NR
                push!(rows, base + D + a); push!(columns, base + D + a)
                push!(values, drag.spin * s.moments[i])
            end
        end
    end
    return sparse(rows, columns, values, size_dof, size_dof)
end

"""
    tangent_basis(n)

One unit tangent in 2D, two orthonormal tangents in 3D.
"""
function tangent_basis(n::SVector{2,Float64})
    return (tangent(n),)
end

function tangent_basis(n::SVector{3,Float64})
    t1 = tangent(n)
    t2 = SVector(n[2] * t1[3] - n[3] * t1[2],
                 n[3] * t1[1] - n[1] * t1[3],
                 n[1] * t1[2] - n[2] * t1[1])
    return (t1, t2)
end

"""
    contact_gradient(dofs, direction, radius_first, radius_second, D, NR, pair)

The gradient of the contact point's relative velocity along `direction` with respect to
the local degrees of freedom `[v_i, omega_i]` (and `[v_j, omega_j]` when `pair`): the
direction on each translation, and `(omega x r) . direction` on each rotation.
"""
function contact_gradient(dofs, direction::SVector{D,Float64},
                          radius_first::SVector{D,Float64},
                          radius_second::SVector{D,Float64}, NR::Int,
                          pair::Bool) where {D}
    gradient = zeros(length(dofs))
    @inbounds for a in 1:D
        gradient[a] = direction[a]
    end
    @inbounds for k in 1:NR
        unit = SVector{NR,Float64}(ntuple(b -> b == k ? 1.0 : 0.0, Val(NR)))
        gradient[D + k] = dot_in_order(spin_cross(unit, radius_first), direction)
    end
    if pair
        @inbounds for a in 1:D
            gradient[D + NR + a] = -direction[a]
        end
        @inbounds for k in 1:NR
            unit = SVector{NR,Float64}(ntuple(b -> b == k ? 1.0 : 0.0, Val(NR)))
            gradient[D + NR + D + k] =
                -dot_in_order(spin_cross(unit, radius_second), direction)
        end
    end
    return gradient
end
