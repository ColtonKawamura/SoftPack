# Notation

Every symbol used in the design doc and the wiki, with its units in SoftPack's
reduced units (small diameter $d = 1$, contact stiffness $k = 1$, particle mass
$m = 1$; see [§2](02-default-packing.md) and [§4](04-mass.md)). Each page also defines
its symbols where they first appear.

## Conventions

- **$\gamma$ is a dashpot coefficient**, force per velocity. It is never a rate.
- **Rates** (inverse time) are $r$ for contact dashpots, with $\gamma = m_\text{eff}\,r$,
  and $a$ for Stokes drag.
- **Rayleigh damping** is written $\boldsymbol\Gamma = a\mathbf M + b\mathbf K$: $a$ is the
  mass-proportional constant (Stokes drag), $b$ the stiffness-proportional one.
- **$c$ and $C$ mean wave speed only**, never damping. SoftPack does not use them.
- Quotes keep the source's own symbols, even where they clash with these. The text
  around the quote says what the source's symbol is in SoftPack's notation, for
  example Silbert et al.'s rate $\gamma_n$, which is our $r_n$.

## Geometry and packing

| Symbol | Meaning | Units |
|---|---|---|
| $D$ | spatial dimension (2 or 3) | – |
| $N$ | number of particles | – |
| $d$ | small-particle diameter (the length unit) | $d$ |
| $d_i$, $R_i$ | diameter and radius of particle $i$ | $d$ |
| $r_{ij}$ | center-to-center distance of particles $i$ and $j$ | $d$ |
| $\delta_{ij}$ | overlap, $\delta_{ij} = (d_i + d_j)/2 - r_{ij}$ (a contact if $\delta_{ij} > 0$) | $d$ |
| $\hat{\mathbf n}$, $\hat{\mathbf t}$ | contact unit normal (from $i$ to $j$) and unit tangent | – |
| $\varphi$, $\varphi_c$ | packing fraction, and its value at jamming | – |
| $z$ | contacts per particle | – |
| $\Omega$ | system area (2D) or volume (3D) | $d^D$ |

## Contact forces

| Symbol | Meaning | Units |
|---|---|---|
| $k$ | contact stiffness constant (the force unit for Hookean contacts) | $k$ |
| $\alpha$ | contact-law exponent, $U(\delta) = (k/\alpha)\,\delta^{\alpha}$: 2 for Hooke, 5/2 for Hertz | – |
| $U$ | contact potential energy | $k\,d^{2}$ (Hooke) |
| $f_{ij}$, $f_n$ | normal contact force, $f = k\,\delta^{\alpha-1}$ | $k\,d$ (Hooke) |
| $\langle f_n\rangle$ | mean normal contact force over all contacts | $k\,d$ |
| $k_n$, $k_t$ | normal and tangential contact stiffness | $k$ |
| $F_n^\text{el}$, $F_t^\text{el}$ | elastic normal and tangential contact forces | $k\,d$ |
| $\mu$ | Coulomb friction coefficient | – |
| $\nu$ | Poisson ratio of the particle material (`Mindlin`) | – |

## Stress and pressure

| Symbol | Meaning | Units |
|---|---|---|
| $\sigma_{\alpha\beta}$ | stress tensor (virial form, [§2](02-default-packing.md)) | $k\,d^{2-D}$ |
| $P$ | pressure, $P = \tfrac1D\operatorname{tr}\boldsymbol\sigma$ | $k\,d^{2-D}$ |
| $P_\text{target}$ | target pressure | $k\,d^{2-D}$ |

## Mass and time

| Symbol | Meaning | Units |
|---|---|---|
| $m$, $m_i$ | particle mass (the mass unit for `EqualMass`) | $m$ |
| $I_i$ | moment of inertia of particle $i$ | $m\,d^2$ |
| $M_n$ | normal effective mass, $1/M_n = 1/m_i + 1/m_j$ | $m$ |
| $M_t$ | tangential effective mass, $1/M_t = 1/m_i + 1/m_j + R_i^2/I_i + R_j^2/I_j$ | $m$ |
| $m_\text{eff}$ | pair (normal) effective mass in the rate conventions, equal to $M_n$ | $m$ |
| $\tau$ | time unit, $\tau = \sqrt{m/k}$ | $\tau$ |
| $t_\text{col}$ | binary collision time ([§12](12-time-step.md)) | $\tau$ |
| $\Delta t$ | integration time step | $\tau$ |

