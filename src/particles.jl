# ---------------------------------------------------------------------------
#  Diameters, the reference scales and masses (design §3, §4).
# ---------------------------------------------------------------------------

"""
    draw_diameters(distribution, count, rng) -> Vector{Float64}

The diameters of `count` particles. Only `UniformPolydisperse` draws random numbers (one
`rand(rng)` per particle, in index order); the other laws are deterministic, so the
random stream starts with the positions of the initial state.
"""
function draw_diameters(d::Bidisperse, count::Int, rng)
    # PROVISIONAL T-c822 / T-73sy: N_s = round(f N) small particles, which take the first
    # indices; no random draw, so the seed's stream starts with the positions (this is how
    # the design's worked example was made, §2).
    small_count = round(Int, d.fraction_small * count)
    large = d.diameter_small * d.diameter_ratio
    return [i <= small_count ? d.diameter_small : large for i in 1:count]
end

draw_diameters(d::Monodisperse, count::Int, rng) = fill(d.diameter, count)

function draw_diameters(d::UniformPolydisperse, count::Int, rng)
    low = d.diameter_mean * (1 - d.spread)
    width = 2 * d.diameter_mean * d.spread
    return [low + width * rand(rng) for _ in 1:count]
end

"""
    diameter_reference(params, diameters) -> Float64

The reference diameter `d_ref` (design §3): the small diameter for `Bidisperse`, the
mean or only diameter for the other laws, and the mean of the list for
`particles_diameters`.
"""
function diameter_reference(p::PackParams, diameters::Vector{Float64})
    p.particles_diameters === nothing || return sum_in_order(diameters) / length(diameters)
    return diameter_reference(p.particles_size_distribution)
end
diameter_reference(d::Bidisperse) = d.diameter_small
diameter_reference(d::UniformPolydisperse) = d.diameter_mean
diameter_reference(d::Monodisperse) = d.diameter

"""
    particle_volume(diameter, dimension)

Area of a disk (2D) or volume of a sphere (3D) of the given diameter.
"""
particle_volume(diameter::Real, dimension::Int) =
    dimension == 2 ? pi * diameter^2 / 4 : pi * diameter^3 / 6

"""
    total_volume(diameters, dimension)

The summed particle areas (2D) or volumes (3D), added in index order.
"""
total_volume(diameters::Vector{Float64}, dimension::Int) =
    sum_in_order(d -> particle_volume(d, dimension), diameters)

"""
    particle_masses(rule, diameters, dimension) -> Vector{Float64}
"""
particle_masses(rule::EqualMass, diameters::Vector{Float64}, dimension::Int) =
    fill(rule.mass, length(diameters))

"""
    mass_reference(rule, masses)

The mass scale `m_ref` (design §4): the `EqualMass` value.
"""
mass_reference(rule::EqualMass, masses) = rule.mass
