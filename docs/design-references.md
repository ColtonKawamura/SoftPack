# SoftPack design decisions and their references

Every design decision for SoftPack's `pack()`, with the sources behind it. Quotes are
copied from the sources' full texts: the published versions for [OHern2003],
[Shundyak2007], [Somfai2007] and [Henkes2010], the arXiv versions or official docs
for the rest. BibTeX for every key is in [`references.bib`](references.bib).
Decisions marked **SoftPack choice** have no literature source: they are our own
call, and the reason is given.

Each decision starts with the call that sets it explicitly, so it can be copied and
changed, followed by the decision and its reasons. Equations are LaTeX (`$...$`),
which GitHub renders; quoted text keeps the source's wording and notation as
transcribed. Notation: $\gamma$ is a dashpot coefficient (force per velocity), $r$ a
damping rate ($1/\text{time}$, with $\gamma = m_\text{eff}\,r$), $\zeta$ a damping ratio,
and $a$, $b$ the mass- and stiffness-proportional constants of the damping matrix,
$\boldsymbol\Gamma = a\mathbf M + b\mathbf K$. The full derivations are in the
[wiki](https://github.com/ColtonKawamura/SoftPack/wiki), one page per section.

Status: design stage (no engine code yet). Last updated 2026-11-21. Every setting has
a default and a reason (§0). Not designed yet: how `pack()` reaches the target
pressure (initial state and compression protocol).

---

## 0. Every default at a glance

Every setting, its default, the other choices, and the section that gives the
reasons. Units: small diameter 1, contact stiffness 1, particle mass 1.

| Setting | Default | Other choices | § |
|---|---|---|---|
| `dimension` | `2` | `3` | 2 |
| `particles_count` | `256` | any number ≥ 2 | 2 |
| `particles_size_distribution` | `Bidisperse(diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5)` | `UniformPolydisperse(diameter_mean = 1.0, spread = 0.2)`, `Monodisperse(diameter = 1.0)` | 2, 3 |
| `particles_diameters` | `nothing` (drawn from the distribution) | a vector with one diameter per particle | 3 |
| `contact` | `Hookean(stiffness = 1.0)` | `Hertzian(stiffness = 1.0)` | 2 |
| `friction` | `nothing` (frictionless) | `CundallStrack(friction_coefficient = 0.5, stiffness_ratio = :matched)`, `Mindlin(friction_coefficient = 0.5, poisson_ratio = 0.0)` | 2, 13 |
| `mass` | `EqualMass(1.0)` | `Density(1.0; shape = :disc)` (`:sphere` in 3D) | 4 |
| `target` | `Pressure(1e-4)` | | 2 |
| `convergence` | `RelativeForce(tolerance = 1e-8)` | `LeidenAcceleration(tolerance = 1e-10)`, `KineticEnergy(tolerance = 1e-8)`, `RestartTest()`, any function | 5 |
| `pressure_tolerance` | `1e-4` | any value | 5 |
| `steps_max` | `10^7` | any value | 5 |
| `failure_action` | `:warn` | `:error` | 6 |
| `restart_packing` | `nothing` | path to a file written by `write_packing` | 6 |
| `restart_file` | `nothing` | `RestartFile(path; every = interval)` | 6 |
| `algorithm` | `FIRE()` | `DampedDynamics()` | 7, 14 |
| `timestep` | `CollisionTime(fraction = 1/50)` | any fraction, or a fixed number | 12 |
| `DampedDynamics` `damping` | `ContactDamping(normal = 0.98, tangential = 0.98)` | other ratios, `ViscousRate(normal = 0.5, tangential = 0.5)`, `RelativeVelocityDamping(rate = 0.5)`, `nothing` | 8 |
| `DampedDynamics` `drag` | `nothing` | `StokesDrag(velocity = rate)`, with `spin` and `during` | 8 |
| `FIRE` `damping`, `drag` | `nothing`, `nothing` | same as `DampedDynamics` | 8 |
| FIRE parameters | LAMMPS FIRE 2.0 defaults | any value | 14 |
| `rattlers` | `ContactCount(cone_test = true)` | `TwoContact()`, `ForceFloor(floor = 1e-3)`, `Unresolved(floor = :tolerance)`, `nothing`, any function | 9 |
| `seed` | `1` | any integer | 10 |
| `snapshots`, `movie` | `nothing` | `Snapshots(every = interval)`, `Movie(path; every = interval)` | 11 |
| file format (`write_packing`) | HDF5 | CSV | 11 |
| `write_packing` `rattlers_file` | `false` | `true` | 11 |
| `write_packing` `compression` | `nothing` | `:gzip` (level 4) | 11 |

## 1. Interface and naming

```julia
pack()                                                  # every default
pack(particles_count = 2000, target = Pressure(1e-4))   # keywords
pack(params)                                            # a reusable PackParams value
```

**Decision.** `pack()` runs with no arguments. Settings are keywords or a reusable
`PackParams` value. Any setting with its own sub-settings is a small type
(`Pressure`, `FIRE`, `CundallStrack`, ...) so algorithms, force laws and rules can be
swapped by dispatch. Names follow the Julia style guide: CamelCase types, snake_case
functions and keywords, `!` for functions that mutate an argument. Keywords are full
English words, never a symbol from one paper's notation or an abbreviation:
`friction_coefficient`, not `mu` or `friction_coeff`. Multi-word keywords read like
`Object.member`, the thing first and then its property: `friction_coefficient`
(friction.coefficient), `particles_count`, `timestep_max`. Functions keep verb-first
names (`find_rattlers`, `write_packing`).

- [JuliaStyle] "modules and type names use capitalization and camel case"
- [JuliaStyle] "Function names should be written in snake case"
- No abbreviations: [JuliaStyle] "conciseness is valued, but avoid abbreviation
  (indexin rather than indxin) as it becomes difficult to remember whether and how
  particular words are abbreviated." (coef or coeff?)
- No notation symbols, because papers name the same quantity differently.
  [Santos2024] "the tangential forces are referred to by the letter 's' to indicate
  that we include sliding friction between the particles", where [Silbert2001] write
  $k_t$ and $\gamma_t$ for the same springs and dashpots; LAMMPS calls the friction
  coefficient `xmu` [LAMMPSgran]. **SoftPack choice.**
- Object-then-property order: **SoftPack choice**, so a keyword reads like a struct
  field (`timestep_max` as timestep.max) and related settings sit together
  (`timestep_max`, `timestep_min`, `timestep_grow`, `timestep_shrink`;
  `particles_count`, `particles_diameters`, `particles_size_distribution`). Function
  names follow the style guide's verb-first examples: [JuliaStyle] "Function names
  should be written in snake case (minimum, count_zeros, escape_string)."

## 2. Default packing

The default packing is 2D, with 256 particles in a 50:50 bidisperse mixture of
diameter ratio 1.4, frictionless Hookean contacts of stiffness 1, a target pressure of
$10^{-4}$, and FIRE. `pack()` with no arguments uses all of them.

```julia
pack(dimension = 2)
```

**Decision.** Two-dimensional packings (disks).

- **SoftPack choice.** 2D packings are the cheapest to make and to check by eye, and
  the bidisperse mixture below is the standard 2D one. `dimension = 3` is an option.

```julia
pack(particles_count = 256)
```

**Decision.** 256 particles.

- **SoftPack choice.** Small enough that `pack()` with no arguments finishes in
  seconds, and inside the range of jamming studies: [OHern2003] "We
  have studied the finite-size effects by varying the number of particles in the
  sample between 4 < N < 4096 in 2D and 3D." Production runs should set
  `particles_count`.

```julia
pack(particles_size_distribution = Bidisperse(diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5))
```

**Decision.** A 50:50 mixture of two diameters with ratio 1.4 (the distribution's
settings are in §3).

- [OHern2003] "In our two-dimensional (2D) simulations,
  we have used 50-50 mixtures of particles with a size ratio of 1.4 in order to
  prevent crystallization".

```julia
pack(contact = Hookean())
```

**Decision.** Hookean (harmonic) contacts. Two particles $i$ and $j$ with diameters
$d_i$, $d_j$ and centers a distance $r_{ij}$ apart overlap by
$\delta_{ij} = (d_i + d_j)/2 - r_{ij}$. While $\delta_{ij} > 0$ their elastic energy
and repulsive force are

$$U(\delta_{ij}) = \frac{k}{\alpha}\,\delta_{ij}^{\,\alpha}, \qquad f_{ij} = -\frac{dU}{dr_{ij}} = k\,\delta_{ij}^{\,\alpha-1},$$

and both are zero when $\delta_{ij} \le 0$. $k$ is the `stiffness`. `Hookean` is
$\alpha = 2$ ($U = \tfrac12 k\delta^2$, $f = k\delta$); `Hertzian(stiffness = 1.0)` is
the option $\alpha = 5/2$ ($U = \tfrac25 k\delta^{5/2}$, $f = k\delta^{3/2}$).

- The exponents are the jamming standard: [OHern2003] use the potential (their
  Eq. 1)

$$V(r_{ij}) = \frac{\epsilon}{\alpha}\left(1 - \frac{r_{ij}}{\sigma_{ij}}\right)^{\alpha} \quad \text{for } r_{ij} < \sigma_{ij}, \qquad V = 0 \text{ otherwise},$$

  with $\sigma_{ij}$ "the sum of the radii of particles i and j", and study both
  "α = 2 for repulsive harmonic springs"
  and "α = 5/2 for repulsive Hertzian interactions".
- One stiffness for every pair: **SoftPack choice**. [OHern2003] divide the overlap
  by $\sigma_{ij}$, so their effective stiffness $\epsilon/\sigma_{ij}^{\alpha}$ is
  smaller for pairs of large particles; the two forms are identical for a pair of
  small particles ($\sigma_{ij} = 1$, $k = \epsilon$). SoftPack uses one $k$ so that
  `stiffness` is a single spring constant that sets the force unit, the collision time
  (§12) and the damping (§8), as in DEM codes: [LAMMPSgran] "Kn = elastic constant for
  normal particle repulsion (force/distance units or pressure units - see discussion
  below)". The material Hertz law also grows with the pair's reduced radius; SoftPack's
  `Hertzian`, like O'Hern's, is the pure power law.
- Hookean is the default (**SoftPack choice**) because its stiffness does not change
  with overlap, so the collision time, time step and damping ratio are fixed for the
  whole run.

```julia
pack(contact = Hookean(stiffness = 1.0))
```

**Decision.** $k = 1$ sets the force unit. With the small diameter $d = 1$ as the
length unit, the target pressure is then the dimensionless pressure, which says how
deeply the particles overlap.

- Why one number is enough. A static packing has only three scales: the diameter $d$,
  the stiffness $k$ and the pressure $P$ (masses set how fast the packing gets there,
  not where it ends up). The pressure is fixed by the mean normal contact force
  $\langle f_n\rangle$: for monodisperse spheres [Agnolin2007] (their Eq. 22) give
  $P = z\Phi\langle N\rangle/(\pi a^2)$, with $z$ the contacts per particle, $\Phi$ the
  packing fraction, $\langle N\rangle$ the mean normal force and $a$ the diameter. The
  same counting for disks gives $P = z\varphi\langle f_n\rangle/(\pi d)$ (our
  conversion). With Hookean contacts $\langle f_n\rangle = k\langle\delta\rangle$, so

$$\text{2D: } \frac{P}{k} = \frac{z\varphi}{\pi}\,\frac{\langle\delta\rangle}{d}, \qquad \text{3D: } \frac{P\,d}{k} = \frac{z\varphi}{\pi}\,\frac{\langle\delta\rangle}{d}.$$

  Near jamming $z\varphi/\pi$ is about 1.1 in 2D ($z \approx 4$, $\varphi \approx 0.84$)
  and 1.2 in 3D ($z \approx 6$, $\varphi \approx 0.64$) (our conversion), so the
  dimensionless pressure is the typical overlap as a fraction of a diameter.
- The pressure also measures the distance to jamming: [OHern2003] find that "the
  pressure vanishes as a power law" as $\varphi \to \varphi_c^+$,
  $p \propto (\varphi - \varphi_c)^{\alpha - 1}$, "independent of polydispersity or
  dimensionality", and explain it: "If the deformation is affine, one would expect the
  exponent for the pressure to be the same as for the force law". For Hookean contacts
  all three are the same small number:

$$\frac{P}{k\,d^{\,2-D}} \sim \frac{\langle\delta\rangle}{d} \sim \varphi - \varphi_c,$$

  where $D$ is the dimension and $\sim$ means equal up to a factor of order one. The
  default $P = 10^{-4}$ is a packing whose overlaps are about $10^{-4}$ of a diameter.
- This is how the field reports pressure. Jamming papers give it in units of the
  contact stiffness: [OHern2003] "The pressure p, stress Σ, bulk modulus B, and shear
  modulus G are measured in units of" $\epsilon/\sigma^{d}$ ($d$ the dimension there),
  which for SoftPack's units is $k$ in 2D and $k/d$ in 3D. DEM papers use the same
  ratio, inverted: [Agnolin2007] "The elastic contact law introduces a dimensionless
  stiffness parameter κ", $\kappa = (\tilde E/P)^{2/3}$ for Hertz contacts, with
  "Under pressure P, the typical force in a contact is of order P a²" and "κ sets the
  scale of the typical normal deflection h in Hertzian contacts, as h/a ∼ 1/κ."
  Packings at the same $P/k$ (or $\kappa$) are the same packing in different units, so
  $k = 1$ loses nothing: **SoftPack choice** for the value.

```julia
pack(target = Pressure(1e-4))
```

**Decision.** Compress to the pressure $P = 10^{-4}$ (in units of $k$ in 2D, $k/d$ in
3D). The pressure is the contact (virial) pressure, from the elastic contact forces
only:

$$P = \frac{1}{D\,V}\sum_{c}\mathbf{f}^{c}\cdot\boldsymbol{\ell}^{c} = \frac{1}{D\,V}\sum_{c} f_n^{c}\,\ell^{c},$$

where the sum runs over all contacts $c$ between particles $i$ and $j$,
$\boldsymbol{\ell}^{c} = \mathbf{r}_i - \mathbf{r}_j$ is the vector between their
centers (nearest periodic image), $\mathbf{f}^{c}$ is the elastic contact force on $i$
from $j$, $V$ is the volume of the box (its area in 2D) and $D$ the dimension. A
tangential (friction) force is perpendicular to $\boldsymbol{\ell}^{c}$ for disks and
spheres, so only the normal force $f_n^{c}$ contributes.

- The formula is the trace of the standard average-stress formula, [Agnolin2007]
  Eq. (8), $\sigma_{\alpha\beta} = \frac{1}{\Omega}\left(\sum_i m_i v_{i\alpha}v_{i\beta} + \sum_{i<j} F_{ij}^{(\alpha)} r_{ij}^{(\beta)}\right)$,
  divided by $D$.
- Elastic contact forces only, no velocity term and no dashpot forces: the target is
  a static packing, and [Agnolin2007] stop when "the elastic contributions to the
  stress components equal the prescribed value P".
- $10^{-4}$: **SoftPack choice**, near jamming but high enough to converge quickly
  (overlaps of about $10^{-4}$ of a diameter, see `stiffness` above). Frictional
  jamming studies span pressures from $10^{-6}$ to $10^{-3}$ [Henkes2010]
  (Hertz-Mindlin particles, so their pressure unit differs from ours).

```julia
pack(algorithm = FIRE())
```

**Decision.** Minimize with FIRE.

- FIRE: introduced in [Bitzek2006]; assessed and implemented in LAMMPS in
  [Guenole2020]. Its settings are in §14. `DampedDynamics()` is the other algorithm
  (§7, §8).

```julia
pack(friction = nothing)
```

**Decision.** Frictionless contacts.

- **SoftPack choice**. FIRE on a frictionless packing has a well-defined end state
  (an energy minimum) and known checks (jamming packing fraction, $z \to 4$ in 2D);
  frictional packings depend on the preparation path (see §7). Friction models are
  in §13.

## 3. Particle size distribution and length unit

Sizes are diameters everywhere. `particles_size_distribution` chooses the law the
diameters are drawn from; `particles_diameters` gives the diameters themselves. Each
distribution sets its own length unit in its defaults: `Bidisperse` makes the small
diameter 1 (the jamming convention); polydisperse distributions make the mean diameter
1 (the Leiden convention). Every output stores each particle's diameter.

- DEM software takes diameters: [LAMMPSset] "diameter value = diameter of spherical
  particle (distance units)"

```julia
pack(particles_size_distribution = Bidisperse(diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5))
```

**Decision.** The default (§2). `fraction_small` is the number fraction of small
particles.

- `diameter_small = 1.0`, the small diameter as the length unit: [OHern2003] "The
  diameter of the smaller particle
  is denoted by σ." ... "lengths are measured in units of σ"
- `diameter_ratio = 1.4`, `fraction_small = 0.5`: the [OHern2003] mixture (§2).

```julia
pack(particles_size_distribution = UniformPolydisperse(diameter_mean = 1.0, spread = 0.2))
```

**Decision.** Diameters uniform between $d_\text{mean}(1 - s)$ and
$d_\text{mean}(1 + s)$, with $d_\text{mean}$ = `diameter_mean` and $s$ = `spread`.

- `diameter_mean = 1.0`, the mean diameter as the length unit: [Somfai2005] "Our unit
  of length is the average grain
  diameter." [Shundyak2007] "our units are such that the mass density, the average
  particle diameter, and the Young's modulus of the grains are 1."
- `spread = 0.2`: [Somfai2005] "For the 2D simulations the spheres have
  polydispersity to avoid crystallization: the diameters are uniformly distributed
  between 0.8 and 1.2 times their average."

```julia
pack(particles_size_distribution = Monodisperse(diameter = 1.0))
```

**Decision.** One diameter for every particle; an option, not the default.

- Equal disks crystallize in 2D (the reason for the bidisperse mixture, §2). In 3D,
  [OHern2003] "we have studied the
  same bidisperse mixture as well as monodisperse systems".
- `diameter = 1.0`: **SoftPack choice**, the one diameter is the length unit.

```julia
pack(particles_diameters = nothing)               # default: draw from particles_size_distribution
pack(particles_diameters = [1.0, 1.4, 1.0, 1.4])  # exactly these diameters
```

**Decision.** By default the diameters are drawn from `particles_size_distribution`.
Giving `particles_diameters` uses exactly those diameters instead, one per particle,
and `particles_count` is then their number. Give a distribution or the diameters, not
both. **SoftPack choice**: an exact list is how a packing is matched to an experiment
or to another code's particles.

## 4. Mass

Every particle has mass 1 by default; the option sets masses from a material density.
Per-particle masses are stored in the output so spectra computed later use the same
masses.

```julia
pack(mass = EqualMass(1.0))
```

**Decision.** Equal masses, each 1.

- Equal mass (jamming / soft-sphere convention): [OHern2003] "... where all
  particles have equal mass m."
- The value 1.0 sets the mass unit: **SoftPack choice**.

```julia
pack(mass = Density(1.0; shape = :disc))
```

**Decision.** The option: mass from a material density times the particle's area
(`shape = :disc`, the default in 2D) or volume (`shape = :sphere`, the default in 3D).

- Density-based mass (DEM convention): [LAMMPSset] "density/disc value = particle
  density for a 2d disc or ellipse (mass/distance^2 units)"; [Somfai2005] "The unit
  of mass is set by asserting that the material of the grains has unit density."
  That is the reason for the default density 1.0.
- `shape = :disc` in 2D: **SoftPack choice**, because SoftPack's 2D particles are
  disks. `shape = :sphere` in 2D gives the Leiden convention: [Somfai2005] "2D
  samples containing 600 spheres (their centers being confined to a plane)".

## 5. Convergence (stopping) criterion

One rule for frictionless and frictional packings: every particle's net force (and
net torque, with friction) must be small compared with the typical contact force, and
the pressure (§2) must be at its target. A run stops after `steps_max` steps at most.
Options: `LeidenAcceleration`, `KineticEnergy`, `RestartTest`, or any function of the
packing state that returns true when done.

