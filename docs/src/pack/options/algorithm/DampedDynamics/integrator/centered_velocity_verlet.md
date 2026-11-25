# `:centered_velocity_verlet`

*Up:* [`integrator`](index.md)

Velocity Verlet with the dashpot evaluated on the end-of-step velocity $\mathbf v_{n+1}$, so the velocity update is implicit.
It is the default `integrator`.
It costs a linear solve over the contacts every step, and in return its stable step does not shrink as damping grows.

## The call with every option written out

```julia
pack(                                             # run the packing
    algorithm = DampedDynamics(                   # damped dynamics instead of the default FIRE
        integrator = :centered_velocity_verlet,   # dashpot on the end-of-step velocity (default)
    )                                             # end of DampedDynamics call
)                                                 # end of pack call
```

- `pack(...)` — [runs the packing](../../../../index.md).
- `algorithm = DampedDynamics(...)` — [damped dynamics](../index.md), Newton's equations with contact dashpots.
- `integrator = :centered_velocity_verlet` **(default)** — the dashpot force uses $\mathbf v_{n+1}$.
  - **SoftPack choice**: the most accurate of the three, with a stable step that does not shrink with damping ([why](index.md#Why-the-default)).

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
- [Lagged velocity Verlet](lagged_velocity_verlet.md) puts $\mathbf v^{\ast} = \mathbf v_{n+1/2}$, and [semi-implicit Euler](semi_implicit_euler.md) puts $\mathbf v^{\ast} = \mathbf v_n$.
- This page puts $\mathbf v^{\ast} = \mathbf v_{n+1}$ and solves for it.

## Steps

0. Hold on to $\mathbf a_n$ from the previous step (same as [lagged velocity Verlet](lagged_velocity_verlet.md)).

1. Move the positions (same as [lagged velocity Verlet](lagged_velocity_verlet.md)):

```math
\mathbf r_{n+1} =
\mathbf r_n +
\mathbf v_n\,\Delta t +
\tfrac12\,\mathbf a_n\,\Delta t^2
```

2. Predict the half-step velocity (same as [lagged velocity Verlet](lagged_velocity_verlet.md); the undamped scheme has no half-step velocity):

```math
\mathbf v_{n+1/2} =
\mathbf v_n + \,\mathbf a_n\,
\underbrace{
\frac{\Delta t}{2}
}_\text{half step}
```

3. Finish the velocity with the second half kick. $\mathbf v_{n+1}$ is the unknown here, and it appears on both sides through the dashpot (differs from the other two):

```math
\mathbf v_{n+1} =
\mathbf v_{n+1/2} +
\underbrace{
\frac{\Delta t}{2}
}_\text{half step}
\,
\underbrace{
\mathbf a_{n+1}
}_\text{new acceleration}
```

- The kick is the same as the last step of the undamped scheme, because $\mathbf v_{n+1/2} = \mathbf v_n + \tfrac12\,\mathbf a_n\,\Delta t$.
- Put $\mathbf a_{n+1}$ in with the dashpot on the end velocity, so the unknown shows up on the right:

```math
\mathbf v_{n+1} =
\mathbf v_{n+1/2} +
\underbrace{
\frac{\Delta t}{2}
}_\text{half step}
\,
\frac{
\mathbf F(\mathbf r_{n+1}) -
\underbrace{
\gamma\,\mathbf v_{n+1}
}_\text{dashpot on end velocity}
}{m}
```

- Move the dashpot term to the left and factor out $\mathbf v_{n+1}$:

```math
\underbrace{
\left(1 + \frac{\gamma\,\Delta t}{2m}\right)
}_\text{damping factor}
\mathbf v_{n+1} =
\mathbf v_{n+1/2} +
\underbrace{
\frac{\Delta t}{2m}\,\mathbf F(\mathbf r_{n+1})
}_\text{force kick}
```

- **One particle:** divide by the damping factor, which is larger than 1, so damping shrinks the new velocity.

```math
\mathbf v_{n+1} =
\frac{
\mathbf v_{n+1/2} + \text{force kick}
}{
\text{damping factor}
}
```

- **Many particles:** multiply the factored equation by $m$ first, so the mass is explicit.

```math
\underbrace{
\left(m + \tfrac{\Delta t}{2}\,\gamma\right)
}_\text{one number}
\mathbf v_{n+1} =
m\,\mathbf v_{n+1/2} +
\tfrac{\Delta t}{2}\,\mathbf F(\mathbf r_{n+1})
```

- Then swap each symbol for its many-particle version.
  - $m \to \mathbf M$, the masses on the diagonal.
  - $\gamma \to \boldsymbol\Gamma$, the damping matrix, which has entries linking particles in contact because a contact's dashpot depends on both particles' velocities.
  - $\mathbf v$ and $\mathbf F$ now hold every particle's values in one list.

```math
\underbrace{
\left(\mathbf M + \tfrac{\Delta t}{2}\,\boldsymbol\Gamma\right)
}_\text{matrix}
\mathbf v_{n+1} =
\mathbf M\,\mathbf v_{n+1/2} +
\tfrac{\Delta t}{2}\,\mathbf F(\mathbf r_{n+1})
```

- The damping factor became a matrix, and a matrix cannot be divided into both sides, so $\mathbf v_{n+1}$ comes from a linear solve every step.
- The matrix is sparse, with entries only for particles that touch.

4. New acceleration, held for step 0 of the next step (new step; the other two integrators get $\mathbf a_{n+1}$ in step 2):

```math
\mathbf a_{n+1} =
\frac{
\mathbf F(\mathbf r_{n+1}) -
\underbrace{
\gamma\,\mathbf v_{n+1}
}_\text{end velocity}
}{m}
```

## Properties

- **Stable step**: one damped oscillator of angular frequency $\omega$ is stable for every damping ratio $\zeta$ up to

```math
\omega\,\Delta t \le
\underbrace{
2
}_\text{no damping penalty}
```

- A packing is stable up to $\Delta t \le 2/\omega_\text{max}$, with $\omega_\text{max}$ its highest mode frequency.
  - For `ContactDamping()` with its defaults the damping is stiffness-proportional, so the modes decouple and each obeys the one-oscillator bound (**SoftPack note**).
  - In a test on 24-degree-of-freedom networks the limit stayed at $2/\omega_\text{max}$ for four random non-proportional damping matrices too, which is a test and not a proof.
- **Accuracy**: second order in the one-oscillator test at $\zeta = 0.01$, $0.05$, $0.3$ and $0.98$.
- **Cost**: one linear solve over the contacts per step, plus one force evaluation.
- **Restart**: $\mathbf a_n$ is a function of $(\mathbf r_n, \mathbf v_n)$ and the contact history, so a restart stores only those.

!!! warning "How the centered velocity Verlet fails, and how SoftPack guards against it"
    **Failure mechanisms**

    - **Blow-up above the stable step**: when $\omega_\text{max}\,\Delta t$ exceeds 2 the highest mode flips sign and grows every step, and the run diverges.
    - **Cost**: the solve every step can make a run slower than an explicit integrator even though the step may be longer, as [Samiei2013] found for implicit integration in DEM.
    - **Nonlinear contacts**: the bound is for linear damping, and Hertzian and Mindlin contacts, clipped dashpots and the Coulomb limit change the matrices from step to step, so for them it is an estimate.
    - **Exact restart**: the restart test passed only for the lagged form so far, and the sliding flags are part of the stored contact history.

    **How SoftPack mitigates this**

    - The run-time check compares $\Delta t$ with the stable step of the chosen integrator and warns when it is exceeded; it does not change the step.
    - The default step keeps a margin of about 13 or more over the stable step in the 3D worst case.
    - The restart file records the integrator and refuses a restart with a different one.
    - The trade-offs: [lagged velocity Verlet](lagged_velocity_verlet.md) is explicit and needs no solve but its stable step shrinks as damping grows, and [semi-implicit Euler](semi_implicit_euler.md) is the cheapest but first order.

## Compared with the other two

| | Centered (default) | [Lagged](lagged_velocity_verlet.md) | [Semi-implicit Euler](semi_implicit_euler.md) |
|:---|:---|:---|:---|
| Dashpot uses | $\mathbf v_{n+1}$ (implicit) | $\mathbf v_{n+1/2}$ | $\mathbf v_n$ |
| Cost per step | a linear solve | one force evaluation | one force evaluation |
| Stable step, one oscillator | $\omega\,\Delta t \le 2$ | $\omega\,\Delta t \le 2\left(\sqrt{1+\zeta^2}-\zeta\right)$ | the same as lagged |
| Order, damped | 2 | 1 | 1 |
| Restart stores | $\mathbf r$, $\mathbf v$, contact history | also $\mathbf a_n$ | $\mathbf r$, $\mathbf v$, contact history |

## Open questions

- How the linear solve is done (the method, its tolerance, any preconditioner) is not designed.
- Whether the solve cost outweighs the longer step on packings is not measured; a benchmark is planned.
- How the run-time check estimates $\omega_\text{max}$ of a packing is not designed.

## Theory

For now these sections are on the wiki.

- [Centered velocity Verlet](https://github.com/ColtonKawamura/SoftPack/wiki/Centered-velocity-Verlet): the same steps with every property.
- [Integrator tests](https://github.com/ColtonKawamura/SoftPack/wiki/Algorithms-and-combinations#integrator-tests): the one-oscillator and network tests.
- [Time step with damping](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#10-time-step-with-damping): the stable-step derivation.

## References

- **[Samiei2013]** K. Samiei, B. Peters, M. Bolten, A. Frommer (2013). *Assessment of the potentials of implicit integration method in discrete element modelling of granular matter*. Computers & Chemical Engineering **49**, 183--193. [doi:10.1016/j.compchemeng.2012.10.009](https://doi.org/10.1016/j.compchemeng.2012.10.009).
