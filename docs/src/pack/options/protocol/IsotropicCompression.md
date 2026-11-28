# `IsotropicCompression()`

*Up:* [`protocol`](index.md)

Shrink every side of the box by the same factor, relax, look at the pressure, and repeat
[Agnolin2007]. One step is:

1. scale the side length, and every position with it, by $1 - \varepsilon$;
2. run the algorithm until the convergence test holds at the new box;
3. read the pressure.

If the pressure is still below the target band, the step is accepted and the next one uses
the same $\varepsilon$. If the step overshoots the band, it is rejected: the state and the
box are restored, $\varepsilon$ is halved, and the step is tried again. The halving stops
at `strain_step_min`, below which the run reports `:strain_step_min` and stops.

## Why it is the default

Isotropic compression is the standard assembling protocol for model granular packings [Agnolin2007]: it has no shear, so the contact network is built by the same strain path in every direction. The record is kept on the result: the default 2D run does 69 accepted and 15 rejected
compression steps before it lands inside the band. Rejections are cheap, because a
rejected step is undone before the expensive minimization.

With `Walls` the walls move with the box, so the container shrinks with the packing.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `strain_step` | `1e-2` | the first relative shrink $\varepsilon$, between 0 and 1 |

## Example

```julia
using SoftPack

packing = pack(
    protocol = IsotropicCompression(
        strain_step = 1e-2,  # first box shrink, one percent
    ),
    particles_count = 256,
    seed = 1,
)
packing.strain_step_final
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