```julia
pack(convergence = RelativeForce(tolerance = 1e-8))
```

**Decision.** With $\epsilon_F$ = `tolerance`, a packing has converged when

$$\max_i \left|\mathbf{F}_i\right| < \epsilon_F\,\langle f_n\rangle \qquad \text{and, with friction,} \qquad \max_i \left|\mathbf{T}_i\right| < \epsilon_F\,\langle f_n\rangle\,\langle d\rangle,$$

where $\mathbf{F}_i$ and $\mathbf{T}_i$ are the net elastic force and torque on
particle $i$, $\langle f_n\rangle$ is the mean normal contact force over all contacts
(the force behind the pressure, §2), and $\langle d\rangle$ is the mean diameter.

- A tolerance relative to the typical force: [Agnolin2007] "Calculations are
  stopped when the net elastic force on each particle is below 10^-4 a^2 P, the
  elastic contributions to the stress components equal the prescribed value P with
  relative error smaller than 10^-4 and the kinetic energy per particle is below
  10^-8 P a^3." [Gilabert2007] "the net force on each disk is less than 10^-4 F_1,
  and the total moment is lower than 10^-4 F_1 a" (with $F_1 = \max(F_0, Pa)$, the
  typical intergranular force).
- The torque scale $\langle f_n\rangle\langle d\rangle$ follows [Gilabert2007]'s
  force times diameter; using the mean diameter for polydisperse packings is a
  **SoftPack choice**.
