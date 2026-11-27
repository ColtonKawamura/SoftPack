# `dimension`

*Up:* [Available options](index.md)

The dimension of the packing: 2 for disks in a square box, 3 for spheres in a cube. It
sets the shape of a particle, the number of rotational degrees of freedom (one angle in
2D, three in 3D), the volume factor in the pressure and the expected jamming point.

The default is 2 because the shortest runs and the clearest movies are 2D. At low
pressure, harmonic disks jam near $\phi = 0.84$ and spheres near $0.64$; the coordination
is $z_\text{iso} = 2D$ frictionless and $D + 1$ with friction.

**Default:** `2`

## Options

| Value | Meaning |
|:---|:---|
| `2` | disks in a square box |
| `3` | spheres in a cube |

## Example

```
pack(dimension = 3, particles_count = 512)
```

In 3D use more particles than in 2D for the same quality: the surface-to-volume ratio of
the fluctuation is larger, and the default 3D run uses 512.

## Archival reference

- [pack(dimension = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#packdimension--)
