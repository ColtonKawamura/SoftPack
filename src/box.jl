# ---------------------------------------------------------------------------
#  Periodic square or cube box of side `side` (design §2), and the small
#  rotation/vector helpers every layer uses.
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

"""
    rotation_count(dimension)

Rotational degrees of freedom per particle: 1 in 2D (a spin about the third axis) and 3 in
3D (a spin vector).
"""
rotation_count(dimension::Int) = dimension == 2 ? 1 : 3

# --- Rotation helpers -------------------------------------------------------

"""
    spin_cross(omega, r)

`omega x r`: a 2D spin acts on a 2D vector through the third axis, a 3D spin vector by the
ordinary cross product.
"""
@inline spin_cross(w::SVector{1,Float64}, r::SVector{2,Float64}) =
    SVector(-w[1] * r[2], w[1] * r[1])
@inline spin_cross(w::SVector{3,Float64}, r::SVector{3,Float64}) =
    SVector(w[2] * r[3] - w[3] * r[2],
            w[3] * r[1] - w[1] * r[3],
            w[1] * r[2] - w[2] * r[1])

"""
    position_cross(r, f)

`r x f` as a rotation vector: the z component in 2D, the cross product in 3D.
"""
@inline position_cross(r::SVector{2,Float64}, f::SVector{2,Float64}) =
    SVector(r[1] * f[2] - r[2] * f[1])
@inline position_cross(r::SVector{3,Float64}, f::SVector{3,Float64}) =
    SVector(r[2] * f[3] - r[3] * f[2],
            r[3] * f[1] - r[1] * f[3],
            r[1] * f[2] - r[2] * f[1])

"""
    rotate(rotation, delta)

The rotation vector advanced by `delta` (a scalar angle in 2D).
"""
@inline rotate(theta::SVector{1,Float64}, delta::SVector{1,Float64}) =
    SVector(theta[1] + delta[1])
@inline rotate(theta::SVector{3,Float64}, delta::SVector{3,Float64}) =
    theta + delta

"""
    tangent(n)

A unit vector in the contact plane: `n` turned by +90 degrees in 2D, `e_z x n` in 3D when
`n` is not parallel to `e_z`, and `e_x` otherwise.
"""
@inline tangent(n::SVector{2,Float64}) = SVector(-n[2], n[1])
@inline function tangent(n::SVector{3,Float64})
    t = SVector(-n[2], n[1], 0.0)            # e_z x n
    length_squared = t[1]^2 + t[2]^2
    if length_squared < 1e-24                # n along z
        return SVector(1.0, 0.0, 0.0)
    end
    return t / sqrt(length_squared)
end

"""
    project_onto_plane(v, n)

The component of `v` perpendicular to the unit normal `n`.
"""
@inline project_onto_plane(v::SVector{D,Float64}, n::SVector{D,Float64}) where {D} =
    v - dot_in_order(v, n) * n
