# `convergence`

*Up:* [Available options](../index.md)

The convergence test decides when a minimization has finished [Agnolin2007], [Somfai2005], [Xiong2019], and it is the setting that
costs the most: the default tolerance of $10^{-8}$ takes about $1.6$ times the steps of
$10^{-4}$ for a packing fraction that moves in the fourth decimal.

Every test is asked after the algorithm has stepped, and it is asked together with the
pressure band: a compression step is accepted only when the test holds *and* the pressure
is inside the band. A test that never holds runs until `steps_max` and the run reports
`converged = false`.

**Default:** `RelativeForce()`

## Choices

| Choice | Default | Asks |
|:---|:---|:---|
| [`RelativeForce()`](RelativeForce.md) | **default** | every net force below `tolerance` times the mean contact force, and with friction every torque similarly |
| [`LeidenAcceleration()`](LeidenAcceleration.md) |  | every acceleration below `tolerance` in reduced units |
| [`KineticEnergy()`](KineticEnergy.md) |  | the force test plus a mean kinetic energy below `tolerance * P * d^D` |
| [`RestartTest()`](RestartTest.md) |  | the force test, then that a restart of the packing does not grow back |
| [Your own test function](custom_test.md) |  | whatever you write, as a function of the `RunState` |

## Example

```julia
using SoftPack

packing = pack(
    convergence = LeidenAcceleration(
        tolerance = 1e-10,
    ),
    particles_count = 256,
    seed = 1,
)
packing.converged
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
- **[Xiong2019]** Fansheng Xiong, Philip Wang, Abram H. Clark, Thibault Bertrand, Nicholas T. Ouellette, Mark D. Shattuck, Corey S. O’Hern (2019). *Comparison of shear and compression jammed packings of frictional disks*. Granular Matter **21**, 109. [doi:10.1007/s10035-019-0964-9](https://doi.org/10.1007/s10035-019-0964-9).
