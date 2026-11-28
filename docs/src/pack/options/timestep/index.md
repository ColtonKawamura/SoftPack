# `timestep`

*Up:* [Available options](../index.md)

The starting time step [Silbert2001], [OSullivan2004]. FIRE starts at it and adapts it as it goes; damped dynamics keeps
it fixed for the whole run. It is chosen from the shortest contact time of the lightest
pair, so that the fastest oscillation in the packing is resolved.

The default rule is `CollisionTime()`, which scales the elastic contact time. A number is
also accepted; it is interpreted in units of $\sqrt{m_{\mathrm{min}}/k}$.

**Default:** `CollisionTime()`

## Choices

| Choice | Default |
|:---|:---|
| [`CollisionTime()`](CollisionTime.md) | **default** |
| a number |  |

## Example

```julia
using SoftPack

packing = pack(
    timestep = 0.02,  # a fixed step, in units of sqrt(m_min/k)
    particles_count = 256,
    seed = 1,
)
packing.timestep_start
```

## References

- **[Silbert2001]** Leonardo E. Silbert, Deniz Ertaş, Gary S. Grest, Thomas C. Halsey, Dov Levine, Steven J. Plimpton (2001). *Granular flow down an inclined plane: Bagnold scaling and rheology*. Physical Review E **64**, 051302. [doi:10.1103/physreve.64.051302](https://doi.org/10.1103/physreve.64.051302).
- **[OSullivan2004]** Catherine O'Sullivan, Jonathan D. Bray (2004). *Selecting a suitable time step for discrete element simulations that use the central difference time integration scheme*. Engineering Computations **21**, 278--303. [doi:10.1108/02644400410519794](https://doi.org/10.1108/02644400410519794).
