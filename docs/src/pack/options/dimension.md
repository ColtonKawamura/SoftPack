# `dimension`

*Up:* [Available options](index.md)

The dimension of the packing: 2 for disks in a square box, 3 for spheres in a cube. It
sets the shape of a particle, the number of rotational degrees of freedom (one angle in
2D, three in 3D), the volume factor in the pressure and the expected jamming point.

The default is 2 because the shortest runs and the clearest movies are 2D. At low
pressure, harmonic disks jam near $\phi = 0.84$ and spheres near $0.64$ [OHern2003]; the coordination
is $z_\text{iso} = 2D$ frictionless and $D + 1$ with friction.

**Default:** `2`

## Options

| Value | Meaning |
|:---|:---|
| `2` | disks in a square box |
| `3` | spheres in a cube |

## Example

```julia
using SoftPack

packing = pack(
    dimension = 3,          # 2 gives disks, 3 gives spheres
    particles_count = 512,  # more particles for a 3D fluctuation
    seed = 1,
)
packing.packing_fraction
```

In 3D use more particles than in 2D for the same quality: the surface-to-volume ratio of
the fluctuation is larger, and the README example uses 512.

## References

- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
