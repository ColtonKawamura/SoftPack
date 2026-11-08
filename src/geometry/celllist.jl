# ---------------------------------------------------------------------------
#  Cell-list pair finder.
#
#  Particles are bucketed into an nx grid of cells (each side >= `cellsize`).
#  Candidate contacts are the particles in the 3^D periodic stencil around each
#  particle's cell. A pair (i, j) with i < j is emitted when its minimum-image
#  centre-to-centre distance is < r_i + r_j + skin. With skin = 0 that is exactly
#  the contact set (delta > 0), and it matches a brute-force scan pair-for-pair.
#
#  Correctness at low cell counts: when any axis has fewer than 3 cells the
#  stencil degenerates (pack.m's 2D finder double-counts pairs when an axis has
#  2 cells), so we fall back to a brute-force scan of the whole system. When
#  every axis has >= 3 cells all 3^D offset cells are distinct, so no
#  de-duplication is needed and the `p < q` test emits each unordered pair once.
#
#  The per-cell neighbor lists are computed ONCE at construction (they depend
#  only on `nx`, not on the positions) and stored in `cl.neighbors`. Keeping that
#  generic-D computation out of the per-call hot loop keeps `pairlist` simple and
#  stable to compile.
# ---------------------------------------------------------------------------

"""
    CellList{D,T}

A cell-list neighbor search over a `PeriodicBox`. Holds the cell partition (built
from a set of positions) and, given current positions, `pairlist` returns the
candidate contacts. Rebuild the partition with `rebuild!` when particles move
more than `skin / 2` (a Verlet list).
"""
struct CellList{D,T}
    box::PeriodicBox{D,T}
    cellsize::T
    skin::T
    nx::NTuple{D,Int}
    ncells::Int
    cell_of::Vector{Int}                 # length N: linear cell index of each particle
    cell_particles::Vector{Vector{Int}}  # length ncells: particle ids per cell
    neighbors::Vector{Vector{Int}}       # length ncells: neighbour cell ids (3^D stencil)
end

"""
    CellList(x, radii, box; skin = 0) -> CellList

Build the cell partition for `x` (a D-by-N position matrix) and `radii`.
`cellsize = 2*max_radius + skin` so the 3^D stencil catches every candidate.
"""
function CellList(x::Matrix{<:Any}, radii::AbstractVector{<:Any},
                  box::PeriodicBox{D,T}; skin::T = zero(T)) where {D,T}
    max_r = maximum(radii)
    cellsize = T(2) * max_r + skin
    # Cells per axis: floor so every cell is >= cellsize (at least one cell).
    nx = ntuple(d -> max(1, floor(Int, box.sides[d] / cellsize)), D)
    ncells = prod(nx)
    cl = CellList{D,T}(box, cellsize, skin, nx, ncells, Int[],
                       Vector{Int}[Int[] for _ in 1:ncells],
                       Vector{Vector{Int}}[Int[] for _ in 1:ncells])
    _build_neighbors!(cl.neighbors, cl.nx)   # depends only on nx, not on x
    return rebuild!(cl, x)
end

# Linear (1-based) cell index from the per-axis cell coordinates (row-major).
function _cell_index(coords::Vector{Int}, nx::NTuple{D,Int}) where {D}
    idx = 0
    mul = 1
    @inbounds for d in 1:D
        idx += (coords[d] - 1) * mul
        mul *= nx[d]
    end
    return idx + 1
end

"""
    _build_neighbors!(neighbors, nx)

Fill each `neighbors[c]` with the 1-based linear indices of the 3^D periodic
stencil around cell `c`. Called once at construction, so it only depends on the
cell counts `nx`.
"""
function _build_neighbors!(neighbors::Vector{Vector{Int}}, nx::NTuple{D,Int}) where {D}
    @inbounds for c in 1:length(neighbors)
        empty!(neighbors[c])
        # 1-based per-axis coordinates of cell c (axis 1 is least significant).
        base = c - 1
        coords = zeros(Int, D)
        @inbounds for d in 1:D
            coords[d] = base % nx[d] + 1
            base = div(base, nx[d])
        end
        # Enumerate the 3^D offset cells by decoding k in base 3 into a per-axis
        # shift of {-1, 0, 1}; mirrors _cell_index ordering.
        @inbounds for k in 0:(3^D - 1)
            m = k
            nc = 0
            mul = 1
            @inbounds for d in 1:D
                off = m % 3 - 1                          # shift in {-1, 0, 1}
                cd = mod(coords[d] + off - 1, nx[d]) + 1  # wrap, 1-based
                nc += (cd - 1) * mul
                mul *= nx[d]
                m = div(m, 3)
            end
            push!(neighbors[c], nc + 1)
        end
    end
    return neighbors
