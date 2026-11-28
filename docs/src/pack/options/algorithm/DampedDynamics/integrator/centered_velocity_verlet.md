# `:centered_velocity_verlet`

*Up:* [`integrator`](index.md)

The default integrator. The damping is evaluated at the midpoint of the step, which turns
the velocity update into a linear system:

$$\left(M + \frac{\Delta t}{2} \Gamma\right) v^{n+1} = \left(M - \frac{\Delta t}{2} \Gamma\right) v^n + \Delta t \, F^n,$$

and the matrix on the left is sparse, symmetric and positive definite, so the implementation
assembles and factorizes it once per step, then solves it once per step (design §8).

Because the damping is treated implicitly, the integrator is stable for any damping ratio
at the time step the contacts allow, and the damping does not lag the motion. That is why
it is the default for production runs.

## Options

None; the integrator is chosen by name.

## Archival reference

- [Integrators](https://github.com/ColtonKawamura/SoftPack/wiki/Damped-dynamics#integrators)
