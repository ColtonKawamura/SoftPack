# ---------------------------------------------------------------------------
#  Hookean contact law:  F = k * delta,   U = (k/2) * delta^2.
#
#  delta > 0 while the two particles overlap (in contact). These helpers take the
#  element type T implicitly through their numeric arguments, so the result stays
#  in Float32 / Float64 as the rest of the run.
#
#  `compute_forces!` calls both laws with the same 4-argument signature
#  (self, k, delta, R_eff). Hooke's law does not use the effective radius, so the
#  4-arg methods accept it and ignore it; this keeps a single uniform call site in
#  forces.jl for every contact law.
# ---------------------------------------------------------------------------

"""
    force_magnitude(::Hookean, k, delta) -> fn

Hookean normal force magnitude `F = k * delta` (delta > 0 in contact).
"""
force_magnitude(::Hookean, k, delta) = k * delta

"""
    force_magnitude(::Hookean, k, delta, R_eff) -> fn

4-argument form used by `compute_forces!`; the effective radius is accepted but
unused because Hooke's law has no size dependence.
"""
force_magnitude(::Hookean, k, delta, R_eff) = k * delta

"""
    contact_energy(::Hookean, k, delta) -> U

Hookean potential energy `U = (k/2) * delta^2`.
"""
contact_energy(::Hookean, k, delta) = k * delta * delta / 2

"""
    contact_energy(::Hookean, k, delta, R_eff) -> U

4-argument form used by `compute_forces!`; the effective radius is accepted but
unused because Hooke's law has no size dependence.
"""
contact_energy(::Hookean, k, delta, R_eff) = k * delta * delta / 2
