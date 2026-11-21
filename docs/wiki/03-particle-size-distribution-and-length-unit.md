# 3. Particle size distribution and length unit

Design decision source: [design-references.md §3](../design-references.md#3-particle-size-distribution-and-length-unit).
Status: design stage (no engine code yet).

## Summary

Particle sizes are diameters everywhere in SoftPack. `particles_size_distribution`
chooses the law the diameters are drawn from; `particles_diameters` gives the
diameters themselves. Each distribution fixes the length unit through its own
defaults: `Bidisperse` makes the small diameter 1 (the jamming convention),
`UniformPolydisperse` makes the mean diameter 1 (the Leiden convention), and
`Monodisperse` makes its one diameter 1. The default is the 50:50 mixture of two
diameters in the ratio 1.4 used in 2D jamming studies. Every output stores each
particle's diameter. This page gives each distribution's formulas and moments, shows
how the choice of length unit changes the numbers a user types, and works out the
values for the defaults.

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| `particles_size_distribution` | `Bidisperse(diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5)` | `UniformPolydisperse(diameter_mean = 1.0, spread = 0.2)`, `Monodisperse(diameter = 1.0)` | [Bidisperse](#bidisperse-default), [UniformPolydisperse](#uniformpolydisperse), [Monodisperse](#monodisperse) |
| `Bidisperse` `diameter_small` | `1.0` | any diameter | the length unit |
| `Bidisperse` `diameter_ratio` | `1.4` | any ratio | large over small diameter |
| `Bidisperse` `fraction_small` | `0.5` | a number fraction | fraction of particles that are small |
| `UniformPolydisperse` `diameter_mean` | `1.0` | any diameter | the length unit |
| `UniformPolydisperse` `spread` | `0.2` | any spread | half-width over mean |
| `Monodisperse` `diameter` | `1.0` | any diameter | the length unit |
| `particles_diameters` | `nothing` (drawn from the distribution) | a vector with one diameter per particle | [Given diameters](#given-diameters) |

## Model

### Diameters

Particle $i$ has diameter $d_i$ and radius $R_i = d_i/2$. SoftPack's settings and
outputs use $d_i$, as DEM software does: [LAMMPSset] "diameter value = diameter of
spherical particle (distance units)". The contact distance of a pair is
$(d_i + d_j)/2$ ([§2](02-default-packing.md#particles-box-and-overlap)). $N$ is the
number of particles, $D$ the dimension, and $\langle\cdot\rangle$ a mean over
particles.

### Bidisperse law

Two diameters, small $d_s$ (`diameter_small`) and large $d_l = r\,d_s$, with
$r$ = `diameter_ratio`. A fraction $f$ = `fraction_small` of the particles **by
number** are small:

$$d_i \in \{d_s,\ r\,d_s\}, \qquad N_s = f\,N \text{ small}, \qquad N_l = (1-f)\,N \text{ large}.$$

Its moments, polydispersity (standard deviation over mean) and the share of the
particle area ($D = 2$) or volume ($D = 3$) held by small particles are

$$\langle d^{n}\rangle = d_s^{n}\left[f + (1-f)\,r^{n}\right], \qquad \frac{\sqrt{\langle d^2\rangle - \langle d\rangle^2}}{\langle d\rangle} = \frac{\sqrt{f(1-f)}\,(r-1)}{f + (1-f)\,r}, \qquad \frac{f}{f + (1-f)\,r^{D}}.$$

### Uniform polydisperse law

Diameters uniform between $d_\text{mean}(1-s)$ and $d_\text{mean}(1+s)$, with
$d_\text{mean}$ = `diameter_mean` and $s$ = `spread`:

$$p(d) = \frac{1}{2s\,d_\text{mean}} \quad \text{for } d_\text{mean}(1-s) \le d \le d_\text{mean}(1+s),$$

$$\langle d\rangle = d_\text{mean}, \qquad \langle d^2\rangle = d_\text{mean}^2\left(1 + \frac{s^2}{3}\right), \qquad \langle d^3\rangle = d_\text{mean}^3\left(1 + s^2\right), \qquad \frac{\sqrt{\langle d^2\rangle - \langle d\rangle^2}}{\langle d\rangle} = \frac{s}{\sqrt3}.$$

The largest over the smallest diameter is $(1+s)/(1-s)$; diameters stay positive for
$s < 1$ (**SoftPack note**).

### Monodisperse law

Every particle has $d_i = d$ (`diameter`).

### Given diameter list

With `particles_diameters = [d_1, ..., d_N]`, particle $i$ has exactly diameter $d_i$,
and $N$ (`particles_count`) is the length of the vector.

### Packing fraction of a mixture

The packing fraction ([§2](02-default-packing.md#packing-fraction)) depends on the
distribution only through $\langle d^{D}\rangle$:

$$\varphi = \frac{N\,\pi\langle d^{2}\rangle}{4\,\Omega} \ (D = 2), \qquad \varphi = \frac{N\,\pi\langle d^{3}\rangle}{6\,\Omega} \ (D = 3),$$

with $\Omega$ the box area or volume.

## Derivations

### Bidisperse moments

A mean over particles weights each diameter by its number fraction:
$\langle d^{n}\rangle = f d_s^{n} + (1-f)(r d_s)^{n}$. The variance is

$$\langle d^2\rangle - \langle d\rangle^2 = d_s^2\left[f + (1-f)r^2 - \left(f + (1-f)r\right)^2\right] = d_s^2\,f(1-f)\,(r-1)^2,$$

which gives the polydispersity above. The small particles' share of the total area
or volume is $f d_s^{D}/\langle d^{D}\rangle = f/(f + (1-f)r^{D})$. For the default
($f = 1/2$, $r = 1.4$): $\langle d\rangle = 1.2\,d_s$, standard deviation $0.2\,d_s$,
polydispersity $1/6 = 0.167$. Half the particles are small, but they hold only 33.8%
of the area in 2D, $\tfrac{1}{1 + 1.96}$, and 26.7% of the volume in 3D, $\tfrac{1}{1 + 2.744}$.

### Uniform moments

Write $d = d_\text{mean}(1 + sU)$ with $U$ uniform on $[-1, 1]$, so that
$\langle U\rangle = \langle U^3\rangle = 0$ and $\langle U^2\rangle = 1/3$. Then

$$\langle d^2\rangle = d_\text{mean}^2\left(1 + 2s\langle U\rangle + s^2\langle U^2\rangle\right) = d_\text{mean}^2\left(1 + \tfrac{s^2}{3}\right),$$

$$\langle d^3\rangle = d_\text{mean}^3\left(1 + 3s\langle U\rangle + 3s^2\langle U^2\rangle + s^3\langle U^3\rangle\right) = d_\text{mean}^3\left(1 + s^2\right),$$

and the standard deviation is $d_\text{mean}\,s/\sqrt3$. Checked with $2\times10^{6}$
random draws at $s = 0.2$: mean 1.0000, standard deviation 0.1155,
$\langle d^2\rangle = 1.0133$, $\langle d^3\rangle = 1.0400$ (**SoftPack note**).

### Changing the length unit

A packing does not change when it is described in another length unit, but the
numbers typed into `pack()` do. Let the length unit be $u$ (the small diameter $d_s$
or the mean diameter $\langle d\rangle$). With the stiffness $k = 1$ in either system,
the number given to `Pressure(...)` is the dimensionless pressure
([§2](02-default-packing.md#dimensionless-pressure-and-overlap))

$$\hat P_u = \frac{P}{k\,u^{\alpha-D}},$$

with $\alpha$ the contact-law exponent (2 Hooke, 5/2 Hertz). For the same physical
packing in two unit systems,

$$\frac{\hat P_{\langle d\rangle}}{\hat P_{d_s}} = \left(\frac{d_s}{\langle d\rangle}\right)^{\alpha-D} = \left(\frac{\langle d\rangle}{d_s}\right)^{D-\alpha}.$$

For the default mixture, $\langle d\rangle/d_s = 1.2$ (**SoftPack note**):

| Contact law | 2D | 3D |
|---|---|---|
| Hookean ($\alpha = 2$) | 1 (unchanged) | 1.2 |
| Hertzian ($\alpha = 5/2$) | $1.2^{-1/2} = 0.913$ | $1.2^{1/2} = 1.095$ |

So a 2D Hookean pressure $P/k$ is the same number in either convention, while a 3D
Hookean pressure in mean-diameter units is 1.2 times the number in small-diameter
units. The same factor applies to every length: in mean-diameter units the default
diameters are $1/1.2 = 0.833$ and $1.4/1.2 = 1.167$. Masses set from a density
([§4](04-mass.md)) and absolute tolerances such as `LeidenAcceleration`
([§5](05-convergence-criterion.md)) also depend on the length unit: the design doc
notes that the value $10^{-10}$ reproduces the Leiden rule only in Leiden units
($E^{\ast} = 1$, mean diameter 1, density 1).

## Defaults and their reasons

### Bidisperse default

```julia
pack(particles_size_distribution = Bidisperse(diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5))
```

**Decision.** The default ([§2](02-default-packing.md#bidisperse-mixture)).
`fraction_small` is the number fraction of small particles.

- `diameter_small = 1.0`, the small diameter as the length unit: [OHern2003] "The
  diameter of the smaller particle is denoted by σ." ... "lengths are measured in
  units of σ"
- `diameter_ratio = 1.4`, `fraction_small = 0.5`: the [OHern2003] mixture,
  "In our two-dimensional (2D) simulations, we have used 50-50 mixtures of particles
  with a size ratio of 1.4 in order to prevent crystallization".
- Why a mixture at all: equal disks crystallize in 2D, and a crystal is not the
  disordered packing jamming studies need. A second size frustrates the hexagonal
  order (**SoftPack note**).

## Options

### UniformPolydisperse

```julia
pack(particles_size_distribution = UniformPolydisperse(diameter_mean = 1.0, spread = 0.2))
```

**Decision.** Diameters uniform between $d_\text{mean}(1 - s)$ and
$d_\text{mean}(1 + s)$, with $d_\text{mean}$ = `diameter_mean` and $s$ = `spread`.

- `diameter_mean = 1.0`, the mean diameter as the length unit: [Somfai2005] "Our unit
  of length is the average grain diameter." [Shundyak2007] "our units are such that
  the mass density, the average particle diameter, and the Young's modulus of the
  grains are 1."
- `spread = 0.2`: [Somfai2005] "For the 2D simulations the spheres have
  polydispersity to avoid crystallization: the diameters are uniformly distributed
  between 0.8 and 1.2 times their average."
- Use it to match the Leiden frictional packings ([Somfai2005], [Shundyak2007]). Their
  2D particles are spheres for the mass ([§4](04-mass.md)).

### Monodisperse

```julia
pack(particles_size_distribution = Monodisperse(diameter = 1.0))
```

**Decision.** One diameter for every particle; an option, not the default.

- Equal disks crystallize in 2D (the reason for the bidisperse default). In 3D,
  [OHern2003] "we have studied the same bidisperse mixture as well as monodisperse
  systems".
- `diameter = 1.0`: **SoftPack choice**, the one diameter is the length unit.

### Given diameters

```julia
pack(particles_diameters = nothing)               # default: draw from particles_size_distribution
pack(particles_diameters = [1.0, 1.4, 1.0, 1.4])  # exactly these diameters
```

**Decision.** By default the diameters are drawn from `particles_size_distribution`.
Giving `particles_diameters` uses exactly those diameters instead, one per particle,
and `particles_count` is then their number. Give a distribution or the diameters, not
both.

- **SoftPack choice**: an exact list is how a packing is matched to an experiment or
  to another code's particles.
- The length unit is then whatever unit the given diameters are in; with $k = 1$ the
  pressure unit follows from it as above.

## Worked numbers

Computed for the defaults (**SoftPack note**; Python checks).

| Quantity | `Bidisperse` default | `UniformPolydisperse` default |
|---|---|---|
| length unit | small diameter | mean diameter |
| diameters | 1.0 and 1.4 | 0.8 to 1.2 |
| largest / smallest | 1.4 | 1.5 |
| $\langle d\rangle$ | 1.2 | 1.0 |
| $\langle d^2\rangle$ | 1.48 | 1.0133 |
| $\langle d^3\rangle$ | 1.872 | 1.04 |
| polydispersity (std / mean) | 0.167 | 0.115 |
| mean disk area $\pi\langle d^2\rangle/4$ | 1.1624 | 0.7959 |
| mean sphere volume $\pi\langle d^3\rangle/6$ | 0.9802 | 0.5445 |
| small particles' share of area (2D) / volume (3D) | 0.338 / 0.267 | – |
| box area for $N = 256$ at $\varphi = 0.84$ (2D) | 354.25 (side 18.82) | 242.55 (side 15.57) |
| diameters in mean-diameter units | 0.833 and 1.167 | – |

For $N = 256$ uniform draws, the sample mean diameter scatters around 1 with standard
deviation $0.1155/\sqrt{256} = 0.0072$.

## Open questions

- **Exact or random counts.** The design doc says the diameters are drawn from the
  distribution. For `Bidisperse` it does not say whether the number of small particles
  is exactly $fN$ (128 of 256, as in O'Hern's 50-50 mixtures) or random (binomial,
  standard deviation 8 for $N = 256$).
- **Sample mean or distribution mean.** For `UniformPolydisperse` the length unit is
  the distribution's mean; the doc does not say whether drawn diameters are rescaled so
  that their sample mean is exactly 1.
- **The small diameter without a bidisperse mixture.** Other sections define scales
  from the small particle: the `KineticEnergy` tolerance uses the small diameter
  ([§5](05-convergence-criterion.md)) and the time unit $\tau$ uses the small-particle
  mass ([§8](08-damping.md)). For `UniformPolydisperse` and given diameters the doc
  does not say which diameter or mass these mean.
- Checks on `particles_diameters` (positive values, length at least 2) are not
  specified.

## Related pages

- [§2 Default packing](02-default-packing.md): the default mixture, packing fraction, pressure units
- [§4 Mass](04-mass.md): masses from diameters
- [§5 Convergence criterion](05-convergence-criterion.md): tolerances that depend on the length unit
- [§11 Outputs](11-outputs.md): stored diameters
- [Notation](notation.md), [References](references.md)

## References

- **[LAMMPSset]** LAMMPS developers. *LAMMPS documentation: set command*. <https://docs.lammps.org/set.html>. Accessed 2026-11-18.
- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
- **[Shundyak2007]** Kostya Shundyak, Martin van Hecke, Wim van Saarloos (2007). *Force mobilization and generalized isostaticity in jammed packings of frictional grains*. Physical Review E **75**, 010301. [doi:10.1103/physreve.75.010301](https://doi.org/10.1103/physreve.75.010301).
- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
