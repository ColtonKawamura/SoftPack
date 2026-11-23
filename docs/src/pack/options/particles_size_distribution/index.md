# `particles_size_distribution`

*Up:* [Available options](../index.md)

`particles_size_distribution` chooses the law that the particle diameters are drawn from.
The default is a 50:50 mixture of two diameters in the ratio 1.4, the mixture that prevents crystallization in 2D jamming studies.
Each choice fixes the length unit through its own defaults: `Bidisperse()` makes the small diameter 1, `UniformPolydisperse()` makes the mean diameter 1, and `Monodisperse()` makes its one diameter 1.
Every output stores each particle's diameter.

## The call with the default written out

```julia
pack(                                           # run the packing
    particles_size_distribution = Bidisperse()  # two-diameter mixture (default)
)                                               # end of pack call
```

- `pack(...)` — [runs the packing](../../index.md).
- `particles_size_distribution = Bidisperse()` **(default)** — a 50:50 mixture of two diameters in the ratio 1.4.
  - For details, see [`Bidisperse()`](Bidisperse.md).

## Choices

| Choice | Draws diameters from | Length unit | |
|:---|:---|:---|:---|
| [`Bidisperse()`](Bidisperse.md) | two diameters, large over small 1.4, half of each by number | the small diameter is 1 | **default** |
| [`UniformPolydisperse()`](UniformPolydisperse.md) | a uniform law between 0.8 and 1.2 times the mean | the mean diameter is 1 | |
| [`Monodisperse()`](Monodisperse.md) | one diameter for every particle | that diameter is 1 | |

## Related keywords

- [`particles_diameters`](../particles_diameters.md): give the diameters themselves instead of drawing them from a distribution.
- [`particles_count`](../particles_count.md): the number of particles $N$.
- [Units and length unit](../../../reference/units.md): how the length unit sets every other unit.

## Theory

For now these sections are on the wiki.

- [Particle size distribution and length unit](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit): the whole wiki page for this keyword.
- [Model](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#model): the diameters, each law and the packing fraction of a mixture.
- [Derivations](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#derivations): the moments of each law and how a change of length unit changes the numbers.
