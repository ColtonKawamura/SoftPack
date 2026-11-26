# ---------------------------------------------------------------------------
#  The starting time step (design §12). FIRE starts here and adapts (§14).
# ---------------------------------------------------------------------------

"""
    timestep_start(rule, masses, stiffness, mass_ref) -> Float64

`CollisionTime(fraction)`: `fraction * pi * sqrt(m_eff / k)`, the shortest binary
collision time, with `m_eff = m_min / 2` the reduced mass of the lightest pair (card
T-d66w, option 1; Silbert et al.'s `t_col` with no damping). A number: that many time
units `tau = sqrt(m_ref / k)`.
"""
function timestep_start(rule::CollisionTime, masses::Vector{Float64}, stiffness::Float64,
                        mass_ref::Float64)
    mass_effective = minimum(masses) / 2   # lightest pair; walls (m_i alone) not built yet
    return rule.fraction * pi * sqrt(mass_effective / stiffness)
end

# PROVISIONAL T-d66w: a fixed step is in units of tau = sqrt(m_ref / k); the card's option 1
# writes sqrt(m_min / k), which is the same number for EqualMass, the only mass rule built.
timestep_start(value::Real, masses::Vector{Float64}, stiffness::Float64, mass_ref::Float64) =
    Float64(value) * sqrt(mass_ref / stiffness)
