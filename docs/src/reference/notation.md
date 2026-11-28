# Notation

*Up:* [SoftPack](../index.md)

The symbol tables, with units per contact law. They are the same as the wiki's
[Notation](https://github.com/ColtonKawamura/SoftPack/wiki/Notation) page; the option
pages define their own symbols where they first appear.

Every symbol used in the design doc and the wiki, with its units in SoftPack's
reduced units (reference diameter $d_\text{ref} = 1$, contact stiffness $k = 1$, reference mass
$m_\text{ref} = 1$; see [§3](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit), [§2](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing) and [§4](https://github.com/ColtonKawamura/SoftPack/wiki/Mass)).
The Units columns write $d$ and $m$ for one $d_\text{ref}$ and one $m_\text{ref}$. Each page also defines
its symbols where they first appear.

The units depend on the contact law through the exponent $\alpha$ of
$U(\delta) = (k/\alpha)\,\delta^{\alpha}$ ($\alpha = 2$ for Hooke, $5/2$ for Hertz;
[§2](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#contact-law)). The columns give the general form and then the
Hookean value; the Hertzian one follows by setting $\alpha = 5/2$:

| Quantity | General | Hooke ($\alpha = 2$) | Hertz ($\alpha = 5/2$) |
|---|---|---|---|
| force | $k\,d^{\alpha-1}$ | $k\,d$ | $k\,d^{3/2}$ |
| energy | $k\,d^{\alpha}$ | $k\,d^2$ | $k\,d^{5/2}$ |
| pressure, stress | $k\,d^{\alpha-D}$ | $k\,d^{2-D}$ | $k\,d^{5/2-D}$ |
| time | $\sqrt{m\,d^{2-\alpha}/k}$ | $\sqrt{m/k}$ | $\sqrt{m\,d^{-1/2}/k}$ |

At the default $k = d = 1$ every column reads 1, which is why a run quotes numbers
without a unit and a comparison between the two laws can be made at the same target
pressure. Away from it the same target number means a different overlap, and so
different physics, under the two laws. **SoftPack note.**

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
| $d_\text{ref}$ | reference diameter, the length unit and the one particle scale ([§3](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit)): the small diameter for `Bidisperse`, the mean diameter for `UniformPolydisperse`, the one diameter for `Monodisperse`, the mean of the list for `particles_diameters`; 1 by default | $d$ |
| $\langle d\rangle$ | mean of the particles' diameters, $\frac1N\sum_i d_i$: 1.2 for the default mixture, $d_\text{ref}$ for `Monodisperse`, $d_\text{ref}$ up to sampling scatter for `UniformPolydisperse` | $d$ |
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
| $U$ | contact potential energy | $k\,d^{\alpha}$: $k\,d^2$ (Hooke) |
| $f_{ij}$, $f_n$ | normal contact force, $f = k\,\delta^{\alpha-1}$ | $k\,d^{\alpha-1}$: $k\,d$ (Hooke) |
| $\langle f_n\rangle$ | mean normal contact force over all contacts | $k\,d$ |
| $k_n$, $k_t$ | normal and tangential contact stiffness | $k$ |
| $F_n^\text{el}$, $F_t^\text{el}$ | elastic normal and tangential contact forces | $k\,d$ |
| $\mu$ | Coulomb friction coefficient | – |
| $\nu$ | Poisson ratio of the particle material (`Mindlin`) | – |

## Stress and pressure

| Symbol | Meaning | Units |
|---|---|---|
| $\sigma_{\alpha\beta}$ | stress tensor (virial form, [§2](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing)) | $k\,d^{\alpha-D}$: $k\,d^{2-D}$ (Hooke) |
| $P$ | pressure, $P = \tfrac1D\operatorname{tr}\boldsymbol\sigma$ | $k\,d^{\alpha-D}$: $k\,d^{2-D}$ (Hooke) |
| $P_\text{target}$ | target pressure | $k\,d^{\alpha-D}$: $k\,d^{2-D}$ (Hooke) |

## Mass and time

| Symbol | Meaning | Units |
|---|---|---|
| $m_\text{ref}$ | reference mass, the mass unit and the one mass scale ([§4](https://github.com/ColtonKawamura/SoftPack/wiki/Mass#reference-mass)): the `EqualMass` value, or the mean mass for `Density` and given masses; 1 by default | $m$ |
| $m$, $m_i$ | particle mass; $m$ is the common mass of `EqualMass` | $m$ |
| $I_i$ | moment of inertia of particle $i$, $I_i = \kappa\,m_i R_i^2$ | $m\,d^2$ |
| $\kappa$ | inertia coefficient of a uniform particle: $1/2$ for a disk (2D), $2/5$ for a sphere (3D). [Agnolin2007]'s Hertz stiffness parameter $\kappa$ in [§2](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing) is a different quantity, in their notation | – |
| $M_n$ | normal effective mass, $1/M_n = 1/m_i + 1/m_j$ | $m$ |
| $M_t$ | tangential effective mass, $1/M_t = 1/m_i + 1/m_j + R_i^2/I_i + R_j^2/I_j$ | $m$ |
| $m_\text{eff}$ | pair (normal) effective mass in the rate conventions, equal to $M_n$ | $m$ |
| $\tau$ | time unit, $\tau = \sqrt{m_\text{ref}\,d_\text{ref}^{2-\alpha}/k}$: $\sqrt{m_\text{ref}/k}$ (Hooke) | $\tau$ |
| $t_\text{col}$ | binary collision time ([§12](https://github.com/ColtonKawamura/SoftPack/wiki/Time-step)) | $\tau$ |
| $\Delta t$ | integration time step | $\tau$ |

## Damping and modes

| Symbol | Meaning | Units |
|---|---|---|
| $\gamma$, $\gamma_n$, $\gamma_t$ | dashpot coefficient (normal, tangential): force per velocity | $\sqrt{k m}$ (Hooke) |
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
[§14](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings).

## Symbols with two meanings

These clash between sources. Each page says which meaning it uses.

| Symbol | Meanings |
|---|---|
| $\alpha$ | contact-law exponent; FIRE mixing parameter ([§14](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings)); a tensor index in $\sigma_{\alpha\beta}$ |
| $\sigma$ | stress tensor $\sigma_{\alpha\beta}$; contact distance $\sigma_{ij}$ in [OHern2003]'s potential |
| $d$ | one $d_\text{ref}$ in the Units columns; the dimension in [OHern2003]'s quotes (SoftPack writes $D$) |
| $P$ | pressure. FIRE's power $\mathbf F\cdot\mathbf v$ is $W$ here; the FIRE papers and LAMMPS call it $P$ ([§14](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings)) |
| $\beta$ | mode decay rate $\beta_\ell$; a tensor index in $\sigma_{\alpha\beta}$ |
| $\boldsymbol\omega$ | particle spin (bold, a vector); $\omega$ (plain) an angular frequency |
| $\gamma$ | SoftPack: coefficient. LAMMPS, [Silbert2001] and [Santos2024]: a rate (our $r$) |
