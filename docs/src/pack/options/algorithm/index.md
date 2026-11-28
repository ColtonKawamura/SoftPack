# `algorithm`

*Up:* [Available options](../index.md)

The algorithm moves the particles [Bitzek2006], [Guenole2020], [Agnolin2007]. SoftPack has two: FIRE, a minimization that adapts its
own time step and steps back half a step on an uphill move, and damped dynamics, a physical
relaxation with contact dashpots and optional Stokes drag.

FIRE is the default because it reaches a tight force tolerance fastest on soft packings:
in the benchmarks it converges the default run in 87,000 steps, while damped dynamics does
not reach the same tolerance in five times as many. Damped dynamics is the choice when the
path matters, not just the endpoint: it is a real trajectory, so its damping models,
integrators and drag can be compared with a physical experiment, and its velocity field
can be read at any step.

Both algorithms take the same optional `damping` and `drag`; FIRE uses them as extra
dissipation on top of its own velocity mixing. They are documented under the
damped-dynamics pages because that is where they are usually used.

**Default:** `FIRE()`

## Choices

| Choice | Default | What it does |
|:---|:---|:---|
| [`FIRE()`](FIRE.md) | **default** | adaptive-step minimization with velocity mixing |
| [`DampedDynamics()`](DampedDynamics/index.md) |  | velocity Verlet with contact dashpots, optional drag, three integrators |

## Example

```julia
using SoftPack

packing = pack(
    algorithm = DampedDynamics(
        integrator = :centered_velocity_verlet,
    ),
    particles_count = 64,
    seed = 1,
)
packing.converged
```

## References

- **[Bitzek2006]** Erik Bitzek, Pekka Koskinen, Franz Gähler, Michael Moseler, Peter Gumbsch (2006). *Structural Relaxation Made Simple*. Physical Review Letters **97**, 170201. [doi:10.1103/physrevlett.97.170201](https://doi.org/10.1103/physrevlett.97.170201).
- **[Guenole2020]** Julien Guénolé, Wolfram G. Nöhring, Aviral Vaid, Frédéric Houllé, Zhuocheng Xie, Aruna Prakash, Erik Bitzek (2020). *Assessment and optimization of the fast inertial relaxation engine (fire) for energy minimization in atomistic simulations and its implementation in lammps*. Computational Materials Science **175**, 109584. [doi:10.1016/j.commatsci.2020.109584](https://doi.org/10.1016/j.commatsci.2020.109584).
- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