- `tolerance = 1e-8`, tighter than the $10^{-4}$ above: provisional **SoftPack
  choice**, to be timed on frictional packings.

```julia
pack(pressure_tolerance = 1e-4)
```

**Decision.** With $\epsilon_P$ = `pressure_tolerance`, the pressure $P$ defined in
§2 must satisfy

$$\left|P - P_\text{target}\right| \le \epsilon_P\,P_\text{target}.$$

- The [Agnolin2007] value above (stress equal to P "with
  relative error smaller than 10^-4"). [Gilabert2007] use the same $10^{-4}$ level for
  the pressure, scaled by their typical force $F_1$.

```julia
pack(steps_max = 10^7)
```

**Decision.** At most $10^7$ steps per call.

- **SoftPack choice.** A safety cap, not a convergence test: a run that hits it is
  returned with `converged = false` (§6) and can be continued with `restart_packing`.
  The value is twice the $5\times10^{6}$ cap of GranEJulia's packer, which SoftPack
  replaces and which stops at a looser force tolerance ($10^{-4}$ against $10^{-8}$
  here).

```julia
pack(convergence = LeidenAcceleration(tolerance = 1e-10))
```

**Decision.** The option's default: every particle's acceleration below
$10^{-10}$, the Leiden rule.

- [Somfai2005] "Our packings
  are considered to have converged to mechanical equilibrium when all grains have
  acceleration less than 10^-10 in our reduced units". [Shundyak2007] builds its
  packings "As in [16]", reference 16 being [Somfai2005]. The number $10^{-10}$ only
  reproduces the Leiden rule in Leiden units ($E^* = 1$, mean diameter 1, density 1).

```julia
pack(convergence = KineticEnergy(tolerance = 1e-8))
```

**Decision.** The option's default: with $\epsilon_K$ = `tolerance`, the mean kinetic
energy per particle must satisfy $\frac{1}{N}\sum_i E_i^\text{kin} < \epsilon_K\,P\,d^{D}$
($N$ the number of particles, $d$ the small diameter, $D$ the dimension).

- The [Agnolin2007] value above; [Xiong2019] stop each minimization on a maximum
  per-disk kinetic energy.

```julia
pack(convergence = RestartTest())
```

**Decision.** The option: zero all velocities, then check that the kinetic energy and
the unbalanced forces do not grow back. It has no settings.

- [Agnolin2007] "On setting all velocities to zero,
  it is observed that the sample does not regain kinetic energy beyond that value,
  while the unbalanced force level does not increase."

## 6. A packing that does not converge

`pack()` never throws away or silently saves an unfinished packing. It returns it
flagged, and the run can be continued later from a file. Long runs can also save
their state as they go, so a job stopped by a time limit or a crash can be continued.

```julia
pack(failure_action = :warn)
```

**Decision.** `pack()` prints a warning and returns the packing with
`converged = false`. Retrying with other seeds is the caller's job.

- **SoftPack choice**: let the caller see and count failures (replacing failures
  conditions an ensemble on convergence).
- Option: `failure_action = :error` throws an error instead, for batch scripts that
  should stop at the first failure. **SoftPack choice.**

```julia
pack(restart_packing = nothing)
```

**Decision.** Off by default. `restart_packing = path` loads a packing written by
`write_packing`, converged or not, with all of its settings and its full state, and
continues the run from the step where it stopped:

```julia
packing = pack(steps_max = 10^6)                # returns with converged = false
write_packing("packing.h5", packing)
packing = pack(restart_packing = "packing.h5")  # continues where it stopped
```

- Precedent: LAMMPS restart files. [LAMMPSreadrestart] "Read in a previously saved
  system configuration from a restart file. This allows continuation of a previous
  run."
- Everything needed is in the file (§11): every particle, including rattlers; positions,
  velocities, rotations and spins; the contact history (tangential springs); the box;
  the algorithm's internal state (FIRE's current step and mixing coefficient and its
  counters); the state of the compression protocol; the step count; every setting; and
  the SoftPack and Julia versions. A restart needs no other input. LAMMPS does not do
  this: [LAMMPSwriterestart] "Although the purpose of restart files is to enable
  restarting a simulation from where it left off, not all information about a
  simulation is stored in the file." **SoftPack choice.**
