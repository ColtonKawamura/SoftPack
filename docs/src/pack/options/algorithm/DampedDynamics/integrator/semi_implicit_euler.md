# `:semi_implicit_euler`

*Up:* [`integrator`](index.md)

The simplest scheme: positions are updated with the new velocity, and the velocity with
the force and the damping at the current step,

$$v^{n+1} = v^n + \Delta t \, M^{-1}\left(F^n - \Gamma v^n\right), \qquad x^{n+1} = x^n + \Delta t \, v^{n+1}.$$

It is explicit and first order, with the same stability limit as the lagged form,
$2(\sqrt{1+\zeta^2}-\zeta)/\omega$. It is the integrator FIRE uses, and it is the one to
choose when the trajectory is only a means to a relaxed state and speed per step matters
more than accuracy.

## Options

None; the integrator is chosen by name.

## Archival reference

- [Integrators](https://github.com/ColtonKawamura/SoftPack/wiki/Damped-dynamics#integrators)
