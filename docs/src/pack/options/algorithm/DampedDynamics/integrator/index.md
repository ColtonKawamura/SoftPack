# `integrator`

*Up:* [`DampedDynamics()`](../index.md)

`integrator` chooses how `DampedDynamics()` steps the particles forward in time when the dashpot force depends on velocity.
The default is the centered velocity Verlet, the most accurate of the three, and its stable time step does not shrink as damping grows.
The three choices differ in which velocity the dashpot uses at the end of a step, and that decides the cost per step, the stable step and what a restart file stores.
FIRE's integrator is a separate setting of [`FIRE()`](../../FIRE.md).

## The call with the default written out

```julia
pack(                                             # run the packing
    algorithm = DampedDynamics(                   # damped dynamics instead of the default FIRE
        integrator = :centered_velocity_verlet,   # dashpot on the end-of-step velocity (default)
    )                                             # end of DampedDynamics call
)                                                 # end of pack call
```

- `pack(...)` — [runs the packing](../../../../index.md).
- `algorithm = DampedDynamics(...)` — [damped dynamics](../index.md), Newton's equations with contact dashpots.
- `integrator = :centered_velocity_verlet` **(default)** — the dashpot force uses the end-of-step velocity $\mathbf v_{n+1}$.
  - For details, see [`:centered_velocity_verlet`](centered_velocity_verlet.md).

## Why the dashpot needs a choice

With a dashpot the new acceleration depends on a velocity $\mathbf v^{\ast}$:

```math
\mathbf a_{n+1} =
\frac{
\mathbf F(\mathbf r_{n+1}) -
\underbrace{
\gamma\,\mathbf v^{\ast}
}_\text{dashpot}
}{m}
```

- Velocity Verlet computes $\mathbf v_{n+1}$ from $\mathbf a_{n+1}$, so $\mathbf v_{n+1}$ does not exist yet when $\mathbf a_{n+1}$ is needed.
- The three choices differ only in $\mathbf v^{\ast}$: the half-step velocity $\mathbf v_{n+1/2}$ (lagged), the old velocity $\mathbf v_n$ (Euler), or $\mathbf v_{n+1}$ solved for (centered).

## Choices

| Choice | Dashpot force uses | Cost per step | Stable step, one damped oscillator | Order, damped | Restart stores | |
|:---|:---|:---|:---|:---|:---|:---|
| [`:centered_velocity_verlet`](centered_velocity_verlet.md) | $\mathbf v_{n+1}$ (implicit) | a linear solve over the contacts | $\omega\,\Delta t \le 2$ | 2 | $\mathbf r$, $\mathbf v$, contact history | **default** |
| [`:lagged_velocity_verlet`](lagged_velocity_verlet.md) | $\mathbf v_{n+1/2}$ | one force evaluation | $\omega\,\Delta t \le 2\left(\sqrt{1+\zeta^2}-\zeta\right)$ | 1 | also the forces and torques of the last evaluation | |
| [`:semi_implicit_euler`](semi_implicit_euler.md) | $\mathbf v_n$ | one force evaluation | the same as lagged | 1 | $\mathbf r$, $\mathbf v$, contact history | |

## Why the default

- Of the three, the centered form is the most accurate, and its stable step does not shrink with damping (**SoftPack choice**).
  - In a one-oscillator test it was second order at $\zeta = 0.01$ to $0.98$, while the other two were first order from $\zeta \approx 0.3$.
- Its cost is a linear solve every step, and [Samiei2013] find that implicit integration in DEM "enables larger time steps" but "the overall speed up is overruled by higher computational costs of the implicit method".
  - **SoftPack note**: the default is to be checked against that cost on packings, and if the solve dominates, the default changes.
- We did not find a paper that compares these three for relaxing jammed packings with contact dashpots (a few searches, 2026-11-24).

## Restart and checks

- The restart file records the integrator and refuses a restart with a different one.
- The run-time check of [`timestep`](../../../timestep/index.md) compares the time step with the stable step of the chosen integrator and warns when it is exceeded.

## Related keywords

- [`damping`](../damping/index.md): the dashpots whose force the integrator steps.
- [`timestep`](../../../timestep/index.md): the step the stable-step check compares against.

## Theory

For now these sections are on the wiki.

- [Algorithms and combinations](https://github.com/ColtonKawamura/SoftPack/wiki/Algorithms-and-combinations#dampeddynamicsintegrator--): the setting, the reason for the default and the integrator tests.
- [Time step with damping](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#10-time-step-with-damping): the stable-step derivation.
- [Restart state](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#the-half-step-velocity): why the lagged form stores forces and torques.

## References

- **[Samiei2013]** K. Samiei, B. Peters, M. Bolten, A. Frommer (2013). *Assessment of the potentials of implicit integration method in discrete element modelling of granular matter*. Computers & Chemical Engineering **49**, 183--193. [doi:10.1016/j.compchemeng.2012.10.009](https://doi.org/10.1016/j.compchemeng.2012.10.009).
