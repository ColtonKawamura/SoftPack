# `damping`

*Up:* [`DampedDynamics`](../index.md)

The contact dashpots. A dashpot removes energy in proportion to the relative velocity at a
contact; SoftPack offers three ways to set its coefficient, all of them written as a
damping ratio or a rate so that a run keeps its meaning when the stiffness changes.

| Choice | Default | Coefficient |
|:---|:---|:---|
| [`ContactDamping()`](ContactDamping.md) | **default** | $\gamma = 2\zeta\sqrt{k M}$, proportional to the contact time |
| [`ViscousRate()`](ViscousRate.md) |  | $\gamma = M r$, a fixed rate per unit mass |
| [`RelativeVelocityDamping()`](RelativeVelocityDamping.md) |  | $\gamma = M r$ on the full relative velocity, one term for both directions |

Damping can also be given to FIRE, where it acts as extra dissipation on top of the
velocity mixing.

All three take `attractive` and `coulomb_limit`. `attractive = false` (the default) lets
the dashpot only push apart, so it never holds two particles together; `attractive = true`
lets it act in both directions, which can help with a saddle but can also pair particles
that should separate. `coulomb_limit = :elastic` caps the tangential dashpot by the elastic
normal force; the alternative `:total` is designed but not implemented.

## Archival reference

- [Damping](https://github.com/ColtonKawamura/SoftPack/wiki/Damping)