- Exact continuation: a run stopped and restarted ends with the same packing as one
  run that was never stopped, on the same machine and versions. This is a test
  requirement. [LAMMPSreadrestart] "Restart files are saved in binary format to enable
  exact restarts, meaning that the trajectories of a restarted run will precisely match
  those produced by the original run had it continued on." LAMMPS warns that granular
  pair styles do not restart exactly: "the forces they compute depend on atom
  velocities, which are used at half-step values every timestep when forces are
  computed. When a run restarts, forces are initially evaluated with a full-step
  velocity, which is different than if the run had continued." SoftPack's dashpots
  depend on velocity too, so the file stores the integrator's half-step state.
  **SoftPack choice.**
- On a different SoftPack or Julia version the restart runs but warns that it may not
  be exact, as LAMMPS does: [LAMMPSreadrestart] "Several things can prevent exact
  restarts due to round-off effects, in which case the trajectories in the 2 runs will
  slowly diverge."
- Only run-control settings may change on a restart: `steps_max` (a new budget,
  counted from the restart), `failure_action`, `convergence`, `restart_file`,
  `snapshots` and `movie`, e.g. `pack(restart_packing = "packing.h5", steps_max = 2 * 10^7)`. Any other keyword
  raises an error, because it would change the protocol halfway through and the
  packing would match neither setting. **SoftPack choice.**
- A converged packing can be restarted too, for example with a tighter `convergence`
  tolerance. The output records each restart (file and step).

```julia
pack(restart_file = nothing)
```

**Decision.** Off by default. `restart_file = RestartFile(path; every = interval)`
saves the run's full state to `path` while it runs, in the same format that
`restart_packing` reads. `every` is a number of steps (`every = 10^5`) or a
wall-clock time (`every = Hour(1)`, from Julia's Dates). For a cluster job with a time
limit:

```julia
# job 1: stopped by the time limit
pack(particles_count = 10^5, restart_file = RestartFile("restart.h5"; every = Hour(1)))
# job 2: continues from the last save
pack(restart_packing = "restart.h5")
```

- Precedent and default: [LAMMPSrestart] "Write out a binary restart file with the
  current state of the simulation on timesteps which are a multiple of N. A value of
  N = 0 means do not write out any restart files, which is the default." Off by default
  also because short runs do not need it and each save costs time and disk.
- `every` has **no default** and must be given: the right interval depends on how long
  the run is and on the job's time limit. **SoftPack choice**, as for `Snapshots`.
- A wall-clock interval: **SoftPack choice**. Cluster limits are in wall-clock time, so
  a time interval bounds the work lost when a job is killed (at most `every`) for any
  system size. Saving does not change the trajectory, so the packing is the same
  whether or not, and how often, it is saved.
- One file, never half-written: each save goes to a temporary file that is then
  renamed over `path`, so a job killed in the middle of a save still leaves the last
  complete file. LAMMPS gets the same safety by alternating between two files:
  [LAMMPSrestart] "If two filenames are specified, only 2 restart files will be
  created, with those names. LAMMPS will toggle between the 2 names as it writes
  successive restart files." The rename keeps one name that is always valid.
  **SoftPack choice.**
- The file is also written when the run stops, converged or not, so the last state is
  always on disk without a separate `write_packing` call. **SoftPack choice.**
- `restart_file` is a run-control setting (see `restart_packing` above): a continued
  run keeps saving to the same file unless a new `restart_file` is given.

## 7. Algorithms and combinations

**Decision.** Every combination of algorithm, contact law, friction model, target,
convergence test and rattler rule is allowed in one `pack()`. Force models (normal
law plus friction, holding the contact history) and algorithms only exchange
positions/rotations and forces/torques. FIRE with friction is allowed and recorded,
but documented as non-standard. The algorithm defaults to `FIRE()` (§2).

- Frictional packings in the literature are made with damped dynamics, not FIRE:
  [Xiong2019] "we minimize the total potential energy U by adding viscous damping
  forces proportional to each disk's velocity"; [Santos2024] use "a Hookean
  spring-dashpot-slider interaction potential (Cundall and Strack, 1979)" with a
  barostat in LAMMPS; [Somfai2007] "The packings are constructed by cooling while
  slowly inflating the particle radii in the presence of a linear damping force";
  [Agnolin2007] "Energy is dissipated thanks to viscous forces in contacts".
- We did not find a paper that makes frictional packings with FIRE (searched
  2026-11-18). That is why FIRE + friction is labeled non-standard.
- The preparation path changes frictional packings, so the algorithm and its damping
  settings (§8) are part of the packing's identity and are recorded in every output.
  [Henkes2010], on the relation between the friction coefficient and $n_m$ (the
  fraction of fully mobilized contacts): "Our simulations indicate that this relation
  depends significantly on the preparation method of the sample, where packings
  prepared with higher viscous damping have larger n_m"; see also [Santos2024].

## 8. Damping

Damping sets how damped molecular dynamics (`DampedDynamics`) removes energy. FIRE
removes energy with its own velocity rules, so its default is no damping, but it
accepts the same settings (§7: any combination is allowed).

### Energy-loss channels

| Channel | What it damps | Setting |
|---|---|---|
| Normal contact dashpot | Approach and separation speed of touching particles | `ContactDamping(normal = ...)` |
| Tangential contact dashpot | Sliding speed at the contact point (friction on only) | `ContactDamping(tangential = ...)` |
| Relative-velocity dashpot | Full relative velocity of the two centers, one rate for both directions (friction on or off) | `RelativeVelocityDamping(rate = ...)` |
| Stokes drag on velocity | Each particle's absolute velocity | `StokesDrag(velocity = ...)` |
| Stokes drag on spin | Each particle's absolute spin | `StokesDrag(spin = ...)` |
| Coulomb sliding | Built into friction | not a setting |

Contact damping and Stokes drag fail in opposite ways on the slow, collective (soft)
modes, which are the last motion left when a run nears its stopping rule. Both are
Rayleigh damping, $\boldsymbol\Gamma = a\mathbf M + b\mathbf K_0$ ($\mathbf M$ the mass
matrix, $\mathbf K_0$ the unstressed stiffness matrix). Each undamped mode $\ell$, of
angular frequency $\omega_\ell$, then obeys its own damped-oscillator equation,

$$\lambda_\ell^2 + \left(a + b\,\omega_\ell^2\right)\lambda_\ell + \omega_\ell^2 = 0,$$

so while underdamped it decays at $\beta_\ell = -\mathrm{Re}\,\lambda_\ell = (a + b\,\omega_\ell^2)/2$, with damping ratio $\zeta_\ell = \beta_\ell/\omega_\ell$.

- Contact damping is the $b$ term. For `ContactDamping` with its defaults and Hookean
  contacts, $b = \gamma/k = 2\zeta/\omega_c$, with $\zeta$ the contact damping ratio and
  $\omega_c = \sqrt{k_n/M_n}$ the contact frequency (tangential decision below). Then
  $\beta_\ell = b\,\omega_\ell^2/2$ and $\zeta_\ell = \zeta\,\omega_\ell/\omega_c$: the
  lowest-frequency modes die last, ringing with $\zeta_\ell \ll 1$.
- Stokes drag is the $a$ term, with $a$ the drag rate. Then $\beta_\ell = a/2$ for every
  mode and $\zeta_\ell = a/(2\,\omega_\ell)$: soft modes are overdamped and creep,
  relaxing at about $\omega_\ell^2/a$.

**SoftPack note** (standard result for Rayleigh damping; not taken from a cited
paper).

The $b$ result is exact for `ContactDamping` with its defaults and Hookean contacts:
normal-only without friction, and with friction because `stiffness_ratio = :matched`
and `tangential_mass = :with_rotation` give both directions the same $b$.
`RelativeVelocityDamping` is not proportional. Without friction its damping matrix is
$\boldsymbol\Gamma = b\,(\mathbf K_0 + \mathbf K_\perp)$, with $b = \gamma/k$ ($\gamma$ the
dashpot coefficient, $k$ the contact stiffness) and $\mathbf K_\perp$ the same sum over
contacts as $\mathbf K_0$ with the tangential projector
$\mathbf I - \hat{\mathbf n}\hat{\mathbf n}^\top$ in place of
$\hat{\mathbf n}\hat{\mathbf n}^\top$: a damping term with no spring behind it. To
first order in the damping (mass-weighted matrices, $|v_\ell\rangle$ the unit vector of
mode $\ell$),

$$\beta_\ell \approx \frac{b}{2}\left[\omega_\ell^2 + \langle v_\ell|\mathbf K_\perp|v_\ell\rangle\right].$$

Soft modes whose contacts mostly slide keep a finite decay rate as
$\omega_\ell \to 0$, so their damping ratio grows and they creep, as under drag.
Low-frequency plane waves, with little relative motion, still decay as
$\omega_\ell^2$. Slow motion near jamming is mostly sliding: [Vagberg2014] find that
"the relative motion of particles in contact is almost always tangential" (shear flow
below jamming, $\phi \gtrsim 0.6$). **SoftPack note** (our derivation, the same
algebra as the proportional case).

### Defaults

All damping defaults together:

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

Each default and the reason for it:

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(normal = 0.98)))
```

**Decision.** Each contact's normal dashpot is 0.98 of its critical value.

- A ratio to critical damping, not a raw coefficient, so it means the same for Hooke
  and Hertz contacts: [Gilabert2007] "We choose its value as a constant fraction ζ of
  the critical damping coefficient" ... "This is equivalent to the choice of a
  constant restitution coefficient in normal collisions if F₀ = 0." ($F_0$ is their
  maximum cohesive force, zero for SoftPack's particles.) [Agnolin2007] use the same
  form, their Eq. (5): $\alpha(h) = \zeta\sqrt{2mK_N(h)}$, which grows as $h^{1/4}$
  for Hertz contacts.
- The value 0.98: [Agnolin2007] "we generally use a strong dissipation, ζ = 0.98, to
  approach equilibrium faster", and "the initial motivation for choosing ζ < 1 is the
  computational inefficiency of overdamped contacts with ζ > 1 in the case of linear
  contact elasticity." For Hooke contacts, $\zeta = 0.98$ gives a restitution
  coefficient $e = \exp\left(-\pi\zeta/\sqrt{1-\zeta^2}\right) \approx 2\times10^{-7}$
  (our conversion): a loose particle stops at its first impact.
- The packing does not depend much on the exact value: [Agnolin2007] "changes of ζ in
  the range between 0.7 and 1 have virtually no detectable effect", and "a value of
  the damping parameter ten times as small as the standard one ζ = 0.98 results in
  quite similar configuration properties".

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(tangential = 0.98)))
```

