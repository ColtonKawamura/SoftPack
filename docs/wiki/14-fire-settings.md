# 14. FIRE settings

Design decision source: [design-references.md §14](../design-references.md#14-fire-settings).
Status: design stage (no engine code yet).

## Summary

FIRE, the Fast Inertial Relaxation Engine [Bitzek2006], is SoftPack's default minimizer
(`algorithm = FIRE()`, [§2](02-default-packing.md), [§7](07-algorithms-and-combinations.md)).
It is molecular dynamics with three changes: the velocity is steered toward the
force, the time step grows while the motion stays downhill, and the system is stopped
(all velocities set to zero) as soon as it starts to move uphill. SoftPack uses
FIRE 2.0 [Guenole2020], the revised algorithm that is LAMMPS's FIRE minimizer, with
LAMMPS's default parameters (Table 1 of [Guenole2020]) and its recommended
semi-implicit Euler integrator. By default FIRE runs with no contact damping and no
drag: its own velocity rules remove the energy ([§8](08-damping.md)). The starting
time step is the `pack()` keyword `timestep` ([§12](12-time-step.md)); every FIRE
step size is a multiple of it.

## Settings

All are fields of `FIRE(...)`, set as `pack(algorithm = FIRE(name = value))`. The
LAMMPS column is the matching `min_modify` keyword [LAMMPSminmodify]; the symbol column
is the one used on this page.

| Setting | Default | Options | LAMMPS | Symbol | Details |
|---|---|---|---|---|---|
| `timestep_max` | `10` | any value | `tmax` | $\Delta t_\text{max}/\Delta t_\text{start}$ | [Largest step](#largest-step-timestep_max) |
| `timestep_min` | `0.02` | any value | `tmin` | $\Delta t_\text{min}/\Delta t_\text{start}$ | [Smallest step](#smallest-step-timestep_min) |
| `delay` | `20` | any integer | `delaystep` | $N_\text{delay}$ | [Delay](#delay-delay) |
| `timestep_grow` | `1.1` | any value | `dtgrow` | $f_\text{inc}$ | [Growth](#growth-and-shrink-factors) |
| `timestep_shrink` | `0.5` | any value | `dtshrink` | $f_\text{dec}$ | [Shrink](#growth-and-shrink-factors) |
| `mixing_coefficient` | `0.25` | any value | `alpha0` | $\alpha_\text{start}$ | [Mixing](#mixing-coefficient-and-its-shrink-factor) |
| `mixing_shrink` | `0.99` | any value | `alphashrink` | $f_\alpha$ | [Mixing](#mixing-coefficient-and-its-shrink-factor) |
| `uphill_max` | `2000` | any integer | `vdfmax` | $N_\text{uphill}$ | [Uphill limit](#uphill-limit-uphill_max) |
| `inertia_correction` | `true` | `false` | `halfstepback` | – | [Half step back](#half-step-back-inertia_correction) |
| `delay_initial` | `true` | `false` | `initialdelay` | – | [Initial delay](#initial-delay-delay_initial) |
| `integrator` | `:semi_implicit_euler` | `:velocity_verlet` | `integrator` | – | [Integrator](#integrator-integrator) |
| `damping` | `nothing` | any `DampedDynamics` damping ([§8](08-damping.md)) | – | – | [No damping](#no-damping-or-drag) |
| `drag` | `nothing` | `StokesDrag(...)` ([§8](08-damping.md)) | – | – | [No damping](#no-damping-or-drag) |

$\Delta t_\text{start}$ is the starting step, set by `pack(timestep = ...)`
([§12](12-time-step.md)), not by `FIRE`. Every value in the table except `damping` and
`drag` is a LAMMPS FIRE 2.0 default [Guenole2020] [LAMMPSminmodify].

## Model

### Symbols

On this page $P$ is the **power**, not the pressure, and $\alpha$ is FIRE's **mixing
coefficient**, not the contact-law exponent of [§2](02-default-packing.md) (both clashes
are listed in [notation.md](notation.md)).

| Symbol | Meaning |
|---|---|
| $\mathbf x$ | all particle coordinates stacked into one vector (length $ND$ for $N$ particles in $D$ dimensions) |
| $\mathbf v = \dot{\mathbf x}$ | all velocities, stacked the same way |
| $E(\mathbf x)$ | elastic energy, the sum of the contact energies $U(\delta)$ of [§2](02-default-packing.md) |
| $\mathbf F = -\nabla E$ | all elastic forces, stacked |
| $\mathbf M$ | diagonal mass matrix (particle masses, [§4](04-mass.md)) |
| $\hat{\mathbf F} = \mathbf F/\lvert\mathbf F\rvert$ | unit vector along the force |
| $\lvert\cdot\rvert$ | Euclidean norm of the whole stacked vector |
| $P = \mathbf F\cdot\mathbf v$ | power |
| $\Delta t$ | current time step; $\Delta t_\text{start}$, $\Delta t_\text{max}$, $\Delta t_\text{min}$ its start, maximum and minimum |
| $\alpha$ | mixing coefficient, between 0 and 1 |
| $N_+$, $N_-$ | counts of consecutive steps with $P > 0$ and with $P \le 0$ |
| $i$ | step index, counted from the start of the run |
| $\tau = \sqrt{m/k}$ | time unit ([§2](02-default-packing.md), [§12](12-time-step.md)) |

The vectors are global: FIRE uses one power, one $\alpha$ and one $\Delta t$ for the
whole packing, not one per particle.

### The continuous equation

[Bitzek2006] write FIRE as a modified equation of motion (their Eq. 1, in our
symbols)

$$\dot{\mathbf v}(t) = \mathbf M^{-1}\mathbf F(t) - s(t)\,\lvert\mathbf v(t)\rvert\left[\hat{\mathbf v}(t) - \hat{\mathbf F}(t)\right],$$

where $s(t) \ge 0$ is a rate (1/time). The first term is Newtonian dynamics. The second
turns the velocity toward the force without changing its magnitude to first order.
The sources call this rate $\gamma(t)$; it is renamed $s$ here because in SoftPack
$\gamma$ is a dashpot coefficient. The power decides what happens next: [Guenole2020]
"Uphill motion is avoided by computing the power P(t) = F(x(t))·v(t) and setting the
velocity to zero whenever P(t) ≤ 0."

### One FIRE 2.0 step

FIRE 2.0 is Algorithm 2 of [Guenole2020] with the integrator of their Appendix A.
Start: $\mathbf v = 0$, $\alpha = \alpha_\text{start}$, $\Delta t = \Delta t_\text{start}$,
$N_+ = N_- = 0$, $\mathbf F = \mathbf F(\mathbf x)$. Each step $i = 1, 2, \dots$:

**1. Power.** $P = \mathbf F\cdot\mathbf v$.

**2. Downhill ($P > 0$).** $N_+ \leftarrow N_+ + 1$, $N_- \leftarrow 0$. If
$N_+ > N_\text{delay}$:

$$\Delta t \leftarrow \min\left(f_\text{inc}\,\Delta t,\ \Delta t_\text{max}\right), \qquad \alpha \leftarrow f_\alpha\,\alpha .$$

**3. Uphill ($P \le 0$), the restart rule.** $N_+ \leftarrow 0$,
$N_- \leftarrow N_- + 1$. If $N_- > N_\text{uphill}$, stop: the run is returned with
`converged = false` ([§6](06-packing-that-does-not-converge.md)). Otherwise, unless
`delay_initial` is on and $i < N_\text{delay}$:

$$\Delta t \leftarrow f_\text{dec}\,\Delta t \ \ \text{only if}\ \ f_\text{dec}\,\Delta t \ge \Delta t_\text{min}, \qquad \alpha \leftarrow \alpha_\text{start}.$$

Then, with `inertia_correction` on, step back; in every case stop:

$$\mathbf x \leftarrow \mathbf x - \tfrac12\,\Delta t\,\mathbf v, \qquad \mathbf v \leftarrow 0,$$

and evaluate $\mathbf F(\mathbf x)$ again at the moved positions.

**4. Integrate and mix** (semi-implicit Euler, the default). With $\mathbf v$ and
$\mathbf F$ the values at the start of this stage:

$$\mathbf v' = \mathbf v + \Delta t\,\mathbf M^{-1}\mathbf F, \qquad \mathbf v_\text{new} = \begin{cases} (1-\alpha)\,\mathbf v' + \alpha\,\lvert\mathbf v\rvert\,\hat{\mathbf F} & P > 0,\\ \mathbf v' & P \le 0,\end{cases} \qquad \mathbf x_\text{new} = \mathbf x + \Delta t\,\mathbf v_\text{new}.$$

**5. New forces and convergence.** $\mathbf F \leftarrow \mathbf F(\mathbf x_\text{new})$;
apply SoftPack's convergence test ([§5](05-convergence-criterion.md)).

The first step always takes the uphill branch: $\mathbf v = 0$ at the start, so
$P = 0$. With `delay_initial` on this costs nothing (the half step back moves nothing,
and $\Delta t$ and $\alpha$ are kept); without it, FIRE would halve $\Delta t$ on the
very first step. **SoftPack note**, from Algorithm 2.

The same step as pseudocode, with SoftPack's keyword names:

```text
x, F = x0, F(x0);  v = 0;  alpha = mixing_coefficient;  dt = dt_start
dt_max = timestep_max * dt_start;  dt_min = timestep_min * dt_start
n_down = 0;  n_up = 0
for i = 1, 2, ..., steps_max
    P = dot(F, v)
    if P > 0
        n_down += 1;  n_up = 0
        if n_down > delay
            dt = min(timestep_grow * dt, dt_max)
            alpha = mixing_shrink * alpha
        end
        mix = true;  speed = norm(v)            # |v| before the kick
    else                                        # P <= 0: uphill, restart
        n_down = 0;  n_up += 1
        if n_up > uphill_max: return (converged = false)
        if !(delay_initial && i < delay)
            if timestep_shrink * dt >= dt_min: dt = timestep_shrink * dt
            alpha = mixing_coefficient
        end
        if inertia_correction: x = x - 0.5 * dt * v   # uses the new dt
        v = 0;  F = F(x)
        mix = false
    end
    v = v + dt * F ./ m                         # semi-implicit Euler: kick
    if mix: v = (1 - alpha) * v + alpha * speed * F / norm(F)
    x = x + dt * v                              # drift with the new velocity
    F = F(x)
    if converged(x, F): return (converged = true)   # §5
end
return (converged = false)                      # steps_max reached, §5 and §6
```

With `integrator = :velocity_verlet` (Algorithm 6 of [Guenole2020]) stage 4 becomes a
half kick, the mixing, a drift and a second half kick with the new force:

$$\mathbf v' = \mathbf v + \tfrac12\Delta t\,\mathbf M^{-1}\mathbf F(\mathbf x), \quad \mathbf v' \leftarrow (1-\alpha)\,\mathbf v' + \alpha\,\lvert\mathbf v\rvert\,\hat{\mathbf F} \ \ (P>0), \quad \mathbf x_\text{new} = \mathbf x + \Delta t\,\mathbf v', \quad \mathbf v_\text{new} = \mathbf v' + \tfrac12\Delta t\,\mathbf M^{-1}\mathbf F(\mathbf x_\text{new}).$$

Three details of the step come from the LAMMPS implementation [LAMMPSminfire] rather
than from the paper's printed algorithms; SoftPack has not yet decided them (see
[Open questions](#open-questions)):

- The mixing acts on the kicked velocity $\mathbf v'$. Algorithm 4 of [Guenole2020]
  prints the first term as $(1-\alpha)\,\mathbf v(t)$, which would discard the kick;
  their Algorithms 5 and 6 and the LAMMPS code apply it to the updated velocity.
- The mixing magnitude is $\lvert\mathbf v\rvert$ from the start of the step, before the
  kick (LAMMPS). Algorithms 5 and 6 of [Guenole2020] use the norm of the updated
  velocity.
- After a half step back, the forces are evaluated again at the moved positions before
  the kick (LAMMPS). This costs one extra force evaluation per uphill step.

### FIRE 2.0 compared with the 2006 algorithm

[Bitzek2006] give the original rules F1–F5 (quoted from the authors' copy): "F3: if P >
0 and the number of steps since P was negative is larger than N_min, increase the time
step ∆t → min(∆t·f_inc, ∆t_max) and decrease α → α·f_α" and "F4: if P ≤ 0, decrease
time step ∆t → ∆t· f_dec, freeze the system v → 0 and set α back to α_start". FIRE 2.0
differs in these ways [Guenole2020]:

| | FIRE (2006) | FIRE 2.0 (SoftPack default) |
|---|---|---|
| Smallest step | none | $\Delta t_\text{min} = 0.02\,\Delta t_\text{start}$ |
| Uphill limit | none | stop after $N_\text{uphill} = 2000$ consecutive uphill steps |
| Half step back | no | yes, $\mathbf x \leftarrow \mathbf x - \tfrac12\Delta t\,\mathbf v$ |
| Initial delay | no | no $\Delta t$ shrink or $\alpha$ reset during the first $N_\text{delay}$ steps |
| Where the mixing is done | before the MD step (F2) | inside the integrator, after the kick |
| Parameters | $N_\text{min} = 5$, $\alpha_\text{start} = 0.1$ | $N_\text{delay} = 20$, $\alpha_\text{start} = 0.25$ |

[Guenole2020] describe two of these as "Adjustments for improved stability": "The
first adjustment consists of delaying the increase of ∆t and decrease α(t) for a few
steps after P(t) becomes negative. The second adjustment is to perform the mixing of
velocity and force vectors (v → (1−α)v + αF̂(x)|v|) just before the last part of the
time integration scheme, instead of at the beginning of the step."

## Derivations

### The power is minus the rate of change of the energy

By the chain rule,

$$\frac{dE}{dt} = \nabla E\cdot\dot{\mathbf x} = -\mathbf F\cdot\mathbf v = -P .$$

$P > 0$ means the energy is falling (downhill motion); $P \le 0$ means it is rising or
the system is at rest. This is why FIRE tests the sign of $P$ and nothing else.

### The mixing step is an Euler step of the steering term

Take one explicit Euler step of length $\Delta t$ of the steering term alone, using
$\lvert\mathbf v\rvert\,\hat{\mathbf v} = \mathbf v$:

$$\mathbf v \leftarrow \mathbf v - s\,\Delta t\,\lvert\mathbf v\rvert\left(\hat{\mathbf v} - \hat{\mathbf F}\right) = (1 - s\,\Delta t)\,\mathbf v + s\,\Delta t\,\lvert\mathbf v\rvert\,\hat{\mathbf F}.$$

This is the mixing rule with $\alpha = s\,\Delta t$, as [Bitzek2006] state: the mixing
results "from an Euler-discretization of the last term in eq. (1) with time step ∆t and
α = γ∆t" (their $\gamma$ is our $s$). Checked numerically: the two expressions agree to
round-off for random vectors. **SoftPack note.**

### Mixing never speeds the system up, and it raises the power

Let $\mathbf u = (1-\alpha)\,\mathbf v + \alpha\,\lvert\mathbf v\rvert\,\hat{\mathbf F}$ with
$0 \le \alpha \le 1$. By the triangle inequality,

$$\lvert\mathbf u\rvert \le (1-\alpha)\,\lvert\mathbf v\rvert + \alpha\,\lvert\mathbf v\rvert = \lvert\mathbf v\rvert,$$

so the mixing never adds kinetic energy. Its power is

$$\mathbf F\cdot\mathbf u = (1-\alpha)\,\mathbf F\cdot\mathbf v + \alpha\,\lvert\mathbf v\rvert\,\lvert\mathbf F\rvert \quad\Longrightarrow\quad \mathbf F\cdot\mathbf u - \mathbf F\cdot\mathbf v = \alpha\left(\lvert\mathbf v\rvert\,\lvert\mathbf F\rvert - \mathbf F\cdot\mathbf v\right) \ge 0$$

by the Cauchy–Schwarz inequality, with equality only when $\mathbf v$ already points
along $\mathbf F$. The mixing turns the motion toward steepest descent without adding
energy. Checked on $10^5$ random vectors (dimensions 2 to 19, random $\alpha$): no case
increased the speed or lowered the power beyond round-off. **SoftPack note.**

### How fast the step grows and the mixing fades

After a restart the step grows only once $N_+ > N_\text{delay}$, by $f_\text{inc}$ per
downhill step, until it reaches $\Delta t_\text{max}$. Starting from
$\Delta t_\text{start}$ this takes

$$n_\text{grow} = \left\lceil \frac{\ln(\Delta t_\text{max}/\Delta t_\text{start})}{\ln f_\text{inc}} \right\rceil = \left\lceil \frac{\ln 10}{\ln 1.1} \right\rceil = \lceil 24.16 \rceil = 25$$

growth steps (the 25th is cut to $\Delta t_\text{max}$ by the $\min$), so at least
$N_\text{delay} + n_\text{grow} = 20 + 25 = 45$ consecutive downhill steps. The mixing
coefficient shrinks on the same steps, $\alpha_n = \alpha_\text{start} f_\alpha^{\,n}$
after $n$ of them, and keeps shrinking after $\Delta t$ has reached $\Delta t_\text{max}$.
It halves every $\ln 2/(-\ln f_\alpha) = 68.97$ steps. **SoftPack note.**

### The smallest step is a floor, not a clamp

Algorithm 2 of [Guenole2020] shrinks the step only if the result stays at or above
$\Delta t_\text{min}$ ("if ∆tf_dec ≥ ∆t_min then ∆t ← ∆tf_dec"); otherwise it leaves it
unchanged. It does not set $\Delta t \leftarrow \max(f_\text{dec}\Delta t, \Delta t_\text{min})$.
From $\Delta t_\text{start}$ with no growth in between, the allowed shrinks satisfy
$0.5^n \ge 0.02$, that is $n \le \ln 0.02/\ln 0.5 = 5.64$: five shrinks, down to
$\Delta t_\text{start}/32 = 0.03125\,\Delta t_\text{start}$. Steps closer to
$\Delta t_\text{min}$ are reachable only after growth: the smallest value of
$1.1^a\,0.5^b \ge 0.02$ with $a \le 25$ is $0.02026$. The step never goes below
$\Delta t_\text{min}$. **SoftPack note** (computed).

### Why half a step back

With semi-implicit Euler the last move was $\mathbf x(t) - \mathbf x(t-\Delta t) = \Delta t\,\mathbf v(t)$. If $P$ turned non-positive during that move, the minimum along
the direction of motion lies somewhere inside it. [Guenole2020]: "One could correct
overshoot by moving backwards for one entire step ∆t and then re-starting the motion
at time t−∆t. This will undo the uphill motion as expected, but could keep the
trajectory too far from where P(t) = 0. A less aggressive correction is to move
backward for half a timestep (0.5∆t)." Without further information the midpoint
halves the largest possible error. **SoftPack note.**

In Algorithm 2 (line 28) and in LAMMPS [LAMMPSminfire] the step back uses $\Delta t$
**after** the shrink of stage 3. With $f_\text{dec} = 0.5$ the system therefore moves
back by a quarter of the last displacement; during the initial delay, or when the
shrink is skipped at $\Delta t_\text{min}$, it moves back by half.

### Stability of the integrator at the largest step

For one undamped mode $\ddot x = -\omega^2 x$, a semi-implicit Euler step with
$h = \omega\,\Delta t$ maps $(x, \dot x/\omega)$ by

$$\begin{pmatrix} x \\ \dot x/\omega \end{pmatrix}_{n+1} = \begin{pmatrix} 1-h^2 & h \\ -h & 1 \end{pmatrix}\begin{pmatrix} x \\ \dot x/\omega \end{pmatrix}_{n},$$

with determinant 1 and trace $2 - h^2$. Both eigenvalues have modulus 1 when
$\lvert 2 - h^2\rvert < 2$, so the step is stable for $\omega\,\Delta t < 2$ (at $h = 2$
the amplitude grows linearly; above it, exponentially). Velocity Verlet has the same
trace and the same limit. Checked by iteration: $h = 1.9$ stays bounded, $h = 2.01$
blows up. FIRE's mixing cannot destabilize the step, because it never increases the
speed (above). **SoftPack note.**

## Defaults and their reasons

`FIRE()` uses the FIRE 2.0 defaults of LAMMPS, listed in Table 1 of [Guenole2020]:
"Arguments of the command min_modify in LAMMPS that define the parameters of the FIRE
2.0 minimization method. Default values are in brackets." The current LAMMPS manual
lists the same values [LAMMPSminmodify]: "For the fire style, the option defaults are
integrator = eulerimplicit, tmax = 10.0, tmin = 0.02, delaystep = 20, dtgrow = 1.1,
dtshrink = 0.5, alpha0 = 0.25, alphashrink = 0.99, vdfmax = 2000, halfstepback = yes
and initialdelay = yes." LAMMPS's `fire` style is FIRE 2.0 [LAMMPSminstyle]: "This
style correspond to an optimized version described in (Guenole) that include
different time integration schemes and default parameters."

### Starting step

```julia
pack(timestep = CollisionTime(fraction = 1/50))
```

**Decision** ([§12](12-time-step.md)). FIRE starts at the dynamics time step,
$\Delta t_\text{start} = t_\text{col}/50$, and adapts from there.

- [Guenole2020] "In any case, we recommend to set the simulation timestep (command
  timestep in LAMMPS) to the same value as in MD at low temperature."
- [LAMMPSminstyle] "For fire, the default timestep is recommended to be equal to the
  one you would normally use for dynamics simulations."

### Largest step (`timestep_max`)

```julia
pack(algorithm = FIRE(timestep_max = 10))
```

**Decision.** $\Delta t_\text{max} = 10\,\Delta t_\text{start}$.

- Table 1 of [Guenole2020], `tmax` (10.0): "The maximum timestep is tmax × ∆t_start".
- The same factor as the 2006 rule of thumb, [Bitzek2006] "From a typical MD
  simulation time step ∆t_MD one can obtain an initial rough estimate of ∆t_max ∼ 10·
  ∆t_MD."
- Its range: [Guenole2020] "tmax can be reduced to improve the stability but should
  range from 2 to 12, and alpha0 should range from 0.10 to 0.25."
- With SoftPack's defaults it stays inside the integrator's stability limit
  ([Worked numbers](#worked-numbers)). **SoftPack note.**

### Smallest step (`timestep_min`)

```julia
pack(algorithm = FIRE(timestep_min = 0.02))
```

**Decision.** $\Delta t_\text{min} = 0.02\,\Delta t_\text{start}$, a floor that a shrink
may not cross ([derivation](#the-smallest-step-is-a-floor-not-a-clamp)).

- Table 1 of [Guenole2020], `tmin` (0.02): "The minimum timestep is tmin × ∆t_start".

### Delay (`delay`)

```julia
pack(algorithm = FIRE(delay = 20))
```

**Decision.** After an uphill step, wait until more than 20 consecutive downhill steps
have passed before the step grows and the mixing coefficient shrinks.

- Table 1 of [Guenole2020], `delaystep` (20): "Number of steps to wait after P < 0
  before increasing ∆t". In Algorithm 2 the same test also delays the shrink of
  $\alpha$.
- Why a delay at all: [Bitzek2006] "A short ‘latency’ time of N_min MD steps before
  accelerating the dynamics is important for the stability of the algorithm." The
  2006 value was $N_\text{min} = 5$.

### Growth and shrink factors

```julia
pack(algorithm = FIRE(timestep_grow = 1.1))
pack(algorithm = FIRE(timestep_shrink = 0.5))
```

**Decision.** The step grows by $f_\text{inc} = 1.1$ per downhill step after the delay
and shrinks by $f_\text{dec} = 0.5$ at each uphill step.

- Table 1 of [Guenole2020]: `dtgrow` (1.1) "Factor by which ∆t is increased",
  `dtshrink` (0.5) "Factor by which ∆t is decreased". The same values as in 2006,
  [Bitzek2006] "N_min = 5, f_inc = 1.1, f_dec = 0.5, α_start = 0.1 and f_α = 0.99".
- What they should satisfy, [Bitzek2006] (footnote 20): "f_inc larger than but near to
  one (avoid too fast acceleration); f_dec smaller than one but much larger than zero
  (avoid too heavy slowing down)".

### Mixing coefficient and its shrink factor

```julia
pack(algorithm = FIRE(mixing_coefficient = 0.25))
pack(algorithm = FIRE(mixing_shrink = 0.99))
```

**Decision.** $\alpha$ starts at $\alpha_\text{start} = 0.25$, is reset to it at every
uphill step, and is multiplied by $f_\alpha = 0.99$ at each downhill step after the
delay.

- Table 1 of [Guenole2020]: `alpha0` (0.25) "Coefficient for mixing velocity and force
  vectors", `alphashrink` (0.99) "Factor by which α is decreased".
- The measured range, [Guenole2020] (their parameter study): "best values lie in a
  range from 0.10 to 0.25". 0.25 is the top of it; the 2006 value was 0.1.
- What they should satisfy, [Bitzek2006] (footnote 20): "α_start larger than, but near
  to zero (avoid too heavy damping); f_α smaller than, but near to one (mixing is
  efficient some time after restart)."

### Uphill limit (`uphill_max`)

```julia
pack(algorithm = FIRE(uphill_max = 2000))
```

**Decision.** Stop when the count of consecutive uphill steps exceeds 2000, and return
the packing with `converged = false` ([§6](06-packing-that-does-not-converge.md)).

- Table 1 of [Guenole2020], `vdfmax` (2000): "Exit after vdfmax consecutive iterations
  with P(t) < 0". Algorithm 2 tests $N_- > N_\text{uphill}$, so the run stops at the
  2001st consecutive uphill step.
- What it catches, [Guenole2020]: "This could happen when the system is stuck in a
  narrow valley, bouncing back and forth from the walls but never reaching the
  bottom." LAMMPS warns [LAMMPSminmodify]: "Note that in this case the system will NOT
  have reached your minimization criteria."
- Returning the packing flagged, where LAMMPS ends the minimization: **SoftPack
  choice**, to match [§6](06-packing-that-does-not-converge.md).

### Half step back (`inertia_correction`)

```julia
pack(algorithm = FIRE(inertia_correction = true))
```

**Decision.** At every uphill step, move back by $\tfrac12\Delta t\,\mathbf v$ before
zeroing the velocities.

- `inertia_correction` is the name [Guenole2020] give it: LAMMPS `halfstepback`, "yes
  activates the inertia correction" (Table 1). The reason is the overshoot quoted
  under [Why half a step back](#why-half-a-step-back).

### Initial delay (`delay_initial`)

```julia
pack(algorithm = FIRE(delay_initial = true))
```

**Decision.** During the first `delay` steps of the run, an uphill step still zeroes
the velocities (and steps back), but does not shrink $\Delta t$ or reset $\alpha$.

- Table 1 of [Guenole2020], `initialdelay`: "yes activates the initial delay in
  modifying ∆t and α". Algorithm 2, line 22: "if not (initialdelay and i < N_delay)".
- Why it matters: the first step always has $P = 0$ (the velocities start at zero), so
  without the initial delay FIRE would halve $\Delta t$ and reset $\alpha$ at once
  ([One FIRE 2.0 step](#one-fire-20-step)). **SoftPack note.**
- The delay before the step can grow needs no switch at the start: $N_+$ starts at 0,
  so growth waits $N_\text{delay}$ steps anyway.

### Integrator (`integrator`)

```julia
pack(algorithm = FIRE(integrator = :semi_implicit_euler))
```

**Decision.** Semi-implicit (symplectic) Euler: kick, then drift with the new velocity,

$$\mathbf v_{n+1} = \mathbf v_n + \Delta t\,\mathbf M^{-1}\mathbf F(\mathbf x_n), \qquad \mathbf x_{n+1} = \mathbf x_n + \Delta t\,\mathbf v_{n+1},$$

with the mixing between the two. `:velocity_verlet` is the option.

- [Guenole2020] "Hence we recommend the usage of FIRE 2.0 with an Euler Implicit
  integrator." Their "Euler Implicit" is the semi-implicit, or symplectic, Euler
  scheme: LAMMPS calls `eulerimplicit` "symplectic Euler" [LAMMPSminmodify].
- Why a symplectic scheme: [Guenole2020] "Symplectic schemes like Euler semi-implicit
  (also called symplectic Euler), Leapfrog or Velocity Verlet are more robust against
  varying timesteps", and in their summary "A non-symplectic scheme like Euler explicit
  should not be used."

### No damping or drag

```julia
pack(algorithm = FIRE(damping = nothing, drag = nothing))
```

**Decision** ([§8](08-damping.md)). FIRE runs without contact damping or Stokes drag.

- FIRE removes energy by steering and by zeroing the velocities: [Guenole2020] "the
  velocities are reset to zero at the beginning of the pseudo-dynamic run and also
  periodically during the run in FIRE 2.0". **SoftPack choice**; both settings accept
  the same values as for `DampedDynamics` ([§7](07-algorithms-and-combinations.md):
  every combination is allowed).

## Options

### Velocity Verlet

```julia
pack(algorithm = FIRE(integrator = :velocity_verlet))
```

The half-kick form in [One FIRE 2.0 step](#one-fire-20-step). One extra half kick per
step, same stability limit $\omega\,\Delta t < 2$. In the tests of [Guenole2020] it
"performs slightly better than the others in problems 1, 3 and 5, but not in problems
2 and 4", with stability problems in some cases; that is why it is not the default.
LAMMPS also offers `leapfrog` and `eulerexplicit` [LAMMPSminmodify]; SoftPack offers
neither.

### Other parameter values

Every parameter takes any value. [Guenole2020] give the useful ranges: `tmax` from 2
to 12 and `alpha0` from 0.10 to 0.25 (quoted above), and "Generally, large values of
tmax will benefit from lower values of alpha0, around 0.10 – 0.15." Lowering
`timestep_max` trades speed for stability.

### Switching off the FIRE 2.0 additions

```julia
pack(algorithm = FIRE(inertia_correction = false, delay_initial = false))
```

Removes the half step back and the initial delay. LAMMPS lists the settings that make
its FIRE "behave similarly to the previous version" [LAMMPSminmodify]:
`integrator eulerexplicit tmax 10.0 tmin 0.0 delaystep 5 dtgrow 1.1 dtshrink 0.5
alpha0 0.1 alphashrink 0.99 vdfmax 100000 halfstepback no initialdelay no`. In SoftPack
keywords this is
`FIRE(timestep_min = 0.0, delay = 5, mixing_coefficient = 0.1, uphill_max = 100000, inertia_correction = false, delay_initial = false)`,
except the explicit Euler integrator, which SoftPack does not offer. **SoftPack note**
(a keyword mapping, not a decision).

### Damping or drag with FIRE

```julia
pack(algorithm = FIRE(damping = ContactDamping(normal = 0.98), drag = nothing))
```

Allowed ([§7](07-algorithms-and-combinations.md), [§8](08-damping.md)); the dashpot and
drag forces are added to the elastic forces. Not needed for FIRE to stop.

## Worked numbers

Defaults: `Hookean(stiffness = 1.0)`, `EqualMass(1.0)`, so $k = 1$, $m = 1$, the pair
mass $M_n = m/2$ and $\tau = \sqrt{m/k} = 1$. Computed in Python. **SoftPack note.**

| Quantity | Formula | Value |
|---|---|---|
| Collision time | $t_\text{col} = \pi\sqrt{M_n/k}$ ([§12](12-time-step.md)) | $2.2214\,\tau$ |
| Starting step | $\Delta t_\text{start} = t_\text{col}/50$ | $0.044429\,\tau$ |
| Largest step | $\Delta t_\text{max} = 10\,\Delta t_\text{start} = t_\text{col}/5$ | $0.44429\,\tau$ |
| Smallest step | $\Delta t_\text{min} = 0.02\,\Delta t_\text{start} = t_\text{col}/2500$ | $8.8858\times10^{-4}\,\tau$ |
| Smallest step reached from $\Delta t_\text{start}$ by shrinks alone | $\Delta t_\text{start}/32$ | $1.3884\times10^{-3}\,\tau$ |
| Growth steps from $\Delta t_\text{start}$ to $\Delta t_\text{max}$ | $\lceil\ln 10/\ln 1.1\rceil$ | 25 |
| Downhill steps from a restart to $\Delta t_\text{max}$ | $N_\text{delay} + 25$ | 45 |
| $\alpha$ after 25 growth steps | $0.25 \times 0.99^{25}$ | 0.1945 |
| Steps for $\alpha$ to halve | $\ln 2/(-\ln 0.99)$ | 68.97 |
| Steering rate at the start | $s = \alpha_\text{start}/\Delta t_\text{start}$ | $5.63/\tau$ |
| One contact at $\Delta t_\text{max}$ | $\omega_c\,\Delta t_\text{max} = \pi/5$, $\omega_c = \sqrt{k/M_n}$ | 0.628 |
| Fastest packing mode at $\Delta t_\text{max}$, 2D ($z = 4$) | $\sqrt{z}\,\omega_c\,\Delta t_\text{max}$ | 1.257 |
| Fastest packing mode at $\Delta t_\text{max}$, 3D ($z = 6$) | $\sqrt{z}\,\omega_c\,\Delta t_\text{max}$ | 1.539 |

The last three rows use the estimate of [§8](08-damping.md) that the fastest vibration
of a packing is at most about $\sqrt{z}$ times faster than one contact. All are below the
stability limit $\omega\,\Delta t = 2$, so with the default contact law and masses the
largest FIRE step stays stable without damping. For `Hertzian` contacts the margin
depends on the stiffness at the largest overlap ([§12](12-time-step.md)).

The pseudocode above was run on a test energy with four decoupled modes of stiffness
1, 0.1, 0.01 and 0.001 ($m = 1$, $\Delta t_\text{start} = \pi/50$): it reached a
largest force below $10^{-10}$ in under 1000 steps, with and without the half step
back. This checks the pseudocode, not FIRE's speed on packings. **SoftPack note.**

## Open questions

- **Mixing details.** Which velocity the mixing magnitude uses ($\lvert\mathbf v\rvert$
  before the kick, as in LAMMPS, or after it, as in Algorithms 5 and 6 of
  [Guenole2020]) is not in the design doc. Neither is what happens when
  $\mathbf F = 0$ ($\hat{\mathbf F}$ undefined; LAMMPS drops the force term when
  $\lvert\mathbf F\rvert^2 \le 10^{-20}$ [LAMMPSminfire]).
- **Friction and rotation.** With friction on, FIRE must also move rotations. Whether
  the power includes the torques ($P = \sum_i \mathbf F_i\cdot\mathbf v_i + \sum_i \mathbf T_i\cdot\boldsymbol\omega_i$)
  and how spins enter the global norm $\lvert\mathbf v\rvert$ is not designed. FIRE +
  friction is non-standard ([§7](07-algorithms-and-combinations.md)). [Bitzek2006]
  warn that the algorithm "assumes that all degrees of freedom are comparable. All the
  velocities should be on the same scale, which for hetero-nuclear systems can be
  roughly achieved by setting all the atom masses equal." SoftPack's default
  `EqualMass` does this; `Density` masses and spins do not.
- **Displacement cap.** LAMMPS also limits how far any particle moves in one FIRE step
  [LAMMPSminmodify]: "For the quickmin and fire minimization styles, the dmax setting
  is how far any atom can move in a single iteration (timestep)" (default `dmax` = 0.1
  distance units). The design doc has no such cap.
- **Damping and drag inside FIRE.** Whether $P$ uses the total force (elastic plus
  dashpot plus drag) or the elastic force only, when `damping` or `drag` is set.
- **Reaching the target pressure.** How FIRE is combined with the box or the
  compression protocol is not designed (design doc, status line).
- **Exact restarts.** [§6](06-packing-that-does-not-converge.md) requires a stopped and
  restarted run to end with the same packing. For FIRE the file must then hold
  $\mathbf v$, $\Delta t$, $\alpha$, $N_+$, $N_-$ and the step index $i$ (which
  `delay_initial` uses), and a restart must not start a new initial delay or reset
  $\Delta t$ to $\Delta t_\text{start}$. **SoftPack note**, derived from §6 and
  Algorithm 2.
- **Parameter checks.** LAMMPS rejects `tmax < tmin`, `dtgrow < 1` and `dtshrink > 1`
  [LAMMPSminfire]. The design doc says "any value".

## Related pages

- [§2 Default packing](02-default-packing.md): FIRE is the default algorithm.
- [§5 Convergence criterion](05-convergence-criterion.md): SoftPack's stopping test
  replaces LAMMPS's force-norm test inside FIRE.
- [§6 A packing that does not converge](06-packing-that-does-not-converge.md):
  `converged = false`, restarts.
- [§7 Algorithms and combinations](07-algorithms-and-combinations.md): FIRE with
  friction.
- [§8 Damping](08-damping.md): FIRE's `damping` and `drag`.
- [§12 Time step](12-time-step.md): the starting step.
- [§0 Every default at a glance](00-every-default-at-a-glance.md),
  [Notation](notation.md), [References](references.md).

## References

- **[Bitzek2006]** Erik Bitzek, Pekka Koskinen, Franz Gähler, Michael Moseler, Peter Gumbsch (2006). *Structural Relaxation Made Simple*. Physical Review Letters **97**, 170201. [doi:10.1103/physrevlett.97.170201](https://doi.org/10.1103/physrevlett.97.170201).
- **[Guenole2020]** Julien Guénolé, Wolfram G. Nöhring, Aviral Vaid, Frédéric Houllé, Zhuocheng Xie, Aruna Prakash, Erik Bitzek (2020). *Assessment and optimization of the fast inertial relaxation engine (fire) for energy minimization in atomistic simulations and its implementation in lammps*. Computational Materials Science **175**, 109584. [doi:10.1016/j.commatsci.2020.109584](https://doi.org/10.1016/j.commatsci.2020.109584).
- **[LAMMPSminfire]** Julien Guénolé, Erik Bitzek, LAMMPS developers. *LAMMPS source code: src/min_fire.cpp*. <https://github.com/lammps/lammps/blob/9ce13d52969247824d3e2575c3672e6605d7da9e/src/min_fire.cpp>. Commit 9ce13d5 (2026-07-10). Accessed 2026-11-20.
- **[LAMMPSminmodify]** LAMMPS developers. *LAMMPS documentation: min_modify command*. <https://docs.lammps.org/min_modify.html>. Accessed 2026-11-20.
- **[LAMMPSminstyle]** LAMMPS developers. *LAMMPS documentation: min_style command*. <https://docs.lammps.org/min_style.html>. Accessed 2026-11-20.
