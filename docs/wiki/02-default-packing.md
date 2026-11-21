# 2. Default packing

Design decision source: [design-references.md §2](../design-references.md#2-default-packing).
Status: design stage (no engine code yet).

## Summary

`pack()` with no arguments makes a two-dimensional packing of 256 frictionless disks:
a 50:50 mixture of two diameters in the ratio 1.4, with Hookean (linear spring)
contacts of stiffness 1, compressed until the contact pressure is $10^{-4}$, and
relaxed with the FIRE minimizer. The small diameter, the contact stiffness and the
particle mass are the units of length, force and mass. The target pressure is then a
pure number, and it says how deeply the particles overlap: about $10^{-4}$ of a
diameter. This page defines the contact law, the packing fraction, the contact number
and the pressure; derives how pressure, contact force, overlap and distance to jamming
are related; and works out the numbers for the defaults.

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| `dimension` | `2` | `3` | [Two dimensions](#two-dimensions), [Three dimensions](#three-dimensions) |
| `particles_count` | `256` | any number ≥ 2 | [256 particles](#256-particles) |
| `particles_size_distribution` | `Bidisperse(diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5)` | `UniformPolydisperse(...)`, `Monodisperse(...)` | [Bidisperse mixture](#bidisperse-mixture); all options on [§3](03-particle-size-distribution-and-length-unit.md) |
| `contact` | `Hookean(stiffness = 1.0)` | `Hertzian(stiffness = 1.0)` | [Hookean contacts](#hookean-contacts), [Stiffness 1 and the units](#stiffness-1-and-the-units), [Hertzian contacts](#hertzian-contacts) |
| `target` | `Pressure(1e-4)` | none listed yet | [Target pressure](#target-pressure) |
| `algorithm` | `FIRE()` | `DampedDynamics()` | [FIRE](#fire); [§7](07-algorithms-and-combinations.md), [§14](14-fire-settings.md) |
| `friction` | `nothing` (frictionless) | `CundallStrack(...)`, `Mindlin(...)` | [Frictionless contacts](#frictionless-contacts); [§13](13-friction-models.md) |

The mass setting (`mass = EqualMass(1.0)`) completes the units and is on
[§4](04-mass.md).

## Model

### Particles, box and overlap

- $N$ particles (`particles_count`) in a periodic box of area (2D) or volume (3D)
  $\Omega$; the design doc writes this $V$. $D$ is the dimension (`dimension`).
- Particle $i$ has center $\mathbf r_i$, diameter $d_i$ and radius $R_i = d_i/2$. The
  small diameter of the default mixture is $d$, the length unit.
- $r_{ij}$ is the distance between the centers of $i$ and $j$, measured to the nearest
  periodic image. The **overlap** is

$$\delta_{ij} = \frac{d_i + d_j}{2} - r_{ij}.$$

- $i$ and $j$ are **in contact** when $\delta_{ij} > 0$. $N_c$ is the number of
  contacts, and the **contact number** (contacts per particle) is

$$z = \frac{2N_c}{N},$$

  the factor 2 because each contact belongs to two particles. Once rattlers are removed
  ([§9](09-rattler-rules.md)), $z$ is counted over the remaining particles.
- $\hat{\mathbf n}\_{ij} = (\mathbf r_j - \mathbf r_i)/r_{ij}$ is the unit normal from
  $i$ to $j$.

### Contact law

While $\delta > 0$, a contact stores the elastic energy and carries the repulsive
normal force

$$U(\delta) = \frac{k}{\alpha}\,\delta^{\alpha}, \qquad f = -\frac{dU}{dr_{ij}} = k\,\delta^{\alpha-1},$$

both zero for $\delta \le 0$. $k$ is the `stiffness` and $\alpha$ the exponent of the
law. The force on $i$ from $j$ is $-f\,\hat{\mathbf n}\_{ij}$: it pushes $i$ away from
$j$. The **contact stiffness** is the slope of the force law,

$$k_n(\delta) = \frac{df}{d\delta} = (\alpha - 1)\,k\,\delta^{\alpha-2}.$$

| Law | Setting | $\alpha$ | $U(\delta)$ | $f(\delta)$ | $k_n(\delta)$ |
|---|---|---|---|---|---|
| Hooke | `Hookean(stiffness = 1.0)` (default) | 2 | $\tfrac12 k\delta^2$ | $k\delta$ | $k$ |
| Hertz | `Hertzian(stiffness = 1.0)` | 5/2 | $\tfrac25 k\delta^{5/2}$ | $k\delta^{3/2}$ | $\tfrac32 k\delta^{1/2}$ |

### Packing fraction

The packing fraction is the particles' total area (2D) or volume (3D) over the box's,

$$\varphi = \frac{1}{\Omega}\sum_{i=1}^{N} v(d_i), \qquad v(d) = \frac{\pi d^2}{4} \ (D = 2), \qquad v(d) = \frac{\pi d^3}{6} \ (D = 3).$$

Each particle counts with its full size, so the small lens where two particles overlap
is counted twice. For equal particles one contact's lens is about
$1.2\,(\delta/d)^{3/2}$ of a disk's area in 2D and $1.5\,(\delta/d)^{2}$ of a sphere's
volume in 3D: about $10^{-6}$ of a disk at $\delta = 10^{-4}d$ (**SoftPack note**,
computed from the circle-overlap and spherical-cap formulas).

### Stress and pressure

SoftPack's pressure is the **contact (virial) pressure from the elastic contact forces
only**. For each contact $c$ between $i$ and $j$, let
$\boldsymbol\ell^{c} = \mathbf r_i - \mathbf r_j$ (nearest image), of length
$\ell^{c} = r_{ij}$, and let $\mathbf f^{c}$ be the elastic force on $i$ from $j$. The
static stress tensor and the pressure are

$$\sigma_{ab} = \frac{1}{\Omega}\sum_{c} f^{c}_{a}\,\ell^{c}_{b}, \qquad P = \frac{1}{D}\operatorname{tr}\boldsymbol\sigma = \frac{1}{D\,\Omega}\sum_{c}\mathbf f^{c}\cdot\boldsymbol\ell^{c} = \frac{1}{D\,\Omega}\sum_{c} f_n^{c}\,\ell^{c},$$

with $a, b$ Cartesian indices and $f_n^{c}$ the normal force magnitude ($f$ above). A
repulsive force points along $\boldsymbol\ell^{c}$, so $P > 0$ under compression.
(Tensor indices are $a$, $b$ here because $\alpha$ is the contact-law exponent.)

The general average-stress formula, [Agnolin2007] Eq. (8), also has a kinetic term,

$$\sigma_{ab} = \frac{1}{\Omega}\left(\sum_i m_i\,v_{i,a}\,v_{i,b} + \sum_{i<j} F_{ij,a}\,r_{ij,b}\right),$$

with $m_i$, $\mathbf v_i$ the particles' masses and velocities and $\mathbf F_{ij}$,
$\mathbf r_{ij}$ the contact force and center-to-center vector of the pair. SoftPack's
target drops the kinetic term and any dashpot forces (see
[Target pressure](#target-pressure)). The arXiv text of Eq. (8) prints the second
index of $r_{ij}$ as $(\alpha)$; the off-diagonal components need $(\beta)$ ($b$
here), as the design doc writes it.

### Units

SoftPack's reduced units are the small diameter $d = 1$, the stiffness $k = 1$ and
the particle mass $m = 1$ ([§4](04-mass.md)). Every other unit follows from these
three by dimensional analysis (**SoftPack note**):

| Quantity | Unit, Hookean ($\alpha = 2$) | Unit, any $\alpha$ |
|---|---|---|
| length | $d$ | $d$ |
| force | $k\,d$ | $k\,d^{\alpha-1}$ |
| energy | $k\,d^{2}$ | $k\,d^{\alpha}$ |
| pressure (force per $\text{length}^{D-1}$) | $k\,d^{2-D}$: $k$ in 2D, $k/d$ in 3D | $k\,d^{\alpha-D}$ |
| time | $\tau = \sqrt{m/k}$ | $\sqrt{m\,d^{2-\alpha}/k}$ |

With $d = k = m = 1$ every one of these units has the value 1, so the numbers do not
change; the table says what a number means.

## Derivations

### Force and stiffness from the potential

The overlap falls as the centers move apart, $d\delta/dr_{ij} = -1$, so

$$f = -\frac{dU}{dr_{ij}} = -\frac{dU}{d\delta}\,\frac{d\delta}{dr_{ij}} = k\,\delta^{\alpha-1}, \qquad k_n = \frac{df}{d\delta} = (\alpha-1)\,k\,\delta^{\alpha-2}.$$

Hooke ($\alpha = 2$): $f = k\delta$ and $k_n = k$ at every overlap. Hertz
($\alpha = 5/2$): $f = k\delta^{3/2}$ and $k_n = \tfrac32 k\delta^{1/2}$, which grows
as the contact is compressed. Checked by finite differences of $U$ for both laws
(**SoftPack note**).

### O'Hern's potential and SoftPack's single stiffness

[OHern2003] (their Eq. 1) write the same family of laws as

$$V(r_{ij}) = \frac{\epsilon}{\alpha}\left(1 - \frac{r_{ij}}{\sigma_{ij}}\right)^{\alpha} \quad \text{for } r_{ij} < \sigma_{ij}, \qquad V = 0 \text{ otherwise},$$

with $\sigma_{ij}$ "the sum of the radii of particles i and j", so
$1 - r_{ij}/\sigma_{ij} = \delta_{ij}/\sigma_{ij}$ and

$$f = -\frac{dV}{dr_{ij}} = \frac{\epsilon}{\sigma_{ij}}\left(\frac{\delta_{ij}}{\sigma_{ij}}\right)^{\alpha-1} = \frac{\epsilon}{\sigma_{ij}^{\alpha}}\,\delta_{ij}^{\alpha-1}.$$

Their effective stiffness is $\epsilon/\sigma_{ij}^{\alpha}$: equal to SoftPack's $k$
(with $k = \epsilon$) for a pair of small particles ($\sigma_{ij} = d = 1$), and smaller
for larger pairs. For the default mixture (**SoftPack note**, checked numerically):

| Pair | $\sigma_{ij}$ | O'Hern stiffness / $k$, Hooke | O'Hern stiffness / $k$, Hertz |
|---|---|---|---|
| small–small | 1.0 | 1.000 | 1.000 |
| small–large | 1.2 | 0.694 | 0.634 |
| large–large | 1.4 | 0.510 | 0.431 |

SoftPack gives every pair the same $k$ (**SoftPack choice**, see
[Hookean contacts](#hookean-contacts)), so its large–large contacts are about twice as
stiff as O'Hern's.

### Pressure as the volume derivative of the energy

The virial pressure is the work needed to shrink the box. Dilate the whole system
affinely by a factor $\lambda$: every center-to-center vector becomes
$\lambda\boldsymbol\ell^{c}$ and the box size becomes $\lambda^{D}\Omega$, while the
diameters stay fixed. The overlap of contact $c$ is then
$\delta_c(\lambda) = s_c - \lambda\,\ell^{c}$, with $s_c = (d_i + d_j)/2$. With
$U_\text{tot} = \sum_c U(\delta_c)$,

$$\frac{dU_\text{tot}}{d\lambda}\bigg|_{\lambda=1} = \sum_c \frac{dU}{d\delta}\,\frac{d\delta_c}{d\lambda} = -\sum_c f_n^{c}\,\ell^{c}, \qquad \frac{d\Omega}{d\lambda}\bigg|_{\lambda=1} = D\,\Omega,$$

so

$$P = -\frac{dU_\text{tot}}{d\Omega} = \frac{1}{D\,\Omega}\sum_c f_n^{c}\,\ell^{c}.$$

This is the trace of $\sigma_{ab}$ over $D$. It holds for any configuration, balanced
or not. **SoftPack note**, checked numerically: for random overlapping bidisperse
configurations (2D and 3D, Hooke and Hertz) the contact sum and a finite-difference
$-dU_\text{tot}/d\Omega$ agree to 7 significant digits.

Two remarks:

- **Tangential forces drop out.** For disks and spheres the contact normal lies along
  $\boldsymbol\ell^{c}$, so a tangential (friction) force has
  $\mathbf f_t\cdot\boldsymbol\ell^{c} = 0$ and does not change $P$ (checked by adding
  random tangential forces). It does enter the off-diagonal stress.
- **The kinetic term.** The trace of Agnolin's kinetic term over $D$ is
  $\sum_i m_i v_i^2/(D\Omega) = 2E_\text{kin}/(D\Omega)$, with $E_\text{kin}$ the total
  kinetic energy. It vanishes in a static packing.

### Pressure and the mean contact force

Write the contact sum as a mean over contacts, $\sum_c f_n^c\ell^c = N_c\langle f\ell\rangle$,
and use $N_c = zN/2$ and $N/\Omega = \varphi/\langle v\rangle$, where
$\langle v\rangle$ is the mean particle area or volume:

$$P = \frac{z\,N\,\langle f\ell\rangle}{2D\,\Omega} = \frac{z\,\varphi\,\langle f\ell\rangle}{2D\,\langle v\rangle}.$$

With $\langle v\rangle = \pi\langle d^2\rangle/4$ in 2D and $\pi\langle d^3\rangle/6$ in
3D, both dimensions give the same form,

$$P = \frac{z\,\varphi\,\langle f\ell\rangle}{\pi\,\langle d^{D}\rangle}.$$

This is exact for the definitions above (checked on the same random configurations;
**SoftPack note**). For equal particles of diameter $d$, and neglecting the overlap in
$\ell \approx d$, it becomes

$$P = \frac{z\,\varphi\,\langle f\rangle}{\pi\,d^{D-1}}.$$

In 3D this is [Agnolin2007] Eq. (22), $P = z\Phi\langle N\rangle/(\pi a^2)$ ($\Phi$ the
packing fraction, $\langle N\rangle$ the mean normal force, $a$ the diameter), which
they derive "neglecting contact deflections before diameter a"; the 2D form is the
design doc's conversion. On compressed triangular (2D) and fcc (3D) lattices the
formula exceeds the exact virial pressure by exactly the factor $d/\ell = 1/(1 - \delta/d)$:
1.0001 at $\delta = 10^{-4}d$ (**SoftPack note**).

With Hookean contacts $\langle f\rangle = k\langle\delta\rangle$, which gives the
design doc's relation

$$\text{2D: } \frac{P}{k} = \frac{z\varphi}{\pi}\,\frac{\langle\delta\rangle}{d}, \qquad \text{3D: } \frac{P\,d}{k} = \frac{z\varphi}{\pi}\,\frac{\langle\delta\rangle}{d}.$$

Near jamming, $z\varphi/\pi = 4 \times 0.84/\pi = 1.07$ in 2D and
$6 \times 0.64/\pi = 1.22$ in 3D.

For the bidisperse default the exact form above is the right one. If the three pair
types touch in proportion to their numbers (small–small, small–large, large–large in
the ratio 1 : 2 : 1, so $\langle\ell\rangle \approx 1.2\,d$) and $f$ is uncorrelated
with $\ell$, then with $\langle d^2\rangle = 1.48\,d^2$,

$$\frac{P}{k} \approx \frac{z\varphi}{\pi}\,\frac{\langle\ell\rangle\,d}{\langle d^{2}\rangle}\,\frac{\langle\delta\rangle}{d} = 0.87\,\frac{\langle\delta\rangle}{d} \qquad (z = 4,\ \varphi = 0.84).$$

**SoftPack note**: an estimate (the pairing assumption is not checked on real
packings). It changes the prefactor from 1.07 to 0.87; the conclusion below, that the
dimensionless pressure is the typical overlap, holds either way.

### Dimensionless pressure and overlap

Dividing $P$ by its unit $k\,d^{\alpha-D}$ gives a pure number $\hat P$. From the
relation above with $f = k\delta^{\alpha-1}$,

$$\frac{\langle\delta^{\alpha-1}\rangle}{d^{\alpha-1}} \approx \frac{\pi}{z\varphi}\,\hat P, \qquad \hat P = \frac{P}{k\,d^{\alpha-D}}.$$

- Hooke: $\langle\delta\rangle/d \approx \hat P$ (prefactor $\pi/(z\varphi)$ of order 1).
  At the default $\hat P = 10^{-4}$, overlaps are about $10^{-4}$ of a diameter.
- Hertz: $\langle\delta^{3/2}\rangle/d^{3/2} \approx \hat P$, so overlaps grow as
  $\hat P^{2/3}$: about $2\times10^{-3}$ of a diameter at $\hat P = 10^{-4}$.

**SoftPack note.** The jamming papers use the same unit: [OHern2003] "The pressure p,
stress Σ, bulk modulus B, and shear modulus G are measured in units of"
$\epsilon/\sigma^{d}$ (their $d$ is the dimension, their $\sigma$ the small diameter).
Since $\epsilon = k\,\sigma^{\alpha}$ (previous derivation),
$\epsilon/\sigma^{D} = k\,\sigma^{\alpha-D}$: $k$ in 2D and $k/d$ in 3D for Hookean
contacts, $k\,d^{1/2}$ and $k\,d^{-1/2}$ for Hertzian ones. The Leiden papers invert
the ratio: [Agnolin2007] "The elastic contact law introduces a dimensionless stiffness
parameter κ", $\kappa = (\tilde E/P)^{2/3}$ for Hertz contacts, and "κ sets the scale of
the typical normal deflection h in Hertzian contacts, as h/a ∼ 1/κ."

### Pressure and distance to jamming

At the jamming point $\varphi_c$ the particles just touch and $P = 0$. Compress an
isotropic packing affinely by a small strain $\varepsilon$: every center-to-center
distance shrinks by the factor $1-\varepsilon$, so (**SoftPack note**)

$$\varphi = \frac{\varphi_c}{(1-\varepsilon)^{D}} \approx \varphi_c\,(1 + D\varepsilon), \qquad \delta \approx \varepsilon\,\ell \approx \varepsilon\,d \quad\Rightarrow\quad \frac{\delta}{d} \approx \frac{\varphi - \varphi_c}{D\,\varphi_c},$$

and the pressure follows the force law,

$$P \propto f \propto \delta^{\alpha-1} \propto (\varphi - \varphi_c)^{\alpha-1}.$$

[OHern2003] measure this: "the pressure vanishes as a power law" as
$\varphi \to \varphi_c^{+}$, $p = p_0(\varphi - \varphi_c)^{\psi}$, with
$\psi = \alpha - 1$ "independent of polydispersity or dimensionality", and give the
affine argument: "If the deformation is affine, one would expect the exponent for the
pressure to be the same as for the force law". The real response is not affine, so
only the exponent survives; the prefactor $p_0$ is measured. Their Table I gives
$p_0 = 0.34$, $\psi = 1.01$ for 2D bidisperse harmonic packings, so $p = 10^{-4}$ is
$\varphi - \varphi_c \approx 3\times10^{-4}$ (**SoftPack note**; in their units, whose
larger pairs are softer than SoftPack's, so an order of magnitude only). For Hookean
contacts the three small numbers $\hat P$, $\langle\delta\rangle/d$ and
$\varphi - \varphi_c$ are therefore of the same order, as the design doc states.

### Isostatic contact numbers

A packing is isostatic when the number of unknown contact forces equals the number of
force-balance equations, so that the forces follow from the geometry alone.

- **Frictionless.** Each contact carries one unknown (its normal force), and each
  particle gives $D$ equations (central forces exert no torque). Isostatic means
  $N_c = DN$, so $z_\text{iso} = 2D$: 4 in 2D, 6 in 3D. [OHern2003] "For purely
  repulsive, frictionless systems of spherical particles, the number of force balance
  equations is Nd so the isostatic condition is" $Z = 2d$, and find that jammed
  packings reach it at $\varphi_c$ (their Table I: $Z_c = 3.98$ in 2D and 5.98 in 3D,
  $\pm0.02$).
- **Frictional, $\mu \to \infty$.** Each contact carries $D$ unknowns (normal plus
  $D-1$ tangential components), and each particle gives $D$ force and $D(D-1)/2$
  torque equations. Then $N_c D = N\left(D + D(D-1)/2\right)$, so
  $z_\text{iso} = D + 1$: 3 in 2D, 4 in 3D. [Shundyak2007] "If in view of this
  inequality we treat these tangential forces as independent new degrees of freedom in
  the constraint counting, the isostatic value jumps from" $z^{0}\_\text{iso} = 2d$ to
  $z^{\mu}\_\text{iso} = d + 1$. Their slowly prepared 2D packings extrapolate to
  $z = 3.98 \pm 0.02$ for $\mu \ll 1$ and $3.00 \pm 0.02$ for $\mu \gg 1$, "which are
  close to the frictionless and frictional isostatic bounds". Finite $\mu$ gives
  values in between.
- **Finite periodic packings.** The $D$ uniform translations of the whole packing cost
  no energy and need no contact, so the frictionless count is $N_c = D(N-1)$ and
  $z = 2D(1 - 1/N)$: 3.984 for $N = 256$ in 2D (**SoftPack note**; $N$ counts the
  particles left after rattler removal).

## Defaults and their reasons

### Two dimensions

```julia
pack(dimension = 2)
```

**Decision.** Two-dimensional packings (disks).

- **SoftPack choice.** 2D packings are the cheapest to make and to check by eye, and
  the bidisperse mixture below is the standard 2D one. `dimension = 3` is an option
  ([Three dimensions](#three-dimensions)).

### 256 particles

```julia
pack(particles_count = 256)
```

**Decision.** 256 particles.

- **SoftPack choice.** Small enough that `pack()` with no arguments finishes in
  seconds, and inside the range of jamming studies: [OHern2003] "We have studied the
  finite-size effects by varying the number of particles in the sample between
  4 < N < 4096 in 2D and 3D."
- At $\varphi = 0.84$ the default box is about 18.8 small diameters on a side
  ([Worked numbers](#worked-numbers)), so finite-size effects are large. Production
  runs should set `particles_count`.

### Bidisperse mixture

```julia
pack(particles_size_distribution = Bidisperse(diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5))
```

**Decision.** A 50:50 mixture (by number) of two diameters with ratio 1.4.

- [OHern2003] "In our two-dimensional (2D) simulations, we have used 50-50 mixtures of
  particles with a size ratio of 1.4 in order to prevent crystallization".
- The distribution's settings, its moments and the length-unit conventions are on
  [§3](03-particle-size-distribution-and-length-unit.md).

### Hookean contacts

```julia
pack(contact = Hookean())
```

**Decision.** Hookean (harmonic) contacts, $\alpha = 2$: $U = \tfrac12 k\delta^2$,
$f = k\delta$ ([Contact law](#contact-law)).

- The exponents are the jamming standard: [OHern2003] use the potential of their Eq. 1
  ([derivation](#oherns-potential-and-softpacks-single-stiffness)) and study both
  "α = 2 for repulsive harmonic springs" and "α = 5/2 for repulsive Hertzian
  interactions".
- One stiffness for every pair: **SoftPack choice**. [OHern2003] divide the overlap by
  $\sigma_{ij}$, so their stiffness $\epsilon/\sigma_{ij}^{\alpha}$ is smaller for large
  pairs (table above); the two forms agree for a pair of small particles. One $k$ makes
  `stiffness` a single spring constant that sets the force unit, the collision time
  ([§12](12-time-step.md)) and the damping ([§8](08-damping.md)), as in DEM codes:
  [LAMMPSgran] "Kn = elastic constant for normal particle repulsion (force/distance
  units or pressure units - see discussion below)". The material Hertz law also grows
  with the pair's reduced radius; SoftPack's `Hertzian`, like O'Hern's, is the pure
  power law.
- Hookean is the default (**SoftPack choice**) because $k_n = k$ does not change with
  overlap. The collision time $t_\text{col} = \pi\sqrt{M_n/k}$ ([§12](12-time-step.md),
  $M_n$ the pair's normal effective mass, [§4](04-mass.md)), the time step and the
  contact damping ratio are then fixed for the whole run: with equal masses
  $M_n = m/2$ and $t_\text{col} = \pi\sqrt{1/2}\,\tau = 2.22\,\tau$ at every contact.

### Stiffness 1 and the units

```julia
pack(contact = Hookean(stiffness = 1.0))
```

**Decision.** $k = 1$ sets the force unit. With the small diameter $d = 1$ as the
length unit, the target pressure is the dimensionless pressure $\hat P$, which says how
deeply the particles overlap.

- **Why one number is enough.** The equilibrium of a static packing involves only the
  diameters, the contact law and the pressure: masses do not enter the force-balance
  equations. With diameters measured in $d$, the only dimensionless combination of
  $d$, $k$ and $P$ is $\hat P = P/(k\,d^{\alpha-D})$
  ([Dimensionless pressure and overlap](#dimensionless-pressure-and-overlap)).
  Masses still change the path to equilibrium, and with it which packing an inertial
  algorithm reaches ([§4](04-mass.md#mass-ratios-change-the-packing-reached)).
- **The pressure is the overlap.** [Agnolin2007]'s Eq. (22) and its 2D form
  ([derivation](#pressure-and-the-mean-contact-force)) give, for Hookean contacts,
  $\langle\delta\rangle/d = \hat P\,\pi/(z\varphi)$ with $\pi/(z\varphi)$ about 0.9 in
  2D and 0.8 in 3D near jamming. [Agnolin2007] "Under pressure P, the typical force in
  a contact is of order P a²".
- **The pressure is the distance to jamming.** For Hookean contacts
  $\hat P \sim \langle\delta\rangle/d \sim \varphi - \varphi_c$
  ([derivation](#pressure-and-distance-to-jamming); $\sim$ means equal up to a factor
  of order one).
- **The field reports pressure this way**: in units of the contact stiffness
  ([OHern2003], unit $\epsilon/\sigma^{d}$) or through the inverse ratio $\kappa$
  ([Agnolin2007]). Packings at the same $\hat P$ are the same packing in different
  units, so $k = 1$ loses nothing: **SoftPack choice** for the value.

### Target pressure

```julia
pack(target = Pressure(1e-4))
```

**Decision.** Compress to $P = 10^{-4}$ (in units of $k$ in 2D, $k/d$ in 3D, for the
default Hookean contacts). The pressure is the contact (virial) pressure from the
elastic contact forces only,

$$P = \frac{1}{D\,\Omega}\sum_{c} f_n^{c}\,\ell^{c}.$$

- It is the trace of the standard average-stress formula, [Agnolin2007] Eq. (8),
  divided by $D$; [Agnolin2007] "In the case of monodisperse sphere packings in
  equilibrium in uniform state of stress σ, pressure P = trσ/3 is directly related to
  the average normal force". Derivation:
  [Pressure as the volume derivative of the energy](#pressure-as-the-volume-derivative-of-the-energy).
- Elastic contact forces only, no velocity term and no dashpot forces: the target is a
  static packing, where both vanish, and [Agnolin2007] stop when "the elastic
  contributions to the stress components equal the prescribed value P". Leaving them
  out also keeps the controlled quantity free of the transient motion while the packing
  settles.
- $10^{-4}$: **SoftPack choice**, near jamming but high enough to converge quickly
  (overlaps of about $10^{-4}$ of a diameter). Frictional jamming studies span
  pressures from $10^{-6}$ to $10^{-3}$ [Henkes2010] (Hertz–Mindlin particles, so their
  pressure unit differs from SoftPack's).
- The pressure must end within `pressure_tolerance` ($10^{-4}$ relative) of the
  target: $|P - 10^{-4}| \le 10^{-8}$ ([§5](05-convergence-criterion.md)).

### FIRE

```julia
pack(algorithm = FIRE())
```

**Decision.** Minimize with FIRE.

- FIRE was introduced in [Bitzek2006] and assessed and implemented in LAMMPS in
  [Guenole2020]. Its settings are on [§14](14-fire-settings.md). `DampedDynamics()` is
  the other algorithm ([§7](07-algorithms-and-combinations.md),
  [§8](08-damping.md)).

### Frictionless contacts

```julia
pack(friction = nothing)
```

**Decision.** Frictionless contacts.

- **SoftPack choice.** FIRE on a frictionless packing has a well-defined end state (an
  energy minimum) and known checks: the jamming packing fraction and $z \to 4$ in 2D
  ([Isostatic contact numbers](#isostatic-contact-numbers)). Frictional packings depend
  on the preparation path ([§7](07-algorithms-and-combinations.md)). Friction models
  are on [§13](13-friction-models.md).

## Options

### Three dimensions

```julia
pack(dimension = 3)
```

Spheres instead of disks. What changes:

- The pressure unit is $k/d$ (Hookean) and $P\,d/k = (z\varphi/\pi)\langle\delta\rangle/d$,
  with $z\varphi/\pi \approx 1.2$ near jamming ($z \approx 6$, $\varphi \approx 0.64$).
  [OHern2003] find $\varphi^{\ast} = 0.639 \pm 0.001$ (their Eq. 5) for 3D monodisperse
  packings in the limit of large $N$.
- The frictionless isostatic contact number is 6.
- The default mass shape becomes `:sphere` for `Density` masses ([§4](04-mass.md)).
- [OHern2003] study 3D bidisperse and monodisperse packings
  ([§3](03-particle-size-distribution-and-length-unit.md)).

### Hertzian contacts

```julia
pack(contact = Hertzian(stiffness = 1.0))
```

$\alpha = 5/2$: $U = \tfrac25 k\delta^{5/2}$, $f = k\delta^{3/2}$,
$k_n = \tfrac32 k\delta^{1/2}$.

- Used by [OHern2003] ("α = 5/2 for repulsive Hertzian interactions") and, with a
  tangential Mindlin force, by the Leiden frictional papers ([Henkes2010];
  [§13](13-friction-models.md)). `Mindlin` friction needs `Hertzian` contacts.
- $k$ now has units of $\text{force}/\text{length}^{3/2}$ and the pressure unit is $k\,d^{\alpha-D}$:
  $k\,d^{1/2}$ in 2D, $k\,d^{-1/2}$ in 3D. With $d = 1$ the numbers are the same, but
  $P = 10^{-4}$ now means overlaps of about $\hat P^{2/3} \approx 2\times10^{-3}$ of a
  diameter ([Worked numbers](#worked-numbers)).
- The contact stiffness grows with overlap, so the collision time shrinks as the
  packing is compressed. The time step uses the stiffness at the largest overlap
  expected and checks it during the run ([§12](12-time-step.md)); contact damping is
  set as a ratio so it keeps its meaning ([§8](08-damping.md)).
- Like the Hookean law, it is the pure power law with one $k$ for every pair (no
  reduced-radius factor).

### Other particle counts, algorithm and friction

- `particles_count`: any number ≥ 2.
- `algorithm = DampedDynamics()`: damped molecular dynamics
  ([§7](07-algorithms-and-combinations.md), [§8](08-damping.md)).
- `friction = CundallStrack(...)` or `Mindlin(...)` ([§13](13-friction-models.md)).
  With friction the jammed contact number lies between $D + 1$ and $2D$
  ([Isostatic contact numbers](#isostatic-contact-numbers)).

## Worked numbers

All numbers below were computed (Python checks) for the default 2D mixture
($d = 1$, $k = 1$, $m = 1$, $N = 256$, $P = 10^{-4}$). Values marked *estimate* use
$\varphi \approx 0.84$, $z \approx 4$ and random pairing ($\langle\ell\rangle = 1.2$).
**SoftPack note.**

| Quantity | Value |
|---|---|
| mean particle area $\pi\langle d^2\rangle/4$ | 1.1624 |
| box area at $\varphi = 0.84$ | 354.25 (side 18.82) |
| box volume for $N = 256$ in 3D at $\varphi = 0.64$ | 392.07 (side 7.32) |
| $N_c = zN/2$ at $z = 4$ (before rattler removal) | 512 |
| $\sum_c f_n^c\ell^c = D\,\Omega\,P$ | 0.0708 |
| mean contact force $\langle f\rangle$ (estimate) | $1.15\times10^{-4}$ |
| mean overlap $\langle\delta\rangle$, Hookean (estimate) | $1.15\times10^{-4}$ |
| same from the monodisperse formula, $\pi P/(z\varphi)$ | $0.94\times10^{-4}$ |
| $z\varphi/\pi$ near jamming, 2D / 3D | 1.07 / 1.22 |
| $\varphi - \varphi_c$ at $p = 10^{-4}$ from [OHern2003] Table I (2D bidisperse, harmonic) | $3.2\times10^{-4}$ |
| affine estimate $\delta/d \approx (\varphi - \varphi_c)/(D\varphi_c)$ from that | $1.9\times10^{-4}$ |
| Hertzian: typical overlap $\langle f\rangle^{2/3}$ (estimate) | $2.4\times10^{-3}$ |
| Hertzian: contact stiffness $\tfrac32 k\delta^{1/2}$ at that overlap | 0.073 |
| Hookean collision time, equal masses, $\pi\sqrt{M_n/k}$ | $2.22\,\tau$ |
| Hertzian collision time at the typical overlap, equal masses | $8.2\,\tau$ |
| isostatic $z$, frictionless / $\mu\to\infty$, 2D | 4 / 3 |
| isostatic $z$ for $N = 256$ with periodic boundaries, frictionless 2D | 3.984 |

The affine estimate of the overlap ($1.9\times10^{-4}$) and the force-balance estimate
($1.15\times10^{-4}$) differ by less than a factor 2: the response near jamming is not
affine, and O'Hern's larger pairs are softer than SoftPack's.

## Open questions

- **How `pack()` reaches the target pressure** (initial state and compression
  protocol) is not designed yet (design doc, status line).
- The values $z\varphi/\pi \approx 1.1$ and 1.2 near jamming are the design doc's
  conversions from monodisperse formulas; for the bidisperse default the prefactor is
  about 0.87 under the random-pairing estimate above. Measuring
  $P/\langle\delta\rangle$ on real SoftPack packings would settle it.
- `target` has no alternative listed in the design doc (§0 leaves the *Other choices*
  column empty).

## Related pages

- [§0 Every default at a glance](00-every-default-at-a-glance.md)
- [§3 Particle size distribution and length unit](03-particle-size-distribution-and-length-unit.md)
- [§4 Mass](04-mass.md): the mass unit, effective masses
- [§5 Convergence criterion](05-convergence-criterion.md): when the pressure counts as reached
- [§7 Algorithms and combinations](07-algorithms-and-combinations.md)
- [§8 Damping](08-damping.md)
- [§9 Rattler rules](09-rattler-rules.md): which particles count in $z$
- [§12 Time step](12-time-step.md): the collision time
- [§13 Friction models](13-friction-models.md)
- [§14 FIRE settings](14-fire-settings.md)
- [Notation](notation.md), [References](references.md)

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[Bitzek2006]** Erik Bitzek, Pekka Koskinen, Franz Gähler, Michael Moseler, Peter Gumbsch (2006). *Structural Relaxation Made Simple*. Physical Review Letters **97**, 170201. [doi:10.1103/physrevlett.97.170201](https://doi.org/10.1103/physrevlett.97.170201).
- **[Guenole2020]** Julien Guénolé, Wolfram G. Nöhring, Aviral Vaid, Frédéric Houllé, Zhuocheng Xie, Aruna Prakash, Erik Bitzek (2020). *Assessment and optimization of the fast inertial relaxation engine (fire) for energy minimization in atomistic simulations and its implementation in lammps*. Computational Materials Science **175**, 109584. [doi:10.1016/j.commatsci.2020.109584](https://doi.org/10.1016/j.commatsci.2020.109584).
- **[Henkes2010]** S. Henkes, M. van Hecke, W. van Saarloos (2010). *Critical jamming of frictional grains in the generalized isostaticity picture*. EPL (Europhysics Letters) **90**, 14003. [doi:10.1209/0295-5075/90/14003](https://doi.org/10.1209/0295-5075/90/14003).
- **[LAMMPSgran]** LAMMPS developers. *LAMMPS documentation: pair_style gran/hooke, gran/hooke/history, gran/hertz/history*. <https://docs.lammps.org/pair_gran.html>. Accessed 2026-11-18.
- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
- **[Shundyak2007]** Kostya Shundyak, Martin van Hecke, Wim van Saarloos (2007). *Force mobilization and generalized isostaticity in jammed packings of frictional grains*. Physical Review E **75**, 010301. [doi:10.1103/physreve.75.010301](https://doi.org/10.1103/physreve.75.010301).
