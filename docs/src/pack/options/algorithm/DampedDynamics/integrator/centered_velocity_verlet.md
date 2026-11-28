# `:centered_velocity_verlet`

*Up:* [`integrator`](index.md)

The default integrator [Samiei2013]. The damping is evaluated at the midpoint of the step, which turns
the velocity update into a linear system:

$$\left(M + \frac{\Delta t}{2} \Gamma\right) v^{n+1} = \left(M - \frac{\Delta t}{2} \Gamma\right) v^n + \Delta t \, F^n,$$

and the matrix on the left is sparse, symmetric and positive definite, so the implementation
assembles and factorizes it once per step, then solves it once per step.

Because the damping is treated implicitly, the integrator is stable for any damping ratio
at the time step the contacts allow, and the damping does not lag the motion. That is why
it is the default for production runs.

## Options

None; the integrator is chosen by name.

## Example

```julia
using SoftPack

packing = pack(
    algorithm = DampedDynamics(
        integrator = :centered_velocity_verlet,  # the default
    ),
    particles_count = 64,
    seed = 1,
)
packing.converged
```

## References

- **[Samiei2013]** K. Samiei, B. Peters, M. Bolten, A. Frommer (2013). *Assessment of the potentials of implicit integration method in discrete element modelling of granular matter*. Computers & Chemical Engineering **49**, 183--193. [doi:10.1016/j.compchemeng.2012.10.009](https://doi.org/10.1016/j.compchemeng.2012.10.009).
