# ---------------------------------------------------------------------------
#  The force model (design §7): it owns the contact list and the contact history,
#  and hands out, after every force evaluation, one table with a row per contact.
#  The algorithm, the pressure, the convergence test and the rattler rules all
#  read that table. Velocities never enter the force model; damping stays a
#  setting of the algorithm (§7, §8).
# ---------------------------------------------------------------------------

"""
    ContactTable{D}

One row per contact (design §7), as plain columns:

- `first`, `second`: the two particles (`first < second`); for a wall contact `second`
  is 0 and `wall_id` says which wall.
- `wall_id`: 0 for a pair contact, `2 (axis - 1) + 1` for the lower wall of an axis and
  `2 (axis - 1) + 2` for the upper one.
- `normals`: unit normal, pointing from `second` to `first` (from the wall inward).
- `branches`: branch vector `r_first - r_second` (nearest image); for a wall contact the
  vector from the particle's center to the wall, of length `h`.
- `overlaps`: positive overlap of the contact.
- `normal_stiffnesses`: `dF/d(overlap)` of the normal law at this overlap.
- `tangential_stiffnesses`: `k_t` of the friction model (0 without friction).
- `normal_forces`: the elastic normal force (repulsive, positive).
- `tangential_forces`: the elastic tangential force vector on `first` (0 without friction).
- `levers_first`, `levers_second`: the lever arms `R_i`, `R_j` (0 for a wall).
- `sliding`: the sliding flag stored at the end of the previous step (§7), so the
  centered integrator can assemble its damping matrix before the solve.
"""
struct ContactTable{D}
    first::Vector{Int}
    second::Vector{Int}
    wall_id::Vector{Int}
    normals::Vector{SVector{D,Float64}}
    branches::Vector{SVector{D,Float64}}
    overlaps::Vector{Float64}
    normal_stiffnesses::Vector{Float64}
    tangential_stiffnesses::Vector{Float64}
    normal_forces::Vector{Float64}
    tangential_forces::Vector{SVector{D,Float64}}
    levers_first::Vector{Float64}
    levers_second::Vector{Float64}
    sliding::Vector{Bool}
end

ContactTable{D}() where {D} = ContactTable{D}(Int[], Int[], Int[], SVector{D,Float64}[],
    SVector{D,Float64}[], Float64[], Float64[], Float64[], Float64[],
    SVector{D,Float64}[], Float64[], Float64[], Bool[])

Base.length(t::ContactTable) = length(t.first)

function Base.empty!(t::ContactTable)
    for column in (t.first, t.second, t.wall_id, t.normals, t.branches, t.overlaps,
                   t.normal_stiffnesses, t.tangential_stiffnesses, t.normal_forces,
                   t.tangential_forces, t.levers_first, t.levers_second, t.sliding)
        empty!(column)
    end
    return t
end

Base.copy(t::ContactTable{D}) where {D} = ContactTable{D}(copy(t.first), copy(t.second),
    copy(t.wall_id), copy(t.normals), copy(t.branches), copy(t.overlaps),
    copy(t.normal_stiffnesses), copy(t.tangential_stiffnesses), copy(t.normal_forces),
    copy(t.tangential_forces), copy(t.levers_first), copy(t.levers_second),
    copy(t.sliding))

# Contact laws: force, energy and stiffness as functions of the overlap (design §2).
@inline contact_force(law::Hookean, overlap::Float64) = law.stiffness * overlap
@inline contact_energy(law::Hookean, overlap::Float64) = law.stiffness * overlap^2 / 2
@inline contact_stiffness(law::Hookean, overlap::Float64) = law.stiffness

@inline contact_force(law::Hertzian, overlap::Float64) =
    law.stiffness * overlap * sqrt(overlap)
@inline contact_energy(law::Hertzian, overlap::Float64) =
    0.4 * law.stiffness * overlap^2 * sqrt(overlap)
