# `Density()`

*Up:* [`mass`](index.md)

The mass follows from a material density and the particle's size [LAMMPSset]:

$$m_i = \rho \frac{\pi d_i^2}{4} \quad \text{(2D)}, \qquad m_i = \rho \frac{\pi d_i^3}{6} \quad \text{(3D)}.$$

The mass reference $m_\text{ref}$ is the mean of the masses, so a polydisperse mixture
keeps the same average inertia as an equal-mass run and the time step stays comparable.
With $\rho = 1$ the small particle ($d = 1$) has mass 0.785 and the large one
($d = 1.4$) mass 1.539 in 2D.

`Density()` is the physical choice when the mixture has more than one size and the
dynamics of the two species should follow their volume, for example when comparing with a
granular experiment made of one material.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `density` | `1.0` | the material density $\rho$, in reduced units |

Both `Density()` and `Density(density = 2.0)` work.

There is no `shape` keyword: the particle shape follows the dimension, disks in 2D and
spheres in 3D. Other shapes are on the [Roadmap](../../../roadmap.md).

## Example

```julia
using SoftPack

packing = pack(
    mass = Density(
        density = 1.0,  # m_i = rho pi d_i^2/4 in 2D
    ),
    particles_count = 256,
    seed = 1,
)
packing.masses
```

## References

- **[LAMMPSset]** LAMMPS developers. *LAMMPS documentation: set command*. <https://docs.lammps.org/set.html>. Accessed 2026-11-18.