**Decision.** Tangential dashpot on, with the same ratio as the normal one.

- Without it, a stuck contact's back-and-forth sliding is damped only when it slips.
  The Leiden protocol damps both directions: [Somfai2005] "which is at every instant
  a given constant fraction of the linear critical viscous damping, both for the
  normal and for the tangential force". [Silbert2001], whose baseline has no
  tangential damping, report for their flow simulations: "Making γt/γn non-zero
  quickens the approach to the steady state by draining out more energy."
- [Santos2024] also damp both directions, with equal raw values: "The normal (n)
  and tangential (s) particle spring (k) and damping (γ) parameters are set equal to
  each other". Their γ is a LAMMPS rate, multiplied by the pair mass in both
  directions [LAMMPSgran], so this is the `ViscousRate` convention with $k_t = k_n$,
  not an equal ratio. For their frictional spheres ($M_t = M_n/3.5$) it makes the
  tangential ratio $\sqrt{3.5} \approx 1.9$ times the normal one (our conversion). It
  supports damping both directions at a similar strength, not the equal ratio itself.
- The same ratio makes the damping exactly proportional to the stiffness. A
  contact's dashpot over its spring is $b = \gamma/k = 2\zeta/\omega$, with
  $\omega = \sqrt{k_n/m_n}$ for the normal direction and $\sqrt{k_t/m_t}$ for the
  tangential one. With `stiffness_ratio = :matched` (§13) and `tangential_mass =
  :with_rotation` (below), the two frequencies are equal, so one $\zeta$ gives one $b$
  in both directions and $\boldsymbol\Gamma = b\,\mathbf K_0$, with $\mathbf K_0$ the
  unstressed stiffness matrix. The modes then decouple, and every underdamped mode
  decays at exactly $b\,\omega_\ell^2/2$. One raw coefficient for both directions
  would instead give $\zeta_t = 3\zeta_n$ for disks (overdamped sliding) and mix the
  modes. Exact for Hookean contacts and equal masses; with Hertz or Mindlin contacts,
  or `Density` masses, $b$ varies from contact to contact. **SoftPack note** (our
  derivation).
- It applies only when friction is on. Frictionless contacts have no tangential
  spring, so there is no tangential critical value to take a fraction of. A
  tangential dashpot without friction is `RelativeVelocityDamping` (Options).

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(tangential_mass = :with_rotation)))
```

**Decision.** The tangential critical value uses the true sliding mass.

- A tangential force at the contact both pushes and spins the two particles, so the
  sliding motion responds like a lighter mass than the pair. For particles $i$ and
  $j$ with masses $m$, radii $R$ and moments of inertia $I$, the tangential and
  normal masses are

$$\frac{1}{M_t} = \frac{1}{m_i} + \frac{1}{m_j} + \frac{R_i^2}{I_i} + \frac{R_j^2}{I_j},
\qquad \frac{1}{M_n} = \frac{1}{m_i} + \frac{1}{m_j}.$$

- Each dashpot is the given fraction $\zeta$ of its own critical value,

$$\gamma_{n,\text{crit}} = 2\sqrt{k_n M_n}, \qquad \gamma_{t,\text{crit}} = 2\sqrt{k_t M_t},$$

  so one $\zeta$ does not mean one coefficient. For equal disks ($M_n = m/2$,
  $M_t = m/6$) with `stiffness_ratio = :matched` ($k_t = k_n/3$, §13),

$$\frac{\gamma_t}{\gamma_n} = \sqrt{\frac{k_t M_t}{k_n M_n}} = \frac{1}{3}.$$

  Both directions decay equally fast, with a tangential coefficient a third of the
  normal one.
- For equal disks $M_t = M_n/3$, for equal spheres $M_t = M_n/3.5$. A ratio measured
  on the pair mass $M_n$ would really be $0.98\sqrt{3} \approx 1.7$ for disks and
  $0.98\sqrt{3.5} \approx 1.8$ for spheres, which is overdamped and slow. Measuring it
  on $M_t$ makes 0.98 mean 0.98. **SoftPack choice**, from the rigid-body mechanics
  of two particles in contact.
- For Mindlin contacts the critical value uses the contact's current tangential
  stiffness, as the normal one does for Hertz.

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(attractive = false)))
```

**Decision.** The dashpot never makes a contact pull.

- When two touching particles separate, the normal dashpot can outweigh the spring.
  [Somfai2005] "We impose that the total radial force, which now also contains the
  viscous contribution, never becomes attractive." LAMMPS offers the same switch:
  [LAMMPSgran] "If two particles are moving away from each other while in contact,
  there is a possibility that the particles could experience an effective attractive
  force due to damping. If the limit_damping keyword is used, this option will zero
  out the normal component of the force if there is an effective attractive force."
