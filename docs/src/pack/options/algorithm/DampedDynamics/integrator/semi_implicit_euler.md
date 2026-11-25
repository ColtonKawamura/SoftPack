# `:semi_implicit_euler`

*Up:* [`integrator`](index.md)

Kick the velocity with the current force, then drift the positions with the new velocity, with the dashpot on the old velocity $\mathbf v_n$.
It is the integrator [`FIRE()`](../../FIRE.md) uses by default, here applied to `DampedDynamics()`.
It is the cheapest of the three and has no half-step state, but it is first order and its stable step shrinks as damping grows, the same as [lagged velocity Verlet](lagged_velocity_verlet.md).

## The call with every option written out

```julia
pack(                                       # run the packing
    algorithm = DampedDynamics(             # damped dynamics instead of the default FIRE
        integrator = :semi_implicit_euler,  # kick with the current force, then drift
    )                                       # end of DampedDynamics call
)                                           # end of pack call
```

- `pack(...)` — [runs the packing](../../../../index.md).
- `algorithm = DampedDynamics(...)` — [damped dynamics](../index.md), Newton's equations with contact dashpots.
- `integrator = :semi_implicit_euler` — the dashpot force uses the velocity at the start of the step $\mathbf v_n$.
  - This is an option, not the default ([why the default is centered](index.md#Why-the-default)).
  - FIRE's own `integrator` is a separate setting.

## Why the dashpot needs a choice

With a dashpot the acceleration depends on a velocity $\mathbf v^{\ast}$:

```math
\mathbf a =
\frac{
\mathbf F(\mathbf r) -
\underbrace{
\gamma\,\mathbf v^{\ast}
}_\text{dashpot}
}{m}
```

- This page puts $\mathbf v^{\ast} = \mathbf v_n$, the velocity at the start of the step, so nothing has to be solved or predicted.
- [Lagged velocity Verlet](lagged_velocity_verlet.md) puts $\mathbf v^{\ast} = \mathbf v_{n+1/2}$, and [centered velocity Verlet](centered_velocity_verlet.md) puts $\mathbf v^{\ast} = \mathbf v_{n+1}$ and solves for it.

## Steps

There is no acceleration to hold over, because the force is computed from the stored state at the start of every step.

1. Compute the acceleration at the current state, with the dashpot on the old velocity:

```math
\mathbf a_n =
\frac{
\mathbf F(\mathbf r_n) -
\underbrace{
\gamma\,\mathbf v_n
}_\text{old velocity}
}{m}
```

2. Kick the velocity with the full step:

```math
\mathbf v_{n+1} =
\mathbf v_n +
\mathbf a_n\,\Delta t
```

3. Drift the positions with the new velocity:

```math
\mathbf r_{n+1} =
\mathbf r_n +
\underbrace{
\mathbf v_{n+1}
}_\text{new velocity}
\Delta t
```

## Properties

- **Stable step**: it is the same map as the lagged form for one damped oscillator, so it is stable up to

```math
\omega\,\Delta t \le
\underbrace{
2
}_\text{undamped limit}
\underbrace{
\left(\sqrt{1+\zeta^2} - \zeta\right)
}_\text{damping shrinks it}
```

- **Accuracy**: first order at every damping in the one-oscillator test, and about 2.5 to 10 times less accurate than [lagged velocity Verlet](lagged_velocity_verlet.md) at $\zeta = 0.05$ and $0.01$, with nearly the same error from $\zeta \approx 0.3$ up.
- **Cost**: one force evaluation per step, with no half-step velocity to predict.
- **Restart**: the force is a function of the stored positions, velocities and contact history, so a restart stores only those.

!!! warning "How semi-implicit Euler fails, and how SoftPack guards against it"
    **Failure mechanisms**

    - **Blow-up above the stable step**: the stable step shrinks as damping grows, to $0.27\,t_\text{col}$ for one contact at the default $\zeta = 0.98$ and about $0.05\,t_\text{col}$ in the 3D packing worst case, and past it the run diverges.
    - **Accuracy**: first order, so results change with $\Delta t$ more than for the centered form, and more than for lagged velocity Verlet at weak damping.
    - **Exact restart**: the restart test was run only for the lagged form, and the sliding flags are part of the stored contact history.

    **How SoftPack mitigates this**

    - The run-time check compares $\Delta t$ with the stable step for this integrator, which includes the damping penalty, and warns when it is exceeded.
    - With near-critical contact damping the step fraction should stay at or below about $1/20$.
    - The restart file records the integrator and refuses a restart with a different one.
    - The trade-offs: [centered velocity Verlet](centered_velocity_verlet.md) is second order with no damping penalty at the cost of a solve every step, and [lagged velocity Verlet](lagged_velocity_verlet.md) is more accurate at weak damping at the cost of a half-step state in the restart file.

## Compared with the other two

| | [Centered](centered_velocity_verlet.md) (default) | [Lagged](lagged_velocity_verlet.md) | Semi-implicit Euler |
|:---|:---|:---|:---|
| Dashpot uses | $\mathbf v_{n+1}$ (implicit) | $\mathbf v_{n+1/2}$ | $\mathbf v_n$ |
| Cost per step | a linear solve | one force evaluation | one force evaluation |
| Stable step, one oscillator | $\omega\,\Delta t \le 2$ | $\omega\,\Delta t \le 2\left(\sqrt{1+\zeta^2}-\zeta\right)$ | the same as lagged |
| Order, damped | 2 | 1 | 1 |
| Restart stores | $\mathbf r$, $\mathbf v$, contact history | also $\mathbf a_n$ | $\mathbf r$, $\mathbf v$, contact history |

## Open questions

- Whether this option is worth keeping next to lagged velocity Verlet is open, because at moderate damping the one-oscillator test shows the same stable step and nearly the same error.
- Whether a restart is bitwise in frictional runs is not tested for this integrator.

## Theory

For now these sections are on the wiki.

- [Semi-implicit Euler for DampedDynamics](https://github.com/ColtonKawamura/SoftPack/wiki/Semi-implicit-Euler-for-DampedDynamics): the same steps with every property.
- [Time step with damping](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#10-time-step-with-damping): the stable-step derivation.
- [FIRE's integrator](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings): the same scheme as FIRE's default.
