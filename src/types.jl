# ---------------------------------------------------------------------------
#  Types: size distributions, contact laws and the packing result.
#
#  In M0 these are plain records ("structs only"): they describe parameters but
#  contain no logic. The code that draws radii (M1) and computes forces (M1/M2)
#  lives elsewhere.
# ---------------------------------------------------------------------------

# Super-types so a field can be typed as "some distribution" / "some contact law"
# without naming every concrete type.
abstract type SizeDistribution end
abstract type ContactLaw end

# ---------------------------------------------------------------------------
#  Size distributions: the parameters that fully describe how radii are chosen.
# ---------------------------------------------------------------------------

# Every particle has the same `radius`.
"""
    Monodisperse(radius = 1.0)

Size distribution in which every particle has the same `radius` (default `1.0`).
"""
Base.@kwdef struct Monodisperse{T<:Real} <: SizeDistribution
    radius::T = 1.0
end

# Two sizes. `ratio` = large diameter / small diameter and `fraction` = the
# number fraction of the SMALL species.
"""
    Bidisperse(ratio = 1.4, fraction = 0.5)

Two-species size distribution: `ratio` is the large/small *diameter* ratio
(default `1.4`) and `fraction` is the number fraction of the *small* species
(default `0.5`).
"""
Base.@kwdef struct Bidisperse{T<:Real} <: SizeDistribution
    ratio::T = 1.4
    fraction::T = 0.5
end

# Radii drawn uniformly from [min_radius, max_radius].
"""
    UniformPolydisperse(min_radius, max_radius)

Radii drawn uniformly from the closed interval `[min_radius, max_radius]`.
"""
Base.@kwdef struct UniformPolydisperse{T<:Real} <: SizeDistribution
    min_radius::T
    max_radius::T
end

# Radii drawn from a log-normal with log-mean `mu` and log-std `sigma`.
"""
    LogNormalPolydisperse(mu, sigma)

Radii drawn from a log-normal distribution with log-mean `mu` and log-standard
deviation `sigma`.
"""
Base.@kwdef struct LogNormalPolydisperse{T<:Real} <: SizeDistribution
    mu::T
    sigma::T
end

# An explicit list of radii, used as-is.
"""
    CustomRadii(radii)

An explicit list of radii, used as-is.
"""
Base.@kwdef struct CustomRadii{T<:Real} <: SizeDistribution
    radii::Vector{T}
end

# ---------------------------------------------------------------------------
#  Contact laws: the parameters of the normal (and, later, frictional) force.
# ---------------------------------------------------------------------------

# Hookean overlap law: F = k * overlap, U = (k/2) * overlap^2.
"""
    Hookean(k = 1.0)

Hookean overlap law: normal force `F = k * overlap`, energy
`U = (k/2) * overlap^2`. `k` is the normal stiffness (default `1.0`).
"""
Base.@kwdef struct Hookean{T<:Real} <: ContactLaw
    k::T = 1.0
end

# Hertzian overlap law: F = (4/3) k sqrt(R_eff) overlap^(3/2).
"""
    Hertzian(k = 1.0)

Hertzian overlap law: normal force `F = (4/3) * k * sqrt(R_eff) * overlap^(3/2)`,
where `R_eff` is the effective radius of the pair. `k` is the elastic modulus
(default `1.0`).
"""
Base.@kwdef struct Hertzian{T<:Real} <: ContactLaw
    k::T = 1.0
end

# ---------------------------------------------------------------------------
#  Contact: a single pairwise interaction, and the result of a packing run.
# ---------------------------------------------------------------------------

# One contact between particles `i` and `j` (1-based ids).
#   * overlap      -- r_i + r_j - distance (> 0 while in contact)
#   * force_normal -- normal force magnitude fn
#   * friction_force -- tangential force magnitude ft, or nothing when frictionless
#   * normal       -- unit contact normal as a D-component vector
"""
    Contact{D,T}(i, j, overlap, force_normal, friction_force, normal)

One contact between particles `i` and `j` (1-based ids):

- `overlap`        -- `r_i + r_j - distance` (> 0 while the particles overlap)
- `force_normal`   -- normal force magnitude
- `friction_force` -- tangential force magnitude, or `nothing` when frictionless
- `normal`         -- unit contact normal as a `D`-component vector

The plain `Contact(...)` constructor infers `D` (length of `normal`) and `T`
(from the numbers), so callers do not have to write `Contact{D,T}(...)`.
"""
struct Contact{D,T}
    i::Int
    j::Int
    overlap::T
    force_normal::T
    friction_force::Union{T,Nothing}
    normal::NTuple{D,T}
end

# Outer constructor: a bare `Contact(1, 2, 0.1, 0.5, nothing, (1.0, 0.0))` infers
# the dimension D (length of `normal`) and element type T (from the numbers), so
# callers do not have to write the explicit `Contact{D,T}(...)`.
function Contact(i, j, overlap, force_normal, friction_force, normal)
    D = length(normal)
    types = typeof[typeof(overlap), typeof(force_normal)]
    friction_force !== nothing && push!(types, typeof(friction_force))
    T = promote_type(types..., eltype(normal))
    return new{D,T}(i, j, T(overlap), T(force_normal),
                    friction_force === nothing ? nothing : T(friction_force),
                    ntuple(k -> T(normal[k]), D))
end

# Result of a packing run.
#   * positions  -- D x N matrix: row d, column i is coordinate d of particle i
#   * radii      -- length N
#   * box        -- length D: side lengths of the periodic box [0, L) per axis
#   * is_rattler -- length N boolean mask
#   * contacts   -- the list of pairwise contacts
#   * metadata   -- free-form key/value notes (pressure, steps, PackParams fields, ...)
"""
    Packing{D,T}

Result of a packing run:

- `positions`  -- `D x N` matrix: row `d`, column `i` is coordinate `d` of particle `i`
- `radii`      -- length `N`
- `box`        -- length `D`: side lengths of the periodic box, `[0, L)` per axis
- `is_rattler` -- length-`N` boolean mask (true for rattlers)
- `contacts`   -- the list of pairwise `Contact`s
- `metadata`   -- free-form key/value notes (pressure, step count, settings, ...)

`D` is the spatial dimension and `T` the element type (`Float64` or `Float32`).
`write_packing` and `read_packing` round-trip a `Packing` to and from the
softpack-1 folder format (see the format specification in the documentation).
"""
struct Packing{D,T}
    positions::Matrix{T}
    radii::Vector{T}
    box::Vector{T}
    is_rattler::Vector{Bool}
    contacts::Vector{Contact{D,T}}
    metadata::Dict{String,Any}
end
