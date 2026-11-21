# 4. Mass

Design decision source: [design-references.md §4](../design-references.md#4-mass).
Status: design stage (no engine code yet).

## Summary

Every particle has mass 1 by default (`EqualMass(1.0)`), the convention of jamming
studies. The option `Density(1.0; shape = :disc)` sets each mass from a material
density times the particle's area (`:disc`) or volume (`:sphere`), the convention of
DEM codes and the Leiden frictional papers. Masses do not appear in the force-balance
conditions of a static packing, but they set its dynamics: the effective mass of each
contact, the collision time and time step, the contact damping, the time unit, the
mass-dependent stopping tests and the vibration spectrum. Scaling every mass by the
same factor only rescales time; changing the mass *ratios* changes the trajectory, and
with it which packing a run reaches. Per-particle masses are stored in the output so
spectra computed later use the same masses.

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| `mass` | `EqualMass(1.0)` | `Density(1.0; shape = :disc)` (`:sphere` in 3D) | [Equal masses](#equal-masses), [Density masses](#density-masses) |
| `EqualMass` value | `1.0` | any mass | the mass unit |
| `Density` value | `1.0` | any density | mass per area (`:disc`) or per volume (`:sphere`) |
| `Density` `shape` | `:disc` in 2D, `:sphere` in 3D | `:sphere` in 2D | [Density masses](#density-masses) |

## Model

### Particle masses

Particle $i$ has diameter $d_i$ ([§3](03-particle-size-distribution-and-length-unit.md))
and mass $m_i$:

$$\text{EqualMass}(m):\ m_i = m, \qquad \text{Density}(\rho;\ \text{disc}):\ m_i = \rho\,\frac{\pi d_i^{2}}{4}, \qquad \text{Density}(\rho;\ \text{sphere}):\ m_i = \rho\,\frac{\pi d_i^{3}}{6}.$$

$\rho$ is a mass per area for `:disc` and a mass per volume for `:sphere`. For a
bidisperse mixture of diameter ratio $r$ (§3), the large over the small mass is 1
with equal masses, $r^2$ with discs and $r^3$ with spheres: 1.96 and 2.744 for
$r = 1.4$.

### Moments of inertia

With friction the particles also rotate. A uniform disk and a uniform sphere have

$$I_i = c\,m_i R_i^{2}, \qquad c = \tfrac12 \ \text{(disk)}, \qquad c = \tfrac25 \ \text{(sphere)},$$

with $R_i = d_i/2$. The design doc does not state SoftPack's rule for $I_i$, but its
constants imply these values: the matched stiffness ratio
$k_t/k_n = 1/(1 + mR^2/I)$ is 1/3 for disks and 2/7 for spheres
([§13](13-friction-models.md)), which needs $mR^2/I = 2$ and $5/2$.

### Effective masses of a contact

A contact between $i$ and $j$ responds to its normal force with the normal effective
mass $M_n$ and to its tangential force with the tangential effective mass $M_t$
([§8](08-damping.md)):

$$\frac{1}{M_n} = \frac{1}{m_i} + \frac{1}{m_j}, \qquad \frac{1}{M_t} = \frac{1}{m_i} + \frac{1}{m_j} + \frac{R_i^2}{I_i} + \frac{R_j^2}{I_j}.$$

$M_n$ is the pair (reduced) mass, written $m_\text{eff}$ in the rate conventions
([Notation](notation.md)).

### Time unit and contact time scales

- Time unit: $\tau = \sqrt{m/k}$, with $k$ the contact stiffness and $m$ the
  small-particle mass ([§8](08-damping.md)).
- Contact angular frequency and collision time of a Hookean contact
  ([§12](12-time-step.md)): $\omega_c = \sqrt{k/M_n}$, $t_\text{col} = \pi\sqrt{M_n/k}$.
- Contact dashpot at damping ratio $\zeta$ (`ContactDamping`, [§8](08-damping.md)):
  $\gamma_n = 2\zeta\sqrt{k\,M_n}$, and its stiffness-proportional constant
  $b = \gamma_n/k = 2\zeta\sqrt{M_n/k}$.
- Raw-rate dashpot (`ViscousRate`, [§8](08-damping.md)): $\gamma_n = M_n\,r_n$, so
  $b = M_n r_n/k$.

## Derivations

### Normal effective mass and collision time

Let a contact carry the normal force $f$, pushing $i$ and $j$ apart along
$\hat{\mathbf n}\_{ij}$. Then $\ddot{\mathbf r}\_i = -f\hat{\mathbf n}\_{ij}/m_i$ and
$\ddot{\mathbf r}\_j = +f\hat{\mathbf n}\_{ij}/m_j$, so the separation obeys

$$\ddot r_{ij} = f\left(\frac{1}{m_i} + \frac{1}{m_j}\right) = \frac{f}{M_n}.$$

The overlap $\delta = (d_i + d_j)/2 - r_{ij}$ then obeys $M_n\ddot\delta = -f$. For a
Hookean contact $f = k\delta$, an oscillator of angular frequency
$\omega_c = \sqrt{k/M_n}$; a binary collision lasts half a period,
$t_\text{col} = \pi/\omega_c = \pi\sqrt{M_n/k}$.

### Tangential effective mass

Apply a tangential impulse $J\hat{\mathbf t}$ to $i$ at the contact point and
$-J\hat{\mathbf t}$ to $j$. Each center velocity changes by $J/m$, and each spin by
$JR/I$, which moves the contact point by a further $JR^2/I$ along $\hat{\mathbf t}$.
The sliding velocity at the contact therefore changes by

$$\Delta v_t = J\left(\frac{1}{m_i} + \frac{1}{m_j} + \frac{R_i^2}{I_i} + \frac{R_j^2}{I_j}\right) = \frac{J}{M_t}.$$

**SoftPack note**, checked by computing the velocity change of the two contact points
for random masses, radii and contact directions.

### Same shape, any sizes: M_t = M_n/3 or M_n/3.5

With $I = c\,mR^2$, each $R^2/I$ is $1/(c\,m)$, so

$$\frac{1}{M_t} = \left(1 + \frac1c\right)\left(\frac{1}{m_i} + \frac{1}{m_j}\right) = \frac{1 + 1/c}{M_n}: \qquad M_t = \frac{M_n}{3} \ \text{(disks)}, \qquad M_t = \frac{M_n}{3.5} \ \text{(spheres)}.$$

This holds for **any** two disks (or any two spheres), whatever their sizes and masses,
so under both mass conventions (**SoftPack note**; the design doc states it for equal
particles). With `stiffness_ratio = :matched`, $k_t/k_n = 1/(1 + 1/c)$
([§13](13-friction-models.md)), so

$$\omega_t^2 = \frac{k_t}{M_t} = \frac{k_n}{1 + 1/c}\cdot\frac{1 + 1/c}{M_n} = \frac{k_n}{M_n} = \omega_n^2$$

at every contact: the tangential and normal vibrations of a contact stay equally fast
with `Density` masses too.

### Equal masses make contact damping proportional to stiffness

With `EqualMass(m)`, every contact has $M_n = m/2$. So every Hookean contact has the
same $\omega_c$, the same $t_\text{col}$, and with `ContactDamping(normal = ζ)` the same
$\gamma_n$ and the same $b = \gamma_n/k$. The damping matrix is then $b$ times the
unstressed stiffness matrix,

$$\boldsymbol\Gamma = \sum_c \gamma_n\,\mathbf B_c = b\sum_c k\,\mathbf B_c = b\,\mathbf K_0,$$

where $\mathbf B_c = (\mathbf e_i - \mathbf e_j)(\mathbf e_i - \mathbf e_j)^\top \otimes \hat{\mathbf n}\hat{\mathbf n}^\top$
is the contact's normal projector placed on the coordinates of its two particles
($\mathbf e_i$ the $i$-th unit vector of length $N$). Every underdamped mode $\ell$ of angular frequency
$\omega_\ell$ then decays at $\beta_\ell = b\,\omega_\ell^2/2$ without mixing with the
others ([§8](08-damping.md)).

With `Density` masses, $M_n$ differs between small–small, small–large and large–large
contacts, and so does $b$:

$$\frac{b_\text{ll}}{b_\text{ss}} = \sqrt{\frac{M_{n,\text{ll}}}{M_{n,\text{ss}}}} = r^{D_m/2} \ \text{(ContactDamping)}, \qquad \frac{b_\text{ll}}{b_\text{ss}} = \frac{M_{n,\text{ll}}}{M_{n,\text{ss}}} = r^{D_m} \ \text{(ViscousRate)},$$

with $D_m = 2$ for `:disc` and 3 for `:sphere`. For $r = 1.4$: 1.4 and 1.96 (disc), 1.66
and 2.74 (sphere). Then $\boldsymbol\Gamma = \sum_c b_c\,k\,\mathbf B_c$ is no longer a
multiple of $\mathbf K_0$, and the modes mix. This is the design doc's statement in §8:
the proportionality is exact for Hookean contacts and equal masses, while with
`Density` masses $b$ varies from contact to contact.

**SoftPack note**, checked on a random frictionless 2D network (40 particles, 64
contacts, Hookean, $\zeta = 0.98$):

| Masses | $b$ per contact | $\lVert\boldsymbol\Gamma - b\mathbf K_0\rVert / \lVert\boldsymbol\Gamma\rVert$ (best $b$) | largest off-diagonal / diagonal modal damping |
|---|---|---|---|
| `EqualMass(1.0)` | 1.386 at every contact | $10^{-16}$ | $5\times10^{-16}$ |
| `Density(1.0; shape = :disc)` | 1.228 to 1.720 | 0.097 | 0.051 |

With equal masses the computed decay rates match $b\,\omega_\ell^2/2$ to $10^{-8}$.

### Scaling all masses only rescales time

Multiply every mass by the same factor $\lambda$. Measuring time in $\tau = \sqrt{m/k}$,
which grows by $\sqrt\lambda$, removes $\lambda$ from Newton's equations
$m_i\ddot{\mathbf r}\_i = \mathbf F_i$. Every other time in SoftPack's defaults is tied
to $\tau$: the time step is a fraction of $t_\text{col} \propto \sqrt{M_n}$
([§12](12-time-step.md)), FIRE's step limits are multiples of it
([§14](14-fire-settings.md)), contact damping ratios give $\gamma \propto \sqrt{M_n}$,
and rates are in units of $1/\tau$ ([§8](08-damping.md)). The default stopping test
uses forces only ([§5](05-convergence-criterion.md)). So with the defaults the run is
the same in units of $\tau$ and ends in the same packing: the value 1.0 is a pure unit.

**SoftPack note**, checked with a small FIRE implementation (64 frictionless Hookean
disks, the default mixture at fixed $\varphi = 0.86$, same random start): masses 1 and masses 2
with the time step scaled by $\sqrt2$ end in the same packing to $10^{-14}$. The
exceptions are tests with absolute thresholds on mass-dependent quantities:
`LeidenAcceleration` (acceleration $\mathbf F_i/m_i$) and `KineticEnergy`.

### Mass ratios change the packing reached

Changing the mass *ratios* is not a rescaling. FIRE and damped dynamics are inertial:
the path down the energy landscape depends on $\mathbf F_i/m_i$, and with many nearby
energy minima the path decides which one is reached. In the same check, the
same start relaxed with `EqualMass(1.0)` and with `Density(1.0; shape = :disc)` masses
(both to $\max_i|\mathbf F_i| < 10^{-12}$) ended in different minima:

| Masses | energy per particle | contacts |
|---|---|---|
| `EqualMass(1.0)` | $2.53\times10^{-4}$ | 145 |
| `Density(1.0; shape = :disc)` | $5.95\times10^{-5}$ | 131 |

with particles up to 1.3 diameters apart between the two end states (**SoftPack
note**; a quench at fixed $\varphi$, not SoftPack's compression protocol, which is not
designed yet). Each seed can thus give a different packing under the two conventions.
Whether ensemble averages differ was not checked. The mass convention is part of the
protocol and is recorded in every output.

### Spectra

Small vibrations about a packing obey $\mathbf M\ddot{\mathbf u} = -\mathbf K\mathbf u$,
with $\mathbf M$ the diagonal mass matrix (masses, and moments of inertia for
rotations) and $\mathbf K$ the stiffness matrix. The mode frequencies solve
$\mathbf K\mathbf v = \omega^2\mathbf M\mathbf v$, or equivalently are the
eigenvalues of $\mathbf M^{-1/2}\mathbf K\mathbf M^{-1/2}$. The same packing has a
different spectrum under the two conventions; this is why the output stores every
particle's mass.

## Defaults and their reasons

### Equal masses

```julia
pack(mass = EqualMass(1.0))
```

**Decision.** Equal masses, each 1.

- Equal mass is the jamming (soft-sphere) convention: [OHern2003] "... where all
  particles have equal mass m."
- The value 1.0 sets the mass unit: **SoftPack choice**. With the defaults it changes
  nothing but the unit of time ([derivation](#scaling-all-masses-only-rescales-time)).
- Equal masses give every contact the same effective mass, so one collision time, one
  dashpot coefficient and exact stiffness-proportional contact damping
  ([derivation](#equal-masses-make-contact-damping-proportional-to-stiffness)); this
  is one of the conditions the design doc lists for that result in §8 (**SoftPack
  note**).

## Options

### Density masses

```julia
pack(mass = Density(1.0; shape = :disc))
```

**Decision.** The option: mass from a material density times the particle's area
(`shape = :disc`, the default in 2D) or volume (`shape = :sphere`, the default in 3D).

- Density-based mass is the DEM convention: [LAMMPSset] "density/disc value =
  particle density for a 2d disc or ellipse (mass/distance^2 units)"; [Somfai2005]
  "The unit of mass is set by asserting that the material of the grains has unit
  density." That is the reason for the default density 1.0. For spheres, [LAMMPSset]
  "density value = particle density for a sphere or ellipsoid (mass/distance^3
  units)".
- `shape = :disc` in 2D: **SoftPack choice**, because SoftPack's 2D particles are
  disks. `shape = :sphere` in 2D gives the Leiden convention: [Somfai2005] "2D samples
  containing 600 spheres (their centers being confined to a plane)". It is also the
  LAMMPS default: [LAMMPSset] "For 2d, the default is for LAMMPS to model particles
  with a radius attribute as spheres. However, if the density/disc keyword is used,
  then they can be modeled as 2d discs (circles)."
- When to use it: to match DEM or Leiden packings and their dynamics, for example the
  `LeidenAcceleration` stopping rule, whose $10^{-10}$ is meant for Leiden units
  (density 1, mean diameter 1; [§5](05-convergence-criterion.md)). [Somfai2005] "Our
  packings are considered to have converged to mechanical equilibrium when all grains
  have acceleration less than 10^-10 in our reduced units".
- What it changes: mass ratio 1.96 (disc) or 2.744 (sphere) between the default
  sizes, a pair-dependent $M_n$, collision time and dashpot, contact damping that is no
  longer exactly proportional to stiffness, and a different time unit
  ([Worked numbers](#worked-numbers)).

## Worked numbers

Default mixture (diameters 1 and 1.4), stiffness $k = 1$, and $\rho = 1$ for `Density`;
times in units of $\sqrt{(\text{mass unit})/k}$. $t_\text{col} = \pi\sqrt{M_n/k}$,
$\Delta t = t_\text{col}/50$ ([§12](12-time-step.md)) and $b = 2\zeta\sqrt{M_n/k}$ at
$\zeta = 0.98$. Spheres apply to 3D and to `:sphere` in 2D. **SoftPack note**
(computed).

| Masses | Pair | $m_i$, $m_j$ | $M_n$ | $M_t$ | $t_\text{col}$ | $t_\text{col}/50$ | $b$ |
|---|---|---|---|---|---|---|---|
| `EqualMass(1.0)` | any | 1, 1 | 0.5 | 0.1667 (disks), 0.1429 (spheres) | 2.221 | 0.0444 | 1.386 |
| `Density`, `:disc` | small–small | 0.7854, 0.7854 | 0.3927 | 0.1309 | 1.969 | 0.0394 | 1.228 |
| | small–large | 0.7854, 1.5394 | 0.5201 | 0.1734 | 2.266 | 0.0453 | 1.413 |
| | large–large | 1.5394, 1.5394 | 0.7697 | 0.2566 | 2.756 | 0.0551 | 1.720 |
| `Density`, `:sphere` | small–small | 0.5236, 0.5236 | 0.2618 | 0.0748 | 1.607 | 0.0321 | 1.003 |
| | small–large | 0.5236, 1.4368 | 0.3838 | 0.1096 | 1.946 | 0.0389 | 1.214 |
| | large–large | 1.4368, 1.4368 | 0.7184 | 0.2053 | 2.663 | 0.0533 | 1.661 |

| Quantity | `EqualMass(1.0)` | `Density`, `:disc` | `Density`, `:sphere` |
|---|---|---|---|
| large / small mass | 1 | 1.96 | 2.744 |
| mean mass (50:50) | 1 | 1.1624 | 0.9802 |
| time unit $\tau = \sqrt{m_\text{small}/k}$ | 1 | 0.886 | 0.724 |
| $b_\text{ll}/b_\text{ss}$, `ContactDamping` | 1 | 1.4 | 1.657 |
| $b_\text{ll}/b_\text{ss}$, `ViscousRate` | 1 | 1.96 | 2.744 |

The time step uses the smallest effective mass (the small–small pair), so `Density`
masses shorten it by $\sqrt{0.3927/0.5} = 0.886$ (disc) or $\sqrt{0.2618/0.5} = 0.724$
(sphere) relative to equal masses.

## Open questions

- **Moments of inertia.** The design doc does not state how $I_i$ is set, under
  either convention. Uniform bodies ($c = 1/2$ for disks, $2/5$ for spheres) are
  implied by the §8 and §13 constants.
- **Spheres in 2D with friction.** With `Density(shape = :sphere)` in 2D the natural
  inertia is the sphere's, giving $M_t = M_n/3.5$; the doc does not say whether
  `stiffness_ratio = :matched` then gives 2/7 (spheres) or 1/3 (disks). Only 2/7 keeps
  the tangential and normal frequencies equal.
- **`shape = :disc` in 3D** is not discussed.
- **The time unit for non-bidisperse sizes.** $\tau$ uses the small-particle mass,
  which is not defined for `UniformPolydisperse` or given diameters
  ([§3](03-particle-size-distribution-and-length-unit.md#open-questions)).

## Related pages

- [§2 Default packing](02-default-packing.md): units
- [§3 Particle size distribution and length unit](03-particle-size-distribution-and-length-unit.md): diameters
- [§5 Convergence criterion](05-convergence-criterion.md): mass-dependent stopping tests
- [§8 Damping](08-damping.md): effective masses and damping ratios
- [§11 Outputs](11-outputs.md): stored masses
- [§12 Time step](12-time-step.md): collision time
- [§13 Friction models](13-friction-models.md): matched stiffness ratio
- [Notation](notation.md), [References](references.md)

## References

- **[LAMMPSset]** LAMMPS developers. *LAMMPS documentation: set command*. <https://docs.lammps.org/set.html>. Accessed 2026-11-18.
- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
