# ---------------------------------------------------------------------------
#  Hertzian contact law:
#     F = (4/3) k sqrt(R_eff) delta^(3/2)
#     U = (4/3)(2/5) k sqrt(R_eff) delta^(5/2)
#  with the reduced (effective) radius  R_eff = r_i r_j / (r_i + r_j).
#
#  Matches the magnitudes in ~/repos/GranE/src/pack.m (its negative sign is
#  absorbed into the normal direction; SoftPack keeps a positive magnitude and a
#  normal pointing from i to j). The fractional exponents are raised to the
#  element type T so Float32 runs stay Float32.
# ---------------------------------------------------------------------------

"""
    effective_radius(r_i, r_j) -> R_eff

Reduced radius `R_eff = r_i r_j / (r_i + r_j)` used by the Hertzian law.
"""
effective_radius(r_i, r_j) = r_i * r_j / (r_i + r_j)

"""
    force_magnitude(::Hertzian, k, delta, R_eff) -> fn

Hertzian normal force magnitude `F = (4/3) k sqrt(R_eff) delta^(3/2)`.
"""
function force_magnitude(::Hertzian, k, delta::T, R_eff::T) where {T}
    return (T(4) / T(3)) * k * sqrt(R_eff) * delta^T(3 / 2)
end

"""
    contact_energy(::Hertzian, k, delta, R_eff) -> U

Hertzian potential energy `U = (4/3)(2/5) k sqrt(R_eff) delta^(5/2)`.
"""
function contact_energy(::Hertzian, k, delta::T, R_eff::T) where {T}
    return (T(4) / T(3)) * (T(2) / T(5)) * k * sqrt(R_eff) * delta^T(5 / 2)
end
