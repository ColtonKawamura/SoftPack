# `boundary`

*Up:* [Available options](../index.md)

The box that holds the particles [Agnolin2007]. A periodic box has no walls: a particle that leaves one
side comes back on the opposite one, so the packing is a piece of an infinite medium and
has no boundary effects. A `Walls` box has rigid walls on every side, so the packing has a
container, a surface layer, and wall friction if the walls are frictional.

The choice changes the pressure bookkeeping (wall contacts add a term to the virial), the
initial placement (walls are filled rather than wrapped), and the coordination number near
the surface, but not the physics of the contact law.

**Default:** `Periodic()`

## Choices

| Choice | Default |
|:---|:---|
| [`Periodic()`](Periodic.md) | **default** |
| [`Walls()`](Walls.md) |  |

## Example

```julia
using SoftPack

packing = pack(
    boundary = Walls(
        friction = true,
    ),
    particles_count = 256,
    seed = 1,
)
packing.packing_fraction
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
