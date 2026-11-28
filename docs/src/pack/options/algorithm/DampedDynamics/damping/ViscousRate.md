# `ViscousRate()`

*Up:* [`damping`](index.md)

The dashpot is a fixed rate per unit mass [Santos2024]:

$$\gamma_n = M_n r_n, \qquad \gamma_t = M_t r_t,$$

with $r$ in inverse time. Because the coefficient does not depend on the stiffness, it does
not change when the contact law or the stiffness changes, which makes it the right choice
when you want a relaxation time you control rather than one the contact sets.

The default rate is 0.5 for both directions, a damping time of two in reduced units.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `normal` | `0.5` | $r_n$, the normal rate |
| `tangential` | `0.5` | $r_t$, the tangential rate |
| `attractive` | `false` | whether the dashpot can pull |
| `coulomb_limit` | `:elastic` | which normal force caps the tangential dashpot |

## Example

```julia
using SoftPack

packing = pack(
    algorithm = DampedDynamics(
        damping = ViscousRate(
            normal = 0.5,      # rate r_n
            tangential = 0.5,  # rate r_t
        ),
    ),
    particles_count = 64,
    seed = 1,
)
packing.converged
```

## References

- **[Santos2024]** A. P. Santos, Ishan Srivastava, Leonardo E. Silbert, Jeremy B. Lechman, Gary S. Grest (2024). *Protocol-dependent frictional granular jamming simulations: cyclical, compression, and expansion*. Frontiers in Soft Matter **3**, 1326756. [doi:10.3389/frsfm.2023.1326756](https://doi.org/10.3389/frsfm.2023.1326756).
