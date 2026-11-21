# 8. Damping

Design decision source: [design-references.md §8](../design-references.md#8-damping).
Status: design stage (no engine code yet).

## Summary

Damping decides how `pack()` removes kinetic energy so that the particles come to rest
in a force-balanced packing. With `algorithm = DampedDynamics()`, the default puts a
dashpot on every contact: a normal dashpot on the approach and separation speed and,
when friction is on, a tangential dashpot on the sliding speed at the contact point.
Each dashpot is 0.98 of its own critical value, and the tangential critical value uses
the sliding mass, which includes particle rotation. The dashpots never make a contact
pull, the friction limit applies to the spring forces only, and there is no Stokes
drag. For Hookean contacts and equal masses these choices make the damping matrix
exactly proportional to the unstressed stiffness matrix, so every vibration mode
decays on its own, at a rate that goes as the square of its frequency: the
lowest-frequency modes are the last to die. FIRE removes energy with its own velocity
rules and has no damping by default. The options are raw damping rates
(`ViscousRate`), one dashpot on the full relative velocity
(`RelativeVelocityDamping`), Stokes drag on velocity and spin (`StokesDrag`), and
LAMMPS's switches (`attractive = true`, `coulomb_limit = :total`, `tangential = 0`).
Damping settings are part of the preparation protocol and are recorded in every
output ([§7](07-algorithms-and-combinations.md)).

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| `DampedDynamics(damping = ...)` | `ContactDamping(...)` with the values below | `ViscousRate(...)`, `RelativeVelocityDamping(...)`, `nothing` | [Defaults](#defaults-and-their-reasons), [Options](#options) |
| `ContactDamping(normal = ...)` | `0.98` | any ratio $\ge 0$ | [Normal ratio](#normal-ratio-098) |
| `ContactDamping(tangential = ...)` | `0.98` | any ratio $\ge 0$; `0` turns it off | [Tangential ratio](#tangential-ratio-098) |
| `ContactDamping(tangential_mass = ...)` | `:with_rotation` | `:pair` | [Sliding mass](#tangential-critical-value-on-the-sliding-mass) |
| `ContactDamping(attractive = ...)` | `false` | `true` | [Never pull](#dashpots-never-pull) |
| `ContactDamping(coulomb_limit = ...)` | `:elastic` | `:total` | [Friction limit](#friction-limit-on-spring-forces) |
| `DampedDynamics(drag = ...)` | `nothing` | `StokesDrag(velocity = rate, spin = velocity, during = :always)` | [No drag](#no-stokes-drag), [StokesDrag](#stokesdrag) |
| `FIRE(damping = ..., drag = ...)` | `nothing`, `nothing` | the same values as `DampedDynamics` | [FIRE](#fire-no-damping) |
| `ViscousRate(normal, tangential)` | option's own defaults `0.5`, `0.5` (units $1/\tau$) | any rates | [ViscousRate](#viscousrate) |
| `RelativeVelocityDamping(rate)` | option's own default `0.5` (units $1/\tau$) | any rate | [RelativeVelocityDamping](#relativevelocitydamping) |
| `StokesDrag(velocity, spin, during)` | `velocity` required; `spin = velocity`; `during = :always` | `during = :compression` | [StokesDrag](#stokesdrag) |

`ViscousRate`, `RelativeVelocityDamping` and `StokesDrag` take the same `attractive` and
`coulomb_limit` keywords as `ContactDamping` (the first two) with the same defaults.
Their own defaults apply only when they are chosen; none of them is on by default.

## Model

### Contact kinematics

Two particles $i$ and $j$ touch. They have masses $m_i$, $m_j$, radii $R_i$, $R_j$,
moments of inertia $I_i$, $I_j$ ($I = mR^2/2$ for a uniform disk, $I = 2mR^2/5$ for a
uniform sphere), center velocities $\mathbf v_i$, $\mathbf v_j$ and spins
$\boldsymbol\omega_i$, $\boldsymbol\omega_j$ (bold: a spin vector; plain $\omega$ is an
angular frequency on this page). In 2D the spin is $\boldsymbol\omega_i = \dot\theta_i\,\hat{\mathbf z}$, with $\theta_i$ the rotation angle. The unit normal
$\hat{\mathbf n}$ points from $i$ to $j$, the 2D unit tangent is $\hat{\mathbf t} = \hat{\mathbf z}\times\hat{\mathbf n} = (-n_y, n_x)$, and the overlap is $\delta = R_i + R_j - r_{ij}$, with $r_{ij}$ the center distance.

A dashpot acts on one of two contact speeds:

$$
v_n = \hat{\mathbf n}\cdot(\mathbf v_j - \mathbf v_i) = -\dot\delta,
\qquad
v_t = \hat{\mathbf t}\cdot(\mathbf v_j - \mathbf v_i) - R_j\dot\theta_j - R_i\dot\theta_i .
$$

- $v_n$ is the separation speed, positive when the particles move apart.
- $v_t$ is the slip speed. The contact point of $j$ sits at $\mathbf r_j - R_j\hat{\mathbf n}$
  and moves with $\mathbf v_j + \boldsymbol\omega_j\times(-R_j\hat{\mathbf n}) = \mathbf v_j - R_j\dot\theta_j\hat{\mathbf t}$. The contact point of $i$ sits at $\mathbf r_i + R_i\hat{\mathbf n}$ and moves with $\mathbf v_i + R_i\dot\theta_i\hat{\mathbf t}$. Their
  difference along $\hat{\mathbf t}$ is $v_t$.
- In 3D the slip velocity is the vector $\mathbf v_s = (\mathbf I_3 - \hat{\mathbf n}\hat{\mathbf n}^\top)(\mathbf v_j - \mathbf v_i) - (R_i\boldsymbol\omega_i + R_j\boldsymbol\omega_j)\times\hat{\mathbf n}$, with two tangential components; in 2D it is
  $v_t\hat{\mathbf t}$.

### Contact forces

The force on $j$ is $F_n\hat{\mathbf n} + F_t\hat{\mathbf t}$; the force on $i$ is the
opposite. With the default `attractive = false`,

$$
F_n = \max\left(0,\; F_n^\text{el} - \gamma_n v_n\right),
\qquad
F_t = F_t^\text{el} - \gamma_t v_t \quad\text{(stuck contact)}.
$$

- $F_n^\text{el} = k\,\delta^{\alpha-1}$ is the elastic normal force of the contact law
  ($\alpha = 2$ Hooke, $5/2$ Hertz; [§2](02-default-packing.md)), and $k_n = dF_n^\text{el}/d\delta$ its stiffness: $k_n = k$ for Hooke, $k_n = \tfrac32 k\,\delta^{1/2}$
  for Hertz.
- $F_t^\text{el} = -k_t\,\xi$ is the tangential spring force ([§13](13-friction-models.md)),
  with $\xi$ the spring's stretch ($\dot\xi = v_t$ while the contact is stuck) and $k_t$
  its stiffness.
- $\gamma_n$, $\gamma_t$ are the dashpot coefficients (force per velocity).
- The tangential force makes torques. About $\hat{\mathbf z}$: $T_j = (-R_j\hat{\mathbf n})\times(F_t\hat{\mathbf t}) = -R_jF_t$ and $T_i = (R_i\hat{\mathbf n})\times(-F_t\hat{\mathbf t}) = -R_iF_t$.

The power of these forces on the two particles is

$$
\begin{aligned}
P_c &= (F_n\hat{\mathbf n} + F_t\hat{\mathbf t})\cdot(\mathbf v_j - \mathbf v_i) - R_jF_t\dot\theta_j - R_iF_t\dot\theta_i \\
&= F_n v_n + F_t v_t ,
\end{aligned}
$$

so the dashpots remove energy at the rate $\gamma_n v_n^2 + \gamma_t v_t^2 \ge 0$, and the
springs exchange it with the stored energy ($F_n^\text{el}v_n = -F_n^\text{el}\dot\delta$).

### Energy-loss channels

| Channel | What it damps | What it leaves undamped | Setting |
|---|---|---|---|
| Normal contact dashpot | Approach and separation speed $v_n$ of touching particles | Sliding, rolling, uniform drift | `ContactDamping(normal = ...)` |
| Tangential contact dashpot | Slip speed $v_t$ at the contact point (friction on only) | Pure rolling ($v_t = 0$), uniform drift | `ContactDamping(tangential = ...)` |
| Relative-velocity dashpot | Full relative velocity $\mathbf v_i - \mathbf v_j$ of the two centers, one rate for both directions (friction on or off) | A particle spinning in place, uniform drift | `RelativeVelocityDamping(rate = ...)` |
| Stokes drag on velocity | Each particle's absolute velocity | Nothing translational; it also damps uniform drift | `StokesDrag(velocity = ...)` |
| Stokes drag on spin | Each particle's absolute spin | Nothing rotational | `StokesDrag(spin = ...)` |
| Coulomb sliding | Sliding contacts | Stuck contacts | not a setting; part of friction |

The first two columns and the settings are the design doc's; the "leaves undamped"
column follows from the contact speeds above and is checked in
[Spin and rolling](#8-spin-and-rolling).

### Linearized equations of motion

Collect every coordinate in one vector $\mathbf q$: positions, and rotation angles when
friction is on. Small motions about a packing obey

$$
\mathbf M\ddot{\mathbf q} + \boldsymbol\Gamma\dot{\mathbf q} + \mathbf K\mathbf q = 0 .
$$

- $\mathbf M$ is the diagonal mass matrix: $m_i$ on each translational coordinate,
  $I_i$ on each rotation.
- For contact $c$, write $v_n = \mathbf h_c^\top\dot{\mathbf q}$ and $v_t = \mathbf g_c^\top\dot{\mathbf q}$. In 2D, $\mathbf h_c$ has $-\hat{\mathbf n}$ on $i$'s position,
  $+\hat{\mathbf n}$ on $j$'s, and zero elsewhere; $\mathbf g_c$ has $-(t_x, t_y, R_i)$ on
  $i$'s $(x, y, \theta)$ and $(t_x, t_y, -R_j)$ on $j$'s.
- The unstressed stiffness matrix and the damping matrix are built from the same
  vectors:

$$
\mathbf K_0 = \sum_c\left(k_n\,\mathbf h_c\mathbf h_c^\top + k_t\,\mathbf g_c\mathbf g_c^\top\right),
\qquad
\boldsymbol\Gamma = \sum_c\left(\gamma_n\,\mathbf h_c\mathbf h_c^\top + \gamma_t\,\mathbf g_c\mathbf g_c^\top\right).
$$

- $\dot{\mathbf q}^\top\boldsymbol\Gamma\dot{\mathbf q} = \sum_c(\gamma_n v_n^2 + \gamma_t v_t^2)$ is the dissipated power, so $\boldsymbol\Gamma$ is symmetric and positive
  semidefinite.
- Without friction, $\mathbf h_c\mathbf h_c^\top = \mathbf L^{(c)}\otimes\hat{\mathbf n}\hat{\mathbf n}^\top$, where $\mathbf L^{(c)}$ is the $N\times N$ contact Laplacian
  with entries $+1$ at $(i,i)$ and $(j,j)$ and $-1$ at $(i,j)$ and $(j,i)$. So $\mathbf K_0 = k_n\sum_c\mathbf L^{(c)}\otimes\hat{\mathbf n}\hat{\mathbf n}^\top$.
- The full Hessian $\mathbf K$ adds a stress term to $\mathbf K_0$. For a frictionless
  pair it is $-\sum_c (F_n^\text{el}/r_{ij})\,\mathbf L^{(c)}\otimes(\mathbf I_D - \hat{\mathbf n}\hat{\mathbf n}^\top)$, with $\mathbf I_D$ the $D\times D$ identity and $D$
  the dimension. The dashpots follow $\mathbf K_0$, not $\mathbf K$.

From here on every matrix is mass-weighted, $\mathbf A \to \mathbf M^{-1/2}\mathbf A\,\mathbf M^{-1/2}$, and keeps its symbol, as in the design doc. The undamped modes
are $\mathbf K_0|v_\ell\rangle = \omega_\ell^2|v_\ell\rangle$, with orthonormal unit
vectors $|v_\ell\rangle$, mode index $\ell$ and angular frequency $\omega_\ell$. A damped
motion $\propto e^{\lambda t}|u\rangle$ solves the quadratic eigenvalue problem (QEP)

$$
\left(\lambda^2\,\mathbf I + \lambda\,\boldsymbol\Gamma + \mathbf K_0\right)|u\rangle = 0 ,
$$

and a mode decays at $\beta_\ell = -\mathrm{Re}\,\lambda_\ell$, with damping ratio $\zeta_\ell = \beta_\ell/\omega_\ell$.

## Derivations

### 1. One contact: critical damping, damping ratio, restitution

For an isolated pair, Newton's law along $\hat{\mathbf n}$ gives $m_j\,\hat{\mathbf n}\cdot\dot{\mathbf v}\_j = F_n$ and $m_i\,\hat{\mathbf n}\cdot\dot{\mathbf v}\_i = -F_n$, so
$\dot v_n = F_n(1/m_i + 1/m_j) = F_n/M_n$. With $\ddot\delta = -\dot v_n$ and a Hookean
contact that pushes ($F_n = k_n\delta + \gamma_n\dot\delta > 0$),

$$
M_n\ddot\delta + \gamma_n\dot\delta + k_n\delta = 0,
\qquad
\frac{1}{M_n} = \frac{1}{m_i} + \frac{1}{m_j}.
$$

This is the damped oscillator $m\ddot x + \gamma\dot x + kx = 0$. With $x \propto e^{\lambda t}$, $m\lambda^2 + \gamma\lambda + k = 0$, so

$$
\lambda = \frac{-\gamma \pm \sqrt{\gamma^2 - 4km}}{2m}
= \omega\left(-\zeta \pm \sqrt{\zeta^2 - 1}\right),
\qquad
\omega = \sqrt{k/m},\quad
\zeta = \frac{\gamma}{\gamma_\text{crit}},\quad
\gamma_\text{crit} = 2\sqrt{km}.
$$

- At $\gamma = \gamma_\text{crit}$ the square root vanishes: the fastest return without
  oscillation. That defines the critical coefficient and the damping ratio $\zeta$.
- For $\zeta < 1$ the motion oscillates at $\omega_d = \omega\sqrt{1-\zeta^2}$ and decays at
  $\zeta\omega$.

**Restitution.** A collision starts with $\delta(0) = 0$ and $\dot\delta(0) = v_0 > 0$.
Then

$$
\delta(t) = \frac{v_0}{\omega_d}\,e^{-\zeta\omega t}\sin\omega_d t,
\qquad
\dot\delta(t) = \frac{v_0}{\omega_d}\,e^{-\zeta\omega t}\left(\omega_d\cos\omega_d t - \zeta\omega\sin\omega_d t\right),
$$

and the restitution coefficient is $e = -\dot\delta(t_\text{end})/v_0$. It depends on when
the contact ends.

- If the dashpot may pull (`attractive = true`), the contact ends when $\delta$ returns
  to zero, at $\omega_d t_\text{end} = \pi$:

$$
e = \exp\left(-\frac{\pi\zeta}{\sqrt{1-\zeta^2}}\right).
$$

- With the default `attractive = false`, the force $k_n\delta + \gamma_n\dot\delta$ reaches
  zero while $\delta > 0$ (at $\delta = 0$ it would be $\gamma_n\dot\delta < 0$). After that
  the clipped force stays zero, because $k_n\delta$ keeps falling while $\dot\delta$ no
  longer changes, and the particles leave with the speed they have. Write $\zeta = \cos\varphi_\zeta$, $\sqrt{1-\zeta^2} = \sin\varphi_\zeta$ ($0 < \varphi_\zeta < \pi/2$). The
  condition $\omega^2\delta + 2\zeta\omega\dot\delta = 0$ becomes $\sin(2\varphi_\zeta - \omega_d t) = 0$, so $\omega_d t_\text{end} = 2\varphi_\zeta$, and there $\omega_d\cos 2\varphi_\zeta - \zeta\omega\sin 2\varphi_\zeta = -\omega\sin\varphi_\zeta = -\omega_d$. Hence

$$
e = e^{-\zeta\omega t_\text{end}} = \exp\left(-\frac{2\zeta\arccos\zeta}{\sqrt{1-\zeta^2}}\right),
$$

  which tends to $e^{-2} \approx 0.135$ at $\zeta = 1$ and continues as
  $\exp\left(-2\zeta\,\mathrm{arccosh}\,\zeta/\sqrt{\zeta^2-1}\right)$ for $\zeta > 1$.

| $\zeta$ | $e$, `attractive = true` | $e$, `attractive = false` |
|---|---|---|
| 0.98 (default) | $1.9\times10^{-7}$ | 0.139 |
| 0.20 | 0.527 | 0.572 |
| 0.177 (`ViscousRate` default, equal masses) | 0.569 | 0.606 |

Both columns were checked by integrating the equation of motion numerically (agreement
to four digits). That the end of contact must be where the force vanishes, and that
this raises $e$, is the point of [Schwager2007]: "It is clear that once the force
becomes zero, the collision is finished", and "In agreement with the repulsive
character of the interaction force, the coefficient of restitution is always well
defined and non-zero." The closed form above is **SoftPack note** (our derivation).
Either way $e$ depends only on $\zeta$, not on the impact speed.

### 2. Normal and tangential effective masses

Give the pair equal and opposite impulses at the contact point, $+J\hat{\mathbf e}$ on $j$
and $-J\hat{\mathbf e}$ on $i$, and ask how much the contact speed changes.

- Normal, $\hat{\mathbf e} = \hat{\mathbf n}$: the impulse passes through both centers, so
  there is no spin. $\Delta v_n = J(1/m_j + 1/m_i) = J/M_n$.
- Tangential, $\hat{\mathbf e} = \hat{\mathbf t}$: the centers change velocity by
  $\Delta\mathbf v_j = J\hat{\mathbf t}/m_j$ and $\Delta\mathbf v_i = -J\hat{\mathbf t}/m_i$.
  The angular impulses are $(-R_j\hat{\mathbf n})\times(J\hat{\mathbf t}) = -R_jJ\,\hat{\mathbf z}$ and $(R_i\hat{\mathbf n})\times(-J\hat{\mathbf t}) = -R_iJ\,\hat{\mathbf z}$, so
  $\Delta\dot\theta_j = -R_jJ/I_j$ and $\Delta\dot\theta_i = -R_iJ/I_i$. Into $v_t$:

$$
\Delta v_t = \hat{\mathbf t}\cdot(\Delta\mathbf v_j - \Delta\mathbf v_i) - R_j\Delta\dot\theta_j - R_i\Delta\dot\theta_i
= J\left(\frac{1}{m_i} + \frac{1}{m_j} + \frac{R_i^2}{I_i} + \frac{R_j^2}{I_j}\right) \equiv \frac{J}{M_t}.
$$

- A normal impulse leaves $v_t$ unchanged and a tangential one leaves $v_n$ unchanged,
  so for one stuck contact the two directions are independent oscillators: $M_n\ddot\delta + \gamma_n\dot\delta + k_n\delta = 0$ and $M_t\ddot\xi + \gamma_t\dot\xi + k_t\xi = 0$.
- The tangential force pushes and spins both particles, so the slip responds like a
  lighter mass than the pair.

Values ($R^2/I = 2/m$ for a uniform disk, $5/(2m)$ for a uniform sphere):

| Pair | $M_n$ | $M_t$ | $M_n/M_t$ |
|---|---|---|---|
| Equal disks, mass $m$ | $m/2$ | $m/6$ | 3 |
| Equal spheres, mass $m$ | $m/2$ | $m/7$ | 3.5 |
| Uniform disks, any masses | $(1/m_i + 1/m_j)^{-1}$ | $M_n/3$ | 3 |

The impulse calculation was checked numerically for random masses, radii and contact
angles: $\Delta v_t/J$ matches $1/M_t$ to machine precision, and the cross responses
are zero. **SoftPack note** (rigid-body mechanics of two particles).

### 3. Critical values in the two directions

Each direction has its own critical coefficient,

$$
\gamma_{n,\text{crit}} = 2\sqrt{k_n M_n},
\qquad
\gamma_{t,\text{crit}} = 2\sqrt{k_t M_t},
$$

and `ContactDamping` sets $\gamma_n = \zeta_n\gamma_{n,\text{crit}}$, $\gamma_t = \zeta_t\gamma_{t,\text{crit}}$, with $\zeta_n$ = `normal` and $\zeta_t$ = `tangential`.

- **Same ratio, different coefficients.** At $\zeta_n = \zeta_t$,
  $\gamma_t/\gamma_n = \sqrt{k_tM_t/(k_nM_n)}$. With `stiffness_ratio = :matched`
  ([§13](13-friction-models.md)), $k_t/k_n = 1/(1 + mR^2/I) = M_t/M_n$ for equal
  particles, so $\gamma_t/\gamma_n = M_t/M_n$: $1/3$ for disks, $2/7$ for spheres.
- **Same coefficient, different ratios.** One shared $\gamma$ gives $\zeta_t/\zeta_n = \sqrt{k_nM_n/(k_tM_t)} = M_n/M_t$ at matched stiffness: $\zeta_t = 3\zeta_n$ for disks and
  $3.5\,\zeta_n$ for spheres.
- **Ratio on the pair mass** (`tangential_mass = :pair`): $\gamma_t = 2\zeta\sqrt{k_tM_n}$
  is $\zeta\sqrt{M_n/M_t}$ of the true critical value: $\sqrt3\,\zeta$ for disks
  ($0.98 \to 1.70$) and $\sqrt{3.5}\,\zeta$ for spheres ($0.98 \to 1.83$).
- At matched stiffness both directions of a contact vibrate at the same frequency,
  $\omega_c = \sqrt{k_n/M_n} = \sqrt{k_t/M_t}$, the contact frequency.

### 4. Rayleigh damping: each mode is a damped oscillator

Rayleigh damping is a damping matrix of the form $\boldsymbol\Gamma = a\mathbf M + b\mathbf K_0$; mass-weighted, $\boldsymbol\Gamma = a\mathbf I + b\mathbf K_0$. Expand a
motion in the undamped modes, $|u(t)\rangle = \sum_\ell q_\ell(t)|v_\ell\rangle$, and project
the equation of motion onto $\langle v_\ell|$. Because $\langle v_\ell|(a\mathbf I + b\mathbf K_0)|v_m\rangle = (a + b\,\omega_\ell^2)\,\delta_{\ell m}$, no mode couples to another:

$$
\ddot q_\ell + \left(a + b\,\omega_\ell^2\right)\dot q_\ell + \omega_\ell^2\,q_\ell = 0,
\qquad
\lambda_\ell^2 + \left(a + b\,\omega_\ell^2\right)\lambda_\ell + \omega_\ell^2 = 0 .
$$

The roots are $\lambda_\ell = -\beta_\ell \pm \sqrt{\beta_\ell^2 - \omega_\ell^2}$ with $\beta_\ell = (a + b\,\omega_\ell^2)/2$. While $\beta_\ell < \omega_\ell$ the mode is underdamped and decays
at $\beta_\ell$, with $\zeta_\ell = \beta_\ell/\omega_\ell$.

- **Contact damping is the $b$ term** ($a = 0$). A Hookean dashpot set as a ratio has
  $b = \gamma/k = 2\zeta\sqrt{kM}/k = 2\zeta/\omega_c$. Then

$$
\beta_\ell = \frac{b\,\omega_\ell^2}{2} = \frac{\zeta\,\omega_\ell^2}{\omega_c},
\qquad
\zeta_\ell = \zeta\,\frac{\omega_\ell}{\omega_c} .
$$

  The lowest-frequency modes ring with $\zeta_\ell \ll 1$ and decay as $\omega_\ell^2$: they die
  last. Modes above $\omega_c/\zeta$ ($1.02\,\omega_c$ at $\zeta = 0.98$) are overdamped.
- **Stokes drag is the $a$ term** ($b = 0$), with $a$ the drag rate. Every underdamped
  mode decays at $\beta_\ell = a/2$, and $\zeta_\ell = a/(2\omega_\ell)$. Modes with $\omega_\ell < a/2$ are overdamped; their slow root is

$$
\lambda_\ell = -\frac a2 + \sqrt{\frac{a^2}{4} - \omega_\ell^2} \approx -\frac{\omega_\ell^2}{a}
\qquad (\omega_\ell \ll a/2),
$$

  so they creep, relaxing at about $\omega_\ell^2/a$, which also goes to zero with
  $\omega_\ell$.
- `StokesDrag` with `spin = velocity` applies $-a\,m_i\mathbf v_i$ and $-a\,I_i\boldsymbol\omega_i$,
  which is exactly $a\mathbf M$. A different spin rate makes the rotational block
  $a_s I_i$ and the drag is no longer proportional to $\mathbf M$.

Under both channels the decay rate vanishes as $\omega_\ell \to 0$, so the
lowest-frequency modes are the last motion left when a run nears its stopping rule
([§5](05-convergence-criterion.md)). **SoftPack note** (standard result for Rayleigh
damping; not taken from a cited paper).

### 5. Decay rate of a mode when the damping is not proportional

When $\boldsymbol\Gamma$ is not of Rayleigh form the modes mix, but for weak damping each
mode's decay rate still follows from its own diagonal element. Put $\lambda = i\omega_\ell + \lambda_1$ and $|u\rangle = |v_\ell\rangle + |u_1\rangle$ into the QEP and keep first-order
terms:

$$
\left(\mathbf K_0 - \omega_\ell^2\,\mathbf I\right)|u_1\rangle + i\omega_\ell\left(2\lambda_1 + \boldsymbol\Gamma\right)|v_\ell\rangle = 0 .
$$

Multiply by $\langle v_\ell|$. The first term vanishes because $\langle v_\ell|\mathbf K_0 = \omega_\ell^2\langle v_\ell|$, which leaves $2\lambda_1 + \langle v_\ell|\boldsymbol\Gamma|v_\ell\rangle = 0$:

$$
\beta_\ell \approx \tfrac12\,\langle v_\ell|\boldsymbol\Gamma|v_\ell\rangle .
$$

- It is exact for Rayleigh damping ($\langle v_\ell|a\mathbf I + b\mathbf K_0|v_\ell\rangle = a + b\,\omega_\ell^2$).
- It needs $\langle v_\ell|\boldsymbol\Gamma|v_\ell\rangle \ll \omega_\ell$ and couplings
  $\langle v_m|\boldsymbol\Gamma|v_\ell\rangle$ small compared with the gaps $|\omega_\ell - \omega_m|$; the error is second order. It fails for $\omega_\ell \to 0$ at fixed damping,
  where the mode becomes overdamped.

**SoftPack note** (standard first-order perturbation of the QEP).

### 6. When ContactDamping is exactly stiffness-proportional

From the Model section, $\boldsymbol\Gamma = b\,\mathbf K_0$ holds when every contact has
$\gamma_n/k_n = \gamma_t/k_t = b$. With ratio-defined dashpots,

$$
b_n = \frac{\gamma_n}{k_n} = 2\zeta\sqrt{\frac{M_n}{k_n}},
\qquad
b_t = \frac{\gamma_t}{k_t} = 2\zeta\sqrt{\frac{M_t}{k_t}} .
$$

- **Within a contact**, $b_t = b_n$ when $k_t/k_n = M_t/M_n$, that is
  `stiffness_ratio = :matched` together with `tangential_mass = :with_rotation`.
- **Between contacts**, $b$ is the same when $M_n/k_n$ is: Hookean contacts (one $k$ for
  every pair) and equal masses.
- Without friction only $b_n$ exists, so the condition is just the second one.

Then the modes decouple (Derivation 4 with $a = 0$) and every underdamped mode decays at
exactly $b\,\omega_\ell^2/2$.

If $b_t \ne b_n \equiv b$, split $\mathbf K_0 = \mathbf K_n + \mathbf K_t$ into its normal-
and tangential-spring parts. Then $\boldsymbol\Gamma = b\,\mathbf K_0 + (b_t - b)\,\mathbf K_t$,
and Derivation 5 gives

$$
\beta_\ell \approx \frac12\left[b\,\omega_\ell^2 + (b_t - b)\,\langle v_\ell|\mathbf K_t|v_\ell\rangle\right].
$$

Both parts are positive semidefinite and add to $\mathbf K_0$, so $0 \le \langle v_\ell|\mathbf K_t|v_\ell\rangle \le \omega_\ell^2$, and $\beta_\ell$ lies between $b\,\omega_\ell^2/2$
and $b_t\,\omega_\ell^2/2$. The lowest modes still die last; exactness and decoupling are
lost. Two examples for disks: `tangential_mass = :pair` gives $b_t = \sqrt3\,b$, and $k_t = k_n$ (`Mindlin` with $\nu = 0$) with `:with_rotation` gives $b_t = b/\sqrt3$.

Exactness fails, and the rate is only approximately $b\,\omega_\ell^2/2$, for:

- Hertz or Mindlin contacts: $k_n$ and $k_t$ change with each contact's overlap, so $b$
  differs between contacts.
- `Density` masses ([§4](04-mass.md)): $M_n$ differs between pairs. (For uniform disks
  $M_t = M_n/3$ for every pair, so $b_t = b_n$ still holds within each contact.)
- The stressed Hessian: the dashpots follow $\mathbf K_0$, while the true modes are those of
  $\mathbf K = \mathbf K_0 + \text{stress term}$. To first order a mode of $\mathbf K$ decays
  at $(b/2)\langle v_\ell|\mathbf K_0|v_\ell\rangle$.
- Sliding contacts and clipped normal forces: the linear analysis assumes every
  contact is stuck and pushing.

**Numerical check** (**SoftPack note**). A 64-disk 2D packing (setup in
[Derivation 7](#numerical-check-of-the-frictionless-results)) with all contacts stuck,
rotations included, equal masses and $\zeta = 0.3$:

| Setting | $b_t/b$ | $\lVert\mathbf K_0\boldsymbol\Gamma - \boldsymbol\Gamma\mathbf K_0\rVert/\lVert\mathbf K_0\boldsymbol\Gamma\rVert$ | $\langle v_\ell\vert\boldsymbol\Gamma\vert v_\ell\rangle/(b\,\omega_\ell^2)$ over all modes |
|---|---|---|---|
| `:matched`, `:with_rotation` (defaults) | 1 | $8\times10^{-17}$ | 1.000 for every mode |
| `tangential_mass = :pair` | 1.732 | 0.058 | 1.21 to 1.67 |
| $k_t = k_n$, `:with_rotation` | 0.577 | 0.041 | 0.578 to 0.904 |

- With the defaults the QEP eigenvalues match each mode's quadratic to $1.4\times10^{-14}$
  (relative).
- For the other two rows the first-order formula above matches the QEP with a median
  relative error of $1.4\times10^{-6}$ and $1\times10^{-7}$ at $\zeta = 6\times10^{-4}$.
- For the stressed Hessian of the same packing ($P/k = 0.025$), $\langle v_\ell|\mathbf K_0|v_\ell\rangle/\omega_\ell^2$ ranges from 1.005 to 5.1, the largest value for the lowest
  mode; for a packing closer to jamming ($P/k = 1.9\times10^{-3}$) the largest is 2.7.

### 7. Frictionless contact matrices and relative-velocity damping

Per unit stiffness, the frictionless unstressed stiffness matrix and the
relative-velocity damping matrix are

$$
\mathbf K' = \sum_c \mathbf L^{(c)}\otimes\hat{\mathbf n}_c\hat{\mathbf n}_c^\top,
\qquad
\boldsymbol\Gamma' = \mathbf L\otimes\mathbf I_D,
\qquad
\mathbf L = \sum_c\mathbf L^{(c)},
$$

so that $\mathbf K_0 = k_n\mathbf K'$ and the `RelativeVelocityDamping` matrix is
$\gamma\,\boldsymbol\Gamma'$ (the force $-\gamma(\mathbf v_i - \mathbf v_j)$ at every contact).
Split each contact's identity into its normal and tangential projectors, $\mathbf I_D = \hat{\mathbf n}\hat{\mathbf n}^\top + (\mathbf I_D - \hat{\mathbf n}\hat{\mathbf n}^\top)$:

$$
\boldsymbol\Gamma' = \sum_c\mathbf L^{(c)}\otimes\hat{\mathbf n}_c\hat{\mathbf n}_c^\top + \sum_c\mathbf L^{(c)}\otimes\left(\mathbf I_D - \hat{\mathbf n}_c\hat{\mathbf n}_c^\top\right) = \mathbf K' + \mathbf K'_\perp .
$$

The split is exact. $\mathbf K'\_\perp$ is the same contact sum with the tangential
projector: a damping term with no spring behind it. In the design doc's notation,
$\boldsymbol\Gamma_\text{RV} = \gamma(\mathbf K' + \mathbf K'\_\perp) = b\,(\mathbf K_0 + \mathbf K_\perp)$ with $b = \gamma/k_n$ and $\mathbf K_\perp = k_n\mathbf K'\_\perp$.

#### Two disks, one contact

Disks 1 and 2, coordinates $(x_1, y_1, x_2, y_2)$, normal $\hat{\mathbf n} = (3/5, 4/5)$.
Then

$$
\hat{\mathbf n}\hat{\mathbf n}^\top = \frac{1}{25}\begin{pmatrix}9 & 12\\ 12 & 16\end{pmatrix}, \qquad
\mathbf I_2 - \hat{\mathbf n}\hat{\mathbf n}^\top = \frac{1}{25}\begin{pmatrix}16 & -12\\ -12 & 9\end{pmatrix}, \qquad
\mathbf L^{(c)} = \begin{pmatrix}1 & -1\\ -1 & 1\end{pmatrix},
$$

so

$$
\mathbf K' = \frac{1}{25}\begin{pmatrix}
9 & 12 & -9 & -12 \\
12 & 16 & -12 & -16 \\
-9 & -12 & 9 & 12 \\
-12 & -16 & 12 & 16
\end{pmatrix},
\qquad
\mathbf K'_\perp = \frac{1}{25}\begin{pmatrix}
16 & -12 & -16 & 12 \\
-12 & 9 & 12 & -9 \\
-16 & 12 & 16 & -12 \\
12 & -9 & -12 & 9
\end{pmatrix},
$$

$$
\mathbf K' + \mathbf K'_\perp = \begin{pmatrix}
1 & 0 & -1 & 0 \\
0 & 1 & 0 & -1 \\
-1 & 0 & 1 & 0 \\
0 & -1 & 0 & 1
\end{pmatrix} = \mathbf L^{(c)}\otimes\mathbf I_2 .
$$

The eigenvectors are the two rigid translations (eigenvalue 0 of both matrices), the
normal relative motion $(-\hat{\mathbf n}, \hat{\mathbf n})/\sqrt2$ (2 for $\mathbf K'$, 0 for
$\mathbf K'\_\perp$) and the sliding motion $(-\hat{\mathbf t}, \hat{\mathbf t})/\sqrt2$ (0 for
$\mathbf K'$, 2 for $\mathbf K'\_\perp$). With masses $m$ ($M_n = m/2$), the QEP per motion is:

| Motion | Normal-only damping $\gamma\,\mathbf K'$ | Relative-velocity damping $\gamma(\mathbf K' + \mathbf K'\_\perp)$ |
|---|---|---|
| Normal | $\lambda^2 + (\gamma/M_n)\lambda + k_n/M_n = 0$ | the same |
| Sliding | $\lambda^2 = 0$: slides freely, undamped | $\lambda^2 + (\gamma/M_n)\lambda = 0$: $\lambda = 0$ or $-\gamma/M_n$ |

Relative-velocity damping stops a free slide at the rate $\gamma/M_n$, with no restoring
force: the sliding velocity decays and the displacement stays. With $m = k_n = 1$ and
$\gamma = 0.3$ the computed eigenvalues are $-0.3 \pm 1.382i$ (normal, both forms) and
$-0.6$ (sliding, relative velocity only), as the table says. For one contact $\mathbf K'$
and $\mathbf K'\_\perp$ commute, because $\hat{\mathbf n}\hat{\mathbf n}^\top$ and $\mathbf I_2 - \hat{\mathbf n}\hat{\mathbf n}^\top$ do; with many contacts at different angles they do not.

#### Normal-only damping is exact

Normal-only damping has $\boldsymbol\Gamma' = \mathbf K'$ exactly, with the same contact
weights. Mass-weighted (equal masses) it is $\boldsymbol\Gamma = b\,\mathbf K_0$ with $b = \gamma_n/k_n$, so the two matrices share one eigenbasis, each $|v_\ell\rangle$ is an exact
eigenvector of the damped problem for any $b$, and

$$
\lambda_\ell^2 + b\,\omega_\ell^2\,\lambda_\ell + \omega_\ell^2 = 0,
\qquad
\beta_\ell = \frac{b\,\omega_\ell^2}{2}\quad\text{(every underdamped mode)} .
$$

This is `ContactDamping` and `ViscousRate` without friction.

#### Relative-velocity damping, to first order

With $\boldsymbol\Gamma = b\,(\mathbf K_0 + \mathbf K_\perp)$, Derivation 5 gives

$$
\beta_\ell \approx \frac{b}{2}\left[\omega_\ell^2 + \langle v_\ell|\mathbf K_\perp|v_\ell\rangle\right].
$$

- $\langle v_\ell|\mathbf K_\perp|v_\ell\rangle = k_n\sum_c\lvert(\mathbf I_D - \hat{\mathbf n}\_c\hat{\mathbf n}\_c^\top)(\mathbf q_j - \mathbf q_i)\rvert^2$, with $\mathbf q = \mathbf M^{-1/2}|v_\ell\rangle$ the
  mode's displacements, measures the mode's sliding at its contacts. Everything beyond
  the proportional rate comes from it.
- For a mode whose contacts mostly slide, $\langle v_\ell|\mathbf K_\perp|v_\ell\rangle$ stays
  finite as $\omega_\ell \to 0$, so $\zeta_\ell$ grows like $1/\omega_\ell$. Once overdamped, the
  mode creeps, with a slow root near $\omega_\ell^2/\langle v_\ell|\boldsymbol\Gamma|v_\ell\rangle$
  (the drag result of Derivation 4 with $a$ replaced by the mode's own damping, mixing
  ignored).
- A long-wavelength plane wave has relative displacements proportional to its wave
  number, so $\omega_\ell^2$ and $\langle v_\ell|\mathbf K_\perp|v_\ell\rangle$ both scale as the
  wave number squared and $\beta_\ell$ still goes as $\omega_\ell^2$. In a triangular lattice
  with nearest-neighbor springs (24 × 24 sites, computed), $\langle v_\ell|\mathbf K_\perp|v_\ell\rangle/\omega_\ell^2 = 1/3$ for longitudinal and 3 for transverse waves, so
  $\beta_\ell \approx \tfrac{2}{3}b\,\omega_\ell^2$ and $2b\,\omega_\ell^2$.
- With friction, relative-velocity damping has no rotational entries, while
  $\mathbf K_0$ does (through $R_i$ in $\mathbf g_c$), so it is never proportional either.

**SoftPack note** (our derivation, the same algebra as the proportional case).

#### Numerical check of the frictionless results

**SoftPack note.** Setup: 64 bidisperse disks (32 of diameter 1, 32 of diameter 1.4),
Hookean contacts with $k = 1$, equal masses $m = 1$, a periodic square box at packing
fraction 0.88, energy minimized with FIRE to a largest net force below $10^{-13}$. No
particle has fewer than 3 contacts; there are 149 contacts, $z = 4.66$, $P/k = 0.025$. A second packing of 128 disks at packing fraction 0.845 (126 after removing
rattlers, 265 contacts, $z = 4.21$, $P/k = 1.9\times10^{-3}$) checks the trends nearer
jamming. Matrices were built as above and the QEP solved in linearized form (Python,
NumPy).

| Quantity | 64 disks | 126 disks |
|---|---|---|
| $\lVert[\mathbf K', \boldsymbol\Gamma']\rVert/\lVert\mathbf K'\boldsymbol\Gamma'\rVert$, normal-only | 0 (exact) | 0 (exact) |
| the same, relative velocity | 0.151 | 0.168 |
| normal-only at $\zeta = 0.98$: QEP vs per-mode roots (relative) | $2.6\times10^{-14}$ | $6.0\times10^{-14}$ |
| lowest mode $\omega_\ell/\omega_c$ | 0.157 | 0.046 |
| $\langle v_\ell\vert\mathbf K'\_\perp\vert v_\ell\rangle/\omega_\ell^2$, six lowest modes | 13 to 28 | 78 to 345 |
| the same, three highest modes | 0.27 to 0.34 | 0.29 to 0.41 |
| first-order $\beta_\ell$ vs QEP at $\zeta = 0.001$ ($b = 1.4\times10^{-3}\,\tau$): median, max relative error | $1.2\times10^{-5}$, $1.0\times10^{-3}$ | $1.7\times10^{-5}$, $8.1\times10^{-3}$ |
| the same at $\zeta = 0.01$ | $1.2\times10^{-3}$, 0.14 | $1.7\times10^{-3}$, 0.10 |

- The sliding share falls steadily with frequency: averaged over frequency quartiles of
  the 64-disk packing, $\langle v_\ell|\mathbf K'\_\perp|v_\ell\rangle/\omega_\ell^2 = 8.8$, 1.9, 0.92
  and 0.45 from lowest to highest.
- The first-order error falls in proportion to the damping, as it should; the largest
  errors are at near-degenerate mode pairs.
- At finite damping, in the 126-disk packing, the slowest decay rate is:

| Coefficient $\gamma$ ($b = \gamma/k$) | Normal-only | Relative velocity | Overdamped roots (relative velocity) |
|---|---|---|---|
| 0.05 | $1.07\times10^{-4}/\tau$ | $2.63\times10^{-2}/\tau$ | 0 |
| 0.25 (rate 0.5, the option defaults) | $5.37\times10^{-4}/\tau$ | $1.01\times10^{-2}/\tau$ | 30 |
| 1.00 | $2.15\times10^{-3}/\tau$ | $2.48\times10^{-3}/\tau$ | 362 |
| 1.386 ($\zeta = 0.98$ normal coefficient) | $2.98\times10^{-3}/\tau$ | $1.79\times10^{-3}/\tau$ | 438 |

  At the options' rate 0.5 the creeping sliding modes still decay about 19 times faster
  than the slowest ringing mode under normal-only damping. At near-critical
  coefficients the order reverses, because a creeping mode slows as its damping grows
  (rate $\approx\omega_\ell^2/\langle v_\ell|\boldsymbol\Gamma|v_\ell\rangle$), while a ringing mode
  speeds up ($b\,\omega_\ell^2/2$).

### 8. Spin and rolling

Which motions each form dissipates follows from which velocities it sees:
`ContactDamping` sees the contact-point speeds $v_n$ and $v_t$, `RelativeVelocityDamping`
the center difference $\mathbf v_i - \mathbf v_j$, and `StokesDrag` absolute velocities. For
two equal disks ($R = 0.5$, $\hat{\mathbf n} = \hat{\mathbf x}$), the dissipation rate of each
form was computed for each motion (friction on for `ContactDamping`):

| Motion | $v_n$ | $v_t$ | $\mathbf v_i - \mathbf v_j$ | `ContactDamping` | `RelativeVelocityDamping` | `StokesDrag` velocity | `StokesDrag` spin |
|---|---|---|---|---|---|---|---|
| $i$ spins in place | 0 | $-R_i\dot\theta_i$ | 0 | damped | not damped | not damped | damped |
| $j$ rolls on a still $i$ without slipping ($\mathbf v_j = R_j\dot\theta_j\hat{\mathbf t}$) | 0 | 0 | $\ne 0$ | not damped | damped | damped | damped |
| The pair rotates as one rigid body | 0 | 0 | $\ne 0$ | not damped | damped | damped | damped |
| $j$ slides along $\hat{\mathbf t}$ without spinning | 0 | $\ne 0$ | $\ne 0$ | damped | damped | damped | not damped |
| Both translate together | 0 | 0 | 0 | not damped | not damped | damped | not damped |
| Approach along $\hat{\mathbf n}$ | $\ne 0$ | 0 | $\ne 0$ | damped | damped | damped | not damped |

- `ContactDamping` damps spin in place (through the slip it makes) but not pure rolling;
  `RelativeVelocityDamping` does the reverse. Neither contact form damps uniform drift.
- A rigid rotation of a touching pair dissipates nothing under `ContactDamping`
  ($v_n = v_t = 0$), as it should for a frame-independent dashpot;
  `RelativeVelocityDamping` damps it because the centers move relative to each other.
- Why spin drag exists: when the motion left in a frictional run is rolling, no contact
  dashpot sees it, and the `StokesDrag(velocity = 0, spin = rate)` option removes it
  without adding drag on translation.

**SoftPack note** (our analysis; the table was computed).

### 9. Clipping and the Coulomb limit

The switches act on one direction each, which is one reason SoftPack splits the
contact dashpot into normal and tangential parts:

$$
F_n = \max\left(0,\; k_n\delta - \gamma_n v_n\right),
\qquad
\left\lvert F_t^\text{el}\right\rvert \le \mu\,F_n^\text{el},
\qquad
\gamma_t \to 0\ \text{while sliding}.
$$

- `attractive = false` clips only the normal force. With `attractive = true`, $F_n = k_n\delta - \gamma_n v_n$ may be negative while the particles separate.
- `coulomb_limit = :elastic` (default): a stuck contact ($\lvert F_t^\text{el}\rvert < \mu F_n^\text{el}$) carries $F_t = F_t^\text{el} - \gamma_tv_t$. A sliding contact carries
  $\lvert F_t\rvert = \lvert F_t^\text{el}\rvert = \mu F_n^\text{el}$, with the dashpot off.
- `coulomb_limit = :total`: the total forces are limited, $\lvert F_t^\text{el} - \gamma_t v_t\rvert \le \mu F_n$, with $F_n$ the total normal force. An approaching contact
  ($v_n < 0$) gets a higher friction limit, a separating one a lower limit, down to zero
  when $F_n$ is clipped.
- At rest every dashpot term is zero, so both rules leave $\lvert F_t^\text{el}\rvert \le \mu F_n^\text{el}$ in the finished packing. They differ along the way, and frictional
  packings depend on the path ([§7](07-algorithms-and-combinations.md)).
- Under `:elastic`, while a stuck contact is loaded toward its limit, the spring force
  and the dashpot force point the same way, so the total tangential force can briefly
  exceed $\mu F_n^\text{el}$ before the contact slips. Only the sliding force is held at
  the limit.

### 10. Time step with damping

**The update rule.** Take one damped oscillator, $\ddot x = -\omega^2x - 2\zeta\omega\dot x$, and the explicit rule in which the dashpot uses the velocity from half a step
before the positions:

$$
v_{n+1/2} = v_{n-1/2} + \Delta t\left(-\omega^2x_n - 2\zeta\omega\,v_{n-1/2}\right),
\qquad
x_{n+1} = x_n + \Delta t\,v_{n+1/2} .
$$

The same rule arises from velocity Verlet run as LAMMPS runs it (forces at $x_{n+1}$
computed with $v_{n+1/2}$; [LAMMPSreadrestart] on granular pair styles: "the forces they
compute depend on atom velocities, which are used at half-step values every timestep
when forces are computed"), from leapfrog, and from semi-implicit Euler with the
dashpot evaluated before the kick (FIRE's integrator, [§14](14-fire-settings.md)).

**Stability.** Eliminate $v$: $x_{n+1} - x_n = (x_n - x_{n-1})(1 - 2\zeta\eta) - \eta^2x_n$
with $\eta = \omega\Delta t$. With $x_n \propto \rho^n$,

$$
p(\rho) = \rho^2 + \left(\eta^2 + 2\zeta\eta - 2\right)\rho + \left(1 - 2\zeta\eta\right) = 0 .
$$

Both roots lie inside the unit circle if and only if $\lvert p(0)\rvert < 1$, $p(1) > 0$ and
$p(-1) > 0$ (the Jury conditions for a quadratic).

- $p(1) = \eta^2 > 0$ always.
- $\lvert 1 - 2\zeta\eta\rvert < 1$ needs $\eta < 1/\zeta$.
- $p(-1) = 4 - 4\zeta\eta - \eta^2 > 0$ needs $\eta < 2\left(\sqrt{1+\zeta^2} - \zeta\right)$.

Since $2(\sqrt{1+\zeta^2} - \zeta) = 2/(\sqrt{1+\zeta^2} + \zeta) < 1/\zeta$, the last condition
binds:

$$
\omega\,\Delta t \le 2\left(\sqrt{1+\zeta^2} - \zeta\right).
$$

At the limit $\rho = -1$: the instability flips sign every step. The bound depends on the
rule. Iterating each rule's amplification matrix and searching for the largest stable
$\omega\Delta t$ gives:

| $\zeta$ | Formula | Dashpot on the lagged half-step velocity (above) | Velocity Verlet, dashpot on the full-step velocity (implicit) | Semi-implicit Euler, dashpot on the new velocity (implicit) | Central difference, centered velocity |
|---|---|---|---|---|---|
| 0 | 2 | 2 | 2 | 2 | 2 |
| 0.5 | 1.236 | 1.236 | 2 | 3.236 | 2 |
| 0.98 | 0.840 | 0.840 | 2 | 4.760 | 2 |
| 1.96 | 0.481 | 0.481 | 2 | 8.321 | 2 |

So the doc's bound holds for the lagged-velocity family (velocity Verlet as in LAMMPS,
leapfrog, explicit semi-implicit Euler). A rule that treats the dashpot implicitly is
not limited by damping at all, or gains stability from it (the implicit semi-implicit
Euler limit is $2(\sqrt{1+\zeta^2} + \zeta)$ instead). The design doc does not name
`DampedDynamics`'s integrator; its restart rule stores "the integrator's half-step
state" ([§6](06-packing-that-does-not-converge.md)), which fits the lagged family.
**SoftPack note** (our derivation and check).

**One contact.** With $t_\text{col} = \pi/\omega_c$ ([§12](12-time-step.md)) and $\zeta = 0.98$,
$\omega_c\Delta t \le 0.8403$, so $\Delta t \le 0.8403\,t_\text{col}/\pi = 0.2675\,t_\text{col}$,
13.4 times the default step $t_\text{col}/50$.

**A packing.** With $\boldsymbol\Gamma = b\,\mathbf K_0$ each mode is its own oscillator with
$\zeta_\ell = \zeta\omega_\ell/\omega_c$ (Derivation 4), so each needs $\omega_\ell\Delta t \le 2(\sqrt{1+\zeta_\ell^2} - \zeta_\ell)$. The left side grows and the right side shrinks with
$\omega_\ell$, so the fastest mode sets the step. How fast can it be? For equal masses and
Hookean contacts, mass-weighted,

$$
\langle u|\mathbf K_0|u\rangle = \sum_c \frac{k_n}{m}\left[\hat{\mathbf n}\cdot(\mathbf u_j - \mathbf u_i)\right]^2
\le \frac{2k_n}{m}\sum_c\left(\lvert\mathbf u_i\rvert^2 + \lvert\mathbf u_j\rvert^2\right)
= \omega_c^2\sum_i z_i\lvert\mathbf u_i\rvert^2 \le z_\text{max}\,\omega_c^2\,\langle u|u\rangle,
$$

so $\omega_\text{max} \le \sqrt{z_\text{max}}\,\omega_c$, with $z_\text{max}$ the largest number of
contacts on one particle. The same bound holds with friction at matched stiffness: each
contact adds $\omega_c^2[(\hat{\mathbf h}\cdot\mathbf u)^2 + (\hat{\mathbf g}\cdot\mathbf u)^2]$ with
orthogonal unit vectors $\hat{\mathbf h}$, $\hat{\mathbf g}$ supported on the two particles.
The design doc's estimate puts the mean contact number in place of $z_\text{max}$:

| Case | $\omega_\text{max}/\omega_c$ | $\zeta$ of the fastest mode | Stable $\Delta t$ | Margin over $t_\text{col}/50$ |
|---|---|---|---|---|
| One contact | 1 | 0.98 | $0.2675\,t_\text{col}$ | 13.4 |
| Design-doc estimate, 2D, $z = 4$ | 2 | 1.96 | $0.0765\,t_\text{col}$ | 3.8 |
| Design-doc estimate, 3D, $z = 6$ | 2.449 | 2.40 | $0.0520\,t_\text{col}$ | 2.6 |
| Bound with $z_\text{max} = 6$ (2D test packings) | 2.449 | 2.40 | $0.0520\,t_\text{col}$ | 2.6 |
| Bound with $z_\text{max} = 12$ (3D test packing) | 3.464 | 3.39 | $0.0265\,t_\text{col}$ | 1.3 |
| Measured, 64 disks, frictionless | 1.667 | 1.63 | $0.108\,t_\text{col}$ | 5.4 |
| Measured, 64 disks, friction, rotations | 1.852 | 1.82 | $0.088\,t_\text{col}$ | 4.4 |
| Measured, 127 spheres ($z = 7.6$), frictionless | 1.844 | 1.81 | $0.089\,t_\text{col}$ | 4.5 |
| Measured, 127 spheres, friction ($k_t = \tfrac27k_n$), rotations | 2.102 | 2.06 | $0.070\,t_\text{col}$ | 3.5 |

- For the measured 2D networks the stable step was also found by iterating the full
  linear update of the damped network; it matches the per-mode formula at
  $\omega_\text{max}$ to four digits.
- The doc's 0.08 and 0.05 $t_\text{col}$ are estimates, not bounds: the strict bound uses
  $z_\text{max}$. The measured packings are more stable than the estimates.
- The 3D packing is 128 bidisperse spheres (diameters 1 and 1.4) at packing fraction
  0.68, made like the 2D ones, with 127 left after removing particles with fewer than 4
  contacts. **SoftPack note** for every row except the doc's two estimates.

## Defaults and their reasons

All damping defaults together (design doc):

```julia
DampedDynamics(
    damping = ContactDamping(
        normal          = 0.98,            # fraction of critical damping
        tangential      = 0.98,            # fraction of critical damping
        tangential_mass = :with_rotation,  # critical value includes particle rotation
        attractive      = false,           # dashpot never makes a contact pull
        coulomb_limit   = :elastic,        # friction limit on spring forces only
    ),
    drag = nothing,                        # no Stokes drag
)
FIRE(damping = nothing, drag = nothing)    # FIRE's own velocity rules remove energy
```

### Normal ratio 0.98

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(normal = 0.98)))
```

**Decision.** Each contact's normal dashpot is 0.98 of its critical value, $\gamma_n = 0.98\times2\sqrt{k_nM_n}$.

- A ratio, not a raw coefficient, so it means the same for Hooke and Hertz contacts:
  [Gilabert2007] "We choose its value as a constant fraction ζ of the critical damping
  coefficient" ... "This is equivalent to the choice of a constant restitution
  coefficient in normal collisions if F₀ = 0." ($F_0$ is their maximum cohesive force,
  zero for SoftPack's particles.) Derivation 1 shows why: $e$ depends only on $\zeta$.
- [Agnolin2007] use the same form, their Eq. (5), $\alpha(h) = \zeta\sqrt{2mK_N(h)}$, with $h$
  the normal deflection and $K_N(h)$ the contact stiffness. For equal masses $M_n = m/2$,
  so $2\sqrt{K_NM_n} = \sqrt{2mK_N}$: the same critical value. For Hertz contacts $K_N \propto h^{1/2}$, so the coefficient grows as $h^{1/4}$.
- The value: [Agnolin2007] "we generally use a strong dissipation, ζ = 0.98, to
  approach equilibrium faster", and "the initial motivation for choosing ζ < 1 is the
  computational inefficiency of overdamped contacts with ζ > 1 in the case of linear
  contact elasticity."
- The packing does not depend much on the exact value: [Agnolin2007] "changes of ζ in
  the range between 0.7 and 1 have virtually no detectable effect", and "a value of the
  damping parameter ten times as small as the standard one ζ = 0.98 results in quite
  similar configuration properties". ("The standard one" is their own choice.)
- Restitution. The design doc converts $\zeta = 0.98$ to $e = \exp(-\pi\zeta/\sqrt{1-\zeta^2}) \approx 2\times10^{-7}$ for Hooke contacts. That is the restitution of a dashpot allowed
  to pull. With the default `attractive = false` the collision ends when the force
  reaches zero, and $e = 0.139$ (Derivation 1, [Schwager2007]): a loose particle keeps
  14% of its approach speed and loses 98% of its kinetic energy in one collision.
  **SoftPack note.**
- The speed argument is about one contact. Collective modes stay underdamped,
  $\zeta_\ell = 0.98\,\omega_\ell/\omega_c$, so a larger $\zeta$ speeds up their decay only in
  proportion (Derivation 4).

### Tangential ratio 0.98

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(tangential = 0.98)))
```

**Decision.** Tangential dashpot on, with the same ratio as the normal one. It applies
only with friction.

- The physics reason: with `stiffness_ratio = :matched` ([§13](13-friction-models.md))
  and `tangential_mass = :with_rotation`, one ratio gives one $b = 2\zeta/\omega_c$ in both
  directions, so $\boldsymbol\Gamma = b\,\mathbf K_0$ and every underdamped mode decays at
  exactly $b\,\omega_\ell^2/2$ (Derivations 4 and 6). One raw coefficient for both
  directions would instead give $\zeta_t = 3\zeta_n$ for disks (Derivation 3), overdamped
  sliding, and modes that mix. Exact for Hookean contacts and equal masses.
  **SoftPack note** (our derivation).
- Without a tangential dashpot, a stuck contact's back-and-forth sliding loses energy
  only when it slips. The Leiden protocol damps both directions: [Somfai2005] "which is
  at every instant a given constant fraction of the linear critical viscous damping,
  both for the normal and for the tangential force". [Silbert2001], whose baseline has
  no tangential damping, report for their flow simulations: "Making γt/γn non-zero
  quickens the approach to the steady state by draining out more energy."
- [Santos2024] also damp both directions, with equal raw values: "The normal (n) and
  tangential (s) particle spring (k) and damping (γ) parameters are set equal to each
  other". Their $\gamma$ is a LAMMPS rate (our $r$), multiplied by the pair mass in both
  directions [LAMMPSgran]. That is `ViscousRate` with $k_t = k_n$, not an equal ratio:
  for their frictional spheres it makes the tangential ratio $\sqrt{3.5} \approx 1.9$ times
  the normal one (Derivation 3). It supports damping both directions at a similar
  strength, not the equal ratio itself.
- Frictionless contacts have no tangential spring, so there is no tangential critical
  value. A tangential dashpot without friction is `RelativeVelocityDamping`
  ([Options](#relativevelocitydamping)).

### Tangential critical value on the sliding mass

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(tangential_mass = :with_rotation)))
```

**Decision.** The tangential critical value is $2\sqrt{k_tM_t}$, with $1/M_t = 1/m_i + 1/m_j + R_i^2/I_i + R_j^2/I_j$ (Derivation 2).

- A tangential force at the contact both pushes and spins the two particles, so the slip
  responds like the lighter mass $M_t$: $m/6$ for equal disks, $m/7$ for equal spheres.
- One $\zeta$ is then one physical damping ratio in each direction. On the pair mass, 0.98
  would really be $0.98\sqrt3 = 1.70$ for disks and $0.98\sqrt{3.5} = 1.83$ for spheres,
  overdamped and slow (Derivation 3). With matched stiffness, $\gamma_t/\gamma_n = 1/3$
  for disks: both directions decay equally fast with a tangential coefficient a third of
  the normal one. **SoftPack choice**, from the rigid-body mechanics of two particles.
- For `Mindlin` contacts the critical value uses the contact's current tangential
  stiffness, as the normal one does for Hertz.

### Dashpots never pull

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(attractive = false)))
```

**Decision.** $F_n = \max(0, F_n^\text{el} - \gamma_nv_n)$ (Derivation 9).

- When two touching particles separate, the normal dashpot can outweigh the spring.
  [Somfai2005] "We impose that the total radial force, which now also contains the
  viscous contribution, never becomes attractive." LAMMPS offers the same switch:
  [LAMMPSgran] "If two particles are moving away from each other while in contact, there
  is a possibility that the particles could experience an effective attractive force
  due to damping. If the limit_damping keyword is used, this option will zero out the
  normal component of the force if there is an effective attractive force."
- Default `false` because SoftPack's particles are cohesionless: a pulling contact is
  an artifact of the dashpot, not physics.
- The clip changes the restitution coefficient (Derivation 1): 0.139 instead of
  $2\times10^{-7}$ at $\zeta = 0.98$. **SoftPack note.**

### Friction limit on spring forces

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(coulomb_limit = :elastic)))
```

**Decision.** $\lvert F_t^\text{el}\rvert \le \mu F_n^\text{el}$; a sliding contact carries
exactly $\mu F_n^\text{el}$, with its tangential dashpot off ($\mu$: the friction
coefficient, [§13](13-friction-models.md)).

- Following [Agnolin2007] "We do not introduce any tangential viscous force, and impose
  the Coulomb inequality to elastic force components only." At rest every dashpot force
  is zero, so the finished packing's forces are purely elastic and satisfy the Coulomb
  limit exactly.
- Switching the dashpot off while sliding is a **SoftPack choice** (Agnolin and Roux
  have no tangential dashpot to switch): slip already removes energy, and it keeps the
  sliding force at the Coulomb limit. A stuck contact being loaded can carry a little
  more than $\mu F_n^\text{el}$ in total for a moment (Derivation 9).

### No Stokes drag

```julia
pack(algorithm = DampedDynamics(drag = nothing))
```

**Decision.** No Stokes drag. **SoftPack choice.**

- Energy leaves only through contacts. Contact damping acts on relative motion only, so
  it does not slow a uniform drift of the whole packing, adds no extra time scale, and
  does not make the low-frequency modes creep (Derivation 4).
- The cost is slower settling of particles with few contacts and of pure rolling
  (Derivation 8). That is why drag exists as an option: [Shimada2026] add it because
  "Without these single-particle dissipative interactions, dissipation occurs only when
  particles are in contact with each other. As a result, particles with fewer contacts
  dissipate energy more slowly, hindering the system from converging to an inherent
  structure within a reasonable timescale."

### FIRE: no damping

```julia
pack(algorithm = FIRE(damping = nothing, drag = nothing))
```

**Decision.** FIRE runs without contact damping or drag. **SoftPack choice**; both
settings take the same values as for `DampedDynamics`.

- FIRE removes energy by steering the velocities toward the force and zeroing them when
  the motion turns uphill: [Guenole2020] "the velocities are reset to zero at the
  beginning of the pseudo-dynamic run and also periodically during the run in FIRE
  2.0". Damping is not needed for FIRE to stop ([§14](14-fire-settings.md)).

## Options

Every option is a setting of `pack()` and combines with any algorithm, contact law and
friction model ([§7](07-algorithms-and-combinations.md)).

| Option | Setting | Used by |
|---|---|---|
| Any other contact damping ratios | `ContactDamping(normal = ratio, tangential = ratio)` | |
| Moderate contact damping (restitution about 0.5) | `ContactDamping(normal = 0.2, tangential = 0.2)` | $\zeta \approx 0.18$ is the doc's conversion of [Santos2024] |
| Normal damping only | `ContactDamping(normal = 0.98, tangential = 0)` | [Agnolin2007] |
| Tangential ratio on the pair mass | `ContactDamping(tangential_mass = :pair)` | the usual raw-coefficient convention |
| Raw damping rates instead of ratios | `ViscousRate(normal = 0.5, tangential = 0.5)` | [Santos2024], [LAMMPSgran] |
| One rate on the full relative velocity, friction on or off | `RelativeVelocityDamping(rate = 0.5)` | CD model of [Vagberg2014], after Durian's bubble model |
| No contact damping | `damping = nothing` | FIRE default |
| Dashpot allowed to pull | `attractive = true` | LAMMPS without `limit_damping` [LAMMPSgran] |
| Friction limit on total forces | `coulomb_limit = :total` | [LAMMPSgran] |
| Stokes drag, always on | `drag = StokesDrag(velocity = rate)` | [Shimada2026], [Xiong2019] |
| Stokes drag while compressing only | `drag = StokesDrag(velocity = rate, during = :compression)` | Leiden-style, [Somfai2007] |
| Overdamped Stokes drag | `drag = StokesDrag(velocity = rate)` with a rate large compared with the soft-mode frequencies | [Xiong2019] |
| Spin drag only (for rolling) | `drag = StokesDrag(velocity = 0, spin = rate)` | |

For the "moderate" row, $\zeta = 0.2$ gives $e = 0.53$ with a pulling dashpot and $0.57$
with the default `attractive = false` (Derivation 1).

### ViscousRate

```julia
pack(algorithm = DampedDynamics(damping = ViscousRate(normal = 0.5, tangential = 0.5)))
```

**Decision** (the option's own defaults). Dashpot force $-\gamma v$ with $\gamma = m_\text{eff}\,r$ in each direction, $m_\text{eff} = M_n$ (the pair mass, in both directions,
as LAMMPS does), and rates $r_n = r_t = 0.5$ in units of $1/\tau$, $\tau = \sqrt{m/k}$ ($m$
the small-particle mass, $k$ the normal stiffness constant).

- The values are [Santos2024]'s, $r_n = r_s = 0.5/\tau$ (their $\gamma_n$, $\gamma_s$ are
  LAMMPS rates) with $\tau = \sqrt{m/k_n}$, as are the equal values for both directions
  (quote above).
- Conversion for equal masses ($M_n = m/2$): $\zeta_n = \gamma_n/(2\sqrt{k_nM_n}) = \tfrac{r}{2}\sqrt{M_n/k_n} = 0.177$, restitution 0.569 with a pulling dashpot and 0.606
  with the default `attractive = false`. With friction at matched stiffness the
  tangential ratio is $M_nr/(2\sqrt{k_tM_t}) = 0.530$ for disks ($3\zeta_n$) and 0.619 for
  spheres ($3.5\zeta_n$). **SoftPack note.**
- How it differs from `ContactDamping`: with Hertz contacts the fixed coefficient damps
  stiffer (more compressed) contacts less, $\zeta \propto \delta^{-1/4}$; with friction it is
  not stiffness-proportional at matched stiffness ($b_t = M_nr/k_t = 3b_n$ for disks);
  with `Density` masses the coefficient scales as $M_n$ instead of $\sqrt{M_n}$. For
  Hookean, equal-mass, frictionless packings `ViscousRate(normal = r)` equals
  `ContactDamping(normal = r/(2*sqrt(2)))` (with $m = k = 1$). With $k_t = k_n$ and equal rates
  (Santos's setup) it is exactly proportional, $b = M_nr/k$ in both directions. **SoftPack
  note.**
- It takes the same `attractive` and `coulomb_limit` keywords with the same defaults.

### RelativeVelocityDamping

```julia
pack(algorithm = DampedDynamics(damping = RelativeVelocityDamping(rate = 0.5)))
```

**Decision** (the option's own defaults). One dashpot on the full relative velocity of
the two centers,

$$
\mathbf F_{ij} = -\gamma\,(\mathbf v_i - \mathbf v_j), \qquad \gamma = m_\text{eff}\,r,
$$

with $\mathbf F_{ij}$ the force on $i$ from $j$ and rate $r = 0.5$ in units of $1/\tau$.

- Since $\hat{\mathbf n}\hat{\mathbf n}^\top + \hat{\mathbf t}\hat{\mathbf t}^\top = \mathbf I_2$, this
  is a normal plus a tangential dashpot with one coefficient, acting on the centers'
  velocities only: no spin, no torque (Derivation 8 table).
- Without friction, `ContactDamping` and `ViscousRate` are normal-only. The two forms are
  the CD and CD<sub>n</sub> models of [Vagberg2014]: "CD<sub>n</sub> is typically used in models of
  massive dry granular particles [15]. CD was introduced by Durian [12] to describe the
  viscous interaction between massless foam bubbles." The choice changes the result:
  [Vagberg2014] "the rheology of soft-core frictionless disks is strongly dependent on
  the specific form of the dissipative interaction" (shear flow below jamming, not
  packing preparation). Use this option to prepare packings with the same damping law
  as a later simulation that damps the full relative velocity.
- Not the default. It is never proportional to the stiffness, so modes mix, and sliding
  low-frequency modes creep (Derivation 7). Slow motion near jamming is mostly sliding:
  [Vagberg2014] find that "the relative motion of particles in contact is almost always
  tangential" (shear flow below jamming). Without friction its tangential half damps a
  direction with no spring, so there is no critical value and a ratio such as 0.98 has
  no meaning; that is why it takes a raw rate. **SoftPack choice.**
- `rate = 0.5` is the `ViscousRate` default [Santos2024], so on frictionless particles
  swapping `ViscousRate(normal = 0.5)` for this option only adds the tangential half.
  **SoftPack choice.** In the 126-disk test packing that tangential half makes the
  slowest motion decay about 19 times faster (Derivation 7).
- It takes the same `attractive` and `coulomb_limit` keywords with the same defaults,
  applied to the normal and tangential parts of its force.

### Friction limit on total forces

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(coulomb_limit = :total)))
```

**Option.** The total tangential force is capped at $\mu$ times the total normal force,
$\lvert F_t\rvert \le \mu F_n$, as in LAMMPS: [LAMMPSgran] "the Coulomb criterion Ft =
xmu*Fn, where Ft and Fn are the total tangential and normal force components in the
formulas above." Effects on the path are in Derivation 9.

### Tangential damping off

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(tangential = 0)))
```

**Option.** Normal dashpot only, LAMMPS's `dampflag` switch: [LAMMPSgran] "dampflag = 0
or 1 if tangential damping force is excluded or included". With friction, $b_t = 0$, so
by Derivation 6 each mode decays at about $\tfrac b2(\omega_\ell^2 - \langle v_\ell|\mathbf K_t|v_\ell\rangle)$ to first order: modes that load mostly the tangential springs are
barely damped. This is [Agnolin2007]'s setting ("We do not introduce any tangential
viscous force").

### StokesDrag

```julia
pack(algorithm = DampedDynamics(drag = StokesDrag(velocity = rate, spin = rate, during = :always)))  # rate: required, no default
```

**Decision** (the option's own defaults). Force $\mathbf F = -a_v\,m\,\mathbf v$ and torque
$\mathbf T = -a_s\,I\,\boldsymbol\omega$, with rates $a_v$ (`velocity`) and $a_s$ (`spin`) in
units of $1/\tau$: the mass-proportional term $a\mathbf M$ of Rayleigh damping
(Derivation 4).

- `velocity` has **no default** and must be given. [Shimada2026] and [Xiong2019] do not
  state numerical values in their texts, and the right size depends on the packing's
  soft-mode frequencies, which change with pressure and system size. [Xiong2019] chose
  theirs "so that the dynamics for the translational and rotational degrees of freedom
  are in the overdamped limit." [Shimada2026] use separate rates for velocity and spin,
  "which are added to accelerate the convergence to inherent structures."
- `spin = velocity`: **SoftPack choice**, so translation and rotation of a free particle
  decay at the same rate, and the drag is exactly $a\mathbf M$. Set it separately as
  [Shimada2026] do.
- `during = :always`: drag on for the whole run, as in [Shimada2026] and [Xiong2019].
- `during = :compression`: drag on until the pressure is within `pressure_tolerance` of
  the target, then off, and the packing settles under contact damping alone. The Leiden
  packings are made with drag that is later removed: [Somfai2007] "The packings are
  constructed by cooling while slowly inflating the particle radii in the presence of a
  linear damping force", and "Once a packing is made, the additional damping force is
  switched off". Where to switch it off during preparation is a **SoftPack choice**; the
  paper does not give one.
- Choosing a rate: modes with $\omega_\ell < a/2$ are overdamped and relax at about
  $\omega_\ell^2/a$ (Derivation 4). A rate far above the lowest mode frequencies therefore
  slows those modes down; this is the drag-side counterpart of the slow ringing under
  contact damping. In the 64-disk test packing with $a = 2/\tau$, 34 of 126 modes are
  overdamped and the six slowest relax at $1.01$ to $1.04$ times $\omega_\ell^2/a$.
  **SoftPack note.**

### Spin drag only

```julia
pack(algorithm = DampedDynamics(drag = StokesDrag(velocity = 0, spin = rate)))
```

**Option.** Contact dashpots do not damp pure rolling (one particle rolling over another
has no sliding speed at the contact; Derivation 8), so runs with friction that stall on
rolling motion can add a small spin drag. **SoftPack note.**

## Worked numbers

Units: $m = k = 1$, equal disks, Hookean contacts, so $\tau = 1$, $M_n = 1/2$, $M_t = 1/6$,
and with matched friction $k_t = 1/3$. All values computed (Python).

| Quantity | Value |
|---|---|
| Contact frequency $\omega_c = \sqrt{k_n/M_n}$ | $1.414/\tau$ |
| Collision time $t_\text{col} = \pi/\omega_c$; default step $t_\text{col}/50$ | $2.221\,\tau$; $0.0444\,\tau$ |
| $\gamma_n$ at $\zeta = 0.98$ | $1.386\sqrt{km}$ |
| $\gamma_t$ at $\zeta = 0.98$ (matched, `:with_rotation`) | $0.462\sqrt{km}$ ($\gamma_t/\gamma_n = 1/3$) |
| $b = \gamma_n/k_n = \gamma_t/k_t = 2\zeta/\omega_c$ | $1.386\,\tau$ |
| Modes overdamped under the defaults | $\omega_\ell > 1.02\,\omega_c$: 66 of 126 (64 disks), 119 of 250 (126 disks) |
| Restitution at $\zeta = 0.98$: pulling dashpot / default clip | $1.9\times10^{-7}$ / 0.139 |
| `ViscousRate` defaults: $\gamma$, $\zeta_n$, $\zeta_t$ (disks, matched) | 0.25, 0.177, 0.530 |
| Ratio measured on the pair mass, 0.98 means | 1.70 (disks), 1.83 (spheres) |
| Slowest mode, 64 disks ($P/k = 0.025$), defaults without friction | $\omega_\ell = 0.157\,\omega_c$, $\zeta_\ell = 0.154$, $\beta_\ell = 0.034/\tau$, $e$-folding in 658 steps |
| Slowest mode, 126 disks ($P/k = 1.9\times10^{-3}$) | $\omega_\ell = 0.046\,\omega_c$, $\zeta_\ell = 0.045$, $\beta_\ell = 3.0\times10^{-3}/\tau$, $e$-folding in 7565 steps; a factor $10^{-8}$ in $1.4\times10^5$ steps |
| Stable step at $\zeta = 0.98$: one contact / doc estimate 2D / doc estimate 3D | $0.27$ / $0.077$ / $0.052\,t_\text{col}$ |

The last two "slowest mode" rows show why the stopping rule is reached last by the
lowest modes: near jamming they ring for thousands of steps even at near-critical
contact damping. **SoftPack note.**

## Open questions

- The time-step margins are, in the design doc's words, "estimates, to be checked once
  `DampedDynamics` runs". The design doc does not name `DampedDynamics`'s integrator; the
  stability bound holds for the lagged-velocity family (Derivation 10).
- `StokesDrag(velocity)` has no default; no source gives a value.
- Where `during = :compression` switches the drag off is a SoftPack choice with no
  source.
- How large the departures from exact proportionality are in practice (Hertz, Mindlin,
  `Density` masses, stressed Hessian) has been estimated only on small test packings
  (Derivation 6); it has not been measured in production runs.

## Related pages

- [§4 Mass](04-mass.md): `EqualMass` and `Density`, which decide whether $b$ is the same
  at every contact.
- [§5 Convergence criterion](05-convergence-criterion.md): the force test that the slowest
  modes must pass.
- [§6 A packing that does not converge](06-packing-that-does-not-converge.md): restarts
  store the integrator's half-step state because dashpots depend on velocity.
- [§7 Algorithms and combinations](07-algorithms-and-combinations.md): `DampedDynamics` and
  FIRE; damping as part of the protocol.
- [§12 Time step](12-time-step.md): $t_\text{col}$ and the default step.
- [§13 Friction models](13-friction-models.md): `stiffness_ratio = :matched` and the
  Coulomb coefficient.
- [§14 FIRE settings](14-fire-settings.md): FIRE's integrator and its own energy removal.
- [Notation](notation.md), [References](references.md), [Wiki index](README.md).

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[Gilabert2007]** F. A. Gilabert, J.-N. Roux, A. Castellanos (2007). *Computer simulation of model cohesive powders: Influence of assembling procedure and contact laws on low consolidation states*. Physical Review E **75**, 011303. [doi:10.1103/physreve.75.011303](https://doi.org/10.1103/physreve.75.011303).
- **[Guenole2020]** Julien Guénolé, Wolfram G. Nöhring, Aviral Vaid, Frédéric Houllé, Zhuocheng Xie, Aruna Prakash, Erik Bitzek (2020). *Assessment and optimization of the fast inertial relaxation engine (fire) for energy minimization in atomistic simulations and its implementation in lammps*. Computational Materials Science **175**, 109584. [doi:10.1016/j.commatsci.2020.109584](https://doi.org/10.1016/j.commatsci.2020.109584).
- **[LAMMPSgran]** LAMMPS developers. *LAMMPS documentation: pair_style gran/hooke, gran/hooke/history, gran/hertz/history*. <https://docs.lammps.org/pair_gran.html>. Accessed 2026-11-18.
- **[LAMMPSreadrestart]** LAMMPS developers. *LAMMPS documentation: read_restart command*. <https://docs.lammps.org/read_restart.html>. Accessed 2026-11-19.
- **[Santos2024]** A. P. Santos, Ishan Srivastava, Leonardo E. Silbert, Jeremy B. Lechman, Gary S. Grest (2024). *Protocol-dependent frictional granular jamming simulations: cyclical, compression, and expansion*. Frontiers in Soft Matter **3**, 1326756. [doi:10.3389/frsfm.2023.1326756](https://doi.org/10.3389/frsfm.2023.1326756).
- **[Schwager2007]** Thomas Schwager, Thorsten Pöschel (2007). *Coefficient of restitution and linear–dashpot model revisited*. Granular Matter **9**, 465–469. [doi:10.1007/s10035-007-0065-z](https://doi.org/10.1007/s10035-007-0065-z). arXiv:cond-mat/0701278.
- **[Shimada2026]** Masanari Shimada, Yusuke Hara, Shihori Koyama, Ryohei Seto, Maria Yokota (2026). *Linear stability and viscoelastic response in weakly jammed frictional granular systems*. arXiv:2608.30151. <https://arxiv.org/abs/2608.30151>.
- **[Silbert2001]** Leonardo E. Silbert, Deniz Ertaş, Gary S. Grest, Thomas C. Halsey, Dov Levine, Steven J. Plimpton (2001). *Granular flow down an inclined plane: Bagnold scaling and rheology*. Physical Review E **64**, 051302. [doi:10.1103/physreve.64.051302](https://doi.org/10.1103/physreve.64.051302).
- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
- **[Somfai2007]** Ellák Somfai, Martin van Hecke, Wouter G. Ellenbroek, Kostya Shundyak, Wim van Saarloos (2007). *Critical and noncritical jamming of frictional grains*. Physical Review E **75**, 020301. [doi:10.1103/physreve.75.020301](https://doi.org/10.1103/physreve.75.020301).
- **[Vagberg2014]** Daniel Vågberg, Peter Olsson, S. Teitel (2014). *Dissipation and Rheology of Sheared Soft-Core Frictionless Disks Below Jamming*. Physical Review Letters **112**, 208303. [doi:10.1103/PhysRevLett.112.208303](https://doi.org/10.1103/PhysRevLett.112.208303). arXiv:1311.4902.
- **[Xiong2019]** Fansheng Xiong, Philip Wang, Abram H. Clark, Thibault Bertrand, Nicholas T. Ouellette, Mark D. Shattuck, Corey S. O’Hern (2019). *Comparison of shear and compression jammed packings of frictional disks*. Granular Matter **21**, 109. [doi:10.1007/s10035-019-0964-9](https://doi.org/10.1007/s10035-019-0964-9).
