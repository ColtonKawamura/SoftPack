# `Dilute()`

*Up:* [`initial_state`](index.md)

Random sequential addition at rest (design §2). The particles are placed one at a time,
largest first, at uniformly random positions; a trial that overlaps a particle already
placed is rejected and a new one is drawn. The placement stops at the requested packing
fraction, and the box is sized to hold it:

$$L_0 = \left(\frac{\sum_i \pi d_i^2/4}{\phi_0}\right)^{1/2} \quad \text{(2D)}, \qquad L_0 = \left(\frac{\sum_i \pi d_i^3/6}{\phi_0}\right)^{1/3} \quad \text{(3D)}.$$

No particle moves during the placement, so the state has no contacts and zero energy, and
the compression starts from a well-defined dilute configuration.

The default $\phi_0 = 0.25$ is low enough that the placement never jams for the default
mixture: the largest particle is the one that limits the trials, and at a quarter packing
fraction there is room for it.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `packing_fraction` | `0.25` | $\phi_0$ of the placement, between 0 and 1 |

## Archival reference

- [Dilute start](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#dilute-start)
- [pack(initial_state = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#packinitial_state--)
