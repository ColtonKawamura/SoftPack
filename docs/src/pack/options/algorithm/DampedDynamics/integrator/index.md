# `integrator`

*Up:* [`DampedDynamics`](../index.md)

How the equations of motion are stepped [Samiei2013], [CodeAster]. The three integrators differ in when they
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

## Example

```julia
using SoftPack

packing = pack(
    algorithm = DampedDynamics(
        integrator = :centered_velocity_verlet,
    ),
    particles_count = 64,
    seed = 1,
)
packing.converged
```

## References

- **[Samiei2013]** K. Samiei, B. Peters, M. Bolten, A. Frommer (2013). *Assessment of the potentials of implicit integration method in discrete element modelling of granular matter*. Computers & Chemical Engineering **49**, 183--193. [doi:10.1016/j.compchemeng.2012.10.009](https://doi.org/10.1016/j.compchemeng.2012.10.009).
- **[CodeAster]** Code_Aster developers. *Algorithmes d'intégration directe de l'opérateur DYNA_VIBRA / BASE_CALCUL='PHYS', manual R5.05.02*. <https://code-aster.org/doc/v16/man_r/r5/r5.05.02.pdf>. Section 6.2, central differences. Accessed 2026-11-24.
