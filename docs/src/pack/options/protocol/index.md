# `protocol`

*Up:* [Available options](../index.md)

How the box is brought to the target [Agnolin2007]. The protocol changes the box, then lets the
algorithm restore force balance, then asks whether the pressure is where it should be; the
answer decides whether the next step grows, shrinks or stays.

**Default:** `IsotropicCompression(strain_step = 1e-2)`

## Choices

| Choice | Default |
|:---|:---|
| [`IsotropicCompression()`](IsotropicCompression.md) | **default** |

## Example

```julia
using SoftPack

packing = pack(
    protocol = IsotropicCompression(
        strain_step = 5e-3,
    ),
    particles_count = 256,
    seed = 1,
)
packing.strain_step_final
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
