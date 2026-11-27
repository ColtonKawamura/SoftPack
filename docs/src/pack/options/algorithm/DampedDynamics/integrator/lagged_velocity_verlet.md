# `:lagged_velocity_verlet`

*Up:* [`integrator`](index.md)

Velocity Verlet with the damping force taken from the previous step's relative velocities
(design §8). The update is explicit:

$$v^{n+1} = v^n + \Delta t \, M^{-1}\left(F^n - \Gamma v^{n-1}\right),$$

so the cost per step is a sparse matrix-vector product rather than a solve.

The lag makes the scheme stable only for a smaller step than the centered form,
$2(\sqrt{1+\zeta^2}-\zeta)/\omega$ instead of $2/\omega$, and it shifts the effective
damping slightly. It is useful when the damping matrix changes every step and a
factorization would be wasteful, and as a reference for the effect of the lag.

## Options

None; the integrator is chosen by name.

## Archival reference

- [Integrators](https://github.com/ColtonKawamura/SoftPack/wiki/Damped-dynamics#integrators)
