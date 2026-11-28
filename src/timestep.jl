# ---------------------------------------------------------------------------
#  The starting time step (design §12). FIRE starts here and adapts (§14);
#  DampedDynamics keeps it fixed.
# ---------------------------------------------------------------------------

"""
    expected_overlap(law, stiffness, target, diameter_ref, dimension, packing_fraction)

The largest overlap a run is expected to reach, used to evaluate a Hertzian stiffness
before any contact exists (design §12: "the stiffness at the largest overlap expected").
With the mean normal force from the pressure, `f = P pi d / (z phi)`, the typical overlap
follows from the contact law, and the largest is taken as three times that force.

PROVISIONAL T-d66w: the factor three is my choice; the card fixes only that the largest
overlap is used.
"""
function expected_overlap(law::Hookean, stiffness::Float64, target::Float64,
                          diameter_ref::Float64, dimension::Int, packing_fraction::Float64)
    return 0.0
end

function expected_overlap(law::Hertzian, stiffness::Float64, target::Float64,
                          diameter_ref::Float64, dimension::Int,
                          packing_fraction::Float64)
    contacts = 2 * dimension                      # z near jamming: 4 in 2D, 6 in 3D
    force = target * pi * diameter_ref / (contacts * packing_fraction)
    return (3 * force / stiffness)^(2 / 3)
end

"""
    stiffest_contact_stiffness(law, stiffness, overlap, friction, dimension)

The largest stiffness a contact can present: the normal one, or the tangential one when
friction is on (design §12). The tangential stiffness of `CundallStrack` is a fixed
multiple of the normal one; `Mindlin` scales the same way at this overlap.
"""
function stiffest_contact_stiffness(law::ContactLaw, stiffness::Float64, overlap::Float64,
                                    friction, dimension::Int)
    normal = contact_stiffness(law, overlap)
    friction === nothing && return normal
    return max(normal, tangential_stiffness(friction, normal, dimension))
end

"""
    timestep_start(rule, masses, stiffness, mass_ref; friction, dimension, law,
                   target, diameter_ref, packing_fraction) -> Float64

`CollisionTime(fraction)`: `fraction` times the shortest binary collision time
`t_col = pi sqrt(M / k)` over the two contact directions, with `M` the reduced mass of the
lightest pair for the normal direction and the rotation-included sliding mass for the
tangential one (card T-d66w, option 1; design §12). A number: that many time units
`tau = sqrt(m_min / stiffness)`.
"""
function timestep_start(rule::CollisionTime, masses::Vector{Float64},
                        stiffness::Float64, mass_ref::Float64;
                        friction = nothing, dimension::Int = 2,
                        law::ContactLaw = Hookean(), target::Float64 = 1e-4,
                        diameter_ref::Float64 = 1.0, packing_fraction::Float64 = 0.84)
    lightest = minimum(masses)
    mass_normal = lightest / 2                      # reduced mass of the lightest pair
    overlap = expected_overlap(law, stiffness, target, diameter_ref, dimension,
                               packing_fraction)
    normal_stiffness = contact_stiffness(law, overlap)
    if friction === nothing
        return rule.fraction * pi * sqrt(mass_normal / normal_stiffness)
    end
    tangential_k = tangential_stiffness(friction, normal_stiffness, dimension)
    # 1/M_t = (1 + 1/kappa)/M_n for a pair of one shape (design §8)
    mass_tangential = mass_normal / (1 + 1 / inertia_ratio(dimension))
    normal_time = sqrt(mass_normal / max(normal_stiffness, eps()))
    tangential_time = sqrt(mass_tangential / max(tangential_k, eps()))
    return rule.fraction * pi * min(normal_time, tangential_time)
end

# Card T-d66w, option 1: a fixed step is in units of tau = sqrt(m_min / k), the elastic
# time of the lightest particle, so the same number is the same physical step for any
# mass distribution. With EqualMass it equals the old sqrt(m_ref / k).
timestep_start(value::Real, masses::Vector{Float64}, stiffness::Float64,
               mass_ref::Float64; kwargs...) =
    Float64(value) * sqrt(minimum(masses) / stiffness)

"""
    stable_step(integrator, omega, zeta)

The largest step a damped oscillator of angular frequency `omega` and damping ratio `zeta`
tolerates under the given integrator (design §8): `2/omega` for the centered velocity
Verlet, `2 (sqrt(1 + zeta^2) - zeta)/omega` for the lagged form and the semi-implicit
Euler.
"""
function stable_step(integrator::Symbol, omega::Float64, zeta::Float64)
    omega <= 0 && return Inf
    if integrator === :centered_velocity_verlet
        return 2 / omega
    end
    return 2 * (sqrt(1 + zeta^2) - zeta) / omega
end

"""
    check_timestep(system, timestep, algorithm) -> (omega_max, stable)

The highest contact frequency in the packing against the chosen step. Returns the largest
`omega` found and the stable step of the algorithm's integrator at the default damping
ratio. The caller warns when `timestep` exceeds it; the step itself is never changed
(design §12).
"""
function check_timestep(s::System{D}, timestep::Float64, algorithm) where {D}
    omega = 0.0
    @inbounds for c in eachindex(s.table.normal_forces)
        i = s.table.first[c]
        j = s.table.second[c]
        mass_normal = j == 0 ? s.masses[i] :
            1 / (1 / s.masses[i] + 1 / s.masses[j])
        omega = max(omega, sqrt(s.table.normal_stiffnesses[c] / mass_normal))
        if s.table.tangential_stiffnesses[c] > 0
            if j == 0
                inverse = 1 / s.masses[i] + s.table.levers_first[c]^2 / s.moments[i]
            else
                inverse = 1 / s.masses[i] + 1 / s.masses[j] +
                          s.table.levers_first[c]^2 / s.moments[i] +
                          s.table.levers_second[c]^2 / s.moments[j]
            end
            omega = max(omega, sqrt(s.table.tangential_stiffnesses[c] * inverse))
        end
    end
    zeta = algorithm isa DampedDynamics && algorithm.damping isa ContactDamping ?
        algorithm.damping.normal : 0.0
    integrator = algorithm isa DampedDynamics ? algorithm.integrator : :semi_implicit_euler
    return omega, stable_step(integrator, omega, zeta)
end
