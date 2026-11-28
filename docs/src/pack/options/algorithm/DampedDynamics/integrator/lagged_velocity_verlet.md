# `:lagged_velocity_verlet`

*Up:* [`integrator`](index.md)

Velocity Verlet with the damping force taken from the previous step's relative velocities
[Golshan2023], [Vyas2025]. The update is explicit:

$$v^{n+1} = v^n + \Delta t \, M^{-1}\left(F^n - \Gamma v^{n-1}\right),$$

so the cost per step is a sparse matrix-vector product rather than a solve.

The lag makes the scheme stable only for a smaller step than the centered form,
$2(\sqrt{1+\zeta^2}-\zeta)/\omega$ instead of $2/\omega$, and it shifts the effective
damping slightly. It is useful when the damping matrix changes every step and a
factorization would be wasteful, and as a reference for the effect of the lag.

## Options

None; the integrator is chosen by name.

## Example

```julia
using SoftPack

packing = pack(
    algorithm = DampedDynamics(
        integrator = :lagged_velocity_verlet,
    ),
    particles_count = 64,
    seed = 1,
)
packing.converged
```

## References

- **[Golshan2023]** Shahab Golshan, Peter Münch, Rene Gassmöller, Martin Kronbichler, Bruno Blais (2023). *Lethe-DEM: an open-source parallel discrete element solver with load balancing*. Computational Particle Mechanics **10**, 77--96. [doi:10.1007/s40571-022-00478-6](https://doi.org/10.1007/s40571-022-00478-6).
- **[Vyas2025]** Dhairya R. Vyas, Julio M. Ottino, Richard M. Lueptow, Paul B. Umbanhowar (2025). *Improved velocity-Verlet algorithm for the discrete element method*. Computer Physics Communications **310**, 109524. [doi:10.1016/j.cpc.2025.109524](https://doi.org/10.1016/j.cpc.2025.109524).
