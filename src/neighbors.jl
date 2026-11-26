# ---------------------------------------------------------------------------
#  Neighbor search: a Verlet list built with a cell grid.
#
#  The list holds every pair whose nearest-image distance is below the contact
#  distance plus a skin. It stays valid until some particle has moved more than
#  half the skin, or the box side has changed. Forces always recompute the
#  nearest image, so wrapping positions between builds is harmless.
# ---------------------------------------------------------------------------

mutable struct NeighborList{D}
    skin::Float64
    first::Vector{Int}
    second::Vector{Int}
    reference_positions::Vector{SVector{D,Float64}}
    side::Float64
end

NeighborList{D}(skin::Float64) where {D} =
    NeighborList{D}(skin, Int[], Int[], SVector{D,Float64}[], NaN)

"""
    CellGrid

Particles binned into `cells_per_side^D` cells of side at least `reach`, stored as linked
lists (`head` per cell, `next` per particle). Two particles closer than `reach` are in
the same or adjacent cells. With fewer than 3 cells per side the grid is not used.
"""
struct CellGrid{D}
    cells_per_side::Int
    head::Vector{Int}
    next::Vector{Int}
    cell_of::Vector{CartesianIndex{D}}
end

function CellGrid(positions::Vector{SVector{D,Float64}}, side::Float64, reach::Float64,
                  capacity::Int = length(positions)) where {D}
    cells_per_side = max(1, floor(Int, side / reach))
    head = zeros(Int, cells_per_side^D)
    grid = CellGrid{D}(cells_per_side, head, zeros(Int, capacity),
                       Vector{CartesianIndex{D}}(undef, capacity))
    for i in eachindex(positions)
        insert!(grid, i, positions[i], side)
    end
    return grid
end

@inline function cell_index(grid::CellGrid{D}, x::SVector{D,Float64}, side::Float64) where {D}
    n = grid.cells_per_side
    return CartesianIndex(ntuple(a -> clamp(floor(Int, x[a] / side * n) + 1, 1, n), Val(D)))
end

@inline linear_index(grid::CellGrid{D}, c::CartesianIndex{D}) where {D} =
    LinearIndices(ntuple(_ -> grid.cells_per_side, Val(D)))[c]

function Base.insert!(grid::CellGrid{D}, i::Int, x::SVector{D,Float64}, side::Float64) where {D}
    c = cell_index(grid, x, side)
    grid.cell_of[i] = c
    l = linear_index(grid, c)
    grid.next[i] = grid.head[l]
    grid.head[l] = i
    return grid
end

"""
    foreach_nearby(f, grid, cell)

Call `f(j)` for every particle in `cell` and its `3^D - 1` periodic neighbor cells.
Needs at least 3 cells per side, so that the neighbor cells are distinct.
"""
@inline function foreach_nearby(f::F, grid::CellGrid{D}, c::CartesianIndex{D}) where {F,D}
    n = grid.cells_per_side
    for offset in CartesianIndices(ntuple(_ -> -1:1, Val(D)))
        neighbor = CartesianIndex(ntuple(a -> mod1(c[a] + offset[a], n), Val(D)))
        j = grid.head[linear_index(grid, neighbor)]
        while j != 0
            f(j)
            j = grid.next[j]
        end
    end
    return nothing
end

"""
    build!(list, positions, diameters, side)

Wrap `positions` into the box (in place) and rebuild the pair list.
"""
function build!(list::NeighborList{D}, positions::Vector{SVector{D,Float64}},
                diameters::Vector{Float64}, side::Float64) where {D}
    count = length(positions)
    reach = maximum(diameters) + list.skin
    # PROVISIONAL T-c822: tiny systems, where one pair could touch through two images, are
    # refused rather than handled; the design allows any particles_count >= 2.
    side > 2 * reach || throw(ArgumentError(
        "the box side $(side) is too small for the nearest-image rule with the largest " *
        "diameter $(maximum(diameters)); use more particles"))
    for i in 1:count
        positions[i] = wrap(positions[i], side)
    end
    empty!(list.first)
    empty!(list.second)
    consider = (i, j) -> begin
        cutoff = (diameters[i] + diameters[j]) / 2 + list.skin
        dx = minimum_image(positions[i] - positions[j], side)
        if dot_in_order(dx, dx) < cutoff^2
            push!(list.first, i)
            push!(list.second, j)
        end
    end
    grid = CellGrid(positions, side, reach)
    if grid.cells_per_side < 3
        for i in 1:count-1, j in i+1:count
            consider(i, j)
        end
    else
        for i in 1:count
            foreach_nearby(j -> (j > i && consider(i, j)), grid, grid.cell_of[i])
        end
    end
    list.reference_positions = copy(positions)
    list.side = side
    return list
end

"""
    needs_rebuild(list, positions, side) -> Bool

True when the box side has changed or some particle has moved more than half the skin
since the last build.
"""
function needs_rebuild(list::NeighborList{D}, positions::Vector{SVector{D,Float64}},
                       side::Float64) where {D}
    side == list.side || return true
    limit = (list.skin / 2)^2
    @inbounds for i in eachindex(positions)
        dx = minimum_image(positions[i] - list.reference_positions[i], side)
        dot_in_order(dx, dx) > limit && return true
    end
    return false
end