- Default `false` because these are cohesionless particles: a pulling contact is an
  artifact of the dashpot, not physics.

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(coulomb_limit = :elastic)))
```

**Decision.** The friction limit applies to the spring forces only.

- The elastic tangential force is capped at $\mu$ times the elastic normal force,
  $|F_t^\text{el}| \le \mu\,F_n^\text{el}$. A sliding contact carries exactly that
  force, and its tangential dashpot is off while it slides, so the tangential force
  never exceeds the Coulomb limit.
- Following [Agnolin2007] "We do not introduce any tangential viscous force, and
  impose the Coulomb inequality to elastic force components only." At rest every
  dashpot force is zero, so the finished packing's forces are purely elastic and
  satisfy the Coulomb limit exactly.
- Switching the dashpot off while sliding is a **SoftPack choice** (Agnolin and
  Roux have no tangential dashpot to switch): slip already removes energy, and it
  keeps the sliding force at the Coulomb limit.

```julia
pack(algorithm = DampedDynamics(drag = nothing))
```

**Decision.** No Stokes drag.

- **SoftPack choice.** Energy leaves only through contacts. Contact damping acts on
  relative motion only, so it does not slow a uniform drift of the whole packing, adds
  no extra time scale, and does not make the soft modes creep (see the channels
  above).
- The cost is slower settling of particles with few contacts and of pure rolling. The
  reason drag exists as an option: [Shimada2026] add it because "Without these
  single-particle dissipative interactions, dissipation occurs only when particles
  are in contact with each other. As a result, particles with fewer contacts
  dissipate energy more slowly, hindering the system from converging to an inherent
  structure within a reasonable timescale."

```julia
pack(algorithm = FIRE(damping = nothing, drag = nothing))
```

**Decision.** FIRE runs without contact damping or drag.

- FIRE removes energy by steering the velocities toward the force and zeroing them
  when the motion turns uphill: [Guenole2020] "the velocities are reset to zero at the
  beginning of the pseudo-dynamic run and also periodically during the run in FIRE
  2.0". Adding damping is not needed for FIRE to stop. **SoftPack choice**; both
  settings take the same values as for `DampedDynamics`.

### Options

Every option below is a setting of `pack()`; any of them combines with any algorithm,
contact law and friction model.

| Option | Setting | Used by |
|---|---|---|
| Any other contact damping ratios | `ContactDamping(normal = ratio, tangential = ratio)` | |
| Moderate contact damping (restitution about 0.5) | `ContactDamping(normal = 0.2, tangential = 0.2)` | $\zeta \approx 0.18$ is our conversion of [Santos2024] |
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

The options' own defaults and the reasons:

```julia
pack(algorithm = DampedDynamics(damping = ViscousRate(normal = 0.5, tangential = 0.5)))
```

**Decision.** The option's defaults: dashpot force $-\gamma\,v$ with coefficient
$\gamma = m_\text{eff}\,r$ and rate $r = 0.5$ in both directions, in units of $1/\tau$,
$\tau = \sqrt{m/k}$ ($m$ the small-particle mass, $k$ the normal stiffness constant).

- The default values are [Santos2024]'s, $r_n = r_s = 0.5/\tau$ (their $\gamma_n$,
  $\gamma_s$, LAMMPS rates) with $\tau = \sqrt{m/k_n}$, as are the equal values for
  both directions (quote above). For equal masses ($m_\text{eff} = m/2$) this is
  $\zeta = \tfrac{r}{2}\sqrt{m_\text{eff}/k} \approx 0.18$, a restitution
  coefficient of about 0.57 (our conversion).
- A raw rate damps Hertz contacts less as they compress; use `ContactDamping` for a
  fixed ratio. `ViscousRate` takes the same `attractive` and `coulomb_limit` keywords
  with the same defaults.

```julia
pack(algorithm = DampedDynamics(damping = RelativeVelocityDamping(rate = 0.5)))
```

**Decision.** The option's defaults: one dashpot on the full relative velocity of the
two centers,

$$\mathbf F_{ij} = -\gamma\,(\mathbf v_i - \mathbf v_j), \qquad \gamma = m_\text{eff}\,r,$$

with rate $r = 0.5$ in units of $1/\tau$, as for `ViscousRate`.

- One rate damps both the normal and the tangential relative motion, with or without
  friction. It acts on the centers' velocities only and applies no torque, so a
  particle spinning in place is not damped, while pure rolling is (the reverse of
  `ContactDamping`).
- Without friction, `ContactDamping` and `ViscousRate` are normal-only. The two forms
  are the CD and CD<sub>n</sub> models of [Vagberg2014]: "CD<sub>n</sub> is typically used in models
  of massive dry granular particles [15]. CD was introduced by Durian [12] to describe
  the viscous interaction between massless foam bubbles." The choice changes the
  result: [Vagberg2014] "the rheology of soft-core frictionless disks is strongly
  dependent on the specific form of the dissipative interaction" (shear flow below
  jamming, not packing preparation). Use this option to prepare packings with the
  same damping law as a later simulation that damps the full relative velocity.
- Not the default. It is never proportional to the stiffness, so modes mix and sliding
  soft modes creep (channels above). Without friction its tangential half damps a
  direction with no spring, so there is no critical value and a ratio like 0.98 has no
  meaning; that is why it takes a raw rate. **SoftPack choice.**
- `rate = 0.5` is the `ViscousRate` default [Santos2024], so on frictionless particles
  swapping `ViscousRate(normal = 0.5)` for this option only adds the tangential half.
  **SoftPack choice.**
- It takes the same `attractive` and `coulomb_limit` keywords with the same defaults,
  applied to the normal and tangential parts of its force.

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(coulomb_limit = :total)))
```

**Option.** The total tangential force (spring plus dashpot) is capped at $\mu$ times
the total normal force, $|F_t| \le \mu\,F_n$, as in LAMMPS: [LAMMPSgran] "the Coulomb
criterion Ft = xmu*Fn, where Ft and Fn are the total tangential and normal force
components in the formulas above."

```julia
pack(algorithm = DampedDynamics(damping = ContactDamping(tangential = 0)))
```

**Option.** Tangential damping off, LAMMPS's `dampflag` switch: [LAMMPSgran]
"dampflag = 0
or 1 if tangential damping force is excluded or included".

```julia
pack(algorithm = DampedDynamics(drag = StokesDrag(velocity = rate, spin = rate, during = :always)))  # rate: required, no default
```

**Decision.** The option's defaults: force $\mathbf{F} = -a_v\,m\,\mathbf{v}$ and
torque $\mathbf{T} = -a_s\,I\,\boldsymbol{\omega}$, with rates $a_v$ (`velocity`) and
$a_s$ (`spin`) in units of $1/\tau$. This is the mass-proportional term $a\mathbf M$ of
Rayleigh damping (channels above).

- `velocity` has **no default** and must be given. [Shimada2026] and [Xiong2019]
  do not state numerical values in their texts, and the right size depends on the
  packing's soft-mode frequencies, which change with pressure and system size.
  [Xiong2019] chose theirs "so that the dynamics for the translational and
  rotational degrees of freedom are in the overdamped limit." [Shimada2026] use
  separate rates for velocity and spin, "which are added to accelerate the
  convergence to inherent structures."
- `spin = velocity`: **SoftPack choice**, so translation and rotation of a free
  particle decay at the same rate. Set it separately as [Shimada2026] do.
- `during = :always`: drag on for the whole run, as in [Shimada2026] and
  [Xiong2019].
- `during = :compression`: drag on until the pressure is within `pressure_tolerance`
  of the target, then off, and the packing settles under contact damping alone. The
  Leiden packings are made with drag that is later removed: [Somfai2007] "The
  packings are constructed by cooling while slowly inflating the particle radii in
  the presence of a linear damping force", and "Once a packing is made, the
  additional damping force is switched off". Where to switch it off during
  preparation is a **SoftPack choice**; the paper does not give one.

```julia
pack(algorithm = DampedDynamics(drag = StokesDrag(velocity = 0, spin = rate)))
```

**Option.** Spin drag only: contact dashpots do not damp pure rolling (one particle
rolling over another has no sliding speed at the contact), so runs with friction that
stall on rolling motion can add a small spin drag. **SoftPack note.**

### Time step with damping

An explicit integrator's stable step shrinks as damping grows. For one damped
oscillator of angular frequency $\omega$ and damping ratio $\zeta$,

$$\omega\,\Delta t \le 2\left(\sqrt{1+\zeta^2} - \zeta\right).$$

With the defaults ($\zeta = 0.98$) a single contact is stable up to about
$0.27\,t_\text{col}$, 13 times the default step $t_\text{col}/50$ (§12). In a packing
the fastest vibration can be up to $\sqrt{z}$ times faster than one contact ($z$ the
contact number), and contact damping then damps it more strongly too. The worst case
is about $0.08\,t_\text{col}$ in 2D ($z = 4$) and $0.05\,t_\text{col}$ in 3D
($z = 6$), still 3.8 and 2.6 times the default step. With near-critical contact
damping, keep the step fraction at or below about $1/20$. **SoftPack note**:
estimates, to be checked once `DampedDynamics` runs.

