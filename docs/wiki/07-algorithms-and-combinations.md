# 7. Algorithms and combinations

Design decision source: [design-references.md §7](../design-references.md#7-algorithms-and-combinations).
Status: design stage (no engine code yet).

## Summary

`pack()` has two algorithms that bring a packing to rest: `FIRE()`, the default, and
`DampedDynamics()`. FIRE is a minimizer that moves the particles with modified
dynamics; damped dynamics is Newton's equations with dashpots. Any algorithm can be
combined with any contact law, friction model, target, convergence test and rattler
rule. To make that possible, force models (the normal law plus friction, holding the
contact history) and algorithms exchange only positions and rotations one way and
forces and torques the other. FIRE with friction is allowed but labeled non-standard:
frictional forces depend on the path the contacts slid along, FIRE's path is not a
physical one, and published frictional packings are made with damped dynamics. Because
frictional packings depend on how they were made, the algorithm and its damping settings
are recorded in every output as part of the packing's identity.

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| `algorithm` | `FIRE()` | `DampedDynamics()` | [Algorithms](#the-two-algorithms), [§14](14-fire-settings.md) (FIRE parameters), [§8](08-damping.md) (damping) |
| `DampedDynamics` `damping`, `drag` | `ContactDamping(normal = 0.98, tangential = 0.98)`, `nothing` | see [§8](08-damping.md) | [Equation of motion](#damped-dynamics-equation-of-motion) |
| `FIRE` `damping`, `drag` | `nothing`, `nothing` | same as `DampedDynamics` | [§8](08-damping.md) |
| combinations | every combination of algorithm, `contact`, `friction`, `target`, `convergence`, `rattlers` | – | [Any combination](#any-combination-is-allowed) |

## Model

### Symbols

| Symbol | Meaning |
|---|---|
| $\mathbf q$ | all coordinates stacked: positions $\mathbf x_i$, and rotation angles $\theta_i$ when friction is on (2D) |
| $\mathbf M$ | diagonal mass matrix: $m_i$ on each position coordinate, $I_i$ on each rotation |
| $m_i$, $I_i$, $R_i$ | mass, moment of inertia ($I = mR^2/2$ for a uniform disk) and radius of particle $i$ |
| $\mathbf v_i$, $\omega_i = \dot\theta_i$ | velocity and spin |
| $\mathbf F$, $\mathbf F_i$, $T_i$ | stacked generalized forces; force and torque on particle $i$ |
| $U$ | elastic energy of the normal contacts ([§2](02-default-packing.md)) |
| $\hat{\mathbf n}$, $\hat{\mathbf t}$ | contact normal (from $i$ to $j$) and 2D tangent $\hat{\mathbf z}\times\hat{\mathbf n}$ |
| $\delta$, $v_n$, $v_t$ | overlap, separation speed and slip speed of a contact ([§8](08-damping.md)) |
| $F_n^\text{el}$, $F_t^\text{el}$ | elastic normal and tangential contact forces |
| $k_n$, $k_t$ | normal and tangential contact stiffness |
| $\xi$ | tangential spring stretch (contact history) |
| $\mu$ | friction coefficient |
| $\gamma_n$, $\gamma_t$ | dashpot coefficients (force per velocity) |
| $\boldsymbol\Gamma$, $\mathbf K_0$ | damping matrix and unstressed stiffness matrix |
| $a$, $a_v$, $a_s$, $b$ | Rayleigh constants: drag rate (velocity, spin) and stiffness-proportional constant |
| $\zeta$, $\omega_c$, $M_n$, $M_t$ | damping ratio, contact frequency $\sqrt{k_n/M_n}$, normal and tangential effective masses |
| $\omega_\ell$, $\beta_\ell$ | frequency and decay rate of mode $\ell$ |
| $\Delta t$, $\alpha$, $P$ | time step, FIRE's mixing coefficient, power (on this page $P$ is the power, not the pressure) |

### The two algorithms

| | `FIRE()` (default) | `DampedDynamics()` |
|---|---|---|
| Equation | Newton's equations plus a term that steers the velocity toward the force, with velocity resets ([Bitzek2006], [§14](14-fire-settings.md)) | $\mathbf M\ddot{\mathbf q} = \mathbf F - \boldsymbol\Gamma\dot{\mathbf q}$ ([below](#damped-dynamics-equation-of-motion)) |
| Removes energy by | mixing $\mathbf v$ toward $\mathbf F$; zeroing $\mathbf v$ when the power $P = \mathbf F\cdot\mathbf v \le 0$ | contact dashpots, optional Stokes drag, Coulomb sliding |
| Default `damping`, `drag` | `nothing`, `nothing` | `ContactDamping(0.98, 0.98)`, `nothing` |
| Time step | starts at $t_\text{col}/50$, adapts between 0.02 and 10 times that | fixed, $t_\text{col}/50$ ([§12](12-time-step.md)) |
| Integrator | semi-implicit Euler (default) or velocity Verlet | not stated in the design doc |
| Is the path a physical trajectory? | no | yes, of a damped mechanical system |
| Frictionless end state | a local minimum of $U$ | a local minimum of $U$ |
| Frictional end state | a static state reached along FIRE's path: **non-standard** | a static state reached by damped motion: the literature's method |
| Used for frictional packings by | none found (design doc, searched 2026-11-18) | [Xiong2019], [Santos2024], [Somfai2007], [Agnolin2007] |

### Damped dynamics: equation of motion

For particle $i$, with the sums over its contacts $c$,

$$m_i\,\ddot{\mathbf x}_i = \sum_{c \ni i}\mathbf f_{c\to i} - a_v\,m_i\,\dot{\mathbf x}_i, \qquad I_i\,\ddot\theta_i = \sum_{c \ni i}T_{c\to i} - a_s\,I_i\,\dot\theta_i .$$

For a contact between $i$ and $j$ the force on $j$ is $F_n\hat{\mathbf n} + F_t\hat{\mathbf t}$
and the force on $i$ is its opposite ([§8](08-damping.md)):

$$F_n = \max\left(0,\ F_n^\text{el} - \gamma_n v_n\right), \qquad F_t = \begin{cases} F_t^\text{el} - \gamma_t v_t & \text{stuck},\\ F_t^\text{el} & \text{sliding},\end{cases}$$

with $F_n^\text{el} = k\,\delta^{\alpha-1}$ ($\alpha = 2$ Hooke, $5/2$ Hertz) and
$F_t^\text{el} = -k_t\xi$. The tangential force acts at the contact point, so it applies
the torques $T_{c\to j} = -R_j F_t$ and $T_{c\to i} = -R_i F_t$ (about $\hat{\mathbf z}$). In
3D, $I_i\dot{\boldsymbol\omega}\_i = \sum_c \mathbf T_{c\to i} - a_s I_i\boldsymbol\omega_i$ for
spheres (isotropic inertia), with torques $\mathbf b\times\mathbf f_t$ ($\mathbf b$ the lever
arm to the contact point).

Collected into one vector, and linearized about a packing (dashpots switched on, no
sliding, no clipping):

$$\mathbf M\ddot{\mathbf q} = \mathbf F(\mathbf q) - \boldsymbol\Gamma\,\dot{\mathbf q}, \qquad \boldsymbol\Gamma = a\,\mathbf M + b\,\mathbf K_0 .$$

The rotational rows of $\mathbf M$ hold $I_i$; the rotational rows of $\boldsymbol\Gamma$
hold the tangential dashpots through the lever arms $R_i$, and $a_s I_i$ for spin drag
(`StokesDrag(spin = ...)`, with $a = a_v = a_s$ for the proportional form). With the
defaults:

- `drag = nothing`, so $a = 0$;
- `ContactDamping(normal = 0.98, tangential = 0.98)` with Hookean contacts and equal
  masses: each contact has $b = \gamma_n/k_n = \gamma_t/k_t = 2\zeta/\omega_c$, and the
  same $b$ in both directions with matched friction ([§8](08-damping.md),
  [§13](13-friction-models.md)). For $m = k = 1$: $M_n = 1/2$, $\omega_c = \sqrt2/\tau$,
  $\gamma_n = 0.98\times2\sqrt{k M_n} = 1.386$, and with friction $k_t = 1/3$, $M_t = 1/6$,
  $\gamma_t = 0.98\times2\sqrt{k_t M_t} = 0.462$, so $b = b_t = 1.386\,\tau$.

Every underdamped mode then decays at $\beta_\ell = (a + b\,\omega_\ell^2)/2$
([§8](08-damping.md)).

### FIRE in brief

FIRE 2.0 ([Guenole2020], with SoftPack's settings in [§14](14-fire-settings.md)) takes
an integrator step and adjusts it with the power $P = \mathbf F\cdot\mathbf v$:

- $P > 0$ (downhill): mix $\mathbf v \leftarrow (1-\alpha)\,\mathbf v + \alpha\,\lvert\mathbf v\rvert\,\hat{\mathbf F}$;
  after 20 such steps in a row, grow $\Delta t$ by 1.1 (up to 10 times the start) and
  shrink $\alpha$ by 0.99.
- $P \le 0$ (uphill): move back half a step, $\mathbf x \leftarrow \mathbf x - \tfrac12\Delta t\,\mathbf v$,
  set $\mathbf v = 0$, halve $\Delta t$ (not below 0.02 times the start), reset $\alpha = 0.25$.

[Guenole2020] "the velocities are reset to zero at the beginning of the pseudo-dynamic
run and also periodically during the run in FIRE 2.0". How the power, the norm
$\lvert\mathbf v\rvert$ and the mixing treat spins, which have different units from
velocities, is not designed ([Open questions](#open-questions)).

### The tangential spring and the Coulomb limit

Both friction models keep, for each open contact, the tangential spring stretch $\xi$,
the integral of the slip speed over the life of the contact ([§13](13-friction-models.md)).
In 2D, with the slip speed
$v_t = \hat{\mathbf t}\cdot(\mathbf v_j - \mathbf v_i) - R_j\omega_j - R_i\omega_i$,
the Cundall–Strack update over one step is

$$\xi^\text{trial} = \xi + v_t\,\Delta t, \qquad \xi \leftarrow \begin{cases}\xi^\text{trial} & k_t\,\lvert\xi^\text{trial}\rvert \le \mu\,F_n^\text{el} \quad \text{(stuck)},\\ \operatorname{sign}(\xi^\text{trial})\,\mu F_n^\text{el}/k_t & \text{otherwise (sliding)},\end{cases}$$

with $\xi = 0$ when the contact forms and when it opens. The elastic tangential force is
$F_t^\text{el} = -k_t\xi$, so the cap is the Coulomb limit
$\lvert F_t^\text{el}\rvert \le \mu F_n^\text{el}$ (`coulomb_limit = :elastic`,
[§8](08-damping.md)). In terms of positions alone, $v_t\Delta t$ is the relative
tangential displacement of the two contact points over the step,
$\Delta\xi = \hat{\mathbf t}\cdot(\Delta\mathbf x_j - \Delta\mathbf x_i) - R_j\Delta\theta_j - R_i\Delta\theta_i$.
The sources:

- [Silbert2001] "Static friction is implemented by keeping track of the elastic shear
  displacement throughout the lifetime of a contact." The displacement is "set to zero
  at the initiation of a contact", and the friction limit "is modeled by truncating the
  magnitude of u_tij as necessary to satisfy |F_tij| < |µF_nij|."
- [Xiong2019], for the same Cundall–Strack model in 2D: the displacement "is set to zero
  when the pair of disks i and j is no longer in contact".

In 3D, $\xi$ is a vector in the tangent plane and is rotated with the contact
([Silbert2001]'s Eq. 5); in 2D the scalar $\xi$ along $\hat{\mathbf t}$ needs no rotation.

### Interface between force models and algorithms

The design doc's contract: "Force models (normal law plus friction, holding the contact
history) and algorithms only exchange positions/rotations and forces/torques."

| Direction or owner | What | In the design doc | Notes |
|---|---|---|---|
| algorithm → force model | positions $\mathbf x_i$, rotations $\theta_i$ (and the box) | yes | the force model derives overlaps, normals and slip increments $\Delta\xi$ from them |
| force model → algorithm | forces $\mathbf F_i$, torques $T_i$ | yes | the algorithm integrates them |
| held by the force model | contact list and history $\xi$ per contact (created at 0, capped, reset on separation) | yes | part of the restart state ([§6](06-packing-that-does-not-converge.md)) |
| held by the algorithm | velocities, spins; FIRE's $\Delta t$, $\alpha$, $N_\pm$ | implied (§6, §14) | part of the restart state |
| needed by contact dashpots | slip and separation speeds $v_t$, $v_n$; each contact's $k_n(\delta)$ (Hertz critical value), sliding flag (dashpot off while sliding), total force (for `coulomb_limit = :total`) | not covered | see [Open questions](#open-questions) |
| needed by the run | per-contact normal forces and branch vectors (pressure, [§2](02-default-packing.md); $\langle f_n\rangle$, [§5](05-convergence-criterion.md)), contact network ([§9](09-rattler-rules.md)) | not covered | outputs of the force model beyond forces and torques |

The first three rows are the decision. The last three are what other sections require
(**SoftPack note**): `damping` is a setting of the algorithm (§8), but a contact dashpot
needs contact-level data that only the force model has, and velocities that only the
algorithm has.

## Derivations

### Damped dynamics comes to rest in a static state

Let $E = \tfrac12\dot{\mathbf q}^\top\mathbf M\dot{\mathbf q} + U + \sum_c \tfrac12 k_t\xi_c^2$ be
the kinetic plus elastic energy (Hookean tangential springs). The elastic forces do work
$-\tfrac{d}{dt}(U + \sum_c\tfrac12 k_t\xi_c^2)$ on stuck contacts, the dashpots and drag
remove $\dot{\mathbf q}^\top\boldsymbol\Gamma\dot{\mathbf q} \ge 0$, and sliding removes
$D \ge 0$ ([next derivation](#power-and-energy-with-friction)), so

$$\frac{dE}{dt} = -\dot{\mathbf q}^\top\boldsymbol\Gamma\,\dot{\mathbf q} - D \le 0 .$$

$E$ can only fall, and motion stops only where the elastic forces and torques balance.
Without friction $E = \tfrac12\dot{\mathbf q}^\top\mathbf M\dot{\mathbf q} + U$ is a Lyapunov
function, and the rest state is a local minimum of $U$. With friction the rest state is
any configuration with balanced forces and every contact inside its Coulomb cone; which
one is reached depends on the path. **SoftPack note** (standard energy argument; the
dashpot power is derived in [§8](08-damping.md)).

### Power and energy with friction

Write $E_\text{el} = U + \sum_c\tfrac12 k_t\xi_c^2$ and let $P$ be the power of the elastic
forces and torques on the particles. Summed contact by contact
([§8](08-damping.md)),

$$P = \sum_i\left(\mathbf F_i^\text{el}\cdot\mathbf v_i + T_i^\text{el}\,\omega_i\right) = \sum_c\left(F_n^\text{el}\,v_n + F_t^\text{el}\,v_t\right).$$

Since $\dot\delta = -v_n$ and $dU/d\delta = F_n^\text{el}$, and $F_t^\text{el} = -k_t\xi$,

$$\frac{dE_\text{el}}{dt} = -\sum_c F_n^\text{el}v_n - \sum_c F_t^\text{el}\,\dot\xi_c = -P + \sum_c F_t^\text{el}\left(v_t - \dot\xi_c\right).$$

On a stuck contact $\dot\xi_c = v_t$ and the last term is zero. On a sliding contact the
slip $v_t - \dot\xi_c$ has the sign of $\xi_c$ and $F_t^\text{el} = -\operatorname{sign}(\xi_c)\,\mu F_n^\text{el}$,
so the term is $-\mu F_n^\text{el}\lvert v_t - \dot\xi_c\rvert$. Hence

$$\frac{dE_\text{el}}{dt} = -P - D, \qquad D = \sum_{c\ \text{sliding}}\mu\,F_n^\text{el}\,\lvert v_t - \dot\xi_c\rvert \ge 0 .$$

Without friction, $P = -dU/dt$: FIRE's uphill test is a test on the energy, and FIRE is
a minimizer of $U(\mathbf q)$. With friction $E_\text{el}$ depends on the history $\xi$,
not on $\mathbf q$ alone, so there is no energy function of the configuration for FIRE to
minimize. Checked numerically on one contact ($k_t = 1/3$, $\mu = 0.5$,
$F_n^\text{el} = 10^{-4}$) driven along a closed slip path of amplitude $3\times10^{-4}$
in $2\times10^5$ steps: the work done on the spring minus $D$ equals the change in
$\tfrac12 k_t\xi^2$ to 0.09%. **SoftPack note.**

### The same configuration, different forces

The stretch $\xi$ is a path integral with a cap, so it is not a function of the current
positions. One contact, $k_t = 1/3$, $\mu = 0.5$, $F_n^\text{el} = 10^{-4}$, so the cap is
$\xi_\text{max} = \mu F_n^\text{el}/k_t = 1.5\times10^{-4}$:

| Path of the relative tangential displacement | Final displacement | Final $\xi$ | $F_t^\text{el}$ on $j$ |
|---|---|---|---|
| A: $+1\times10^{-4}$ (stuck throughout) | $+1\times10^{-4}$ | $+1.0\times10^{-4}$ | $-3.33\times10^{-5}$ |
| B: $+3\times10^{-4}$ (slides at the cap), then $-2\times10^{-4}$ | $+1\times10^{-4}$ | $-0.5\times10^{-4}$ | $+1.67\times10^{-5}$ |

Same final configuration, opposite tangential forces. The closed path of the previous
check returns to zero displacement but ends with $\xi = \xi_\text{max}$, a stored force of
$5\times10^{-5}$ where the path started with none. Whatever moves the particles (FIRE's
mixing, its velocity resets, its half step back, its adaptive $\Delta t$, or a dashpot
of one strength or another) therefore enters the forces of the final packing.
[Silbert2001] call the cap a simplification: "This “proportional loading” approximation
[35] is a simplification of the much more complicated and hysteretic behavior of real
contacts [36]." **SoftPack note** (our example; numbers computed).

### Why FIRE with friction is non-standard

- FIRE moves the particles along a path designed to reach a minimum of an energy fast,
  not along a physical trajectory: it rotates the velocity toward the force, zeroes it
  on every uphill step, moves positions back by $\tfrac12\Delta t\,\mathbf v$, and changes
  $\Delta t$ by factors 1.1 and 0.5.
- Without friction this does not matter for the kind of end state: any path that ends
  at rest ends at a local minimum of $U$ ([above](#power-and-energy-with-friction)).
- With friction it does. The end state is one of a continuum of static states, selected
  by the slip history of every contact ([above](#the-same-configuration-different-forces)).
  [Xiong2019]: "the number of contacts for MS packings of frictional disks
  is below the isostatic value z_iso = 4, and thus there are many solutions for the
  normal and tangential forces for each fixed network of interparticle contacts." A
  FIRE-made frictional packing is a valid static packing, but one selected by FIRE's
  rules and parameters.
- The half step back acts on positions only. Under SoftPack's contract the force model
  sees the moved positions and books the move as a reverse slip $\Delta\xi$, which no
  physical motion produced. (An implementation that integrated $\xi$ from velocities
  instead would miss the move, and $\xi$ would no longer match the contact geometry.)
- No validation: the design doc found no paper that makes frictional packings with
  FIRE, while the papers it cites use damped dynamics (quotes
  [below](#fire-with-friction-is-allowed-and-labeled-non-standard)).

**SoftPack note** for the analysis; the label "non-standard" is the design doc's.

## Defaults and their reasons

### FIRE is the default algorithm

```julia
pack(algorithm = FIRE())
```

**Decision.** Minimize with FIRE ([§2](02-default-packing.md)).

- FIRE: introduced in [Bitzek2006]; assessed and implemented in LAMMPS in
  [Guenole2020]. Its settings are in [§14](14-fire-settings.md).
- The default packing is frictionless ([§2](02-default-packing.md)), where FIRE has a
  well-defined end state (an energy minimum) and known checks
  ([derivation](#power-and-energy-with-friction)).

### Any combination is allowed

```julia
pack(algorithm = DampedDynamics(), contact = Hertzian(), friction = Mindlin(),
     convergence = KineticEnergy(), rattlers = TwoContact())
```

**Decision.** Every combination of algorithm, contact law, friction model, target,
convergence test and rattler rule is allowed in one `pack()`. Force models and
algorithms only exchange positions/rotations and forces/torques. **SoftPack choice**: the
pieces are small types swapped by dispatch ([§1](01-interface-and-naming.md)), and a
narrow interface keeps each one independent of the others. One exception in the design
doc itself: `Mindlin` needs `Hertzian` contacts ([§13](13-friction-models.md)).

### FIRE with friction is allowed and labeled non-standard

```julia
pack(algorithm = FIRE(), friction = CundallStrack())   # allowed, recorded, non-standard
```

**Decision.** FIRE with friction is allowed and recorded, but documented as
non-standard.

- Frictional packings in the literature are made with damped dynamics, not FIRE:
  [Xiong2019] "we minimize the total potential energy U by adding viscous damping forces
  proportional to each disk's velocity"; [Santos2024] use "a Hookean
  spring-dashpot-slider interaction potential (Cundall and Strack, 1979)" with a
  barostat in LAMMPS; [Somfai2007] "The packings are constructed by cooling while slowly
  inflating the particle radii in the presence of a linear damping force";
  [Agnolin2007] "Energy is dissipated thanks to viscous forces in contacts".
- The design doc did not find a paper that makes frictional packings with FIRE (searched
  2026-11-18). That is why FIRE + friction is labeled non-standard.
- Why the algorithm matters with friction: [derivations](#why-fire-with-friction-is-non-standard).

### The preparation path is recorded

**Decision.** The algorithm and its damping settings ([§8](08-damping.md)) are part of
the packing's identity and are recorded in every output ([§11](11-outputs.md)).

- [Henkes2010], on the relation between the friction coefficient and $n_m$ (the fraction
  of fully mobilized contacts): "Our simulations indicate that this relation depends
  significantly on the preparation method of the sample, where packings prepared with
  higher viscous damping have larger n_m".
- [Santos2024] explore "four stress-controlled protocols" and "demonstrate
  the strong protocol dependence of frictional granular matter."
- [Xiong2019]: "one can imagine that different protocols for generating
  jammed packings of frictional disks can give rise to MS packings with different
  distributions of sliding contacts, different force solutions for a given contact
  network, or even different types of contact networks."

## Options

### DampedDynamics

```julia
pack(algorithm = DampedDynamics())
pack(algorithm = DampedDynamics(damping = ContactDamping(normal = 0.98, tangential = 0.98), drag = nothing))
```

**Option.** Newton's equations with contact dashpots
([equation of motion](#damped-dynamics-equation-of-motion)); its damping and drag
settings and their defaults are in [§8](08-damping.md), the time step in
[§12](12-time-step.md). When to use it: for frictional packings, to follow the
literature's method, and whenever the packing should come from physical damped motion.
It is slower than FIRE: on our frictionless probe it took 22,761 steps against FIRE's
1,332 ([Worked numbers](#worked-numbers)); [§5](05-convergence-criterion.md) estimates the
settling time from the slowest mode, $\beta_\text{min} = b\,\omega_\text{min}^2/2$.

### FIRE with damping or drag

```julia
pack(algorithm = FIRE(damping = ContactDamping(), drag = StokesDrag(velocity = 0.1)))
```

**Option.** FIRE accepts the same `damping` and `drag` settings
([§8](08-damping.md), [§14](14-fire-settings.md)); any combination is allowed.

## Worked numbers

Default damping constants (Hookean, $m = k = 1$, [§8](08-damping.md)):

| Quantity | Value |
|---|---|
| $M_n$, $M_t$ (equal disks) | 1/2, 1/6 |
| $\omega_c = \sqrt{k/M_n}$ | $1.414/\tau$ |
| $\gamma_n = 0.98\times2\sqrt{kM_n}$ | 1.386 |
| $\gamma_t = 0.98\times2\sqrt{k_tM_t}$ ($k_t = 1/3$) | 0.462 ($= \gamma_n/3$) |
| $b = \gamma_n/k = \gamma_t/k_t = 2\zeta/\omega_c$ | $1.386\,\tau$ |
| $t_\text{col}$, $\Delta t = t_\text{col}/50$ | $2.221\,\tau$, $0.0444\,\tau$ |

Our probe (Python, not SoftPack code; set-up as in
[§6 Worked numbers](06-packing-that-does-not-converge.md#worked-numbers): 64 disks,
packing fraction 0.85 in a fixed periodic box, Hookean, `CundallStrack` $\mu = 0.5$ when
frictional, tolerance $10^{-6}$), all runs from the same random start:

| Run | Frictionless: $P$, $z$, steps | Frictional: $P$, $z$, mean $\lvert F_t^\text{el}\rvert/(\mu F_n^\text{el})$, steps |
|---|---|---|
| `DampedDynamics`, $\zeta = 0.98$ | 0.004602, 4.19, 22,761 | 0.02494, 3.94, 0.450, 5,636 |
| `DampedDynamics`, $\zeta = 0.098$ | 0.004087, 4.09, 140,571 | 0.01389, 3.84, 0.243, 36,752 |
| `FIRE` (no damping) | 0.006475, 4.41, 1,332 | 0.02910, 3.94, 0.445, 262 |

($z$ is contacts per particle with rattlers included; no contact was fully mobilized at
the end of any run, so $n_m = 0$ and [Henkes2010]'s $n_m$ trend cannot be tested on this
probe.) From a random, strongly overlapping start, each run ends in a different packing
(different contact sets; highest over lowest pressure 1.58 without friction and 2.10
with friction), with or without friction: the algorithm picks the basin.

The frictional difference shows when two runs start from the same configuration
([§6](06-packing-that-does-not-converge.md#worked-numbers)): a run continued from the
same mid-run positions, with velocities (and springs) dropped, reaches the same
frictionless packing (same contacts, pressure equal to $7\times10^{-9}$, damped
dynamics) but a different frictional one (pressure 10.3% lower and other contacts with
damped dynamics, 3.5% lower with FIRE). Without friction the end state is fixed by the configuration and the energy;
with friction it also depends on the path. **SoftPack note**: one small probe, not a
statistical study.

## Open questions

- The interface contract (positions/rotations in, forces/torques out) does not cover
  what contact dashpots need: slip and separation speeds, each contact's stiffness (for
  the Hertz critical value), its sliding flag (the tangential dashpot is off while
  sliding) and the total force (`coulomb_limit = :total`). Nor does it cover the
  per-contact data the pressure, the convergence test and the rattler rules need.
  Where the dashpots are computed (algorithm or force model) is not designed.
- How FIRE treats rotations: whether the power, the norm $\lvert\mathbf v\rvert$ and the
  mixing use spins directly (different units from velocities) or scaled by a radius or
  by $\sqrt{I/m}$. Our probe mixed them directly.
- The integrator of `DampedDynamics` is not stated ([§12](12-time-step.md)).
- How "non-standard" is recorded: the algorithm and settings are in every output (§7,
  §11), but whether `pack()` also warns or sets a flag for FIRE + friction is not stated.
- §7 allows every combination, but `Mindlin` needs `Hertzian` contacts (§13).
- The compression protocol (how `pack()` reaches the target pressure) is not designed;
  it is part of the preparation path.

## Related pages

- [§2 Default packing](02-default-packing.md): FIRE and frictionless contacts as defaults.
- [§5 Convergence criterion](05-convergence-criterion.md): when either algorithm stops.
- [§6 A packing that does not converge](06-packing-that-does-not-converge.md): the
  state each algorithm needs for exact restarts.
- [§8 Damping](08-damping.md): $\boldsymbol\Gamma$, mode decay, dashpot defaults.
- [§12 Time step](12-time-step.md): $t_\text{col}/50$ and stability.
- [§13 Friction models](13-friction-models.md): the tangential spring, $k_t$, $M_t$.
- [§14 FIRE settings](14-fire-settings.md): FIRE 2.0 step by step.
- [Notation](notation.md), [References](references.md).

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[Bitzek2006]** Erik Bitzek, Pekka Koskinen, Franz Gähler, Michael Moseler, Peter Gumbsch (2006). *Structural Relaxation Made Simple*. Physical Review Letters **97**, 170201. [doi:10.1103/physrevlett.97.170201](https://doi.org/10.1103/physrevlett.97.170201).
- **[Guenole2020]** Julien Guénolé, Wolfram G. Nöhring, Aviral Vaid, Frédéric Houllé, Zhuocheng Xie, Aruna Prakash, Erik Bitzek (2020). *Assessment and optimization of the fast inertial relaxation engine (fire) for energy minimization in atomistic simulations and its implementation in lammps*. Computational Materials Science **175**, 109584. [doi:10.1016/j.commatsci.2020.109584](https://doi.org/10.1016/j.commatsci.2020.109584).
- **[Henkes2010]** S. Henkes, M. van Hecke, W. van Saarloos (2010). *Critical jamming of frictional grains in the generalized isostaticity picture*. EPL (Europhysics Letters) **90**, 14003. [doi:10.1209/0295-5075/90/14003](https://doi.org/10.1209/0295-5075/90/14003).
- **[Santos2024]** A. P. Santos, Ishan Srivastava, Leonardo E. Silbert, Jeremy B. Lechman, Gary S. Grest (2024). *Protocol-dependent frictional granular jamming simulations: cyclical, compression, and expansion*. Frontiers in Soft Matter **3**, 1326756. [doi:10.3389/frsfm.2023.1326756](https://doi.org/10.3389/frsfm.2023.1326756).
- **[Silbert2001]** Leonardo E. Silbert, Deniz Ertaş, Gary S. Grest, Thomas C. Halsey, Dov Levine, Steven J. Plimpton (2001). *Granular flow down an inclined plane: Bagnold scaling and rheology*. Physical Review E **64**, 051302. [doi:10.1103/physreve.64.051302](https://doi.org/10.1103/physreve.64.051302).
- **[Somfai2007]** Ellák Somfai, Martin van Hecke, Wouter G. Ellenbroek, Kostya Shundyak, Wim van Saarloos (2007). *Critical and noncritical jamming of frictional grains*. Physical Review E **75**, 020301. [doi:10.1103/physreve.75.020301](https://doi.org/10.1103/physreve.75.020301).
- **[Xiong2019]** Fansheng Xiong, Philip Wang, Abram H. Clark, Thibault Bertrand, Nicholas T. Ouellette, Mark D. Shattuck, Corey S. O’Hern (2019). *Comparison of shear and compression jammed packings of frictional disks*. Granular Matter **21**, 109. [doi:10.1007/s10035-019-0964-9](https://doi.org/10.1007/s10035-019-0964-9).
