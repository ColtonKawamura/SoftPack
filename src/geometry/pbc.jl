# ---------------------------------------------------------------------------
#  Periodic boundary helpers: minimum-image displacement and coordinate wrapping.
#
#  `minimum_image` folds a displacement vector into the central cell [-L_d/2, L_d/2]
#  on every axis; `wrap` folds particle coordinates into the half-open box [0, L).
#  Both keep the element type T generic (Float32 / Float64).
# ---------------------------------------------------------------------------

"""
    minimum_image(dx, box::PeriodicBox{D}) -> dx

Return the minimum-image displacement: `dx` folded so every component lies in
`[-L_d/2, L_d/2]`. This is the shortest vector between two points related by `dx`
under periodic boundary conditions. Uses `round` so a displacement of exactly
`L_d` maps to `0` and one of exactly `L_d/2` maps to itself.
"""
function minimum_image!(dx::AbstractVector, box::PeriodicBox{D}) where {D}
    @inbounds for d in 1:D
        L = box.sides[d]
        dx[d] = L * (dx[d] / L - round(dx[d] / L))
    end
    return dx
end

minimum_image(dx::AbstractVector, box::PeriodicBox{D}) where {D} =
    minimum_image!(copy(dx), box)

"""
    wrap!(x, box::PeriodicBox{D}) -> x

Fold the coordinates in `x` (a `D`-by-`N` matrix: row `d`, column `i` is
coordinate `d` of particle `i`) into the half-open box `[0, L_d)` on every axis.
`wrap` returns a fresh copy instead of mutating.
"""
function wrap!(x::AbstractMatrix, box::PeriodicBox{D}) where {D}
    @inbounds for d in 1:D
        L = box.sides[d]
        for i in 1:size(x, 2)
            x[d, i] = L * mod(x[d, i] / L, 1)
        end
    end
    return x
end

wrap(x::AbstractMatrix, box::PeriodicBox{D}) where {D} = wrap!(copy(x), box)

"""
    rescale!(box::PeriodicBox{D}, x::Matrix, lambda::Real) -> x

Affine (isotropic) rescale: multiply every side length and every coordinate by
`lambda`. Used by the compression protocols to grow/shrink the box together with
the positions so the packing fraction is preserved (the volume scales like
`lambda^D`).
"""
function rescale!(box::PeriodicBox{D,T}, x::AbstractMatrix{<:Any}, lambda::Real) where {D,T}
    λ = T(lambda)
    @inbounds for d in 1:D
        box.sides[d] *= λ
        for i in 1:size(x, 2)
            x[d, i] *= λ
        end
    end
    return x
end

"""
    wrap!(x::AbstractVector, box::PeriodicBox{D}) -> x

Fold a single coordinate vector into `[0, L_d)` on each axis. See `wrap!` for the
matrix version that folds an entire position array.
"""
function wrap!(x::AbstractVector, box::PeriodicBox{D}) where {D}
    @inbounds for d in 1:D
        x[d] = box.sides[d] * mod(x[d] / box.sides[d], 1)
    end
    return x
end

wrap(x::AbstractVector, box::PeriodicBox{D}) where {D} = wrap!(copy(x), box)
