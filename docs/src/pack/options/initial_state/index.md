# `initial_state`

*Up:* [Available options](../index.md)

Where the compression starts. The start has to be below the jamming packing fraction, so
that the particles do not overlap and the first minimization has something to do; a dilute
random placement at rest is the simplest such state [Agnolin2007] and is the one the design specifies.

**Default:** `Dilute(packing_fraction = 0.25)`

## Choices

| Choice | Default |
|:---|:---|
| [`Dilute()`](Dilute.md) | **default** |

## Example

```julia
using SoftPack

packing = pack(
    initial_state = Dilute(
        packing_fraction = 0.20,
    ),
    particles_count = 256,
    seed = 1,
)
packing.packing_fraction
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
