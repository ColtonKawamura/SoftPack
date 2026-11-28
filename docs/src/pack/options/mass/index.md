# `mass`

*Up:* [Available options](../index.md)

The mass sets the inertia of a particle and, with the stiffness, the elastic time scale of
the run. It does not change the jammed configuration at a given pressure, only how the run
gets there and how long it takes: heavier particles move more slowly under the same force [OHern2003], [LAMMPSset].

With friction the mass matters twice, because each particle also carries a moment of
inertia

$$I = \kappa m R^2,$$

with $\kappa = 1/2$ for a disk and $\kappa = 2/5$ for a sphere, and $R = d/2$. The spin
equation uses $I$, and the tangential effective mass that sets the tangential contact
time includes it.

**Default:** `EqualMass()`

## Choices

| Choice | Default | Mass of particle $i$ |
|:---|:---|:---|
| [`EqualMass()`](EqualMass.md) | **default** | $m$ for every particle |
| [`Density()`](Density.md) |  | $\rho$ times the area (2D) or volume (3D) |

## Example

```julia
using SoftPack

packing = pack(
    mass = Density(
        density = 1.0,
    ),
    particles_count = 256,
    seed = 1,
)
packing.masses
```

## References

- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
- **[LAMMPSset]** LAMMPS developers. *LAMMPS documentation: set command*. <https://docs.lammps.org/set.html>. Accessed 2026-11-18.
