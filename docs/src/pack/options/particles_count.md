# `particles_count`

*Up:* [Available options](index.md)

How many particles the packing has. More particles mean smaller finite-size scatter and a
packing fraction closer to the thermodynamic limit [OHern2003], at a cost that grows faster than
linearly: the default 2D run takes 0.7 s at 256 particles, 7.5 s at 1024 and 112.6 s at
4096.

The default is 256, which is large enough for the packing fraction to be stable to about
$10^{-3}$ and small enough to run in under a second.

**Default:** `256`

## Options

| Value | Meaning |
|:---|:---|
| any integer $N \ge 2$ | the number of particles |

With `particles_diameters` the count is taken from the list; the two cannot disagree.

## Finite-size effect

Default settings, seed 1, 2D:

| $N$ | $\phi$ | $z$ |
|:---|---:|---:|
| 256 | 0.8387 | 4.016 |
| 1024 | 0.8410 | 4.043 |
| 4096 | 0.8415 | 4.045 |

The packing fraction rises with $N$ because the small systems keep a larger fraction of
their particles at the surface of the fluctuation; the rise is 0.0023 from 256 to 1024 and
0.0005 from 1024 to 4096, so quote the largest $N$ or an ensemble.

## Example

```julia
using SoftPack

packing = pack(
    particles_count = 1024,  # four times the default
    seed = 1,
)
packing.packing_fraction
```

## References

- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