@inline contact_stiffness(law::Hertzian, overlap::Float64) =
    1.5 * law.stiffness * sqrt(overlap)

"""
    tangential_stiffness(friction, normal_stiffness, dimension)

`CundallStrack`: `stiffness_ratio * k_n`, with `:matched` giving `1/(1 + mR^2/I)` (1/3 in
2D, 2/7 in 3D, design §13). `Mindlin`: `eta * k_n` with
`eta = 2 (1 - nu)/(2 - nu)` (design §13).
"""
function tangential_stiffness(f::CundallStrack, normal_stiffness::Float64, dimension::Int)
    ratio = f.stiffness_ratio === :matched ?
        1 / (1 + inertia_ratio(dimension)) : f.stiffness_ratio
    return ratio * normal_stiffness
end

function tangential_stiffness(f::Mindlin, normal_stiffness::Float64, dimension::Int)
    eta = 2 * (1 - f.poisson_ratio) / (2 - f.poisson_ratio)
    return eta * normal_stiffness
end

"""
    System{D,NR}

Everything a run changes or reads: positions, velocities, rotations and spins, the net
elastic forces and torques, the total accelerations of the last step (the velocity Verlet
half-step state), the box side, the force model (contact law, friction model, boundary),
the neighbor list with its contact history, and the contact table of the last evaluation.
"""
mutable struct System{D,NR,L<:ContactLaw,F,BD}
    positions::Vector{SVector{D,Float64}}
    velocities::Vector{SVector{D,Float64}}
    rotations::Vector{SVector{NR,Float64}}
    spins::Vector{SVector{NR,Float64}}
    forces::Vector{SVector{D,Float64}}
    torques::Vector{SVector{NR,Float64}}
    accelerations::Vector{SVector{D,Float64}}
    angular_accelerations::Vector{SVector{NR,Float64}}
    diameters::Vector{Float64}
    masses::Vector{Float64}
    moments::Vector{Float64}
    side::Float64
    law::L
    friction::F
    boundary::BD
    neighbors::NeighborList{D}
    table::ContactTable{D}
    wall_tangential::Matrix{SVector{D,Float64}}
    wall_sliding::Matrix{Bool}
    last_positions::Vector{SVector{D,Float64}}
    last_rotations::Vector{SVector{NR,Float64}}
    stepped::Vector{SVector{D,Float64}}
    turned::Vector{SVector{NR,Float64}}
    energy::Float64
    force_evaluations::Int
end

function System(positions::Vector{SVector{D,Float64}}, diameters::Vector{Float64},
                masses::Vector{Float64}, side::Float64, law::ContactLaw,
                friction, boundary::Boundary;
                skin = 0.4 * minimum(diameters), moments = nothing) where {D}
    count = length(positions)
    NR = rotation_count(D)
    masses = masses
    moments = moments === nothing ?
        [moment_of_inertia(masses[i], diameters[i], D) for i in 1:count] : moments
    zero_translation = fill(zero(SVector{D,Float64}), count)
    zero_rotation = fill(zero(SVector{NR,Float64}), count)
    walls = boundary isa Periodic ? 0 : 2 * D
    return System{D,NR,typeof(law),typeof(friction),typeof(boundary)}(
        copy(positions), copy(zero_translation), copy(zero_rotation), copy(zero_rotation),
        copy(zero_translation), copy(zero_rotation), copy(zero_translation),
        copy(zero_rotation), diameters, masses, moments, side, law, friction, boundary,
        NeighborList{D}(skin), ContactTable{D}(),
        zeros(SVector{D,Float64}, walls, count), falses(walls, count),
        copy(positions), copy(zero_rotation), copy(zero_translation),
        copy(zero_rotation), 0.0, 0)
end

System(positions::Vector{SVector{D,Float64}}, diameters::Vector{Float64},
       masses::Vector{Float64}, side::Float64, law::ContactLaw; kwargs...) where {D} =
    System(positions, diameters, masses, side, law, nothing, Periodic(); kwargs...)

