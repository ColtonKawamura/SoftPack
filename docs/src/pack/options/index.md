# Available options

*Up:* [`pack()`](../index.md)

Every keyword of `pack()`, grouped, with its default and a link to its page.
A keyword page lists the choices for that keyword and says which is the default.
A choice that has settings of its own, such as `Bidisperse()`, links on to a page of its own.

## Particles and contacts

Who the particles are and how they touch.

| Keyword | Sets | Default | Choices |
|:---|:---|:---|:---|
| [`dimension`](dimension.md) | 2D disks or 3D spheres | `2` | `3` |
| [`particles_count`](particles_count.md) | the number of particles | `256` | any N ≥ 2 |
| [`particles_size_distribution`](particles_size_distribution/index.md) | how particle diameters are drawn | `Bidisperse()` | [`Bidisperse()`](particles_size_distribution/Bidisperse.md), [`UniformPolydisperse()`](particles_size_distribution/UniformPolydisperse.md), [`Monodisperse()`](particles_size_distribution/Monodisperse.md) |
| [`particles_diameters`](particles_diameters.md) | an explicit list of diameters | `nothing` | a vector |
| [`contact`](contact/index.md) | the contact force law | `Hookean()` | [`Hookean()`](contact/Hookean.md), [`Hertzian()`](contact/Hertzian.md) |
| [`friction`](friction/index.md) | tangential contact forces | `nothing` | [`CundallStrack()`](friction/CundallStrack.md), [`Mindlin()`](friction/Mindlin.md) |
| [`mass`](mass/index.md) | the particle masses | `EqualMass()` | [`EqualMass()`](mass/EqualMass.md), [`Density()`](mass/Density.md) |
| [`target`](target/index.md) | the pressure the compression runs to | `Pressure(1e-4)` | [`Pressure()`](target/Pressure.md) |

## Stopping, failure and restarts

When a run stops, what happens if it does not converge, and how to continue it.

| Keyword | Sets | Default | Choices |
|:---|:---|:---|:---|
| [`convergence`](convergence/index.md) | when a run counts as converged | `RelativeForce()` | [`RelativeForce()`](convergence/RelativeForce.md), [`LeidenAcceleration()`](convergence/LeidenAcceleration.md), [`KineticEnergy()`](convergence/KineticEnergy.md), [`RestartTest()`](convergence/RestartTest.md), [Your own test function](convergence/custom_test.md) |
| [`pressure_tolerance`](pressure_tolerance.md) | how close the pressure must come to the target | `1e-4` | any value |
| [`steps_max`](steps_max.md) | the step cap per call | `10^7` | any value |
| [`failure_action`](failure_action.md) | what happens when a run does not converge | `:warn` | `:error` |
| [`restart_packing`](restart_packing.md) | continue from a saved run | `nothing` | path to a file |
| [`restart_file`](restart_file/index.md) | save the run state during the run | `nothing` | [`RestartFile()`](restart_file/RestartFile.md) |

## Algorithm, damping and time step

How the packing is relaxed. `damping` and `drag` are not keywords of `pack()`: they are keywords of the algorithm, so they sit one level down, under `algorithm`.

| Keyword | Sets | Default | Choices |
|:---|:---|:---|:---|
| [`algorithm`](algorithm/index.md) | the minimizer or dynamics | `FIRE()` | [`FIRE()`](algorithm/FIRE.md), [`DampedDynamics()`](algorithm/DampedDynamics/index.md); inside them: [`damping`](algorithm/DampedDynamics/damping/index.md), [`drag`](algorithm/DampedDynamics/drag/index.md) |
| [`timestep`](timestep/index.md) | the size of the time step | `CollisionTime()` | [`CollisionTime()`](timestep/CollisionTime.md), fixed number |

## Rattlers

Which particles are rattlers and whether they are removed.

| Keyword | Sets | Default | Choices |
|:---|:---|:---|:---|
| [`rattlers`](rattlers/index.md) | which particles are rattlers and whether to remove them | `ContactCount()` | [`ContactCount()`](rattlers/ContactCount.md), [`TwoContact()`](rattlers/TwoContact.md), [`ForceFloor()`](rattlers/ForceFloor.md), [`Unresolved()`](rattlers/Unresolved.md), [Your own rule function](rattlers/custom_rule.md), `nothing` |

## Reproducibility and outputs

The random seed and what is recorded during the run.

| Keyword | Sets | Default | Choices |
|:---|:---|:---|:---|
| [`seed`](seed.md) | the random seed | `1` | any integer |
| [`snapshots`](snapshots/index.md) | record the configuration during the run | `nothing` | [`Snapshots()`](snapshots/Snapshots.md) |
| [`movie`](movie/index.md) | render a movie during the run | `nothing` | [`Movie()`](movie/Movie.md) |

## Where is damping?

!!! note "damping and drag are keywords of the algorithm, not of `pack()`"
    The algorithm decides whether there are dashpots at all.
    `FIRE()` takes `damping` and `drag` and defaults both to `nothing`.
    `DampedDynamics()` takes the same two keywords and defaults `damping` to `ContactDamping()`.

```julia
pack(                                             # run the packing
    algorithm = DampedDynamics(                   # velocity-Verlet damped dynamics
        damping = ContactDamping(normal = 0.98),  # contact dashpots, normal ratio 0.98
        drag    = nothing,                        # no Stokes drag
    )                                             # end of DampedDynamics call
)                                                 # end of pack call
```

- [`damping`](algorithm/DampedDynamics/damping/index.md): the dashpot models [`ContactDamping()`](algorithm/DampedDynamics/damping/ContactDamping.md), [`ViscousRate()`](algorithm/DampedDynamics/damping/ViscousRate.md) and [`RelativeVelocityDamping()`](algorithm/DampedDynamics/damping/RelativeVelocityDamping.md).
- [`drag`](algorithm/DampedDynamics/drag/index.md): Stokes drag, [`StokesDrag()`](algorithm/DampedDynamics/drag/StokesDrag.md).
- [`FIRE()`](algorithm/FIRE.md): the default algorithm, with no damping and no drag.

## Beyond the keywords

- [`PackParams()`](../PackParams.md): bundle keywords into a reusable value and call `pack(params)`.
- [`Packing`](../Packing.md): what `pack()` returns.
- [`find_rattlers()`](rattlers/find_rattlers.md): apply a rattler rule to a finished packing.
- [Your own test function](convergence/custom_test.md) and [Your own rule function](rattlers/custom_rule.md): any function can be a convergence test or a rattler rule.
- [`write_packing()`](../../write_packing/index.md): save a packing to disk.
