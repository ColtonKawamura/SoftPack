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
Base.@kwdef struct Monodisperse{T<:Real} <: SizeDistribution
    radius::T = 1.0
end

# Two sizes. `ratio` = large diameter / small diameter and `fraction` = the
# number fraction of the SMALL species.
Base.@kwdef struct Bidisperse{T<:Real} <: SizeDistribution
    ratio::T = 1.4
    fraction::T = 0.5
end

# Radii drawn uniformly from [min_radius, max_radius].
Base.@kwdef struct UniformPolydisperse{T<:Real} <: SizeDistribution
    min_radius::T
    max_radius::T
end

# Radii drawn from a log-normal with log-mean `mu` and log-std `sigma`.
Base.@kwdef struct LogNormalPolydisperse{T<:Real} <: SizeDistribution
    mu::T
    sigma::T
end

# An explicit list of radii, used as-is.
Base.@kwdef struct CustomRadii{T<:Real} <: SizeDistribution
    radii::Vector{T}
end

# ---------------------------------------------------------------------------
#  Contact laws: the parameters of the normal (and, later, frictional) force.
# ---------------------------------------------------------------------------

# Hookean overlap law: F = k * overlap, U = (k/2) * overlap^2.
Base.@kwdef struct Hookean{T<:Real} <: ContactLaw
    k::T = 1.0
end

# Hertzian overlap law: F = (4/3) k sqrt(R_eff) overlap^(3/2).
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
struct Packing{D,T}
    positions::Matrix{T}
    radii::Vector{T}
    box::Vector{T}
    is_rattler::Vector{Bool}
    contacts::Vector{Contact{D,T}}
    metadata::Dict{String,Any}
end
