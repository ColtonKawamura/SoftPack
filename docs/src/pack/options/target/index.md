# `target`

*Up:* [Available options](../index.md)

The target is what the compression runs to [Agnolin2007]. SoftPack stops when the pressure measured from
the contacts is inside a band around the target and the convergence test holds, so the
target is the pressure at which the packing is defined, not a packing fraction: the
packing fraction that comes out is the answer, not the input.

The pressure is the elastic virial of the contact forces divided by the volume; it counts
the pair contacts and, for a `Walls` box, the wall contacts.

**Default:** `Pressure(1e-4)`

## Choices

| Choice | Default |
|:---|:---|
| [`Pressure()`](Pressure.md) | **default** |

## Example

```julia
using SoftPack

packing = pack(
    target = Pressure(1e-3),  # a looser, faster packing
    particles_count = 256,
    seed = 1,
)
packing.packing_fraction
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
