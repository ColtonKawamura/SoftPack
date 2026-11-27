# `IsotropicCompression()`

*Up:* [`protocol`](index.md)

Shrink every side of the box by the same factor, relax, look at the pressure, and repeat
(design §2). One step is:

1. scale the side length, and every position with it, by $1 - \varepsilon$;
2. run the algorithm until the convergence test holds at the new box;
3. read the pressure.

If the pressure is still below the target band, the step is accepted and the next one uses
the same $\varepsilon$. If the step overshoots the band, it is rejected: the state and the
box are restored, $\varepsilon$ is halved, and the step is tried again. The halving stops
at `strain_step_min`, below which the run reports `:strain_step_min` and stops.

The record is kept on the result: the default 2D run does 69 accepted and 15 rejected
compression steps before it lands inside the band. Rejections are cheap, because a
rejected step is undone before the expensive minimization.

With `Walls` the walls move with the box, so the container shrinks with the packing.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `strain_step` | `1e-2` | the first relative shrink $\varepsilon$, between 0 and 1 |

## Archival reference

- [Isotropic compression](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#isotropic-compression)
- [Compression of the default packing](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#compression-of-the-default-packing)
