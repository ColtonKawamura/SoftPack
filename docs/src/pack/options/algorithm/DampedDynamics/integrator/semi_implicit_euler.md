# `:semi_implicit_euler`

*Up:* [`integrator`](index.md)

The simplest scheme [Samiei2013]: positions are updated with the new velocity, and the velocity with
the force and the damping at the current step,

$$v^{n+1} = v^n + \Delta t \, M^{-1}\left(F^n - \Gamma v^n\right), \qquad x^{n+1} = x^n + \Delta t \, v^{n+1}.$$

It is explicit and first order, with the same stability limit as the lagged form,
$2(\sqrt{1+\zeta^2}-\zeta)/\omega$. It is the integrator FIRE uses, and it is the one to
choose when the trajectory is only a means to a relaxed state and speed per step matters
more than accuracy.

## Options

None; the integrator is chosen by name.

## Example

```julia
using SoftPack

packing = pack(
    algorithm = DampedDynamics(
        integrator = :semi_implicit_euler,
    ),
    particles_count = 64,
    seed = 1,
)
packing.converged
```

## References

- **[Samiei2013]** K. Samiei, B. Peters, M. Bolten, A. Frommer (2013). *Assessment of the potentials of implicit integration method in discrete element modelling of granular matter*. Computers & Chemical Engineering **49**, 183--193. [doi:10.1016/j.compchemeng.2012.10.009](https://doi.org/10.1016/j.compchemeng.2012.10.009).
