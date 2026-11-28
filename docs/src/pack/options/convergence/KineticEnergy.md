# `KineticEnergy()`

*Up:* [`convergence`](index.md)

A test for dynamics rather than minimization [Agnolin2007], [Xiong2019]: the packing must be at rest,

$$\frac{1}{N}\sum_i \left(\tfrac{1}{2} m_i |v_i|^2 + \tfrac{1}{2} I_i |\omega_i|^2\right) < \varepsilon \, P_\text{target} \, d_\text{ref}^D,$$

and the ordinary `RelativeForce` test must hold at its default tolerance. The right-hand
side is the energy scale of the target pressure, so a run at a lower pressure is asked for
a correspondingly lower kinetic energy.

The rotational term was fixed for 3D. The test exists for damped
dynamics, where the velocities are physical and a packing can be mechanically balanced
while one particle still drifts. FIRE manages its velocities itself,
so with FIRE the plain force test is the natural one.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `tolerance` | `1e-8` | $\varepsilon$, relative to the pressure energy scale |

## Example

```julia
using SoftPack

packing = pack(
    algorithm = DampedDynamics(),  # velocities are physical
    convergence = KineticEnergy(
        tolerance = 1e-8,
    ),
    particles_count = 64,
    seed = 1,
)
packing.converged
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[Xiong2019]** Fansheng Xiong, Philip Wang, Abram H. Clark, Thibault Bertrand, Nicholas T. Ouellette, Mark D. Shattuck, Corey S. O’Hern (2019). *Comparison of shear and compression jammed packings of frictional disks*. Granular Matter **21**, 109. [doi:10.1007/s10035-019-0964-9](https://doi.org/10.1007/s10035-019-0964-9).