## Damping and modes

| Symbol | Meaning | Units |
|---|---|---|
| $\gamma$, $\gamma_n$, $\gamma_t$ | dashpot coefficient (normal, tangential): force per velocity | $\sqrt{k m}$ |
| $\gamma_\text{crit}$ | critical coefficient, $\gamma_\text{crit} = 2\sqrt{k M}$ for that direction | $\sqrt{k m}$ |
| $\zeta$ | damping ratio, $\zeta = \gamma/\gamma_\text{crit}$ | – |
| $r$, $r_n$, $r_t$ | contact damping rate, $\gamma = m_\text{eff}\,r$ (`ViscousRate`, `RelativeVelocityDamping`) | $1/\tau$ |
| $a$, $a_v$, $a_s$ | Stokes drag rate (on velocity, on spin): the $a\mathbf M$ term | $1/\tau$ |
| $b$, $b_t$ | stiffness-proportional constant, $b = \gamma/k$ per contact (tangential $b_t = \gamma_t/k_t$) | $\tau$ |
| $\boldsymbol\Gamma$ | damping matrix | $\sqrt{k m}$ |
| $\mathbf M$ | mass matrix | $m$ |
| $\mathbf K$, $\mathbf K_0$ | stiffness matrix (Hessian), and its unstressed part | $k$ |
| $\mathbf K_t$ | tangential-spring part of $\mathbf K_0$ | $k$ |
| $\mathbf K_\perp$ | contact sum with the tangential projector $\mathbf I - \hat{\mathbf n}\hat{\mathbf n}^\top$ (frictionless; no spring behind it) | $k$ |
| $\ell$ | mode index | – |
| $\omega_\ell$, $\lvert v_\ell\rangle$ | undamped mode angular frequency and unit (mass-weighted) eigenvector | $1/\tau$, – |
| $\lambda_\ell$ | damped eigenvalue, $\mathbf r(t) \propto e^{\lambda_\ell t}$ | $1/\tau$ |
| $\beta_\ell$ | mode decay rate, $\beta_\ell = -\operatorname{Re}\lambda_\ell$ | $1/\tau$ |
| $\zeta_\ell$ | mode damping ratio, $\zeta_\ell = \beta_\ell/\omega_\ell$ | – |
| $\omega_c$ | single-contact angular frequency, $\omega_c = \sqrt{k_n/M_n}$ | $1/\tau$ |
| $e$ | restitution coefficient | – |

## Convergence

| Symbol | Meaning | Units |
|---|---|---|
| $\mathbf F_i$, $\mathbf T_i$ | net force and net torque on particle $i$ | $k\,d$, $k\,d^2$ |
| $\epsilon_F$ | force (and torque) tolerance, `tolerance` | – |
| $\epsilon_P$ | pressure tolerance, `pressure_tolerance` | – |
| $\epsilon_K$ | kinetic-energy tolerance (option) | – |
| $E_i^\text{kin}$ | kinetic energy of particle $i$ | $k\,d^2$ |

FIRE's own parameters (mixing parameter, time-step factors, delay) are listed on
[§14](14-fire-settings.md).

## Symbols with two meanings

These clash between sources. Each page says which meaning it uses.

| Symbol | Meanings |
|---|---|
| $\alpha$ | contact-law exponent; FIRE mixing parameter ([§14](14-fire-settings.md)); a tensor index in $\sigma_{\alpha\beta}$ |
| $\sigma$ | stress tensor $\sigma_{\alpha\beta}$; contact distance $\sigma_{ij}$ in [OHern2003]'s potential |
| $d$ | small diameter; the dimension in [OHern2003]'s quotes (SoftPack writes $D$) |
| $P$ | pressure; the FIRE power $\mathbf F\cdot\mathbf v$ in some sources ([§14](14-fire-settings.md) says which) |
| $\beta$ | mode decay rate $\beta_\ell$; a tensor index in $\sigma_{\alpha\beta}$ |
| $\boldsymbol\omega$ | particle spin (bold, a vector); $\omega$ (plain) an angular frequency |
| $\gamma$ | SoftPack: coefficient. LAMMPS, [Silbert2001] and [Santos2024]: a rate (our $r$) |
