# ---------------------------------------------------------------------------
#  Periodic square or cube box of side `side` (design §2).
# ---------------------------------------------------------------------------

"""
    minimum_image(displacement, side)

The nearest periodic image of a displacement: every component folded into
`[-side/2, side/2]`. A displacement already inside is returned unchanged, bit for bit.
"""
@inline minimum_image(dx::SVector{D,Float64}, side::Float64) where {D} =
    dx - side * round.(dx / side)

"""
    sum_in_order(f, values)

`f(v)` summed over `values` with a plain loop, first to last. Base's `sum` may reorder the
additions (SIMD, pairwise blocks) and its order has changed between Julia versions; a
last-bit change in the box side or a force norm sends FIRE down another path, so every
sum that feeds the trajectory uses this one, keeping a seed's packing the same on every
Julia version (design §10).
"""
function sum_in_order(f, values)
    total = 0.0
    for v in values
        total += f(v)
    end
    return total
end
sum_in_order(values) = sum_in_order(identity, values)

"""
    dot_in_order(a, b)

The dot product added component by component, first to last. StaticArrays' `dot` uses a
`@simd` loop, which lets the compiler reorder and fuse the additions differently on
different Julia versions.
"""
@inline function dot_in_order(a::SVector{D,Float64}, b::SVector{D,Float64}) where {D}
    total = a[1] * b[1]
    for k in 2:D
        total += a[k] * b[k]
    end
    return total
end

"""
    box_side_for(volume, packing_fraction, dimension)

The side of the square or cube that holds particles of total `volume` at
`packing_fraction`, with `sqrt` and `cbrt` rather than `^(1/D)`, whose implementation has
changed between Julia versions.
"""
box_side_for(volume::Float64, packing_fraction::Float64, dimension::Int) =
    dimension == 2 ? sqrt(volume / packing_fraction) : cbrt(volume / packing_fraction)

"""
    wrap(position, side)

The position folded into the box `[0, side)` on every axis.
"""
@inline function wrap(x::SVector{D,Float64}, side::Float64) where {D}
    return SVector{D,Float64}(ntuple(Val(D)) do a
        y = x[a] - side * floor(x[a] / side)
        y >= side ? y - side : y      # floor can round a tiny negative value up to side
    end)
end
