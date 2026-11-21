# 12. Time step

Design decision source: [design-references.md §12](../design-references.md#12-time-step).
Status: design stage (no engine code yet).

## Summary

`pack()` moves the particles with an explicit integrator, one time step $\Delta t$ at a
time. By default the step is 1/50 of the shortest binary collision time,
$t_\text{col} = \pi\sqrt{m_\text{eff}/k}$, the time two touching particles take to
bounce off each other. It is computed for the lightest pair of particles and the
stiffest contact: normal, or tangential with rotation when friction is on, and for
Hertzian contacts the stiffness at the largest overlap expected. A run-time check warns
if a contact becomes stiffer than the step resolves. A fixed number can be given
instead. `DampedDynamics` keeps the step fixed; `FIRE` starts from it and adapts it
between 0.02 and 10 times this value ([§14](14-fire-settings.md)). The factor 1/50 is an
accuracy rule from the DEM literature. Without damping the integrator would stay
stable with a step about 13 to 16 times longer (31.8 for a single contact);
near-critical contact damping lowers that margin to about 2.6 to 3.8
([§8](08-damping.md)).

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| `timestep` | `CollisionTime(fraction = 1/50)` | any fraction, or a fixed number | [Default](#collisiontime-default), [Options](#options) |
| `FIRE` `timestep_max`, `timestep_min` | 10, 0.02 (times the starting step) | any value | [§14](14-fire-settings.md), [FIRE below](#fire-and-the-time-step) |

## Model

Symbols used on this page:

- Particles $i$ and $j$ have masses $m_i$, $m_j$, radii $R_i$, $R_j$ and moments of
  inertia $I_i$, $I_j$. $m$ is the small-particle mass; $k$ is the `stiffness` of the
  contact law ([§2](02-default-packing.md)); $\tau = \sqrt{m/k}$ is the time unit
  (1 in the default units).
- $M_n$ and $M_t$ are the normal and tangential effective masses of a contact
  ([§8](08-damping.md), [§13](13-friction-models.md)):

$$\frac{1}{M_n} = \frac{1}{m_i} + \frac{1}{m_j}, \qquad \frac{1}{M_t} = \frac{1}{m_i} + \frac{1}{m_j} + \frac{R_i^2}{I_i} + \frac{R_j^2}{I_j}.$$

  The design doc writes $m_\text{eff}$ for $M_n$ in $t_\text{col}$.
- $\delta$ is the overlap of the pair. $k_n$ is the normal contact stiffness, the slope
  of the force law: $k_n = k$ for `Hookean` ($f = k\delta$), and
  $k_n(\delta) = \tfrac32 k\,\delta^{1/2}$ for `Hertzian` ($f = k\delta^{3/2}$).
  $k_t$ is the tangential stiffness ([§13](13-friction-models.md)).
- $\gamma_n$ is a normal dashpot coefficient (force per velocity), $r_n = \gamma_n/M_n$
  the same dashpot as a rate, and $\zeta = \gamma_n/(2\sqrt{k_n M_n})$ its damping
  ratio.
- $\omega_n = \sqrt{k_n/M_n}$ and $\omega_t = \sqrt{k_t/M_t}$ are the normal and
  tangential contact frequencies (angular). $\omega_c$ is the frequency of one contact
  in the default setting ($\omega_c = \omega_n$; with matched friction also
  $\omega_t = \omega_c$).
- $z$ is the contact number (contacts per particle), $z_i$ that of particle $i$.

While two particles touch, the overlap of a Hookean pair obeys a damped oscillator
equation, and the stuck sliding displacement $\xi_t$ obeys another
([§13](13-friction-models.md)):

$$M_n\,\ddot\delta = -k_n\,\delta - \gamma_n\,\dot\delta, \qquad M_t\,\ddot\xi_t = -k_t\,\xi_t - \gamma_t\,\dot\xi_t.$$

The rule is

$$\Delta t = \text{fraction}\times t_\text{col}, \qquad t_\text{col} = \frac{\pi}{\omega_\text{max}}, \qquad \omega_\text{max} = \max\left(\omega_n, \omega_t\right),$$

with $\omega_n$ and $\omega_t$ evaluated for the lightest pair and the stiffest contact.
For frictionless Hookean contacts this is the design doc's
$t_\text{col} = \pi\sqrt{m_\text{eff}/k}$.

## Derivations

### Collision time of a Hookean contact

Two particles meet at relative normal speed $v_0$: $\delta(0) = 0$,
$\dot\delta(0) = v_0$. Dividing the overlap equation by $M_n$ gives
$\ddot\delta + (\gamma_n/M_n)\,\dot\delta + (k_n/M_n)\,\delta = 0$, whose underdamped
solution is

$$\delta(t) = \frac{v_0}{\omega_d}\,e^{-\gamma_n t/(2M_n)}\sin(\omega_d t), \qquad \omega_d = \sqrt{\frac{k_n}{M_n} - \left(\frac{\gamma_n}{2M_n}\right)^2} = \omega_n\sqrt{1 - \zeta^2}.$$

The overlap returns to zero at $t = \pi/\omega_d$, the collision time:

$$t_\text{col} = \frac{\pi}{\sqrt{k_n/M_n - \left(\gamma_n/2M_n\right)^2}} = \frac{\pi}{\sqrt{k_n/M_n - r_n^2/4}}, \qquad t_\text{col}\big|_{\gamma_n = 0} = \pi\sqrt{\frac{M_n}{k_n}}.$$

[Silbert2001] write the normal dashpot as $-\gamma_n m_\text{eff}\mathbf v_n$, so their
$\gamma_n$ is our rate $r_n$; with equal masses $M_n = m/2$ and $k_n/M_n = 2k_n/m$,
which gives the formula the design doc quotes,
$t_\text{col} = \pi\left(2k_n/m - r_n^2/4\right)^{-1/2}$. The velocity at
$t_\text{col}$ is $-v_0\,e^{-\pi\zeta/\sqrt{1-\zeta^2}}$, so the restitution coefficient
is $e = \exp\left(-\pi\zeta/\sqrt{1-\zeta^2}\right)$.

Checked numerically (velocity Verlet with a step $10^{-5}$ of the unit, $k = 1$,
$M_n = 1/2$): for $\zeta$ from 0 to 0.98 the collision times match the formula to a
relative $2\times10^{-4}$ and the restitution coefficients to 0.3%.

| $\zeta$ | $t_\text{col}$ with damping / without | restitution $e$ |
|---|---|---|
| 0 | 1 | 1 |
| 0.1 | 1.005 | 0.729 |
| 0.5 | 1.155 | 0.163 |
| 0.9 | 2.294 | $1.5\times10^{-3}$ |
| 0.98 | 5.025 | $1.9\times10^{-7}$ |

SoftPack's rule uses the undamped time, $\gamma_n = 0$. Two reasons (**SoftPack note**):

- The stability of an explicit integrator is set by the undamped frequency, and
  damping only lowers the stable step ([below](#stability-with-damping)). The damped
  collision time does the opposite: it grows with $\zeta$ (5.0 times longer at the
  default $\zeta = 0.98$) and does not exist for $\zeta \ge 1$. Using it would lengthen
  the step exactly when the stable step shrinks.
- For [Silbert2001]'s own parameters ($k_n = 2\times10^5$, $r_n = 33.5$ and 50, so
  $\zeta = 0.026$ and 0.040) the two forms differ by 0.04% and 0.08% (our
  conversion), so the rule they state is the same rule.

### Collision time of a Hertzian contact

For `Hertzian` contacts the undamped overlap obeys $M_n\ddot\delta = -k\,\delta^{3/2}$.
Energy conservation gives the largest overlap $\delta_\text{max}$ and the speed at
overlap $\delta$:

$$\frac12 M_n v_0^2 = \frac25 k\,\delta_\text{max}^{5/2} \;\Rightarrow\; \delta_\text{max} = \left(\frac{5M_n v_0^2}{4k}\right)^{2/5}, \qquad \dot\delta = v_0\sqrt{1 - (\delta/\delta_\text{max})^{5/2}}.$$

The collision lasts twice the time to reach $\delta_\text{max}$:

$$t_\text{col} = 2\int_0^{\delta_\text{max}}\frac{d\delta}{\dot\delta} = \frac{2\delta_\text{max}}{v_0}\int_0^1\frac{dx}{\sqrt{1 - x^{5/2}}} = \frac{2\delta_\text{max}}{v_0}\,\frac{\sqrt\pi\,\Gamma(7/5)}{\Gamma(9/10)},$$

where the integral (substitute $u = x^{5/2}$, a Beta function) is 1.4716. Inserting
$\delta_\text{max}$:

$$t_\text{col} = 2 \times 1.4716 \times \left(\frac54\right)^{2/5}\left(\frac{M_n}{k}\right)^{2/5} v_0^{-1/5} = 3.218\left(\frac{M_n}{k}\right)^{2/5} v_0^{-1/5}.$$

A Hertzian collision is longer the slower the impact, $t_\text{col} \propto v_0^{-1/5}$.
Checked numerically for $v_0$ from $10^{-4}$ to $10^{-1}$: the fitted exponent is
$-0.2000$ and the constant matches to six digits. [Silbert2001] note the same
dependence for their Hertzian model: "For Model H, the effective coefficients of
restitution depend on the initial velocity of the particles."

In a packing the velocities go to zero, so the impact speed cannot set the step. What
the integrator must resolve are small vibrations about each contact's static overlap
$\delta_0$. Expanding the force, $f(\delta_0 + u) \approx f(\delta_0) + k_n(\delta_0)\,u$,
so the contact vibrates at $\omega_n(\delta_0) = \sqrt{k_n(\delta_0)/M_n}$ with

$$t_\text{col}(\delta_0) = \pi\sqrt{\frac{M_n}{k_n(\delta_0)}} = \pi\sqrt{\frac{2M_n}{3k}}\;\delta_0^{-1/4}.$$

This is shortest at the largest overlap, which is why the design doc takes the
stiffness at the largest overlap expected. The estimate is also safe for real
collisions: for an impact that reaches $\delta_\text{max}$,
$\pi/\omega_n(\delta_\text{max})$ is 0.78 times the true collision time (the ratio
$\pi\sqrt{8/15}/2.943 = 0.7795$ is the same for every speed; checked numerically). In
terms of force, $\delta_0 \propto f^{2/3}$ gives $k_n \propto f^{1/3}$ and
$t_\text{col} \propto f^{-1/6}$: a contact carrying 10 times the mean force needs a
step only $10^{1/6} = 1.47$ times shorter. **SoftPack note.**

### The lightest pair

$t_\text{col}$ grows with $\sqrt{M_n}$, and

$$M_n = \left(\frac{1}{m_i} + \frac{1}{m_j}\right)^{-1} \ge \left(\frac{2}{m_\text{min}}\right)^{-1} = \frac{m_\text{min}}{2},$$

with equality for two particles of the smallest mass $m_\text{min}$. The shortest
collision time is therefore between two of the lightest particles,
$m_\text{eff} = m_\text{min}/2$. A light particle hitting a heavy one has a larger
$M_n$, up to $m_\text{min}$. **SoftPack note.**

### The tangential contact frequency

With friction the stuck sliding motion is a second oscillator, of frequency
$\omega_t = \sqrt{k_t/M_t}$ ([§13](13-friction-models.md) derives $M_t$). For uniform
particles of the same shape, $I = \kappa m R^2$ ($\kappa = 1/2$ for disks, $2/5$ for
spheres), $R^2/I = 1/(\kappa m)$ and so $M_n/M_t = 1 + 1/\kappa = 1 + mR^2/I$ for every
pair. Hence

$$\frac{\omega_t}{\omega_n} = \sqrt{\frac{k_t}{k_n}\left(1 + \frac{mR^2}{I}\right)}.$$

| Friction setting | $k_t/k_n$ | $\omega_t/\omega_n$, disks | $\omega_t/\omega_n$, spheres |
|---|---|---|---|
| `CundallStrack(stiffness_ratio = :matched)` | 1/3 (disks), 2/7 (spheres) | 1 | 1 |
| `Mindlin(poisson_ratio = 0.0)` | 1 | $\sqrt3 = 1.732$ | $\sqrt{3.5} = 1.871$ |
| `Mindlin(poisson_ratio = 0.3)` | 0.824 | 1.572 | 1.698 |
| `CundallStrack(stiffness_ratio = 1.0)` ([Santos2024]'s $k_s = k_n$) | 1 | 1.732 | 1.871 |

The Mindlin ratio $k_t/k_n = 1 - \nu/(2 - \nu)$ is [Somfai2005]'s Eq. (A4), with $\nu$
the Poisson ratio. Checked numerically with the full 6- and 12-degree-of-freedom
two-particle problem, for equal and unequal masses and radii. With `:matched` the
tangential direction never shortens the step; with `Mindlin(poisson_ratio = 0.0)` it
does, by $\sqrt3$ for disks, and the step follows $\omega_t$.

### Stability without damping

Velocity Verlet updates

$$\mathbf x_{n+1} = \mathbf x_n + \Delta t\,\mathbf v_n + \tfrac12\Delta t^2\,\mathbf a_n, \qquad \mathbf v_{n+1} = \mathbf v_n + \tfrac12\Delta t\left(\mathbf a_n + \mathbf a_{n+1}\right).$$

Eliminating the velocities gives $\mathbf x_{n+1} - 2\mathbf x_n + \mathbf x_{n-1} = \Delta t^2\,\mathbf a_n$.
For one undamped oscillator, $a = -\omega^2 x$, and with $h = \omega\Delta t$ and
$x_n = \lambda^n$:

$$\lambda^2 - \left(2 - h^2\right)\lambda + 1 = 0.$$

The two roots multiply to 1. For $h < 2$ they are complex conjugates on the unit
circle and the motion stays bounded; for $h > 2$ they are real and one has
$\lvert\lambda\rvert > 1$, so errors grow every step. The stability limit is

$$\omega\,\Delta t < 2.$$

Semi-implicit Euler (FIRE's default integrator, [§14](14-fire-settings.md)),
$v_{n+1} = v_n - \Delta t\,\omega^2 x_n$, $x_{n+1} = x_n + \Delta t\,v_{n+1}$, has an
update matrix with trace $2 - h^2$ and determinant 1, the same polynomial and the same
limit. Checked numerically: the largest stable $h$ is 2.000 for both.

A packing's linearized motion, $\mathbf M\ddot{\mathbf x} = -\mathbf K\mathbf x$,
separates into modes of frequency $\omega_\ell$ (eigenvalues of
$\mathbf M^{-1/2}\mathbf K\mathbf M^{-1/2}$), and both integrators are linear, so each
mode follows the recurrence above. The packing is stable when
$\omega_\text{max}\Delta t < 2$. For one contact, $\omega = \pi/t_\text{col}$, so any
$\Delta t < (2/\pi)\,t_\text{col} = 0.637\,t_\text{col}$ is stable: 31.8 times the
default step.

### The fastest packing mode: the $\sqrt z$ estimate

Take frictionless Hookean contacts and equal masses $m$, so $\omega_c^2 = k/M_n = 2k/m$.
The mass-weighted stiffness matrix is a sum over contacts,

$$\tilde{\mathbf K} = \frac{k}{m}\sum_c \mathbf b_c\mathbf b_c^\top,$$

where $\mathbf b_c$ holds $-\hat{\mathbf n}\_c$ in the block of particle $i$ and
$+\hat{\mathbf n}\_c$ in the block of $j$, so $\lvert\mathbf b_c\rvert^2 = 2$. Its nonzero
eigenvalues are those of the contact matrix $G_{cc'} = \mathbf b_c\cdot\mathbf b_{c'}$,
which has $G_{cc} = 2$, $G_{cc'} = \pm\hat{\mathbf n}\_c\cdot\hat{\mathbf n}\_{c'}$ when
$c$ and $c'$ share a particle, and 0 otherwise. Gershgorin's theorem bounds every
eigenvalue by the largest row sum of absolute values, and each $\lvert G_{cc'}\rvert \le 1$:

$$\lambda_\text{max}(G) \le \max_c\left[2 + (z_i - 1) + (z_j - 1)\right] = \max_c\,(z_i + z_j).$$

Hence

$$\omega_\text{max}^2 \le \frac{k}{m}\,\max_c(z_i + z_j) = \omega_c^2\,\max_c\frac{z_i + z_j}{2}.$$

If every particle has $z$ contacts this is $\omega_\text{max} \le \sqrt z\,\omega_c$, the
estimate used in [§8](08-damping.md). A straight chain ($z = 2$) reaches it,
$\omega_\text{max} = 2\sqrt{k/m} = \sqrt2\,\omega_c$. In 2D and 3D the normals are not
collinear, so the bound is not reached. It is a bound in the local contact numbers,
not in the mean $z$. With friction the same row-sum argument picks up tangential
terms and gives a somewhat larger bound. **SoftPack note.**

Measured on our test packings (bidisperse, diameter ratio 1.4, equal masses, one
stiffness, made by energy minimization; rattlers removed; unstressed stiffness matrix):

| Packing | mean $z$ | $\omega_\text{max}/\omega_c$ | $\sqrt{\text{mean } z}$ | bound $\sqrt{\max(z_i + z_j)/2}$ |
|---|---|---|---|---|
| 2D, 256 disks, packing fraction 0.845 | 4.15 to 4.32 | 1.65 to 1.67 | 2.04 to 2.08 | 2.45 |
| 2D, 256 disks, 0.86 | 4.44 to 4.49 | 1.67 | 2.11 to 2.12 | 2.45 |
| 2D, 256 disks, 0.90 | 4.84 to 4.88 | 1.69 to 1.70 | 2.20 to 2.21 | 2.55 |
| 3D, 256 spheres, 0.66 | 6.79 to 6.99 | 1.82 to 1.85 | 2.61 to 2.64 | 3.24 to 3.39 |
| 3D, 256 spheres, 0.70 | 7.94 to 7.96 | 1.88 to 1.90 | 2.82 | 3.46 to 3.54 |
| 2D, 128 disks, 0.86, with tangential springs ($k_t = k_n/3$) and rotations | 4.44 | 1.84 | 2.11 | – |

The fastest mode stayed below $\sqrt z\,\omega_c$ in every case, so the estimate is on
the safe side. In the 128-disk packing, including the stress term of the stiffness
matrix changed $\omega_\text{max}$ by 0.08%.

### Stability with damping

[§8](08-damping.md) gives the stable step for one damped oscillator,
$\omega\Delta t \le 2\left(\sqrt{1+\zeta^2} - \zeta\right)$. It holds when the damping
force is computed from the velocity of the half step before, which is how velocity
Verlet codes compute velocity-dependent forces: in LAMMPS granular forces "depend on
atom velocities, which are used at half-step values every timestep when forces are
computed" [LAMMPSreadrestart]. With $h = \omega\Delta t$ the update

$$v_{n+1/2} = v_{n-1/2} + \Delta t\left(-\omega^2 x_n - 2\zeta\omega\,v_{n-1/2}\right), \qquad x_{n+1} = x_n + \Delta t\,v_{n+1/2}$$

has an update matrix with trace $T = 2 - h^2 - 2\zeta h$ and determinant
$1 - 2\zeta h$. Both roots of $\lambda^2 - T\lambda + (1 - 2\zeta h) = 0$ lie inside the
unit circle when $-T \le 1 + (1 - 2\zeta h)$, that is $h^2 + 4\zeta h - 4 \le 0$:

$$\omega\,\Delta t \le 2\left(\sqrt{1 + \zeta^2} - \zeta\right).$$

(The other condition, determinant $\ge -1$, gives $h \le 1/\zeta$, which is weaker.)
Semi-implicit Euler with the damping force from the current velocity is the same map.
If the damping used the centered velocity (an implicit term), the limit would stay at
$\omega\Delta t < 2$ for every $\zeta$. Checked numerically (largest stable $h$):

| $\zeta$ | lagged velocity | formula | centered velocity |
|---|---|---|---|
| 0.2 | 1.6396 | 1.6396 | 2.0000 |
| 0.5 | 1.2361 | 1.2361 | 2.0000 |
| 0.98 | 0.8403 | 0.8403 | 2.0000 |
| 1.96 | 0.4807 | 0.4807 | 2.0000 |
| 2.40 | 0.3999 | 0.3999 | 2.0000 |

With `ContactDamping` defaults the damping matrix is $b\,\mathbf K_0$
([§8](08-damping.md)), so mode $\ell$ has damping ratio $\zeta\,\omega_\ell/\omega_c$:
the fastest mode is also the most damped. Its stable step, for
$\omega_\text{max} = s\,\omega_c$ and $t_\text{col} = \pi/\omega_c$, is
$\Delta t_\text{max} = 2\left(\sqrt{1+\zeta_s^2} - \zeta_s\right)/(s\,\omega_c)$ with
$\zeta_s = 0.98\,s$:

| Case | $s = \omega_\text{max}/\omega_c$ | stable step | margin over $t_\text{col}/50$ | margin without damping |
|---|---|---|---|---|
| one contact | 1 | $0.267\,t_\text{col}$ | 13.4 | 31.8 |
| 2D worst case ($z = 4$) | 2 | $0.0765\,t_\text{col}$ | 3.83 | 15.9 |
| 3D worst case ($z = 6$) | $\sqrt6$ | $0.0520\,t_\text{col}$ | 2.60 | 13.0 |
| 2D test packings, frictionless | 1.70 | $0.104\,t_\text{col}$ | 5.19 | 18.7 |
| 2D test packing, matched friction | 1.84 | $0.0895\,t_\text{col}$ | 4.48 | 17.3 |
| 3D test packings | 1.90 | $0.0843\,t_\text{col}$ | 4.21 | 16.8 |

The first three rows are the design doc's §8 estimates. **SoftPack note.**

## Defaults and their reasons

### CollisionTime (default)

```julia
pack(timestep = CollisionTime(fraction = 1/50))
```

**Decision.** The time step is 1/50 of the shortest binary collision time
$t_\text{col} = \pi\sqrt{m_\text{eff}/k}$, taken over the smallest particle mass, the
stiffest contact (normal, or tangential with rotation when friction is on), and for
Hertzian contacts the stiffness at the largest overlap expected. A run-time check warns
if a contact becomes stiffer than the chosen `timestep` resolves. For FIRE this is the
starting step.

- 1/50 of the collision time: [Silbert2001] "an accurate simulation typically requires
  δt ∼ t_col/50", with $t_\text{col} = \pi\left(2k_n/m - r_n^2/4\right)^{-1/2}$ (their
  $\gamma_n$ is a rate, our $r_n$; [derivation](#collision-time-of-a-hookean-contact)).
  Their own runs follow it: they integrate "with a time-step δt = 10^-4 for kn = 2 × 10^5"
  [Silbert2001], and their $t_\text{col}$ is $4.97\times10^{-3}$, so
  $t_\text{col}/\delta t = 49.7$ (our conversion).
- 1/50 is an accuracy rule, not a stability limit. Without damping the step could be
  31.8 times longer for one contact and about 13 to 16 times longer in a packing
  ([derivation](#stability-without-damping)).
- Computed from the contact state, not fixed once: [OSullivan2004] "it is shown that
  the critical time increment is a function of the current contact conditions" and
  earlier recommendations "can be unconservative, in that they often overestimate the
  actual critical time step."
- The lightest pair and the stiffest contact give the shortest collision time
  ([lightest pair](#the-lightest-pair), [tangential frequency](#the-tangential-contact-frequency)).
  For Hertzian contacts the stiffness grows with the overlap, so the largest expected
  overlap sets the step, and the run-time check covers overlaps beyond it
  ([derivation](#collision-time-of-a-hertzian-contact)). **SoftPack note.**
- The undamped collision time is used even when contact damping is on
  ([reasons](#collision-time-of-a-hookean-contact)).
- FIRE step limits: [Guenole2020] list LAMMPS FIRE 2.0 defaults of a maximum step of 10
  times and a minimum step of 0.02 times the starting step.
- With near-critical contact damping the stable step is smaller. The default keeps a
  margin of at least about 2.6 (the $\sqrt z$ worst case in 3D;
  [table](#stability-with-damping)).

## Options

### A different fraction

```julia
pack(timestep = CollisionTime(fraction = 1/100))
```

**Option.** Any fraction of the same collision time. A smaller fraction follows each
collision more closely and costs proportionally more steps; a larger one is cheaper.
With near-critical contact damping keep the fraction at or below about 1/20
([§8](08-damping.md), "Time step with damping"). Values in use, converted to the same
measure (our conversions):

| Source | Their step | In collision times |
|---|---|---|
| [Silbert2001] | "δt ∼ t_col/50" | $t_\text{col}/50$ |
| [Santos2024] | "∆t = 0.02τ", $\tau = \sqrt{m/k_n}$, Hookean, $k_s = k_n$ | normal: $t_\text{col}/111$; tangential (spheres, $\omega_t = \sqrt{3.5}\,\omega_n$): $t_{\text{col},t}/59$ |
| [Ishima2023] | $\Delta t = 1.0\times10^{-2}\,t_0$, $t_0 = (m/k_N)^{1/2}d^{1/4}$ ($m$, $d$: mass and diameter of their large disks; small disks have diameter $d/1.4$ and mass $m/1.96$), Hertzian, velocity Verlet | two small disks: $t_\text{col} = 1.30\,(\delta/d)^{-1/4}\,t_0$, so from $t_\text{col}/410$ at $\delta/d = 10^{-2}$ to $t_\text{col}/1296$ at $10^{-4}$ |
| [EDEMtimestep] | "20% of the Rayleigh Time Step is the default value recommended" | not a collision time; not converted |

[Santos2024] also tested a ten times smaller step: "A time step ∆t = 0.002τ was also
tested and did not change the results for the pressures studied within the
uncertainties." [EDEMtimestep] give "the normal range is 10%-40% of the Rayleigh Time
Step". The Rayleigh time step of Hertz-Mindlin DEM codes is a different criterion (an
elastic wave crossing a particle), so it is not converted here.

### A fixed number

```julia
pack(timestep = 0.02)
```

**Option.** A fixed step in the simulation's time unit ($\tau = \sqrt{m/k}$, which is
1 in the default units). With equal masses 1 and $k = 1$, `timestep = 0.02` is
[Santos2024]'s $\Delta t = 0.02\tau$. When to use it: to reproduce another code's
step exactly, or to keep the same step across runs whose collision times differ. The
run-time stiffness check still warns if a contact needs a shorter step (design doc
§12).

### FIRE and the time step

```julia
pack(algorithm = FIRE(timestep_max = 10, timestep_min = 0.02))
```

FIRE starts at the `timestep` value and changes its step as it runs, between
`timestep_min` and `timestep_max` times the starting step ([§14](14-fire-settings.md)).
The largest step is $t_\text{col}/5$, so $\omega_c\Delta t = \pi/5 = 0.63$ for one
contact and at most $\sqrt z\,\pi/5$ = 1.26 (2D, $z = 4$) or 1.54 (3D, $z = 6$) for the
fastest mode: below the undamped limit 2 (our conversion). FIRE's default has no
contact damping; with `ContactDamping` added (allowed, [§8](08-damping.md)) the largest
step exceeds the damped limits in the table above (see
[Open questions](#open-questions)).

## Worked numbers

Default units: $k = 1$, small diameter 1, masses from [§4](04-mass.md).

| Setting | $m_\text{eff}$ | stiffness | $t_\text{col}$ | $\Delta t = t_\text{col}/50$ |
|---|---|---|---|---|
| defaults: `EqualMass(1.0)`, `Hookean(stiffness = 1.0)` | 0.5 | $k_n = 1$ | 2.2214 | 0.044429 |
| `Density(1.0; shape = :disc)`, small disk mass $\pi/4$ | 0.39270 | $k_n = 1$ | 1.9687 | 0.039374 |
| defaults + `CundallStrack()` (`:matched`) | 0.5 | $\omega_t = \omega_n$ | 2.2214 | 0.044429 |
| defaults + `CundallStrack(stiffness_ratio = 1.0)`, disks | 0.5 | $\omega_t = \sqrt3\,\omega_n$ | 1.2825 | 0.025651 |

`Hertzian(stiffness = 1.0)` at the default pressure $P = 10^{-4}$ in 2D. The mean
normal force is $\langle f_n\rangle = \pi P d/(z\phi) = 9.35\times10^{-5}$ ($z = 4$,
packing fraction $\phi = 0.84$, [§2](02-default-packing.md); our conversion). A contact
carrying force $f$ has overlap $\delta = (f/k)^{2/3}$ and stiffness
$k_n = \tfrac32 k\delta^{1/2}$; equal masses 1:

| Contact force | $\delta$ | $k_n(\delta)$ | $t_\text{col}$ | $t_\text{col}/50$ | tangential $t_\text{col}$ with `Mindlin(poisson_ratio = 0.0)` |
|---|---|---|---|---|---|
| $\langle f_n\rangle$ | $2.06\times10^{-3}$ | 0.0681 | 8.51 | 0.170 | 4.92 |
| $3\langle f_n\rangle$ | $4.29\times10^{-3}$ | 0.0982 | 7.09 | 0.142 | 4.09 |
| $10\langle f_n\rangle$ | $9.56\times10^{-3}$ | 0.147 | 5.80 | 0.116 | 3.35 |

These show the scale and the weak $f^{-1/6}$ dependence; which overlap SoftPack takes
as "the largest expected" is not designed yet.

## Open questions

- How the largest expected Hertzian overlap is estimated, what exactly the run-time
  check compares, and whether it may shorten the step or only warns (the design doc
  says it warns).
- The integrator of `DampedDynamics` and how its damping force is discretized are not
  stated. The §8 stability formula assumes the explicit half-step velocity form
  ([derivation](#stability-with-damping)); a centered (implicit) damping term would
  remove the damping penalty.
- FIRE with contact damping: the largest FIRE step, $t_\text{col}/5 = 0.2\,t_\text{col}$,
  is above the damped network limits (0.05 to 0.10 $t_\text{col}$). The "margin of at
  least about 2.6" applies to a fixed step at the default fraction.
- The §8 margins are estimates "to be checked once `DampedDynamics` runs" (design doc).
- The moment-of-inertia convention, which sets $M_t$ and $\omega_t$, is not stated in
  the design doc ([§13](13-friction-models.md)).

## Related pages

- [8. Damping](08-damping.md): damping ratios and the stable step with damping.
- [13. Friction models](13-friction-models.md): tangential stiffness and $M_t$.
- [14. FIRE settings](14-fire-settings.md): how FIRE adapts the step.
- [4. Mass](04-mass.md), [2. Default packing](02-default-packing.md): masses, stiffness
  and units.
- [Notation](notation.md), [References](references.md).

## References

- **[EDEMtimestep]** Altair Engineering. *Time Steps, EDEM documentation*. <https://help.altair.com/EDEM/topics/edem_simulator/understanding_time_steps_c.htm>. Accessed 2026-11-18.
- **[Guenole2020]** Julien Guénolé, Wolfram G. Nöhring, Aviral Vaid, Frédéric Houllé, Zhuocheng Xie, Aruna Prakash, Erik Bitzek (2020). *Assessment and optimization of the fast inertial relaxation engine (fire) for energy minimization in atomistic simulations and its implementation in lammps*. Computational Materials Science **175**, 109584. [doi:10.1016/j.commatsci.2020.109584](https://doi.org/10.1016/j.commatsci.2020.109584).
- **[Ishima2023]** Daisuke Ishima, Kuniyasu Saitoh, Michio Otsuki, Hisao Hayakawa (2023). *Theory of rigidity and numerical analysis of density of states of two-dimensional amorphous solids with dispersed frictional grains in the linear response regime*. Physical Review E **107**, 054902. [doi:10.1103/physreve.107.054902](https://doi.org/10.1103/physreve.107.054902).
- **[LAMMPSreadrestart]** LAMMPS developers. *LAMMPS documentation: read_restart command*. <https://docs.lammps.org/read_restart.html>. Accessed 2026-11-19.
- **[OSullivan2004]** Catherine O'Sullivan, Jonathan D. Bray (2004). *Selecting a suitable time step for discrete element simulations that use the central difference time integration scheme*. Engineering Computations **21**, 278–303. [doi:10.1108/02644400410519794](https://doi.org/10.1108/02644400410519794).
- **[Santos2024]** A. P. Santos, Ishan Srivastava, Leonardo E. Silbert, Jeremy B. Lechman, Gary S. Grest (2024). *Protocol-dependent frictional granular jamming simulations: cyclical, compression, and expansion*. Frontiers in Soft Matter **3**, 1326756. [doi:10.3389/frsfm.2023.1326756](https://doi.org/10.3389/frsfm.2023.1326756).
- **[Silbert2001]** Leonardo E. Silbert, Deniz Ertaş, Gary S. Grest, Thomas C. Halsey, Dov Levine, Steven J. Plimpton (2001). *Granular flow down an inclined plane: Bagnold scaling and rheology*. Physical Review E **64**, 051302. [doi:10.1103/physreve.64.051302](https://doi.org/10.1103/physreve.64.051302).
- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
