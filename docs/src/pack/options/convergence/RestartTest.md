# `RestartTest()`

*Up:* [`convergence`](index.md)

The check for saddles [Agnolin2007]. It first requires the `RelativeForce` test at its
default tolerance, then zeroes the velocities on the final packing, relaxes once more, and
asks whether the kinetic energy and the unbalanced forces stay down. A packing that passes
the force test but drifts as soon as it is nudged was sitting on a saddle or on a
marginal contact, and the restart test catches it.

It has three options:

| Option | Default | Meaning |
|:---|:---|:---|
| `watch` | `2000` | steps of relaxation after the velocities are zeroed |
| `growth` | `2.0` | how much the largest unbalanced force may grow |
| `energy_tolerance` | `1e-8` | the kinetic-energy scale, as in `KineticEnergy` |

The first part of the test is the force balance at the `RelativeForce` default,
$10^{-8}$.

This is the most expensive test of the five, because it runs a second short minimization
for every acceptance.

## Example

```julia
using SoftPack

packing = pack(
    convergence = RestartTest(
        watch = 2000,        # steps after zeroing the velocities
        growth = 2.0,        # allowed force growth
        energy_tolerance = 1e-8,
    ),
    particles_count = 256,
    seed = 1,
)
packing.converged
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
