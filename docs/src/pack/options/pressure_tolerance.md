# `pressure_tolerance`

*Up:* [Available options](index.md)

The width of the pressure band [Agnolin2007]. A compression step is accepted only when the measured
pressure is within this relative band of the target,

$$|P - P_\text{target}| \le \text{pressure\_tolerance} \times P_\text{target},$$

on top of whatever the `convergence` test says. The default $10^{-4}$ lands the pressure
within one part in ten thousand, which is tighter than the run-to-run scatter of the
packing fraction.

The band is what makes the compression protocol finite: without it the box would shrink
until the pressure matched the target exactly, which no finite number of steps can do. A
tighter band costs steps; a looser band saves them and lets the packing fraction wander in
the fourth decimal.

**Default:** `1e-4`

## Options

| Value | Meaning |
|:---|:---|
| any positive number | the relative half-width of the accepted pressure band |

## Example

```julia
using SoftPack

packing = pack(
    pressure_tolerance = 1e-4,  # relative band around the target
    particles_count = 256,
    seed = 1,
)
packing.pressure
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
