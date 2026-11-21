# 13. Friction models

Design decision source: [design-references.md §13](../design-references.md#13-friction-models).
Status: design stage (no engine code yet).

## Summary

By default SoftPack particles are frictionless (`friction = nothing`,
[§2](02-default-packing.md)). Two friction models are options. `CundallStrack` adds a
linear tangential spring at each contact, with Coulomb slip; it works with `Hookean` or
`Hertzian` normal contacts. `Mindlin` is the Hertz-Mindlin tangential force, whose
stiffness grows with the overlap; it needs `Hertzian` contacts. Both default to the
friction coefficient $\mu = 0.5$. `CundallStrack` sets its tangential stiffness by
`stiffness_ratio = :matched`, $k_t/k_n = 1/(1 + mR^2/I)$ (1/3 for disks, 2/7 for
spheres), which makes the tangential contact vibration exactly as fast as the normal
one. `Mindlin` uses the Poisson ratio $\nu = 0$, which makes the two stiffnesses equal,
so its tangential vibration is $\sqrt3$ times faster than the normal one for disks. How
damping and the Coulomb limit interact is in [§8](08-damping.md).

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| `friction` | `nothing` (frictionless) | `CundallStrack(...)`, `Mindlin(...)` | [§2](02-default-packing.md), [Options](#options) |
| `CundallStrack` `friction_coefficient` | `0.5` | any value $\ge 0$ | [Friction coefficient](#friction-coefficient) |
| `CundallStrack` `stiffness_ratio` | `:matched` | any number | [Stiffness ratio](#stiffness-ratio) |
| `Mindlin` `friction_coefficient` | `0.5` | any value $\ge 0$ | [Friction coefficient](#friction-coefficient) |
| `Mindlin` `poisson_ratio` | `0.0` | another Poisson ratio | [Poisson ratio](#poisson-ratio) |

## Model

Symbols used on this page:

- Particles $i$ and $j$ have masses $m_i$, $m_j$, radii $R_i$, $R_j$, moments of inertia
  $I_i$, $I_j$, velocities $\mathbf v_i$, $\mathbf v_j$ and spins $\omega_i$, $\omega_j$
  (2D). For uniform particles $I = \kappa m R^2$, with $\kappa = 1/2$ for disks and
  $\kappa = 2/5$ for spheres.
- $\hat{\mathbf n}$ is the unit vector from the center of $i$ to the center of $j$;
  in 2D $\hat{\mathbf t} = \hat{\mathbf z}\times\hat{\mathbf n}$ is the tangent.
  $\delta$ is the overlap.
- $k_n$ and $k_t$ are the normal and tangential contact stiffnesses, $f_n$ the normal
  (elastic) force, $\mu$ the friction coefficient, $\nu$ the Poisson ratio of the
  particle material.
- $M_n$ and $M_t$ are the normal and tangential effective masses, $\omega_n$ and
  $\omega_t$ the normal and tangential contact frequencies (derived below).
- $\gamma_n$, $\gamma_t$: dashpot coefficients (force per velocity); $\zeta$: damping
  ratio; $b = \gamma/k$: the stiffness-proportional damping constant of a contact
  ([§8](08-damping.md)).

**Sliding and the tangential spring.** The contact point of $i$ moves with
$\mathbf v_i + R_i\omega_i\hat{\mathbf t}$, that of $j$ with
$\mathbf v_j - R_j\omega_j\hat{\mathbf t}$. Their relative tangential (sliding) velocity
is

$$v_t = \hat{\mathbf t}\cdot(\mathbf v_j - \mathbf v_i) - R_i\,\omega_i - R_j\,\omega_j.$$

Both friction models store the elastic tangential displacement $\xi_t$, the integral of
$v_t$ over the life of the contact (the contact history). [Silbert2001]: "Static
friction is implemented by keeping track of the elastic shear displacement throughout
the lifetime of a contact." The spring force on $j$ is $-k_t\xi_t\hat{\mathbf t}$, on $i$
it is $+k_t\xi_t\hat{\mathbf t}$, and each acts at the contact point, so both particles
also feel a torque, $R_i k_t\xi_t$ on $i$ and $R_j k_t\xi_t$ on $j$ (about
$\hat{\mathbf z}$).

**Coulomb limit.** The elastic tangential force is capped at $\mu$ times the elastic
normal force,

$$\lvert k_t\,\xi_t\rvert \le \mu\,f_n.$$

When the cap is reached the contact slides and carries exactly $\mu f_n$
(`coulomb_limit = :elastic`, [§8](08-damping.md)). Equivalently the contact force must
stay inside the friction cone of half-angle $\arctan\mu$ about the normal, which is the
geometry behind the rattler cone test ([§9](09-rattler-rules.md)).

**CundallStrack.** $k_t = s\,k_n$, a fixed multiple of the normal stiffness, with
$s$ = `stiffness_ratio`.

**Mindlin.** For Hertzian contacts ($f_n = k\,\delta^{3/2}$, so
$k_n(\delta) = \tfrac32 k\,\delta^{1/2}$) the tangential stiffness follows the normal
one,

$$k_t(\delta) = \eta\,k_n(\delta), \qquad \eta = 1 - \frac{\nu}{2 - \nu} = \frac{2(1-\nu)}{2-\nu},$$

which is [Somfai2005]'s Eq. (A4) (derived below). With $\nu = 0$, $\eta = 1$ and
$k_t = k_n$ at every overlap. **SoftPack note**: the design doc states only the
$\nu = 0$ case; applying Eq. (A4) for other $\nu$ is our reading.

## Derivations

### Tangential effective mass

Let the tangential spring force be $F = -k_t\xi_t$ on $j$ (along $\hat{\mathbf t}$) and
$-F$ on $i$. From the force and torque on each particle,

$$\hat{\mathbf t}\cdot\mathbf a_j = \frac{F}{m_j}, \qquad \hat{\mathbf t}\cdot\mathbf a_i = -\frac{F}{m_i}, \qquad \dot\omega_i = -\frac{R_i F}{I_i}, \qquad \dot\omega_j = -\frac{R_j F}{I_j}.$$

Differentiating $v_t$ once more,

$$\ddot\xi_t = \dot v_t = \frac{F}{m_j} + \frac{F}{m_i} + \frac{R_i^2 F}{I_i} + \frac{R_j^2 F}{I_j} = \frac{F}{M_t}, \qquad \frac{1}{M_t} = \frac{1}{m_i} + \frac{1}{m_j} + \frac{R_i^2}{I_i} + \frac{R_j^2}{I_j}.$$

With $F = -k_t\xi_t$ the stuck contact vibrates at $\omega_t = \sqrt{k_t/M_t}$. The same
steps for the overlap give $\omega_n = \sqrt{k_n/M_n}$ with
$1/M_n = 1/m_i + 1/m_j$. A tangential force both pushes and spins the particles, so the
sliding motion responds like a lighter mass: $M_t < M_n$.

For uniform particles, $R^2/I = 1/(\kappa m)$, so

$$\frac{1}{M_t} = \left(1 + \frac{1}{\kappa}\right)\left(\frac{1}{m_i} + \frac{1}{m_j}\right) \quad\Rightarrow\quad \frac{M_t}{M_n} = \frac{1}{1 + 1/\kappa} = \frac{1}{1 + mR^2/I}.$$

That is $M_t = M_n/3$ for disks and $M_t = M_n/3.5$ for spheres, for any two particles of
the same shape, whatever their masses and radii. **SoftPack note.**

### The matched stiffness ratio

Equal normal and tangential frequencies, $k_t/M_t = k_n/M_n$, require

$$\frac{k_t}{k_n} = \frac{M_t}{M_n} = \frac{1}{1 + mR^2/I} = \begin{cases} 1/(1+2) = 1/3 & \text{disks},\\ 1/(1 + 5/2) = 2/7 & \text{spheres}.\end{cases}$$

This is the design doc's `stiffness_ratio = :matched`. By the result above it matches
the frequencies at every contact between uniform particles of one shape, not only for
two equal particles. Checked numerically: for the full two-particle problem (positions
and rotations, 6 degrees of freedom for disks, 12 for spheres) with equal and with
unequal masses and radii, the nonzero eigenvalues are $k_n/M_n$ (once) and $k_t/M_t$
(once for disks, twice for spheres), and they coincide at $k_t/k_n$ = 1/3 (disks) or
2/7 (spheres).

### The Mindlin stiffness ratio

[Somfai2005] (their Appendix A) write the Hertz normal force between spheres 1 and 2
as $F_n = \tfrac43\sqrt{R_{12}}\,E^\ast_{12}\,n^{3/2}$ (their Eq. A1, with $n$ the
overlap, $R_{12}$ the effective radius and $E^\ast = E/(1-\nu^2)$, their "modified
Young modulus, non-standard notation") and the Mindlin tangential force increment as
$\Delta F_t = 8G^\ast_{12}\sqrt{R_{12}\,n}\,\Delta t$ (Eq. A2, with $t$ the tangential
displacement and $G^\ast = E/[2(1+\nu)(2-\nu)]$). The two stiffnesses are

$$\frac{dF_n}{dn} = 2E^\ast_{12}\sqrt{R_{12}\,n}, \qquad \frac{dF_t}{dt} = 8G^\ast_{12}\sqrt{R_{12}\,n}.$$

Both grow as $\sqrt{R_{12}\,n}$, the radius of the Hertz contact area, so their ratio
does not depend on the overlap. For two particles of the same material,

$$\eta = \frac{dF_t/dt}{dF_n/dn} = \frac{8G^\ast}{2E^\ast} = \frac{4(1-\nu^2)}{2(1+\nu)(2-\nu)} = \frac{2(1-\nu)}{2-\nu} = 1 - \frac{\nu}{2-\nu},$$

their Eq. (A4). For $\nu = 0$, $\eta = 1$. Checked numerically: $8G^\ast/(2E^\ast)$ =
1.0000 at $\nu = 0$ and 0.8235 at $\nu = 0.3$, equal to $1 - \nu/(2 - \nu)$. Because both
stiffnesses scale with the Hertz contact radius, the ratio is constant only with the
Hertzian normal law, which is why `Mindlin` needs `Hertzian` contacts. **SoftPack
note.**

### Mindlin with zero Poisson ratio vibrates faster tangentially

With $k_t = k_n$ the tangential frequency is

$$\frac{\omega_t}{\omega_n} = \sqrt{\frac{k_t}{k_n}\,\frac{M_n}{M_t}} = \sqrt{1 + \frac{mR^2}{I}} = \begin{cases}\sqrt3 = 1.732 & \text{disks},\\ \sqrt{3.5} = 1.871 & \text{spheres}.\end{cases}$$

Two consequences (**SoftPack note**):

- The tangential direction sets the time step: $t_\text{col}$ is $\sqrt3$ times shorter
  for disks than the normal collision time ([§12](12-time-step.md)).
- With one damping ratio $\zeta$ in both directions, each direction's damping constant
  is $b = \gamma/k = 2\zeta/\omega$, so $b_t = 2\zeta/\omega_t = b/\sqrt3$ for disks
  ($b/\sqrt{3.5}$ for spheres). The two directions no longer share one $b$ (next
  derivation).

### Proportional damping and first-order mode mixing

With `ContactDamping` ([§8](08-damping.md)) each contact has a normal dashpot
$\gamma_n = b\,k_n$ and a tangential one $\gamma_t = b_t\,k_t$. Summed over contacts, in
mass-weighted coordinates,

$$\boldsymbol\Gamma = b\,\mathbf K_n + b_t\,\mathbf K_t, \qquad \mathbf K_0 = \mathbf K_n + \mathbf K_t,$$

where $\mathbf K_n$ and $\mathbf K_t$ are the normal-spring and tangential-spring parts
of the unstressed stiffness matrix $\mathbf K_0$ (both positive semidefinite). The
linearized motion is $\ddot{\mathbf x} + \boldsymbol\Gamma\dot{\mathbf x} + \mathbf K_0\mathbf x = 0$.

**Matched.** With `stiffness_ratio = :matched` and `tangential_mass = :with_rotation`,
$\omega_t = \omega_n$, so $b_t = b$ and $\boldsymbol\Gamma = b\,\mathbf K_0$ exactly. Then
$\boldsymbol\Gamma$ and $\mathbf K_0$ share their eigenvectors $|v_\ell\rangle$, and each
mode obeys its own equation

$$\lambda_\ell^2 + b\,\omega_\ell^2\,\lambda_\ell + \omega_\ell^2 = 0,$$

so every underdamped mode decays at $\beta_\ell = -\mathrm{Re}\,\lambda_\ell = b\,\omega_\ell^2/2$
(Hookean contacts and equal masses, so that $b$ is the same at every contact).

**Not matched.** With $b_t \ne b$ the modes mix. Treat the damping as a small
perturbation: write $\lambda = i\omega_\ell + \lambda^{(1)}$ and
$|v\rangle = |v_\ell\rangle + |v^{(1)}\rangle$ in
$\left(\lambda^2 + \lambda\boldsymbol\Gamma + \mathbf K_0\right)|v\rangle = 0$. To first
order, $2i\omega_\ell\lambda^{(1)}|v_\ell\rangle + i\omega_\ell\boldsymbol\Gamma|v_\ell\rangle + (\mathbf K_0 - \omega_\ell^2)|v^{(1)}\rangle = 0$;
projecting on $\langle v_\ell|$ removes the last term, so
$\lambda^{(1)} = -\tfrac12\langle v_\ell|\boldsymbol\Gamma|v_\ell\rangle$. With
$\langle v_\ell|\mathbf K_n|v_\ell\rangle = \omega_\ell^2 - \langle v_\ell|\mathbf K_t|v_\ell\rangle$:

$$\beta_\ell \approx \frac12\langle v_\ell|\boldsymbol\Gamma|v_\ell\rangle = \frac12\left[b\,\omega_\ell^2 + (b_t - b)\,\langle v_\ell|\mathbf K_t|v_\ell\rangle\right],$$

the design doc's formula. Since both parts are positive semidefinite,
$0 \le \langle v_\ell|\mathbf K_t|v_\ell\rangle \le \omega_\ell^2$, so the rate lies between
$b\,\omega_\ell^2/2$ and $b_t\,\omega_\ell^2/2$: the slowest modes still decay slowest,
but no longer at one exact rate, and the mode shapes change. With Hertzian or Mindlin
contacts $b$ differs from contact to contact; the first-order rate is then
$\tfrac12\sum_c\left(b_c\langle v_\ell|\mathbf K_{n,c}|v_\ell\rangle + b_{t,c}\langle v_\ell|\mathbf K_{t,c}|v_\ell\rangle\right)$,
a sum over contacts $c$. **SoftPack note.**

Checked numerically on a 2D packing (128 bidisperse disks at packing fraction 0.86,
rattlers removed, equal masses, Hookean contacts with tangential springs and rotations,
$\zeta = 0.98$):

| Quantity | matched, $k_t = k_n/3$ | $k_t = k_n$ (Mindlin, $\nu = 0$) |
|---|---|---|
| $b_t/b$ | 1 | 0.5774 ($1/\sqrt3$) |
| $\lVert\boldsymbol\Gamma\mathbf K_0 - \mathbf K_0\boldsymbol\Gamma\rVert / \lVert\mathbf K_0\rVert^2$ (largest entries) | $1\times10^{-16}$ | $2.6\times10^{-2}$ |
| first-order $\beta_\ell/(b\,\omega_\ell^2/2)$, all modes | 1.000 | 0.579 to 0.912 |
| $\langle v_\ell\vert\mathbf K_t\vert v_\ell\rangle/\omega_\ell^2$, all modes | 0.260 to 0.945 | 0.209 to 0.997 |
| first-order vs exact decay rate, 8 slowest modes | exact ($10^{-14}$) | 0.6% at $\zeta = 0.98$; $1.4\times10^{-5}$ at $\zeta = 0.05$ |

In the matched case the exact eigenvalues of the damped problem are the roots of
$\lambda^2 + b\,\omega_\ell^2\lambda + \omega_\ell^2 = 0$ to $1.6\times10^{-14}$.

## Defaults and their reasons

### CundallStrack

```julia
pack(friction = CundallStrack(friction_coefficient = 0.5, stiffness_ratio = :matched))
```

**Decision.** The option's defaults: a linear tangential spring with Coulomb slip.
Works with `Hookean` or `Hertzian` contacts.

- The "Hookean spring-dashpot-slider interaction potential (Cundall and Strack, 1979)"
  of [Santos2024]. [Silbert2001] describe their contact model as "developed earlier by
  Cundall and Strack [28]" and keep a tangential spring stretched by the sliding
  motion, truncated at the Coulomb limit (model above).
- With `Hookean` contacts the tangential stiffness is constant, like the normal one, so
  the collision time, time step and damping constant stay fixed for the whole run
  ([§12](12-time-step.md), [§8](08-damping.md)). **SoftPack note.**

### Mindlin

```julia
pack(contact = Hertzian(stiffness = 1.0),
     friction = Mindlin(friction_coefficient = 0.5, poisson_ratio = 0.0))
```

**Decision.** The option's defaults: the Hertz-Mindlin tangential force, whose
stiffness grows with the overlap. Needs `Hertzian` contacts.

- The Leiden frictional packings use it: [Somfai2005] "The standard approach is to
  consider changes in the tangential force with Mindlin’s approximation [51]", their
  Eq. (A2) ([derivation](#the-mindlin-stiffness-ratio)); [Henkes2010] use
  Hertz-Mindlin particles too ([§2](02-default-packing.md)).
- Needs `Hertzian`: the Mindlin stiffness, like the Hertz one, scales with the contact
  radius, which is what keeps their ratio fixed
  ([derivation](#the-mindlin-stiffness-ratio)). **SoftPack note.**
- [Somfai2005] note a limit of this incremental law: "(Note that Eq. (A4), a
  consequence of approximation (A2), is really only valid for |Ft| ≪ µFn, as pointed
  out in [3].)"

### Friction coefficient

```julia
pack(friction = CundallStrack(friction_coefficient = 0.5))
```

**Decision.** The Coulomb friction coefficient $\mu$ is 0.5 in both models.

- [Somfai2005] packings are "prepared with friction coefficient µ = 0.5 and Poisson
  ratio ν = 0"; [Silbert2001] use "friction coefficient µ = 0.50". It is a common
  value, not a material constant. Frictional studies usually vary $\mu$: [Henkes2010]
  cover $\mu$ from $10^{-3}$ to $10^{3}$, and [Agnolin2007] use "a moderate, plausible
  value µ = 0.3". Production runs should set `friction_coefficient`.
- At $\mu = 0.5$ the friction angle is $\arctan 0.5 = 26.57°$, so a two-contact
  particle can carry load only if its two contact directions are at least
  $126.87°$ apart ([§9](09-rattler-rules.md), our computation).

### Stiffness ratio

```julia
pack(friction = CundallStrack(stiffness_ratio = :matched))
```

**Decision.** The tangential over the normal stiffness is

$$\frac{k_t}{k_n} = \frac{1}{1 + mR^2/I},$$

which makes the tangential contact vibration (sliding plus rotation) exactly as fast as
the normal one. That is 1/3 for disks and 2/7 for spheres
([derivation](#the-matched-stiffness-ratio)).

- [Silbert2001] use $k_t/k_n = 2/7$ for spheres for this reason: "For ease in our
  simulations, we use a value kt/kn=2/7, which makes the period of normal and shear
  contact oscillations equal to each other for Model L [38]." LAMMPS uses the same
  value when $K_t$ is not given: [LAMMPSgran] "If a NULL is used for $K_t$, then a
  default value is used where $K_t = 2/7 K_n$." Applying the same rule to disks is a
  **SoftPack choice**.
- The tangential direction then does not shorten the time step
  ([§12](12-time-step.md)), and the default damping ratio ([§8](08-damping.md)) gives
  both directions the same decay time.
- With equal damping ratios and `tangential_mass = :with_rotation` ([§8](08-damping.md)),
  it makes contact damping exactly proportional to the unstressed stiffness,
  $\boldsymbol\Gamma = b\,\mathbf K_0$, and every underdamped mode decays at
  $b\,\omega_\ell^2/2$; any other ratio mixes the modes
  ([derivation](#proportional-damping-and-first-order-mode-mixing)). **SoftPack note**
  (the design doc's derivation).
- The value matters little for flows: [Silbert2001] "However, the contact dynamics are
  not very sensitive to the precise value of this ratio." Any number can be given
  instead.

### Poisson ratio

```julia
pack(contact = Hertzian(), friction = Mindlin(poisson_ratio = 0.0))
```

**Decision.** The particle material's Poisson ratio $\nu$ is 0 in `Mindlin`.

- The Leiden choice. [Shundyak2007] "The Poisson ratio of the grains is taken to be
  zero"; [Somfai2005] same (quote above). With $\nu = 0$ the two stiffnesses are equal:
  [Somfai2005] "for ν = 0, the value we use in most of the simulations, the two
  effective stiffnesses dFt/dt and dFn/dn are equal", which they continue: "so for
  vibrations neither the radial nor the frictional part of the contact will dominate
  the other."
- Equal stiffnesses do not mean equal frequencies: rotation makes $M_t$ smaller than
  $M_n$, so the tangential vibration is $\sqrt3$ times faster than the normal one for
  disks and sets the time step ([derivation](#mindlin-with-zero-poisson-ratio-vibrates-faster-tangentially),
  [§12](12-time-step.md)).
- For real materials, [Silbert2001] "For Hertzian contacts [37], the ratio kt/kn
  depends on the Poisson ratio of the material, and is about 2/3 for most materials."
  By [Somfai2005]'s Eq. (A4), $\eta = 2/3$ corresponds to $\nu = 0.5$; $\nu$ = 0.2 to 0.3
  gives $\eta$ = 0.89 to 0.82 (our conversion).

## Options

### Frictionless (the default)

```julia
pack(friction = nothing)
```

**Option.** No tangential force and no contact history; particles still rotate freely
but no force can spin them. This is the `pack()` default ([§2](02-default-packing.md)).

### Another stiffness ratio

```julia
pack(friction = CundallStrack(stiffness_ratio = 1.0))
```

**Option.** Any fixed $k_t/k_n$. What it changes: $\omega_t/\omega_n = \sqrt{3s}$ for
disks and $\sqrt{3.5s}$ for spheres ($s$ = `stiffness_ratio`), the time step follows
the faster direction, and contact damping is no longer proportional to the stiffness.

| Value | Used by | $\omega_t/\omega_n$, disks | $\omega_t/\omega_n$, spheres |
|---|---|---|---|
| `:matched` (1/3 disks, 2/7 spheres) | SoftPack default; [Silbert2001], [LAMMPSgran] for spheres | 1 | 1 |
| `2/7` | [Silbert2001], [LAMMPSgran] default | 0.926 | 1 |
| `1.0` | [Santos2024] ($k_n = k_s = 1$ in their units) | 1.732 | 1.871 |

[Santos2024] set "The normal (n) and tangential (s) particle spring (k) and damping (γ)
parameters are set equal to each other" (quote in [§8](08-damping.md)). To reproduce
their contacts, use `stiffness_ratio = 1.0`.

### Another Poisson ratio

```julia
pack(contact = Hertzian(), friction = Mindlin(poisson_ratio = 0.3))
```

**Option.** Lowers $k_t/k_n$ to $\eta = 1 - \nu/(2-\nu)$ (our reading, see Model). For
$\nu = 0.3$: $\eta = 0.824$, $\omega_t/\omega_n = 1.572$ (disks), 1.698 (spheres).

## Worked numbers

| Setting | $k_t/k_n$ | $M_t/M_n$ | $\omega_t/\omega_n$ | $\gamma_t/\gamma_n$ at equal $\zeta$ | $b_t/b$ |
|---|---|---|---|---|---|
| `CundallStrack()`, disks | 1/3 | 1/3 | 1 | 1/3 | 1 |
| `CundallStrack()`, spheres | 2/7 | 2/7 | 1 | 2/7 | 1 |
| `Mindlin(poisson_ratio = 0.0)`, disks | 1 | 1/3 | 1.732 | 0.577 | 0.577 |
| `Mindlin(poisson_ratio = 0.0)`, spheres | 1 | 2/7 | 1.871 | 0.535 | 0.535 |
| `Mindlin(poisson_ratio = 0.3)`, disks | 0.824 | 1/3 | 1.572 | 0.524 | 0.636 |

$\gamma_t/\gamma_n = \sqrt{k_t M_t/(k_n M_n)}$ and
$b_t/b = (\gamma_t/k_t)/(\gamma_n/k_n) = \omega_n/\omega_t$ (computed).

Friction angle and two-contact limit at the default $\mu = 0.5$:
$\arctan 0.5 = 26.565°$, $\theta_\text{min} = 126.870°$ ([§9](09-rattler-rules.md)).

## Open questions

- `CundallStrack` with `Hertzian` contacts: the design doc does not say which normal
  stiffness the ratio refers to. The Hertz stiffness $k_n(\delta) = \tfrac32k\delta^{1/2}$
  changes with the overlap, so either the tangential spring follows it (and is no
  longer linear) or it uses a fixed reference stiffness.
- `Mindlin` for $\nu \ne 0$: the design doc states only $\nu = 0$ ($k_t = k_n$).
  [Somfai2005]'s Eq. (A4) is the natural general rule.
- `Mindlin` history: Eq. (A4) holds only for $\lvert F_t\rvert \ll \mu F_n$ (quote
  above), and how the stored tangential force is handled when a contact unloads is not
  designed.
- Contact rotation: the stored $\xi_t$ must stay in the tangent plane as the pair
  rotates ([Silbert2001]'s Eq. (5) has a term for this, and 3D adds a second tangential
  direction). Not designed yet.
- Moment of inertia: the design doc does not state the convention. `:matched` gives
  1/3 only if 2D particles have the disk value $I = mR^2/2$; with
  `Density(shape = :sphere)` in 2D (spheres confined to a plane,
  [§4](04-mass.md)) a sphere's $I = \tfrac25 mR^2$ would make the matched ratio 2/7.
- FIRE with friction is allowed but non-standard ([§7](07-algorithms-and-combinations.md)).

## Related pages

- [8. Damping](08-damping.md): tangential dashpot, `tangential_mass`, `coulomb_limit`.
- [9. Rattler rules](09-rattler-rules.md): the friction cone and two-contact particles.
- [12. Time step](12-time-step.md): the tangential frequency in the time step.
- [2. Default packing](02-default-packing.md): `Hookean` and `Hertzian` contact laws.
- [Notation](notation.md), [References](references.md).

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[Henkes2010]** S. Henkes, M. van Hecke, W. van Saarloos (2010). *Critical jamming of frictional grains in the generalized isostaticity picture*. EPL (Europhysics Letters) **90**, 14003. [doi:10.1209/0295-5075/90/14003](https://doi.org/10.1209/0295-5075/90/14003).
- **[LAMMPSgran]** LAMMPS developers. *LAMMPS documentation: pair_style gran/hooke, gran/hooke/history, gran/hertz/history*. <https://docs.lammps.org/pair_gran.html>. Accessed 2026-11-18.
- **[Santos2024]** A. P. Santos, Ishan Srivastava, Leonardo E. Silbert, Jeremy B. Lechman, Gary S. Grest (2024). *Protocol-dependent frictional granular jamming simulations: cyclical, compression, and expansion*. Frontiers in Soft Matter **3**, 1326756. [doi:10.3389/frsfm.2023.1326756](https://doi.org/10.3389/frsfm.2023.1326756).
- **[Shundyak2007]** Kostya Shundyak, Martin van Hecke, Wim van Saarloos (2007). *Force mobilization and generalized isostaticity in jammed packings of frictional grains*. Physical Review E **75**, 010301. [doi:10.1103/physreve.75.010301](https://doi.org/10.1103/physreve.75.010301).
- **[Silbert2001]** Leonardo E. Silbert, Deniz Ertaş, Gary S. Grest, Thomas C. Halsey, Dov Levine, Steven J. Plimpton (2001). *Granular flow down an inclined plane: Bagnold scaling and rheology*. Physical Review E **64**, 051302. [doi:10.1103/physreve.64.051302](https://doi.org/10.1103/physreve.64.051302).
- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