end

"""
    rebuild!(cl, x) -> cl

Re-bucket the particles of `x` into `cl`'s cells from scratch. Only
`cell_of` / `cell_particles` depend on `x`; the precomputed `neighbors` are left
untouched.
"""
function rebuild!(cl::CellList{D,T}, x::Matrix{<:Any}) where {D,T}
    N = size(x, 2)
    resize!(cl.cell_of, N)
    @inbounds for i in 1:N
        coords = zeros(Int, D)
        @inbounds for d in 1:D
            c = floor(Int, mod(x[d, i] / cl.box.sides[d], 1) * cl.nx[d]) + 1
            coords[d] = min(max(c, 1), cl.nx[d])
        end
        cl.cell_of[i] = _cell_index(coords, cl.nx)
    end
    resize!(cl.cell_particles, cl.ncells)
    @inbounds for c in 1:cl.ncells
        empty!(cl.cell_particles[c])
    end
    @inbounds for i in 1:N
        push!(cl.cell_particles[cl.cell_of[i]], i)
    end
    return cl
end

"""
    pairlist(cl, x, radii) -> (i_indices, j_indices)

Candidate contacts (flat arrays, i < j) whose minimum-image distance is
`< r_i + r_j + skin`. Falls back to brute force if any axis has < 3 cells.
"""
function pairlist(cl::CellList{D,T}, x::Matrix{<:Any},
                  radii::AbstractVector{<:Any}) where {D,T}
    any(n -> n < 3, cl.nx) && return brute_force_pairlist(x, radii, cl.box; skin = skincutoff(cl))
    ii = Int[]
    jj = Int[]
    @inbounds for c in 1:cl.ncells
        cp = cl.cell_particles[c]
        isempty(cp) && continue
        nb = cl.neighbors[c]
        @inbounds for p in cp
            rp = radii[p]
            for nc in nb
                for q in cl.cell_particles[nc]
                    p < q || continue
                    # minimum-image squared distance (explicit loop, no broadcast)
                    d2sq = zero(T)
                    @inbounds for d in 1:D
                        dd = x[d, q] - x[d, p]
                        dd = cl.box.sides[d] * (dd / cl.box.sides[d] -
                                                round(dd / cl.box.sides[d]))
                        d2sq += dd * dd
                    end
                    rsum = rp + radii[q] + skincutoff(cl)
                    if d2sq < rsum * rsum
                        push!(ii, p)
                        push!(jj, q)
                    end
                end
            end
        end
    end
    return (ii, jj)
end

# Candidate search radius added to every pair's contact distance (the Verlet skin).
skincutoff(cl::CellList{D,T}) where {D,T} = cl.skin

"""
    brute_force_pairlist(x, radii, box; skin = 0) -> (i_indices, j_indices)

O(N^2) reference pair finder with minimum image: every pair (i, j), i < j, whose
minimum-image distance is < r_i + r_j + skin. Used both as the low-cell-count
fallback and to validate the cell list in tests.
"""
function brute_force_pairlist(x::Matrix{<:Any}, radii::AbstractVector{<:Any},
                              box::PeriodicBox{D,T}; skin::T = zero(T)) where {D,T}
    N = length(radii)
    ii = Int[]
    jj = Int[]
    @inbounds for p in 1:N-1
        rp = radii[p]
        for q in p+1:N
            disp = x[:, q] .- x[:, p]
            minimum_image!(disp, box)
            d2sq = zero(T)
            @inbounds for d in 1:D
                d2sq += disp[d] * disp[d]
            end
            rsum = rp + radii[q] + skin
            if d2sq < rsum^2
                push!(ii, p)
                push!(jj, q)
            end
        end
    end
    return (ii, jj)
end

"""
    needs_rebuild!(cl, x_prev, x) -> Bool

True when some particle has moved more than `skin / 2` (largest single-component
displacement) since the list was built, so the Verlet list must be rebuilt.
"""
function needs_rebuild!(cl::CellList, x_prev::Matrix{<:Any}, x::Matrix{<:Any})
    N = size(x, 2)
    half = skincutoff(cl) / 2
    @inbounds for i in 1:N
        @inbounds for d in 1:size(x, 1)
            abs(x[d, i] - x_prev[d, i]) > half && return true
        end
    end
    return false
end