## 9. Rattler rules

`rattlers` takes any function of the contact network that returns a true/false mask
per particle. Built-in rules: `ContactCount()` (default), `TwoContact()`,
`ForceFloor()`, `Unresolved()`. Every rule takes a `cone_test` option, on by default.
Rattlers are removed by default; `rattlers = nothing` keeps every particle.
`find_rattlers(packing, rule)` applies a rule to a finished packing. The mean force
$\langle f\rangle$ is taken over all contacts before anything is removed.

```julia
pack(rattlers = ContactCount(cone_test = true))
```

**Decision.** Repeatedly remove particles with fewer than $D + 1$ contacts when
frictionless ($D$ the dimension) or fewer than 2 when frictional.

- [Xiong2019] "we recursively remove rattler disks with fewer than three
  contacts for frictionless disks or fewer than two contacts for frictional disks."
  For frictional particles, [Agnolin2007] note that "spheres with as few as two contacts
  may carry forces (even large ones, as we shall see) and should not be regarded as
  rattlers."

```julia
pack(rattlers = ContactCount(cone_test = true))  # cone_test is a setting of every rule
```

**Decision.** `cone_test = true` in every rule: a two-contact particle is removed when
no forces inside its friction cones can hold it.

- [Gilabert2007] "Without cohesion, the Coulomb condition restricts
  the angle between the directions of the 2 contacts to values between π − 2ϕ and
  π, where ϕ is the friction angle (tan ϕ = µ)." [Agnolin2007]: the angle α "between
  the line joining the centers of 1 and 2 and the one joining the contact points be
  smaller than the angle of friction, for the total contact force to stay within the
  Coulomb cone." On by default for every rule: **SoftPack choice** (a particle that
  fails it cannot carry load). `cone_test = false` gives back the published
  contact-count rule.

```julia
pack(rattlers = TwoContact(cone_test = true))
```

**Decision.** The option: repeatedly remove particles with two or fewer contacts.

- [Ishima2023] regard particles with $Z_i \le Z_\text{Th}$ as rattlers and "repeat
  these processes until the
  number of rattlers is converged", with $Z_\text{Th} = 2$. [Shimada2026] "we refer to
  particles with two contacts as pseudo-rattlers to distinguish them from true
  rattlers", and count samples "remaining jammed after removing rattlers and
  pseudo-rattlers".

```julia
pack(rattlers = ForceFloor(floor = 1e-3, cone_test = true))
```

**Decision.** The option: contacts with force below
$10^{-3}\,\langle f\rangle$ count as broken, then particles with fewer than two
contacts are removed.

- [Shundyak2007] "we always take out rattlers by considering contact forces less than
  10^-3 times the average force broken and removing particles, with less than two
  contacts."

```julia
pack(rattlers = Unresolved(floor = :tolerance, cone_test = true))
```

**Decision.** The option's default: remove particles whose contacts all carry less
than the packing's force tolerance.

- [Agnolin2007] "We also discard from the backbone all spheres with only forces
  smaller than the tolerance." Tying the floor to the packing's own tolerance
  (`floor = :tolerance`) is a **SoftPack choice**: the rule means "below the stopping
  rule's noise".

## 10. Reproducibility

```julia
pack(seed = 1)
```

**Decision.** Seeds use StableRNGs.jl so a seed gives the same packing on every
Julia version; every output records the SoftPack version, git commit, Julia version,
seed and RNG. The default seed is 1.

- `seed = 1`: **SoftPack choice**, so `pack()` with no arguments gives the same
  packing every time.
- [JuliaRandom] "a minor release of Julia (e.g. 1.3 to 1.4) *may change* the
  sequence of pseudorandom numbers generated from a specific seed."
- [StableRNGs] the package the Julia manual points to for stable streams.

## 11. Outputs

```julia
packing = pack()
write_packing("packing.h5", packing)
```

**Decision.** `pack()` returns a `Packing` in memory. Writing files is a separate
call, except for the optional movie and snapshot recording below. The word is
"particles" throughout (API, files, docs). The default file format is HDF5. Every file
also holds the full state needed to continue the run with `restart_packing` (§6),
including every particle before rattlers are removed.

**HDF5.** One binary file holds the packing, the contacts, all settings and any
optional extras (time series, snapshots, matrices), with exact floating-point values.
It is read natively by MATLAB, Python and Julia:

- [MATLABh5read] `h5read` is built into MATLAB ("Introduced in R2011a").
- [h5py] Python reads datasets as NumPy arrays: "Datasets are very similar to NumPy
  arrays."
- [HDF5jl] Julia's JLD/JLD2 files "are still both regular HDF5 files and are
  therefore compatible with any HDF5 reader or writer."

Three rules follow from the sources:

- Store per-particle and per-contact quantities as one 1-D dataset per column
  (`x`, `y`, `diameter`, ...), not as $N \times D$ matrices: [HDF5jl] "Julia, like
  Fortran
  and MATLAB, stores multidimensional arrays in column-major order, while other
  languages, including C and Python (NumPy), use row-major order. Therefore when
  reading an array in Julia from row-major order language the dimensions may be
  inverted." 1-D datasets read the same in every language. **SoftPack choice.**
- When an option stores a genuinely multi-dimensional array (for example snapshots
  as frames × particles, or dense matrices), `pack()` prints a warning when the run
  starts, naming those outputs and saying that Python and C readers will see them
  transposed, and each such dataset carries an `array_order = "column-major"`
  attribute. **SoftPack choice**, from the [HDF5jl] note above.
- Compress only with gzip/deflate: [h5py] the GZIP filter is "Available with every
  installation of HDF5, so it's best where portability is required." [HDF5jl] warns
  that Blosc-compressed datasets cannot be read by "vanilla HDF5 distributions".

**Formats.** HDF5 is the default. CSV is an option, for spreadsheets or reading
without an HDF5 library. MATLAB `.mat` and JLD2 are not offered: MATLAB reads HDF5
directly [MATLABh5read] and JLD2 files are HDF5 files [HDF5jl]. Extended XYZ (for
OVITO) and LAMMPS data files may be added later. **SoftPack choice.**

```julia
write_packing("packing.h5", packing; rattlers_file = false)
```

**Decision.** When a rattler rule is applied (the default), the main datasets hold
only the remaining particles, with their original ids. `rattlers_file = true` also
writes a second file with every particle and a rattler flag in the same layout. With
`rattlers = nothing` there is one file with every particle.

- **SoftPack choice**.

```julia
write_packing("packing.h5", packing; compression = nothing)
```

**Decision.** No compression by default.

- Packing files are small, and uncompressed datasets can be memory-mapped: [HDF5jl]
  "This is possible only under
  particular conditions: when the dataset is an array of standard 'bits' types (e.g.,
  Float64 or Int32) and no chunking/compression is being used."
- `compression = :gzip` uses level 4 unless a level is given: [h5py]
  "compression_opts sets the compression
  level and may be an integer from 0 to 9, default is 4."

```julia
pack(snapshots = nothing)
pack(movie = nothing)
```

**Decision.** No snapshots and no movie by default. `pack()` can record snapshots
during the run (`snapshots = Snapshots(every = interval)`) and render a GIF or video
from them (`movie = Movie(path; every = interval)`).

- **SoftPack choice**: both cost time and disk. `every` has no default: a useful
  interval depends on how long the run is.

## 12. Time step

```julia
pack(timestep = CollisionTime(fraction = 1/50))
```

**Decision.** The time step is 1/50 of the shortest binary collision time

$$t_\text{col} = \pi\sqrt{\frac{m_\text{eff}}{k}},$$

taken over the smallest particle mass, the stiffest contact (normal, or tangential
with rotation when friction is on), and for Hertzian contacts the stiffness at the
largest overlap expected; a run-time check warns if a contact becomes stiffer than
the chosen `timestep` resolves. A fixed value can be given instead. For FIRE this is
the starting step; FIRE then adapts it (§14).

- 1/50 of the collision time: [Silbert2001] "an accurate simulation typically
  requires δt ∼ t_col/50", with
  $t_\text{col} = \pi\left(2k_n/m - r_n^2/4\right)^{-1/2}$ (their $\gamma_n$ is a rate,
  our $r_n$).
