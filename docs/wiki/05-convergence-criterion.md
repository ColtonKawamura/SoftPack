# 5. Convergence (stopping) criterion

Design decision source: [design-references.md §5](../design-references.md#5-convergence-stopping-criterion).
Status: design stage (no engine code yet).

## Summary

`pack()` stops when the packing is in mechanical equilibrium at the target pressure.
The default test, `RelativeForce`, has two parts. First, every particle's net force,
and with friction its net torque, must be small compared with the typical contact
force. Second, the contact pressure must be within `pressure_tolerance` of the target.
The same rule applies to frictionless and frictional packings. The tolerance is
relative to the mean contact force, so it means the same thing in any units and at
any pressure. `steps_max` caps every run; a run that reaches it is returned unfinished
(§6). The options are the Leiden absolute-acceleration rule (`LeidenAcceleration`), a
kinetic-energy bound (`KineticEnergy`), a check that zeroes the velocities and watches
whether motion comes back (`RestartTest`), or any user function.

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| `convergence` | `RelativeForce(tolerance = 1e-8)` | `LeidenAcceleration(tolerance = 1e-10)`, `KineticEnergy(tolerance = 1e-8)`, `RestartTest()`, any function of the packing state that returns true when done | [Force and torque test](#force-and-torque-test-relativeforce), [Options](#options) |
| `pressure_tolerance` | `1e-4` | any value | [Pressure test](#pressure-test-pressure_tolerance) |
| `steps_max` | `10^7` | any value | [Step cap](#step-cap-steps_max) |

## Model

### Symbols

| Symbol | Meaning |
|---|---|
| $i = 1,\dots,N$ | particles; $N$ is their number |
| $D$ | dimension (2 or 3) |
| $d_i$, $R_i = d_i/2$ | diameter and radius of particle $i$ |
| $\langle d\rangle = \frac1N\sum_i d_i$ | mean diameter |
| $d$ | small diameter, the length unit of `Bidisperse` (§3) |
| $m_i$, $I_i$ | mass and moment of inertia of particle $i$ |
| $c$ | a contact between two particles; $N_c$ is the number of contacts |
| $\delta_c$ | overlap of contact $c$ |
| $f_n^c$ | elastic normal force of contact $c$, $f_n^c = k\,\delta_c^{\,\alpha-1}$ (§2) |
| $\mathbf f^{c}\_{t}$ | elastic tangential (friction) force of contact $c$ (zero without friction) |
| $\langle f_n\rangle = \frac{1}{N_c}\sum_c f_n^c$ | mean normal contact force over all contacts |
| $\ell^c$ | center-to-center distance of the two particles of contact $c$ |
| $\Omega$ | box area (2D) or volume (3D) |
| $\mathbf F_i$, $\mathbf T_i$ | net elastic force and net elastic torque on particle $i$ |
| $\epsilon_F$, $\epsilon_P$, $\epsilon_K$ | `tolerance` of `RelativeForce`, `pressure_tolerance`, `tolerance` of `KineticEnergy` |
| $a_\text{tol}$ | `tolerance` of `LeidenAcceleration` (an acceleration) |
| $k$, $\tau$ | contact stiffness and time unit $\tau = \sqrt{m/k}$ |
| $\varphi$, $z$ | packing fraction and contacts per particle |

### Net force and torque

For particle $i$ the net elastic force and torque are sums over its contacts,

$$\mathbf F_i = \sum_{c \ni i}\left(f_n^c\,\hat{\mathbf n}_{c,i} + \mathbf f^{c}_{t,i}\right), \qquad \mathbf T_i = \sum_{c \ni i} \mathbf b_{c,i} \times \mathbf f^{c}_{t,i},$$

where $\hat{\mathbf n}\_{c,i}$ is the unit normal pointing into particle $i$ (the
repulsion pushes $i$ away from its partner), $\mathbf f^{c}\_{t,i}$ is the tangential force
that contact $c$ exerts on $i$, and $\mathbf b_{c,i}$ is the lever arm from the center of
$i$ to the contact point, of length close to $R_i$. In 2D, $\mathbf T_i$ is a scalar (the
out-of-plane component). Without friction every $\mathbf f_t$ is zero, so every
$\mathbf T_i$ is zero. Dashpot and drag forces are not included: the test is on the
elastic forces, which are all that remain once the packing is at rest.

### The default test

With $\epsilon_F$ = `tolerance` and $\epsilon_P$ = `pressure_tolerance`, `pack()`
reports `converged = true` when all of these hold:

$$\max_i \left|\mathbf F_i\right| < \epsilon_F\,\langle f_n\rangle,$$

$$\max_i \left|\mathbf T_i\right| < \epsilon_F\,\langle f_n\rangle\,\langle d\rangle \quad \text{(with friction)},$$

$$\left|P - P_\text{target}\right| \le \epsilon_P\,P_\text{target},$$

with $P$ the elastic contact pressure of §2,

$$P = \frac{1}{D\,\Omega}\sum_c f_n^c\,\ell^c .$$

If $10^7$ steps (`steps_max`) pass first, the run stops with `converged = false` (§6).

### The options' tests

**`LeidenAcceleration`.** With $a_\text{tol}$ = `tolerance`, every particle's
acceleration must be below $a_\text{tol}$. For the translational part this is

$$\max_i \frac{\left|\mathbf F_i\right|}{m_i} < a_\text{tol}.$$

**`KineticEnergy`.** With $\epsilon_K$ = `tolerance`, the mean kinetic energy per
particle must satisfy

$$\frac{1}{N}\sum_i E_i^\text{kin} < \epsilon_K\,P\,d^{D}, \qquad E_i^\text{kin} = \tfrac12 m_i\left|\mathbf v_i\right|^2,$$

with $\mathbf v_i$ the velocity of particle $i$. Whether the spin energy
$\tfrac12 I_i\,\omega_i^2$ ($\omega_i$ the spin) is included is not stated in the design
doc; see [Open questions](#open-questions).

**`RestartTest`.** Set every velocity to zero, keep running, and accept if neither the
kinetic energy nor the unbalanced forces grow back.

**Any function.** `pack()` calls it with the packing state and stops when it returns
`true`.

## Derivations

### The relative tolerance is scale-free

Every net force is a sum of contact forces, and $\langle f_n\rangle$ is an average of the
same contact forces. Multiply every contact force by one factor $\lambda$, as a change of
force unit or of `stiffness` does at fixed geometry ($k \to \lambda k$):

$$\mathbf F_i \to \lambda\,\mathbf F_i, \qquad \langle f_n\rangle \to \lambda\,\langle f_n\rangle \qquad\Longrightarrow\qquad \frac{\max_i|\mathbf F_i|}{\langle f_n\rangle} \ \text{unchanged}.$$

A change of length unit by a factor $s$ (positions, diameters and box all times $s$)
multiplies every overlap by $s$. For any power law $f = k\,\delta^{\alpha-1}$ it multiplies
every contact force by the same factor $s^{\alpha-1}$, so the force ratio is again
unchanged. Torques pick up one more factor $s$ from the lever arm, and so does
$\langle f_n\rangle\langle d\rangle$, so the torque ratio is unchanged too. Masses do not
enter: the test uses static forces only. So `RelativeForce(tolerance = 1e-8)` means the
same thing for any `stiffness`, `mass`, length unit, and for Hooke or Hertz contacts.
**SoftPack note** (our derivation). Checked numerically on a 64-disk configuration:
multiplying lengths by 3.7 and stiffness by 11 left the ratio unchanged to 5 parts in
$10^{12}$ (Hookean) and to all printed digits (Hertzian).

An absolute rule is not scale-free. The acceleration $\mathbf F_i/m_i$ scales with the
force unit over the mass unit, so a fixed $a_\text{tol}$ is a relative tolerance

$$\epsilon_\text{eff} = \frac{m\,a_\text{tol}}{\langle f_n\rangle}$$

that depends on the units and on the pressure (at fixed units, $\langle f_n\rangle$ is
proportional to $P$, see below). The relative test asks for the same relative precision
at every pressure; the allowed absolute residual shrinks with $P$.

### Mean contact force from the pressure

The pressure fixes $\langle f_n\rangle$. Write the sum in $P$ as $N_c$ times an average,
use $N_c = zN/2$, and neglect the correlation between $f_n^c$ and $\ell^c$:

$$P = \frac{N_c\,\langle f_n\,\ell\rangle}{D\,\Omega} \approx \frac{z\,N\,\langle f_n\rangle\,\langle\ell\rangle}{2\,D\,\Omega}.$$

In 2D the packing fraction is $\varphi = N\pi\langle d^2\rangle/(4\Omega)$, in 3D
$\varphi = N\pi\langle d^3\rangle/(6\Omega)$. Eliminating $\Omega$,

$$\text{2D: } \langle f_n\rangle \approx \frac{\pi\,\langle d^2\rangle\,P}{z\,\varphi\,\langle\ell\rangle}, \qquad \text{3D: } \langle f_n\rangle \approx \frac{\pi\,\langle d^3\rangle\,P}{z\,\varphi\,\langle\ell\rangle}.$$

For equal particles ($\langle\ell\rangle \approx d$) these are $P = z\varphi\langle f_n\rangle/(\pi d)$ in 2D,
the relation used in §2, and $P = z\varphi\langle f_n\rangle/(\pi d^2)$ in 3D, which is
[Agnolin2007]'s Eq. 22, $P = z\Phi\langle N\rangle/(\pi a^2)$, with their $\langle N\rangle$ our
$\langle f_n\rangle$ and their $a$ the diameter. **SoftPack note** (our conversion).

Two consequences:

- At acceptance the pressure test holds, so $P > 0$ and $\langle f_n\rangle > 0$: the
  relative test is never divided by zero on an accepted packing.
- [Agnolin2007]'s force tolerance $10^{-4}a^2P$ is, with $z \approx 6$ and
  $\Phi \approx 0.64$, $10^{-4} \times z\Phi/\pi \approx 1.22\times10^{-4}\,\langle f_n\rangle$:
  their rule is a relative tolerance of about $10^{-4}$ in SoftPack's form.

Checked on a probe packing (2D, $N = 256$, the default mixture, $P = 9.9992\times10^{-5}$,
see [Worked numbers](#worked-numbers)): the measured $\langle f_n\rangle = 1.176\times10^{-4}$;
the formula with the measured $z = 3.84$, $\varphi = 0.8418$, $\langle\ell\rangle = 1.218$ gives
$1.182\times10^{-4}$ (0.5% high, from the neglected correlation between $f$ and $\ell$), and with the round
values $z = 4$, $\varphi = 0.84$, $\langle\ell\rangle = 1.2$ it gives $1.153\times10^{-4}$.

### The torque scale

If the unbalanced torque on particle $i$ came from one tangential force $f$ at its
surface, $|\mathbf T_i| = R_i\,f$. The torque bound
$|\mathbf T_i| < \epsilon_F\langle f_n\rangle\langle d\rangle$ therefore allows a tangential
imbalance

$$f < \frac{2\,\langle d\rangle}{d_i}\,\epsilon_F\,\langle f_n\rangle,$$

that is $2.4\,\epsilon_F\langle f_n\rangle$ for the small particles and
$1.71\,\epsilon_F\langle f_n\rangle$ for the large ones of the default mixture
($\langle d\rangle = 1.2$). The torque test is a factor of about 2 looser than the force
test, as with [Gilabert2007]'s force times diameter. **SoftPack note** (our
derivation).

### What the residual force says about energy, positions and contact forces

Near a minimum $\mathbf x^{\ast}$ of the elastic energy $U$, write the configuration as
$\mathbf x = \mathbf x^{\ast} + \mathbf u$, with $\mathbf x$ the vector of all particle
coordinates. To second order,

$$U(\mathbf x) = U^* + \tfrac12\,\mathbf u^\top\mathbf K\,\mathbf u, \qquad \mathbf F = -\mathbf K\,\mathbf u,$$

with $\mathbf K$ the stiffness matrix (Hessian) and $\mathbf F$ the stacked net forces.
Eliminating $\mathbf u$,

$$\Delta U \equiv U - U^* = \tfrac12\,\mathbf F^\top\mathbf K^{+}\mathbf F,$$

with $\mathbf K^+$ the pseudo-inverse ($\mathbf F$ has no component along the zero modes,
because it equals $-\mathbf K\mathbf u$). For equal masses $m$ the nonzero eigenvalues of
$\mathbf K$ are $m\,\omega_\ell^2$, with $\omega_\ell$ the vibration frequencies, so

$$\frac{|\mathbf F|^2}{2\,m\,\omega_\text{max}^2} \le \Delta U \le \frac{|\mathbf F|^2}{2\,m\,\omega_\text{min}^2}, \qquad |\mathbf u| \le \frac{|\mathbf F|}{m\,\omega_\text{min}^2}.$$

The criterion bounds the largest particle force, not the Euclidean norm, and

$$\max_i|\mathbf F_i| \le |\mathbf F| \le \sqrt{N}\,\max_i|\mathbf F_i|.$$

Three consequences follow (**SoftPack note**, our derivation).

**The energy converges quadratically.** Halving the force residual quarters
$\Delta U$. On the probe packing ($\omega_\text{min} = 0.0170/\tau$, $m = 1$,
$\langle f_n\rangle = 1.176\times10^{-4}$) the default tolerance gives
$\Delta U/N \le (\epsilon_F\langle f_n\rangle)^2/(2m\omega_\text{min}^2) = 2.4\times10^{-21}$,
which is $1.2\times10^{-13}$ of the elastic energy per particle
($U/N = 2.0\times10^{-8}$), about 540 machine epsilons. An energy-change test would have
to resolve differences that small; the force test works with numbers of order
$\epsilon_F$. This is why force criteria are used to stop minimizations.

**Positions converge more slowly along soft modes.** The residual displacement can be
$1/(m\omega_\text{min}^2)$ times the residual force:
$|\mathbf u|/\sqrt N \le \epsilon_F\langle f_n\rangle/(m\omega_\text{min}^2) = 4.1\times10^{-9}$
diameters on the probe packing.

**Contact forces are known less precisely than net forces.** A residual along mode
$\ell$ (unit mass-weighted vector $|v_\ell\rangle$, frequency $\omega_\ell$) changes the
contact forces by

$$\frac{|\delta\mathbf f|}{|\mathbf F|} = \frac{\sqrt{k\,\langle v_\ell|\mathbf K_0|v_\ell\rangle}}{m\,\omega_\ell^2} \approx \frac{\sqrt{k/m}}{\omega_\ell},$$

with $\mathbf K_0$ the unstressed stiffness matrix (the approximation drops the stress
term of $\mathbf K$). For the softest mode of the probe packing this factor is 73.6
(formula and a finite-difference test agree to 6 digits), and the largest single
contact-force change is 55.6 times the largest net-force residual. With
$\epsilon_F = 10^{-8}$, individual contact forces are therefore resolved to about
$6\times10^{-7}\langle f_n\rangle$ even in this worst case. With a tolerance of $10^{-4}$ (the
[Agnolin2007] and [Gilabert2007] level) the same worst case is about
$6\times10^{-3}\langle f_n\rangle$, above the $10^{-3}\langle f\rangle$ floor of the
`ForceFloor` rattler rule ([§9](09-rattler-rules.md)). This is one reason a tight
relative tolerance matters when small forces are analyzed.

Checked numerically on the probe packing: $\Delta U$ from a direct energy difference
equals $\tfrac12\mathbf F^\top\mathbf K^+\mathbf F$ to 0.1% (displacement $10^{-6}$ along the
softest mode) and to $3\times10^{-7}$ (random direction).

### The pressure tolerance

$|P - P_\text{target}| \le \epsilon_P P_\text{target}$ is a relative bound, scale-free by the
same argument as the force test (in 2D $P/k$, in 3D $P\,d/k$, is unchanged by a change
of units). For Hookean contacts at fixed contact network, $P$ is proportional to the
mean overlap, so the mean overlap is fixed to the same relative precision $\epsilon_P$.
At the defaults the window is $|P - 10^{-4}| \le 10^{-8}$. [Gilabert2007]'s pressure
bound, $10^{-4}F_1/a$ with $F_1 = \max(F_0, Pa)$, is the same relative test for
cohesionless particles: with $F_0 = 0$, $F_1/a = P$, so their bound is $10^{-4}P$.
**SoftPack note** (our conversion).

### What a kinetic-energy test measures

For one vibration mode of frequency $\omega$ ringing with amplitude $A$, the largest
force is $m\omega^2 A$ and the largest kinetic energy $\tfrac12 m\omega^2A^2$. A force bound
gives $A \le F_\text{tol}/(m\omega^2)$, a kinetic-energy bound $A \le \sqrt{2E_\text{tol}/m}/\omega$.
Neither implies the other. A configuration that is not moving but not balanced has no
kinetic energy at all; this happens after every FIRE velocity reset
([§7](07-algorithms-and-combinations.md)). One semi-implicit Euler step from
$\mathbf v = 0$ gives $\mathbf v_i = \Delta t\,\mathbf F_i/m_i$, so with equal masses

$$\frac1N\sum_i E_i^\text{kin} = \frac{\Delta t^2}{2m}\,\frac1N\sum_i|\mathbf F_i|^2,$$

and the kinetic-energy test passes whenever the root-mean-square force is below
$\sqrt{2m\,\epsilon_K P\,d^D}/\Delta t$. At the defaults ($\epsilon_K = 10^{-8}$,
$P = 10^{-4}$, $d = 1$, $m = 1$, starting step $\Delta t = 0.0444\,\tau$) that is
$3.2\times10^{-5} \approx 0.28\,\langle f_n\rangle$; at FIRE's smallest step
($0.02\,\Delta t$) it is about $14\,\langle f_n\rangle$. **SoftPack note** (our derivation).
In one FIRE minimization of the probe system (6,871 steps, ending at
$P = 1.19\times10^{-4}$), the kinetic-energy test alone was met at 1,425 steps at which
the force test failed, with $\max_i|\mathbf F_i|$ up to $0.22\,\langle f_n\rangle$. This is
why [Agnolin2007] use the kinetic-energy bound together with the force and stress
bounds, not instead of them.

### What the restart test measures

Start the linearized motion from rest at displacement $\mathbf u_0$ from the minimum.
Without damping the total energy is conserved, so the kinetic energy that comes back
can never exceed $\Delta U = \tfrac12\mathbf F^\top\mathbf K^+\mathbf F$: the test measures the
excess energy directly. It also separates a minimum from a saddle. At both,
$\mathbf F = 0$ can hold, so no force test can tell them apart; but along a direction
with a negative eigenvalue $-m\kappa^2$ the displacement grows as $e^{\kappa t}$, and the
kinetic energy and forces grow with it. That is what [Agnolin2007] conclude from their
test (quoted below): a stable equilibrium. Along the softest mode, the kinetic energy
peaks a quarter period after the velocities are zeroed,
$\pi/(2\omega_\text{min}) = 92.6\,\tau$ or about 2,100 default steps on the probe packing,
so a shorter watch can miss it. **SoftPack note** (our derivation; the saddle growth was
checked on a one-mode example).

### Floating-point floor of the force residual

Positions are `Float64`. Near a coordinate value $x$ they can only change in steps of
$\mathrm{ulp}(x) = 2^{\lfloor\log_2|x|\rfloor-52}$, so the smallest residual force a minimizer
can reach is of order $k\,\mathrm{ulp}(L)$, with $L$ the largest coordinate (the box side).
On the probe packing ($L = 18.8$, $\mathrm{ulp} = 3.6\times10^{-15}$), FIRE run with no
stopping rule bottomed out at $\max_i|\mathbf F_i| = 3.0\times10^{-11}\langle f_n\rangle$
(median $5.7\times10^{-11}$), that is 1 to 2 $k\,\mathrm{ulp}(L)$, far below $10^{-8}$. The same
packing with every coordinate shifted by 8192 ($\mathrm{ulp} = 1.8\times10^{-12}$) bottomed out
at $2.2\times10^{-8}$ (median $3.9\times10^{-8}$): the default tolerance is then out of
reach. With a floor of about $2k\,\mathrm{ulp}(L)$, `RelativeForce(tolerance = 1e-8)` is
reachable only if $\langle f_n\rangle \gtrsim 2\,\mathrm{ulp}(L)/10^{-8}$. Using the
relation between $P$ and $\langle f_n\rangle$ above, the pressure below which the default cannot be
reached is roughly:

| System | $L$ | $P$ below which $\epsilon_F = 10^{-8}$ is out of reach |
|---|---|---|
| 2D, $N = 256$ | 18.8 | $6\times10^{-7}$ |
| 2D, $N = 10^4$ | 118 | $2\times10^{-6}$ |
| 2D, $N = 10^5$ | 372 | $1\times10^{-5}$ |
| 3D, $N = 10^5$ | 53.5 | $1\times10^{-6}$ |

**SoftPack note**: estimates from our probe (bidisperse 1:1.4; 3D with $z = 6$,
$\varphi = 0.64$, $\langle\ell\rangle = 1.2$); see [Open questions](#open-questions).

### How many steps damped dynamics needs

For `DampedDynamics` with its default `ContactDamping`, every mode decays at
$\beta_\ell = b\,\omega_\ell^2/2$ with $b = 2\zeta/\omega_c$, $\zeta = 0.98$ and
$\omega_c = \sqrt{k/M_n} = \sqrt2/\tau$ for equal masses ([§8](08-damping.md)). The
slowest mode sets the time to shrink the residual from about $\langle f_n\rangle$ to
$\epsilon_F\langle f_n\rangle$:

$$n_\text{steps} \approx \frac{\ln(1/\epsilon_F)}{\beta_\text{min}\,\Delta t}.$$

On the probe packing, $\omega_\text{min} = 0.0211/\tau$ for $\mathbf K_0$, $b = 1.386\,\tau$,
so $\beta_\text{min} = 3.09\times10^{-4}/\tau$; the exact slowest decay of the linearized
equations of motion (stress term included) is $3.11\times10^{-4}/\tau$. With
$\ln(10^8) = 18.4$ and $\Delta t = 0.0444\,\tau$ this is $1.3\times10^{6}$ steps, about 13%
of `steps_max`, for the final settling alone. Near jamming the soft modes slow down:
the crossover frequency $\omega^{\ast}$ scales as $z - z_\text{iso}$ [Henkes2010], and
$z - z_c \propto (\varphi - \varphi_c)^{1/2}$ while $P \propto \varphi - \varphi_c$ for Hookean
contacts [OHern2003], so $\beta_\text{min} \propto \omega^{\ast}2} \propto P$ and the step
count grows as $1/P$ when the soft modes are the slowest. **SoftPack note** (our
derivation and estimate; compression, rearrangements and FIRE are not covered by it).

## Defaults and their reasons

### Force and torque test (`RelativeForce`)

```julia
pack(convergence = RelativeForce(tolerance = 1e-8))
```

**Decision.** Converged when $\max_i|\mathbf F_i| < \epsilon_F\langle f_n\rangle$ and, with
friction, $\max_i|\mathbf T_i| < \epsilon_F\langle f_n\rangle\langle d\rangle$, together with the
pressure test below. One rule for frictionless and frictional packings.

- A tolerance relative to the typical force, as in the Roux group's papers:
  [Agnolin2007] "Calculations are stopped when the net elastic force on each particle
  is below 10^-4 a^2 P, the elastic contributions to the stress components equal the
  prescribed value P with relative error smaller than 10^-4 and the kinetic energy per
  particle is below 10^-8 P a^3." [Gilabert2007] "the net force on each disk is less
  than 10^-4 F_1, and the total moment is lower than 10^-4 F_1 a" (with
  $F_1 = \max(F_0, Pa)$, the typical intergranular force; $F_0$ is their maximum
  tensile contact force, zero without cohesion).
- Why the precision matters: [Gilabert2007] "Due to the frequent occurrence of small
  contact force values, this requires forces to balance with sufficient accuracy."
  The contact-force estimate above shows how much less precise individual contact
  forces are than the net forces.
- Relative, not absolute, so the number means the same thing in any units and at any
  pressure (derivation above).
- The norm is the largest per-particle force. LAMMPS uses the Euclidean norm of all
  forces instead: [Guenole2020] "lammps uses the f2norm criterion that corresponds to
  the Euclidean norm of the 3 × N force vector." and "the f2norm criterion considered
  by lammps can be several order of magnitude stricter than the others." For
  SoftPack's test, $\max_i|\mathbf F_i| \le |\mathbf F| \le \sqrt N\max_i|\mathbf F_i|$, so
  the two differ by at most $\sqrt N$ (16 for $N = 256$). [Guenole2020] also ask that
  the criterion be stated: "This has to be considered when comparing systems relaxed
  with different codes and the exact criterion should be reported in publications."
  SoftPack records the convergence setting in every output (§11).
- The torque scale $\langle f_n\rangle\langle d\rangle$ follows [Gilabert2007]'s force times
  diameter. Their $a$ is the largest diameter: [Gilabert2007] "The maximum diameter, a,
  will be used as unit of length." Using the mean diameter for polydisperse packings
  is a **SoftPack choice**.
- `tolerance = 1e-8`, tighter than the $10^{-4}$ above: provisional **SoftPack
  choice**, to be timed on frictional packings. The worked numbers below show what it
  buys (contact forces to about $10^{-6}\langle f_n\rangle$) and where `Float64` limits it.

### Pressure test (`pressure_tolerance`)

```julia
pack(pressure_tolerance = 1e-4)
```

**Decision.** $|P - P_\text{target}| \le \epsilon_P\,P_\text{target}$, with $P$ the elastic
contact pressure of §2.

- The [Agnolin2007] value above (stress equal to P "with relative error smaller than
  10^-4"). [Gilabert2007] use the same $10^{-4}$ level for the pressure, scaled by their
  typical force $F_1$: [Gilabert2007] "the difference between imposed and measured
  pressure is less than 10^-4 F_1/a", which is $10^{-4}P$ for cohesionless particles
  (derivation above).
- Elastic forces only, as in §2: [Agnolin2007] stop when "the elastic contributions to
  the stress components equal the prescribed value P".

### Step cap (`steps_max`)

```julia
pack(steps_max = 10^7)
```

**Decision.** At most $10^7$ steps per call.

- **SoftPack choice.** A safety cap, not a convergence test: a run that hits it is
  returned with `converged = false` ([§6](06-packing-that-does-not-converge.md)) and
  can be continued with `restart_packing`.
- The value is twice the $5\times10^{6}$ cap of GranEJulia's packer, which SoftPack
  replaces and which stops at a looser force tolerance ($10^{-4}$ against $10^{-8}$
  here). (Checked in GranEJulia's `src/pack.jl`: a hard loop cap of 5,000,000 steps and
  a default frictional force tolerance of `1e-4`.)
- In time units: with the default step $\Delta t = t_\text{col}/50 = 0.0444\,\tau$
  ([§12](12-time-step.md)), $10^7$ steps are $4.4\times10^{5}\,\tau$ of simulated time.
  The damped-dynamics estimate above ($1.3\times10^6$ steps for the probe packing) fits
  with a margin of about 7; FIRE needed far fewer steps on the probe (about
  $1.3\times10^{4}$ in total, see Worked numbers).

## Options

### `LeidenAcceleration`

```julia
pack(convergence = LeidenAcceleration(tolerance = 1e-10))
```

**Decision.** The option's default: every particle's acceleration below $10^{-10}$, the
Leiden rule.

- [Somfai2005] "Our packings are considered to have converged to mechanical
  equilibrium when all grains have acceleration less than 10^-10 in our reduced units".
  [Shundyak2007] builds its packings "As in [16]", reference 16 being [Somfai2005].
- Leiden units: [Somfai2005] "Our unit of length is the average grain diameter." and
  "The unit of mass is set by asserting that the material of the grains has unit
  density."; [Shundyak2007] "our units are such that the mass density, the average
  particle diameter, and the Young's modulus of the grains are 1." The number
  $10^{-10}$ only reproduces the Leiden rule in those units ($E^{\ast} = 1$, mean diameter
  1, density 1).
- When to use it: to reproduce Leiden-protocol packings, in Leiden units.

What it changes: an absolute bound. In SoftPack's default units it is the relative
tolerance $\epsilon_\text{eff} = m\,a_\text{tol}/\langle f_n\rangle$. For the default 2D mixture
($m = 1$, $\langle f_n\rangle \approx 1.15\,P$):

| $P$ | $10^{-3}$ | $10^{-4}$ | $10^{-5}$ | $10^{-6}$ |
|---|---|---|---|---|
| $\epsilon_\text{eff}$ of `LeidenAcceleration(tolerance = 1e-10)` | $8.7\times10^{-8}$ | $8.7\times10^{-7}$ | $8.7\times10^{-6}$ | $8.7\times10^{-5}$ |

It is looser than the default at every pressure in this table, and more so the lower
the pressure. On the probe packing, with the measured $\langle f_n\rangle$, the
$P = 10^{-4}$ value is $8.5\times10^{-7}$. **SoftPack note** (our conversion).

### `KineticEnergy`

```julia
pack(convergence = KineticEnergy(tolerance = 1e-8))
```

**Decision.** The option's default: the mean kinetic energy per particle below
$\epsilon_K\,P\,d^{D}$ ($N$ the number of particles, $d$ the small diameter, $D$ the
dimension). At the defaults the bound is $10^{-12}$ per particle.

- The [Agnolin2007] value above; [Xiong2019] stop each minimization on a maximum
  per-disk kinetic energy: [Xiong2019] "Energy minimization is terminated when K_max <
  10^-20, where K_max is the maximum kinetic energy of one of the disks." SoftPack's
  test uses the mean, which is never larger than the maximum, so it is the looser of
  the two forms.
- What it changes: it bounds motion, not force balance. Used alone it can pass while
  forces are far from balanced, for example right after a FIRE velocity reset
  (derivation above: unbalanced forces up to $0.22\langle f_n\rangle$ passed it in our
  probe). [Agnolin2007] combine it with the force and stress bounds.
- When to use it: as an extra check of rest in damped dynamics, or to match
  minimizations stopped on kinetic energy such as [Xiong2019]'s.

### `RestartTest`

```julia
pack(convergence = RestartTest())
```

**Decision.** The option: zero all velocities, then check that the kinetic energy and
the unbalanced forces do not grow back. It has no settings.

- [Agnolin2007] "On setting all velocities to zero, it is observed that the sample does
  not regain kinetic energy beyond that value, while the unbalanced force level does
  not increase." They conclude: [Agnolin2007] "We have thus a stable equilibrium
  state."
- What it adds: a stability check. It tells a minimum from a saddle, which no force
  test can, and bounds the excess energy $\Delta U$ (derivation above).
- How long to watch is not set; the quarter period of the softest mode is the natural
  scale ([Open questions](#open-questions)).

### Any function

```julia
pack(convergence = my_test)   # my_test(state) returns true when the run is done
```

**Option.** Any function of the packing state that returns true when done
(**SoftPack choice**, so convergence tests are plug-ins like rattler rules, §9).

## Worked numbers

The probe is our own 2D frictionless check (Python, FIRE 2.0 with the LAMMPS
defaults, all-pairs forces), not SoftPack code: $N = 256$, the default 50:50 mixture
of diameters 1 and 1.4, Hookean $k = 1$, $m = 1$, brought to the target pressure by
adjusting the packing fraction.

| Quantity | Value | Source |
|---|---|---|
| Final pressure | $9.9992\times10^{-5}$, relative error $-7.8\times10^{-5}$ (passes $\epsilon_P = 10^{-4}$) | probe |
| $\max_i\lvert\mathbf F_i\rvert/\langle f_n\rangle$ at acceptance | $6.2\times10^{-9}$ (passes $\epsilon_F = 10^{-8}$) | probe |
| $\langle f_n\rangle$ | $1.176\times10^{-4}$ | probe |
| Force threshold $\epsilon_F\langle f_n\rangle$ | $1.18\times10^{-12}$ | probe |
| Torque threshold $\epsilon_F\langle f_n\rangle\langle d\rangle$ | $1.41\times10^{-12}$ | probe |
| $z$ (all particles), $z$ (13 rattlers removed), $\varphi$ | 3.84, 4.04, 0.8418 | probe |
| Pressure window at the defaults | $\lvert P - 10^{-4}\rvert \le 10^{-8}$ | $\epsilon_P P_\text{target}$ |
| Kinetic-energy bound per particle (`KineticEnergy` defaults) | $10^{-12}$ | $\epsilon_K P d^D$ |
| Softest vibration frequency ($\mathbf K$; $\mathbf K_0$) | $0.0170/\tau$; $0.0211/\tau$ | probe |
| Contact-force error over net-force residual (softest mode) | 73.6 (2-norm), 55.6 (largest single contact) | probe |
| Energy error at $\epsilon_F = 10^{-8}$ (worst case) | $\Delta U/U \le 1.2\times10^{-13}$ | derivation + probe |
| Float64 floor of $\max_i\lvert\mathbf F_i\rvert/\langle f_n\rangle$ | $3.0\times10^{-11}$ (box at origin), $2.2\times10^{-8}$ (shifted by 8192) | probe |
| `DampedDynamics` steps to settle by $10^{8}$ | $1.3\times10^{6}$ (13% of `steps_max`) | probe + §8 decay rate |
| FIRE steps on the probe | 2,879 from random positions at $\varphi = 0.86$, then 6,871 + 1,891 + 1,538 to reach $P = 10^{-4}$ | probe |
| `steps_max` in time | $10^7 \times 0.0444\,\tau = 4.4\times10^{5}\,\tau$ | §12 |

## Open questions

- `tolerance = 1e-8` is provisional, to be timed on frictional packings (design doc).
- `Float64` floor: at low pressure and large $N$ the default tolerance can be below what
  `Float64` positions allow (table above). The design doc does not say what happens
  then; the run would end at `steps_max` with `converged = false`. **SoftPack note.**
- The design doc does not say whether a non-default `convergence` (`KineticEnergy`,
  `RestartTest`, a user function) replaces the force test or is added to it, nor
  whether the pressure test still applies. `KineticEnergy` alone is unreliable with
  FIRE (derivation above).
- `LeidenAcceleration`: whether angular accelerations $|\mathbf T_i|/I_i$ also count.
- `KineticEnergy`: whether spin energy counts, and what "the small diameter" $d$ is for
  `UniformPolydisperse` or user-given diameters (the torque test uses
  $\langle d\rangle$ instead).
- `RestartTest`: how long to watch, and what "does not grow back" means numerically.
- How often the test is evaluated (every step or every few steps), and whether it is
  evaluated before or after a FIRE velocity reset.
- How `pack()` reaches the target pressure (initial state and compression protocol)
  is not designed yet; the pressure test depends on it.

## Related pages

- [§2 Default packing](02-default-packing.md): the contact pressure $P$ and the units.
- [§6 A packing that does not converge](06-packing-that-does-not-converge.md):
  `converged = false`, restarts.
- [§7 Algorithms and combinations](07-algorithms-and-combinations.md): FIRE and damped
  dynamics, any convergence test with any algorithm.
- [§8 Damping](08-damping.md): mode decay rates behind the step estimate.
- [§9 Rattler rules](09-rattler-rules.md): `ForceFloor` and `Unresolved`
  (`floor = :tolerance` ties a rattler rule to $\epsilon_F$).
- [§11 Outputs](11-outputs.md): the convergence setting and flag stored in every file.
- [§12 Time step](12-time-step.md): $\Delta t = t_\text{col}/50$.
- [§14 FIRE settings](14-fire-settings.md): FIRE's own stop after `uphill_max` uphill
  moves.
- [Notation](notation.md), [References](references.md).

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[Gilabert2007]** F. A. Gilabert, J.-N. Roux, A. Castellanos (2007). *Computer simulation of model cohesive powders: Influence of assembling procedure and contact laws on low consolidation states*. Physical Review E **75**, 011303. [doi:10.1103/physreve.75.011303](https://doi.org/10.1103/physreve.75.011303).
- **[Guenole2020]** Julien Guénolé, Wolfram G. Nöhring, Aviral Vaid, Frédéric Houllé, Zhuocheng Xie, Aruna Prakash, Erik Bitzek (2020). *Assessment and optimization of the fast inertial relaxation engine (fire) for energy minimization in atomistic simulations and its implementation in lammps*. Computational Materials Science **175**, 109584. [doi:10.1016/j.commatsci.2020.109584](https://doi.org/10.1016/j.commatsci.2020.109584).
- **[Henkes2010]** S. Henkes, M. van Hecke, W. van Saarloos (2010). *Critical jamming of frictional grains in the generalized isostaticity picture*. EPL (Europhysics Letters) **90**, 14003. [doi:10.1209/0295-5075/90/14003](https://doi.org/10.1209/0295-5075/90/14003).
- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
- **[Shundyak2007]** Kostya Shundyak, Martin van Hecke, Wim van Saarloos (2007). *Force mobilization and generalized isostaticity in jammed packings of frictional grains*. Physical Review E **75**, 010301. [doi:10.1103/physreve.75.010301](https://doi.org/10.1103/physreve.75.010301).
- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
- **[Xiong2019]** Fansheng Xiong, Philip Wang, Abram H. Clark, Thibault Bertrand, Nicholas T. Ouellette, Mark D. Shattuck, Corey S. O’Hern (2019). *Comparison of shear and compression jammed packings of frictional disks*. Granular Matter **21**, 109. [doi:10.1007/s10035-019-0964-9](https://doi.org/10.1007/s10035-019-0964-9).