periodic(s::System) = s.boundary isa Periodic
wall_friction(s::System) = s.friction !== nothing && s.boundary isa Walls &&
                           s.boundary.friction

"""
    evaluate_forces!(system)

Refresh the neighbor list if needed, then compute every net elastic force and torque, the
elastic energy, and the contact table at the current positions. Friction springs advance
from the displacement and rotation since the last evaluation (design §7).
"""
function evaluate_forces!(s::System{D,NR}) where {D,NR}
    is_periodic = periodic(s)
    needs_rebuild(s.neighbors, s.positions, s.side) &&
        build!(s.neighbors, s.positions, s.diameters, s.side, is_periodic)
    table = empty!(s.table)
    forces, torques = s.forces, s.torques
    fill!(forces, zero(SVector{D,Float64}))
    fill!(torques, zero(SVector{NR,Float64}))
    stepped, turned = s.stepped, s.turned
    @inbounds for i in eachindex(s.positions)
        stepped[i] = separation(s.positions[i], s.last_positions[i], s.side, is_periodic)
        turned[i] = s.rotations[i] - s.last_rotations[i]
    end
    energy = 0.0
    side = s.side
    list = s.neighbors
    @inbounds for p in eachindex(list.first)
        i = list.first[p]
        j = list.second[p]
        branch = separation(s.positions[i], s.positions[j], side, is_periodic)
        contact_distance = (s.diameters[i] + s.diameters[j]) / 2
        distance_squared = dot_in_order(branch, branch)
        if distance_squared >= contact_distance^2
            list.tangential[p] = zero(SVector{D,Float64})
            list.sliding[p] = false
            continue
        end
        distance = sqrt(distance_squared)
        overlap = contact_distance - distance
        normal = branch / distance
        force = contact_force(s.law, overlap)
        stiffness = contact_stiffness(s.law, overlap)
        lever_first = s.diameters[i] / 2
        lever_second = s.diameters[j] / 2
        radius_first = -lever_first * normal          # center to contact point
        radius_second = lever_second * normal
        tangential_force = zero(SVector{D,Float64})
        tangential_k = 0.0
        flag = list.sliding[p]                        # the previous step's flag (§7)
        if s.friction !== nothing
            tangential_k = tangential_stiffness(s.friction, stiffness, D)
            stretch = project_onto_plane(list.tangential[p], normal)
            relative = stepped[i] - stepped[j]
            slide = project_onto_plane(relative, normal) +
                    spin_cross(turned[i], radius_first) -
                    spin_cross(turned[j], radius_second)
            stretch += slide
            magnitude = sqrt(dot_in_order(stretch, stretch))
            cap = s.friction.friction_coefficient * force
            if tangential_k * magnitude > cap && magnitude > 0
                stretch *= cap / (tangential_k * magnitude)
                list.sliding[p] = true
            else
                list.sliding[p] = false
            end
            list.tangential[p] = stretch
            tangential_force = -tangential_k * stretch
            forces[i] += tangential_force
            forces[j] -= tangential_force
            torques[i] += position_cross(radius_first, tangential_force)
            torques[j] += position_cross(radius_second, -tangential_force)
        end
        forces[i] += force * normal
        forces[j] -= force * normal
        energy += contact_energy(s.law, overlap)
        push!(table.first, i)
        push!(table.second, j)
        push!(table.wall_id, 0)
        push!(table.normals, normal)
        push!(table.branches, branch)
        push!(table.overlaps, overlap)
        push!(table.normal_stiffnesses, stiffness)
        push!(table.tangential_stiffnesses, tangential_k)
        push!(table.normal_forces, force)
        push!(table.tangential_forces, tangential_force)
        push!(table.levers_first, lever_first)
        push!(table.levers_second, lever_second)
        push!(table.sliding, flag)
    end
    if s.boundary isa Walls
        energy += wall_contacts!(s, table, stepped, turned)
    end
    copyto!(s.last_positions, s.positions)
    copyto!(s.last_rotations, s.rotations)
    s.energy = energy
    s.force_evaluations += 1
    return s