- Other values in use: [Santos2024] "The simulation time step was set to
  ∆t = 0.02τ. A time step ∆t = 0.002τ was also tested and did not change the
  results for the pressures studied within the uncertainties." [Ishima2023] use
  $\Delta t = 1.0\times10^{-2}\,t_0$ with velocity Verlet. Industrial DEM sets the
  step from the Rayleigh time instead: [EDEMtimestep] "the normal range is 10%-40% of
  the Rayleigh
  Time Step" and "20% of the Rayleigh Time Step is the default value recommended."
- Why it is computed from the contact state: [OSullivan2004] "it is shown that the
  critical time increment is a function of the current contact conditions" and
  earlier recommendations "can be unconservative, in that they often overestimate
  the actual critical time step."
- FIRE step limits: [Guenole2020] list LAMMPS FIRE 2.0 defaults of a maximum step of
  10 times and a minimum step of 0.02 times the starting step.
- With near-critical contact damping the stable step is smaller. The default keeps a
  margin of at least about 2.6 (estimate in §8, "Time step with damping").

## 13. Friction models

`friction = nothing` (frictionless, §2) is the default. Two friction models are
options. Keyword names follow §1 (full words, no symbols). How damping and the
Coulomb limit interact is in §8.

```julia
pack(friction = CundallStrack(friction_coefficient = 0.5, stiffness_ratio = :matched))
```

**Decision.** The option's defaults: a linear tangential spring with Coulomb slip.
Works with `Hookean` or `Hertzian` contacts.

- The "Hookean spring-dashpot-slider interaction potential (Cundall and
  Strack, 1979)" of [Santos2024].

```julia
pack(contact = Hertzian(stiffness = 1.0),
     friction = Mindlin(friction_coefficient = 0.5, poisson_ratio = 0.0))
```

**Decision.** The option's defaults: the Hertz-Mindlin tangential force, whose
stiffness grows with the overlap. Needs `Hertzian` contacts.

```julia
pack(friction = CundallStrack(friction_coefficient = 0.5))
```

**Decision.** The Coulomb friction coefficient $\mu$ is 0.5 in both models.

- [Somfai2005] packings are "prepared with friction coefficient µ = 0.5
  and Poisson ratio ν = 0"; [Silbert2001] use "friction coefficient µ = 0.50". It is a
  common value, not a material constant. Frictional studies usually vary $\mu$:
  [Henkes2010] cover $\mu$ from $10^{-3}$ to $10^{3}$, and [Agnolin2007] use "a
  moderate,
  plausible value µ = 0.3". Production runs should set `friction_coefficient`.

```julia
pack(friction = CundallStrack(stiffness_ratio = :matched))
```

**Decision.** The tangential over the normal stiffness is

$$\frac{k_t}{k_n} = \frac{1}{1 + mR^2/I},$$

which makes the tangential contact vibration (sliding plus rotation, §8) exactly as
fast as the normal one for two equal particles. That is 1/3 for disks and 2/7 for
spheres.

- [Silbert2001] use $k_t/k_n = 2/7$ for spheres for this reason (equal periods of
  normal and shear contact oscillations), and LAMMPS uses 2/7 when $K_t$ is not
  given [LAMMPSgran]. Applying the same rule to disks is a **SoftPack choice**. The
  tangential direction then does not shorten the time step (§12), and the default
  damping ratio (§8) gives both directions the same decay time. [Silbert2001], for
  their flows: "However, the
  contact dynamics are not very sensitive to the precise value of this ratio." Any
  number can be given instead.

- With equal damping ratios and `tangential_mass = :with_rotation` (§8), it also makes
  contact damping exactly proportional to the unstressed stiffness. Each direction has
  $b = \gamma/k = 2\zeta/\omega$, and $\omega = \sqrt{k_n/M_n} = \sqrt{k_t/M_t}$ is the
  same in both, so $\boldsymbol\Gamma = b\,\mathbf K_0$ and every underdamped mode decays
  at $b\,\omega_\ell^2/2$. With another ratio the tangential constant $b_t = \gamma_t/k_t$
  differs from $b$ and the modes mix. To first order in the damping, with $\mathbf K_t$
  the tangential-spring part of $\mathbf K_0$ (mass-weighted),

$$\beta_\ell \approx \frac12\left[b\,\omega_\ell^2 + (b_t - b)\,\langle v_\ell|\mathbf K_t|v_\ell\rangle\right],$$

  which lies between $b\,\omega_\ell^2/2$ and $b_t\,\omega_\ell^2/2$ because
  $0 \le \langle v_\ell|\mathbf K_t|v_\ell\rangle \le \omega_\ell^2$. For example,
  `Mindlin` with $\nu = 0$ ($k_t = k_n$) gives $b_t = b/\sqrt3$ for disks, contact by
  contact. **SoftPack note** (our derivation).

```julia
pack(contact = Hertzian(), friction = Mindlin(poisson_ratio = 0.0))
```

**Decision.** The particle material's Poisson ratio $\nu$ is 0 in `Mindlin`.

- The Leiden choice. [Shundyak2007] "The Poisson ratio of the grains is
  taken to be zero"; [Somfai2005] same (quote above). With $\nu = 0$ the two
  stiffnesses are equal: [Somfai2005] "for ν = 0, the value we use in most of the
  simulations, the
  two effective stiffnesses dFt/dt and dFn/dn are equal". The tangential vibration is
  then faster than the normal one ($\sqrt{3}$ times for disks), so it sets the time
  step (§12). For real materials, [Silbert2001] "For Hertzian contacts [37], the ratio
  kt/kn depends on the Poisson ratio of the material, and is about 2/3 for most
  materials."

## 14. FIRE settings

`FIRE()` uses the FIRE 2.0 defaults of LAMMPS, listed in [Guenole2020] (Table 1), the
paper that assessed FIRE 2.0 and implemented it in LAMMPS. FIRE itself is from
[Bitzek2006]. Every value below except `integrator`, `damping` and `drag` is from that
table (LAMMPS `min_modify` defaults for FIRE 2.0).

```julia
pack(algorithm = FIRE(timestep_max = 10))
```

**Decision.** Largest step: 10 times the starting step (§12).

```julia
pack(algorithm = FIRE(timestep_min = 0.02))
```

**Decision.** Smallest step: 0.02 times the starting step.

```julia
pack(algorithm = FIRE(delay = 20))
```

**Decision.** Wait 20 steps after an uphill move before the step may grow.

```julia
pack(algorithm = FIRE(timestep_grow = 1.1))
```

**Decision.** The step grows by a factor 1.1.

```julia
pack(algorithm = FIRE(timestep_shrink = 0.5))
```

**Decision.** The step shrinks by a factor 0.5 after an uphill move.

```julia
pack(algorithm = FIRE(mixing_coefficient = 0.25))
```

**Decision.** The coefficient for mixing the velocity and force directions starts at
0.25.

```julia
pack(algorithm = FIRE(mixing_shrink = 0.99))
```

**Decision.** That coefficient shrinks by a factor 0.99.

```julia
pack(algorithm = FIRE(uphill_max = 2000))
```

**Decision.** Stop after 2000 consecutive uphill moves.

- A run that reaches `uphill_max` is returned with `converged = false` (§6), where
  LAMMPS ends the minimization. **SoftPack choice**, to match §6.

```julia
pack(algorithm = FIRE(inertia_correction = true))
```

**Decision.** Move back half a step after an uphill move (LAMMPS `halfstepback`).

- `inertia_correction` is their name for the half step back: LAMMPS `halfstepback`,
  "yes activates the inertia correction" [Guenole2020].

```julia
pack(algorithm = FIRE(delay_initial = true))
```

**Decision.** Apply the delay at the start of the run too.

```julia
pack(algorithm = FIRE(integrator = :semi_implicit_euler))
```

**Decision.** Semi-implicit Euler; `:velocity_verlet` is the option.

- [Guenole2020] "Hence we recommend the usage of
  FIRE 2.0 with an Euler Implicit integrator." (Their Euler implicit is the
  semi-implicit, or symplectic, Euler scheme.) Velocity Verlet is also suitable:
  [Guenole2020] "Symplectic schemes like Euler semi-implicit (also called symplectic
  Euler), Leapfrog or Velocity Verlet are more robust against varying timesteps".

```julia
pack(algorithm = FIRE(damping = nothing, drag = nothing))
```

**Decision.** No contact damping and no drag; see §8.
