# `damping`

*Up:* [`DampedDynamics`](../index.md)

The contact dashpots [Agnolin2007], [Santos2024]. A dashpot removes energy in proportion to the relative velocity at a
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

## Example

```julia
using SoftPack

packing = pack(
    algorithm = DampedDynamics(
        damping = ContactDamping(
            normal = 0.98,
            tangential = 0.98,
        ),
    ),
    particles_count = 64,
    seed = 1,
)
packing.converged
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[Santos2024]** A. P. Santos, Ishan Srivastava, Leonardo E. Silbert, Jeremy B. Lechman, Gary S. Grest (2024). *Protocol-dependent frictional granular jamming simulations: cyclical, compression, and expansion*. Frontiers in Soft Matter **3**, 1326756. [doi:10.3389/frsfm.2023.1326756](https://doi.org/10.3389/frsfm.2023.1326756).