end

"""
    wall_contacts!(system, table, stepped, turned) -> energy

Every particle's contacts with the `2D` walls (design §2). A wall is flat, rigid and does
not rotate, so its lever arm is `R_i` and only the particle's own motion advances the
friction spring. Returns the elastic wall energy.
"""
function wall_contacts!(s::System{D}, table::ContactTable{D}, stepped, turned) where {D}
    energy = 0.0
    side = s.side
    for axis in 1:D
        unit = SVector{D,Float64}(ntuple(a -> a == axis ? 1.0 : 0.0, Val(D)))
        for i in eachindex(s.positions)
            for (side_of_wall, height, normal) in
                    ((1, s.positions[i][axis], unit),
                     (2, side - s.positions[i][axis], -unit))
                wall = 2 * (axis - 1) + side_of_wall
                lever = s.diameters[i] / 2
                overlap = lever - height
                if overlap <= 0
                    s.wall_tangential[wall, i] = zero(SVector{D,Float64})
                    s.wall_sliding[wall, i] = false
                    continue
                end
                force = contact_force(s.law, overlap)
                stiffness = contact_stiffness(s.law, overlap)
                radius = -lever * normal
                tangential_force = zero(SVector{D,Float64})
                tangential_k = 0.0
                flag = s.wall_sliding[wall, i]
                if wall_friction(s)
                    tangential_k = tangential_stiffness(s.friction, stiffness, D)
                    stretch = project_onto_plane(s.wall_tangential[wall, i], normal)
                    slide = project_onto_plane(stepped[i], normal) +
                            spin_cross(turned[i], radius)
                    stretch += slide
                    magnitude = sqrt(dot_in_order(stretch, stretch))
                    cap = s.friction.friction_coefficient * force
                    if tangential_k * magnitude > cap && magnitude > 0
                        stretch *= cap / (tangential_k * magnitude)
                        s.wall_sliding[wall, i] = true
                    else
                        s.wall_sliding[wall, i] = false
                    end
                    s.wall_tangential[wall, i] = stretch
                    tangential_force = -tangential_k * stretch
                    s.forces[i] += tangential_force
                    s.torques[i] += position_cross(radius, tangential_force)
                end
                s.forces[i] += force * normal
                energy += contact_energy(s.law, overlap)
                push!(table.first, i)
                push!(table.second, 0)
                push!(table.wall_id, wall)
                push!(table.normals, normal)
                push!(table.branches, -height * normal)
                push!(table.overlaps, overlap)
                push!(table.normal_stiffnesses, stiffness)
                push!(table.tangential_stiffnesses, tangential_k)
                push!(table.normal_forces, force)
                push!(table.tangential_forces, tangential_force)
                push!(table.levers_first, lever)
                push!(table.levers_second, 0.0)
                push!(table.sliding, flag)
            end
        end
    end
    return energy
end

"""
    contact_pressure(table, side, dimension)

The elastic contact (virial) pressure `P = sum_c f_n |l| / (D V)` (design §2), with
`V = side^D`; a wall contact counts like a pair contact with `|l| = h` (§2).
"""
function contact_pressure(table::ContactTable, side::Float64, dimension::Int)
    virial = 0.0
    @inbounds for c in eachindex(table.normal_forces)
        virial += table.normal_forces[c] *
                  sqrt(dot_in_order(table.branches[c], table.branches[c]))
    end
    return virial / (dimension * side^dimension)
end

"""
    mean_normal_force(table)

The mean elastic normal force over all contacts, read as 0 when there is no contact.
"""
mean_normal_force(table::ContactTable) =
    isempty(table.normal_forces) ? 0.0 :
    sum_in_order(table.normal_forces) / length(table.normal_forces)
