# `:lagged_velocity_verlet`

*Up:* [`integrator`](index.md)

Velocity Verlet with the dashpot evaluated on the half-step velocity $\mathbf v_{n+1/2}$, which is how LAMMPS evaluates granular dashpots.
It is explicit, with one force evaluation per step and no solve, but its stable step shrinks as damping grows and its restart has to store the forces and torques of the last evaluation.

## The call with every option written out

```julia
pack(                                           # run the packing
    algorithm = DampedDynamics(                 # damped dynamics instead of the default FIRE
        integrator = :lagged_velocity_verlet,   # dashpot on the half-step velocity
    )                                           # end of DampedDynamics call
)                                               # end of pack call
```

- `pack(...)` — [runs the packing](../../../../index.md).
- `algorithm = DampedDynamics(...)` — [damped dynamics](../index.md), Newton's equations with contact dashpots.
- `integrator = :lagged_velocity_verlet` — the dashpot force uses $\mathbf v_{n+1/2}$.
  - This is an option, not the default ([why the default is centered](index.md#Why-the-default)).

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
- This page puts $\mathbf v^{\ast} = \mathbf v_{n+1/2}$, the velocity already known at that point.
- [Centered velocity Verlet](centered_velocity_verlet.md) puts $\mathbf v^{\ast} = \mathbf v_{n+1}$ and solves for it, and [semi-implicit Euler](semi_implicit_euler.md) puts $\mathbf v^{\ast} = \mathbf v_n$.

## Steps

Steps 0, 1 and 3 are the same as in undamped velocity Verlet.

0. Hold on to $\mathbf a_n$ from the previous step (same as undamped velocity Verlet).

1. Move the positions (same as undamped velocity Verlet):

```math
\mathbf r_{n+1} =
\mathbf r_n +
\mathbf v_n\,\Delta t +
\tfrac12\,\mathbf a_n\,\Delta t^2
```

2. Predict the half-step velocity, then compute the new acceleration with it in the dashpot (differs from undamped velocity Verlet):

```math
\mathbf v_{n+1/2} =
\mathbf v_n + \,\mathbf a_n\,
\underbrace{
\frac{\Delta t}{2}
}_\text{half step}
```

```math
\mathbf a_{n+1} =
\frac{
\mathbf F(\mathbf r_{n+1}) -
\underbrace{
\gamma\,\mathbf v_{n+1/2}
}_\text{half-step velocity}
}{m}
```

3. Finish the velocity with both accelerations (same as undamped velocity Verlet):

```math
\mathbf v_{n+1} =
\mathbf v_n +
\tfrac12\,
\underbrace{
(\mathbf a_n + \mathbf a_{n+1})
}_\text{average acceleration}
\Delta t
```

## Properties

- **Stable step**: one damped oscillator of angular frequency $\omega$ and damping ratio $\zeta$ is stable up to

```math
\omega\,\Delta t \le
\underbrace{
2
}_\text{undamped limit}
\underbrace{
\left(\sqrt{1+\zeta^2} - \zeta\right)
}_\text{damping shrinks it}
```

- The same formula is the central-difference result with the damping term lagged [CodeAster].
- **Accuracy**: first order once damping is not weak, because the dashpot velocity is half a step old.
  - [CodeAster] says the lagged approximation is valid for weak damping and loses second-order accuracy when damping is large.
  - [Golshan2023] find velocity Verlet with a velocity-dependent force first order, and still more accurate than explicit Euler in practice.
  - In the one-oscillator test it was first order at $\zeta = 0.3$ and $0.98$, and 2.5 to 10 times more accurate than semi-implicit Euler at $\zeta = 0.05$ and $0.01$.
- **Cost**: one force evaluation per step.
- **Restart**: $\mathbf a_n$ was built from $\mathbf v_{n-1/2}$, so it cannot be rebuilt from $(\mathbf r_n, \mathbf v_n)$ and a restart has to store the forces and torques of the last evaluation.

!!! warning "How the lagged velocity Verlet fails, and how SoftPack guards against it"
    **Failure mechanisms**

    - **Blow-up above the stable step**: the stable step shrinks as damping grows, to $0.27\,t_\text{col}$ for one contact at the default $\zeta = 0.98$ and about $0.05\,t_\text{col}$ in the 3D packing worst case, and past it the run diverges.
    - **Accuracy**: the half-step-old dashpot velocity makes the damped dynamics first order, so results change more with $\Delta t$ than for the centered form.
    - **Half-step state**: restarting from stored full-step velocities gives a different trajectory, as LAMMPS warns for granular styles, and even re-evaluating from stored half-step velocities was not bitwise in the frictional probe.
    - **Staggered variables**: [Vyas2025] report unphysical contact behavior in the LAMMPS velocity Verlet at large size ratios, from mixing half-step and full-step variables, and whether this matters at the default diameter ratio 1.4 is untested.

    **How SoftPack mitigates this**

    - The run-time check compares $\Delta t$ with the stable step for this integrator, which includes the damping penalty, and warns when it is exceeded.
    - With near-critical contact damping the step fraction should stay at or below about $1/20$.
    - The restart file stores the forces and torques of the last evaluation, records the integrator and refuses a restart with a different one.
    - The trade-offs: [centered velocity Verlet](centered_velocity_verlet.md) removes the damping penalty and is second order, at the cost of a solve every step, and [semi-implicit Euler](semi_implicit_euler.md) has the same stable step with no half-step state.

## Compared with the other two

| | [Centered](centered_velocity_verlet.md) (default) | Lagged | [Semi-implicit Euler](semi_implicit_euler.md) |
|:---|:---|:---|:---|
| Dashpot uses | $\mathbf v_{n+1}$ (implicit) | $\mathbf v_{n+1/2}$ | $\mathbf v_n$ |
| Cost per step | a linear solve | one force evaluation | one force evaluation |
| Stable step, one oscillator | $\omega\,\Delta t \le 2$ | $\omega\,\Delta t \le 2\left(\sqrt{1+\zeta^2}-\zeta\right)$ | the same as lagged |
| Order, damped | 2 | 1 | 1 |
| Restart stores | $\mathbf r$, $\mathbf v$, contact history | also $\mathbf a_n$ | $\mathbf r$, $\mathbf v$, contact history |

## Open questions

- Whether a restart from the stored forces and torques is bitwise for every damping setting is tested only on one frictional probe.
- Whether this integrator is worth keeping over semi-implicit Euler at moderate damping is open, because the one-oscillator test shows the same stable step and nearly the same error from $\zeta \approx 0.3$ up.

## Theory

For now these sections are on the wiki.

- [Lagged velocity Verlet](https://github.com/ColtonKawamura/SoftPack/wiki/Lagged-velocity-Verlet): the same steps with every property.
- [Time step with damping](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#10-time-step-with-damping): the stable-step derivation.
- [The half-step velocity](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#the-half-step-velocity): the LAMMPS restart caveat and the probe.

## References

- **[CodeAster]** Code_Aster developers. *Algorithmes d'intégration directe de l'opérateur DYNA_VIBRA / BASE_CALCUL='PHYS', manual R5.05.02*. <https://code-aster.org/doc/v16/man_r/r5/r5.05.02.pdf>. Section 6.2, central differences. Accessed 2026-11-24.
- **[Golshan2023]** Shahab Golshan, Peter Münch, Rene Gassmöller, Martin Kronbichler, Bruno Blais (2023). *Lethe-DEM: an open-source parallel discrete element solver with load balancing*. Computational Particle Mechanics **10**, 77--96. [doi:10.1007/s40571-022-00478-6](https://doi.org/10.1007/s40571-022-00478-6).
- **[Vyas2025]** Dhairya R. Vyas, Julio M. Ottino, Richard M. Lueptow, Paul B. Umbanhowar (2025). *Improved velocity-Verlet algorithm for the discrete element method*. Computer Physics Communications **310**, 109524. [doi:10.1016/j.cpc.2025.109524](https://doi.org/10.1016/j.cpc.2025.109524).
