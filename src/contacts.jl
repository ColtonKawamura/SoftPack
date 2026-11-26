# ---------------------------------------------------------------------------
#  The force model (design §7): it owns the contact list and hands out, after
#  every force evaluation, one table with a row per contact. The algorithm, the
#  pressure, the convergence test and the rattler rules all read that table.
#  Frictionless contacts carry no history, so this build has none to keep.
# ---------------------------------------------------------------------------

"""
    ContactTable{D}

One row per contact (design §7), as plain columns:

- `first`, `second`: the two particles (`first < second`).
- `normals`: unit normal, pointing from `second` to `first`.
- `branches`: branch vector `r_first - r_second` (nearest image), whose length enters the
  pressure.
- `overlaps`: `(d_first + d_second)/2 - |branch|`, positive for every row.
- `normal_stiffnesses`: `dF/d(overlap)` of the contact law at this overlap.
- `normal_forces`: the elastic normal force (repulsive, positive).

The friction columns of §7 (lever arms, tangential stiffness, sliding flag) arrive with
friction.
"""
struct ContactTable{D}
    first::Vector{Int}
    second::Vector{Int}
    normals::Vector{SVector{D,Float64}}
    branches::Vector{SVector{D,Float64}}
    overlaps::Vector{Float64}
    normal_stiffnesses::Vector{Float64}
    normal_forces::Vector{Float64}
end

ContactTable{D}() where {D} = ContactTable{D}(Int[], Int[], SVector{D,Float64}[],
    SVector{D,Float64}[], Float64[], Float64[], Float64[])

Base.length(t::ContactTable) = length(t.first)

function Base.empty!(t::ContactTable)
    for column in (t.first, t.second, t.normals, t.branches, t.overlaps,
                   t.normal_stiffnesses, t.normal_forces)
        empty!(column)
    end
    return t
end

Base.copy(t::ContactTable{D}) where {D} = ContactTable{D}(copy(t.first), copy(t.second),
    copy(t.normals), copy(t.branches), copy(t.overlaps), copy(t.normal_stiffnesses),
    copy(t.normal_forces))

# Contact laws: force, energy and stiffness as functions of the overlap (design §2).
@inline contact_force(law::Hookean, overlap::Float64) = law.stiffness * overlap
@inline contact_energy(law::Hookean, overlap::Float64) = law.stiffness * overlap^2 / 2
@inline contact_stiffness(law::Hookean, overlap::Float64) = law.stiffness

"""
    System{D}

Everything a minimization changes or reads: positions, velocities, net forces, the box
side, the neighbor list and the contact table of the last force evaluation.
"""
mutable struct System{D,L<:ContactLaw}
    positions::Vector{SVector{D,Float64}}
    velocities::Vector{SVector{D,Float64}}
    forces::Vector{SVector{D,Float64}}
    diameters::Vector{Float64}
    masses::Vector{Float64}
    side::Float64
    law::L
    neighbors::NeighborList{D}
    table::ContactTable{D}
    energy::Float64
    force_evaluations::Int
end

function System(positions::Vector{SVector{D,Float64}}, diameters, masses, side, law;
                skin = 0.4 * minimum(diameters)) where {D}
    count = length(positions)
    zero_vectors = fill(zero(SVector{D,Float64}), count)
    return System{D,typeof(law)}(copy(positions), copy(zero_vectors), copy(zero_vectors),
        diameters, masses, side, law, NeighborList{D}(skin), ContactTable{D}(), 0.0, 0)
end

"""
    evaluate_forces!(system)

Refresh the neighbor list if needed, then compute every net elastic force, the elastic
energy and the contact table at the current positions.
"""
function evaluate_forces!(s::System{D}) where {D}
    needs_rebuild(s.neighbors, s.positions, s.side) &&
        build!(s.neighbors, s.positions, s.diameters, s.side)
    table = empty!(s.table)
    forces = s.forces
    fill!(forces, zero(SVector{D,Float64}))
    energy = 0.0
    side = s.side
    @inbounds for p in eachindex(s.neighbors.first)
        i = s.neighbors.first[p]
        j = s.neighbors.second[p]
        branch = minimum_image(s.positions[i] - s.positions[j], side)
        contact_distance = (s.diameters[i] + s.diameters[j]) / 2
        distance_squared = dot_in_order(branch, branch)
        distance_squared < contact_distance^2 || continue
        distance = sqrt(distance_squared)
        overlap = contact_distance - distance
        normal = branch / distance
        force = contact_force(s.law, overlap)
        forces[i] += force * normal
        forces[j] -= force * normal
        energy += contact_energy(s.law, overlap)
        push!(table.first, i)
        push!(table.second, j)
        push!(table.normals, normal)
        push!(table.branches, branch)
        push!(table.overlaps, overlap)
        push!(table.normal_stiffnesses, contact_stiffness(s.law, overlap))
        push!(table.normal_forces, force)
    end
    s.energy = energy
    s.force_evaluations += 1
    return s
end

"""
    contact_pressure(table, side, dimension)

The elastic contact (virial) pressure `P = sum_c f_n |l| / (D V)` (design §2), with
`V = side^D`.
"""
function contact_pressure(table::ContactTable, side::Float64, dimension::Int)
    virial = 0.0
    @inbounds for c in eachindex(table.normal_forces)
        virial += table.normal_forces[c] * sqrt(dot_in_order(table.branches[c], table.branches[c]))
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
