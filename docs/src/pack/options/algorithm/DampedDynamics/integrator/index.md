# `integrator`

*Up:* [`DampedDynamics`](../index.md)

How the equations of motion are stepped. The three integrators differ in when they
evaluate the damping: the centered velocity Verlet solves the damping implicitly and is the
most robust; the lagged velocity Verlet uses the previous step's relative velocities and is
explicit; the semi-implicit Euler is the simplest explicit scheme.

| Choice | Default | Damping |
|:---|:---|:---|
| `:centered_velocity_verlet` | **default** | implicit, one sparse Cholesky solve per step |
| `:lagged_velocity_verlet` |  | from the previous step's relative velocities |
| `:semi_implicit_euler` |  | explicit, evaluated at the current velocities |

All three are stable at the run's time step, which `CollisionTime` sets from the stiffest
contact. Their stable limits differ,
$2/\omega$ for the centered form and $2(\sqrt{1+\zeta^2}-\zeta)/\omega$ for the other
two, and the packer warns if the chosen step exceeds the limit of the chosen integrator.

The centered form is the default because it tolerates the largest step and does not
introduce a lag in the damping. It costs a sparse Cholesky solve of
$M + \tfrac{\Delta t}{2}\Gamma$ every step; with $N = 256$ that is cheaper than the extra
steps the explicit forms need.

## Archival reference

- [Integrators](https://github.com/ColtonKawamura/SoftPack/wiki/Damped-dynamics#integrators)
