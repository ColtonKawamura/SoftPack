# ---------------------------------------------------------------------------
#  PeriodicBox: the side lengths of a D-dimensional periodic box.
#
#  A box is just its D side lengths; the domain is the half-open product
#  [0, L_1) x ... x [0, L_D) with periodic boundary conditions. Everything else
#  about the box (wrapping, minimum image, rescaling) lives in pbc.jl / celllist.jl.
#
#  D (dimension) and T (floating-point type, e.g. Float64 or Float32) are type
#  parameters so the whole engine stays generic in both.
# ---------------------------------------------------------------------------

"""
    PeriodicBox{D,T}

A rectangular periodic box in `D` dimensions with side lengths of type `T`.
`sides[d]` is the length `L_d` of axis `d`, so the domain is
`[0, L_1) x ... x [0, L_D)` with periodic boundary conditions.

    PeriodicBox(sides::AbstractVector)     # one side per element
    PeriodicBox(length::Real, dim::Int)     # a cube
"""
struct PeriodicBox{D,T}
    sides::Vector{T}
end

# Build a box from any vector of side lengths. The dimension is the vector
# length. A floating-point input keeps its type (Float32 stays Float32 so the
# whole run stays Float32); only integer input is promoted to Float64.
function PeriodicBox(sides::AbstractVector{<:Real})
    D = length(sides)
    T = eltype(sides) <: AbstractFloat ? eltype(sides) : Float64
    return PeriodicBox{D,T}(T.(sides))
end

# A convenient cube constructor.
function PeriodicBox(length::Real, dim::Int)
    T = promote_type(typeof(length), Float64)
    return PeriodicBox{dim,T}(fill(T(length), dim))
end

# The dimension is just the number of side lengths; indexing a box returns its
# side length for that axis.
Base.length(box::PeriodicBox) = length(box.sides)
Base.size(box::PeriodicBox) = (length(box),)
Base.getindex(box::PeriodicBox, d::Int) = box.sides[d]
Base.show(io::IO, box::PeriodicBox{D,T}) where {D,T} =
    print(io, "PeriodicBox{$D,$T}(", box.sides, ")")

"""
    volume(box::PeriodicBox) -> Float

The box volume: the product of the side lengths. This is an area in 2D and a
true volume in 3D, matching the packing-fraction convention in
`~/repos/GranE/src/computePackingFraction.m`.
"""
volume(box::PeriodicBox) = prod(box.sides)
