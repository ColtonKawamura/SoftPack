# `convergence`

*Up:* [Available options](../index.md)

The convergence test decides when a minimization has finished, and it is the setting that
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

## Archival reference

- [Convergence criterion](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion)
