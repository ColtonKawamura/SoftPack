# `algorithm`

*Up:* [Available options](../index.md)

The algorithm moves the particles. SoftPack has two: FIRE, a minimization that adapts its
own time step and zeroes the velocity on an uphill step, and damped dynamics, a physical
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

## Archival reference

- [Algorithms](https://github.com/ColtonKawamura/SoftPack/wiki/Algorithms)
