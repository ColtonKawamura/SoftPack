# ---------------------------------------------------------------------------
#  Particle size distributions: draw radii with a seeded RNG and size the box
#  for a target packing fraction.
#
#  Length unit. All lengths in this module are expressed in units of the smallest
#  particle radius (so the smallest particle has radius 1 in these units).
#  This is an internal engine convention for M1; a later milestone may normalize
#  the softpack-1 output to the mean radius instead.
# ---------------------------------------------------------------------------

"""
    draw_radii(dist::SizeDistribution, rng, N) -> Vector{Float64}

Draw `N` particle radii from `dist` using the seeded RNG `rng` (a
`StableRNG`), so the same seed always yields the same radii. The element type of
the returned vector matches the distribution (Float32 / Float64).
"""
function draw_radii(dist::Monodisperse{T}, ::Any, N::Int) where {T}
    return fill(T(dist.radius), N)
end

function draw_radii(dist::Bidisperse{T}, rng, N::Int) where {T}
    # `fraction` is the number fraction of the SMALL species (unit radius 1);
    # the LARGE species has radius `ratio` (ratio = large / small).
    f = T(dist.fraction)
    u = rand(rng, N)
    return [u[i] < f ? T(1) : T(dist.ratio) for i in 1:N]
end

function draw_radii(dist::UniformPolydisperse{T}, rng, N::Int) where {T}
    return T.(rand(rng, N) .* (dist.max_radius - dist.min_radius) .+ dist.min_radius)
end

# Log-normal sampled by hand (SoftPack has no Distributions.jl dependency):
# z ~ N(0,1)  =>  radius = exp(mu + sigma * z).
function draw_radii(dist::LogNormalPolydisperse{T}, rng, N::Int) where {T}
    z = randn(rng, N)
    return T.(exp.(dist.mu .+ dist.sigma .* z))
end

function draw_radii(dist::CustomRadii{T}, ::Any, N::Int) where {T}
    length(dist.radii) == N ||
        throw(ArgumentError("CustomRadii has $(length(dist.radii)) radii but N = $N; they must match"))
    return copy(dist.radii)
end

"""
    sphere_volume(r::T, dim::Int) -> T

Volume (2D area / 3D volume) of a disk/sphere of radius `r`, matching the
convention in `~/repos/GranE/src/computePackingFraction.m`:
`pi r^2` in 2D, `(4/3) pi r^3` in 3D.
"""
function sphere_volume(r::T, dim::Int) where {T}
    dim == 2 && return T(pi) * r^2
    dim == 3 && return T(4) / T(3) * pi * r^3
    throw(ArgumentError("dim must be 2 or 3, got $dim"))
end

"""
    box_for_phi(radii, phi, dim) -> L

Side length of the (cubic) box that gives packing fraction `phi` for the given
`radii`: `L = (sum of particle volumes / phi)^(1/dim)`. Returns a single length;
use `PeriodicBox(L, dim)` for a cube.
"""
function box_for_phi(radii::AbstractVector{<:Any}, phi::Real, dim::Int)
    T = Float64
    V_spheres = sum(sphere_volume(T(r), dim) for r in radii)
    L = (V_spheres / T(phi))^(T(1) / dim)
    return L
end

"""
    random_positions(radii, box::PeriodicBox{D}, rng) -> Matrix

`D`-by-`N` matrix of uniform-random particle positions inside `box` (wrapped into
`[0, L)`), drawn with the seeded RNG `rng`. Rows are coordinates, columns are
particles.
"""
function random_positions(radii::AbstractVector, box::PeriodicBox{D,T}, rng) where {D,T}
    N = length(radii)
    x = Matrix{T}(undef, D, N)
    rand!(rng, x)                       # Uniform(0,1) in a D x N matrix
    x .*= reshape(box.sides, length(box.sides), 1)   # scale row d by the side length L_d
    return wrap!(x, box)
end
