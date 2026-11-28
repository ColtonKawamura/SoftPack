# SoftPack design decisions and their references


> **Open points.** The board's decision cards are settled in the Documenter
> section *Design decisions* (`docs/src/decisions/`), one page per card, with the
> reason and the evidence. Where this document and a decision page disagree, the
> decision page is the later word.

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

Status: design stage. The engine in `src/` implements every setting of this document;
choices still open are coded provisionally and marked `PROVISIONAL` in the source. Last
updated 2026-11-27. Every setting has
a default and a reason (§0), including how `pack()` reaches the target pressure
(the boundary, the initial state and the compression protocol, §2).

---

## 0. Every default at a glance

Every setting, its default, the other choices, and the section that gives the
reasons. Units: reference diameter $d_\text{ref} = 1$ (the small diameter of the default
mixture, §3), contact stiffness 1, reference mass $m_\text{ref} = 1$ (§4).

| Setting | Default | Other choices | § |
|---|---|---|---|
| `dimension` | `2` | `3` | 2 |
| `particles_count` | `256` | any number ≥ 2 | 2 |
| `particles_size_distribution` | `Bidisperse(diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5)` | `UniformPolydisperse(diameter_mean = 1.0, spread = 0.2)`, `Monodisperse(diameter = 1.0)` | 2, 3 |
| `particles_diameters` | `nothing` (drawn from the distribution) | a vector with one diameter per particle | 3 |
| `contact` | `Hookean(stiffness = 1.0)` | `Hertzian(stiffness = 1.0)` | 2 |
| `friction` | `nothing` (frictionless) | `CundallStrack(friction_coefficient = 0.5, stiffness_ratio = :matched)`, `Mindlin(friction_coefficient = 0.5, poisson_ratio = 0.0)` | 2, 13 |
| `mass` | `EqualMass(1.0)` | `Density(1.0)` (disk area in 2D, sphere volume in 3D) | 4 |
| `target` | `Pressure(1e-4)` | | 2 |
| `boundary` | `Periodic()` | `Walls(friction = true)` (rigid flat walls), `Walls(friction = false)` | 2 |
| `initial_state` | `Dilute(packing_fraction = 0.25)` | any packing fraction at which the particles fit | 2 |
| `protocol` | `IsotropicCompression(strain_step = 1e-2)` | any `strain_step` | 2 |
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
| `DampedDynamics` `integrator` | `:centered_velocity_verlet` | `:lagged_velocity_verlet`, `:semi_implicit_euler` | 8 |
| `FIRE` `damping`, `drag` | `nothing`, `nothing` | same as `DampedDynamics` | 8 |
| FIRE parameters | LAMMPS FIRE 2.0 defaults | any value | 14 |
| `rattlers` | `ContactCount(cone_test = true)` | `TwoContact()`, `ForceFloor(floor = 1e-3)`, `Unresolved(floor = :tolerance)`, `nothing`, any function | 9 |
| `seed` | `1` | any integer | 10 |
| `snapshots`, `movie` | `nothing` | `Snapshots(every = interval)`, `Movie(path; every = interval)` | 11 |
| file format (`write_packing`) | HDF5 | CSV | 11 |
| `write_packing` `rattlers_file` | `false` | `true` | 11 |
| `write_packing` `compression` | `nothing` | `:gzip` (level 4) | 11 |
| `write_packing` `overwrite` | `false` | `true` | 11 |

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
$10^{-4}$, and FIRE. `pack()` with no arguments uses all of them. It starts from random,
non-touching particles at packing fraction 0.25 in a periodic square box and shrinks the
box isotropically, minimizing after every step, until the pressure reaches the target.

```julia
pack(dimension = 2)
```

**Decision.** Two-dimensional packings (disks).

- **SoftPack choice.** 2D packings are the cheapest to make and to check by eye, and
  the bidisperse mixture below is the standard 2D one. `dimension = 3` is an option.
- The dimension also fixes the particle shape: disks in 2D, spheres in 3D (§4).

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

**Decision.** $k = 1$ sets the force unit. With the reference diameter $d_\text{ref} = 1$
(written $d$ below) as the length unit (§3), the target pressure is then the
dimensionless pressure, which says how deeply the particles overlap.

- Why one number is enough. A static packing has only three scales: the diameter $d$,
  the stiffness $k$ and the pressure $P$ (masses set how fast the packing gets there,
  not where it ends up). The pressure is fixed by the mean normal contact force
  $\langle f_n\rangle$: for monodisperse spheres [Agnolin2007] (their Eq. 22) give
  $P = z\Phi\langle N\rangle/(\pi a^2)$, with $z$ the contacts per particle, $\Phi$ the
  packing fraction, $\langle N\rangle$ the mean normal force and $a$ the diameter. The
  same counting for disks gives $P = z\varphi\langle f_n\rangle/(\pi d)$ (our
  conversion). With Hookean contacts $\langle f_n\rangle = k\langle\delta\rangle$, so

$$\text{2D: } \frac{P}{k} = \frac{z\varphi}{\pi}\,\frac{\langle\delta\rangle}{d}, \qquad \text{3D: } \frac{P\,d}{k} = \frac{z\varphi}{\pi}\,\frac{\langle\delta\rangle}{d}.$$

  Near jamming $z\varphi/\pi = 4\times0.84/\pi = 1.07$ in 2D ($z \approx 4$, $\varphi \approx 0.84$)
  and $6\times0.64/\pi = 1.22$ in 3D ($z \approx 6$, $\varphi \approx 0.64$) (our conversion), so the
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
  which for SoftPack's units is the Hookean pressure unit $k\,d^{2-D}$ ($k$ in 2D,
  $k/d$ in 3D; for Hertzian contacts $k\,d^{5/2-D}$, §2 "Units"). DEM papers use the same
  ratio, inverted: [Agnolin2007] "The elastic contact law introduces a dimensionless
  stiffness parameter κ", $\kappa = (\tilde E/P)^{2/3}$ for Hertz contacts, with
  "Under pressure P, the typical force in a contact is of order P a²" and "κ sets the
  scale of the typical normal deflection h in Hertzian contacts, as h/a ∼ 1/κ."
  Packings at the same $P/k$ (or [Agnolin2007]'s $\kappa$) are the same packing in different units, so
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
pack(boundary = Periodic())
```

**Decision.** The box is a square (2D) or a cube (3D) of side $L$, and its boundaries are
periodic. `Walls(friction = true)` is the option for a non-periodic packing: a flat, rigid
wall on every side of the box.

- Periodic is the default because it leaves no surface layer, as in the standard
  assembling studies: [Agnolin2007] "enclosed in a cubic or parallelipipedic cell with
  periodic boundary conditions". **SoftPack choice** for the square or cube:
  [Agnolin2007] let the cell lengths $L_\alpha$ vary separately, and SoftPack scales
  every side by the same factor, so the compression is isotropic by construction (no
  change of aspect, no shear).
- `Walls`: a particle whose center is a distance $h$ from a wall overlaps it by
  $\delta = d_i/2 - h$. While $\delta > 0$ the wall pushes it along the wall normal with
  the `contact` law above ($f = k\delta$ for `Hookean`). **SoftPack choice**: the wall
  is a flat surface of infinite mass with the same law and stiffness as a
  particle-particle contact; a separate wall law may be added later. The effective mass
  of a wall contact is $m_i$, where a pair has the reduced mass $m_i m_j/(m_i + m_j)$.
- `friction = true`, the `Walls` default: with `friction` set (§13), a wall contact has
  the same friction model and coefficients as a particle-particle contact, and its own
  tangential spring. `Walls(friction = false)` makes wall contacts carry the normal force
  only. With `friction = nothing` the walls are frictionless either way.
  **SoftPack choice.**
- The pressure below needs no extra term: a wall contact counts like a pair contact, with
  $\ell^{c} = h$, the distance from the particle's center to the wall, and $\Omega = L^{D}$
the box area (2D) or volume (3D).
  At force balance the sum equals the mean wall pressure, from the sum of the wall
  contact forces $f_n^{c}$ over the $2D$ walls of area $L^{D-1}$,

$$P = \frac{1}{D\,\Omega}\left(\sum_{\text{pairs}} f_n^{c}\,\ell^{c} + \sum_{\text{walls}} f_n^{c}\,h^{c}\right) = \frac{1}{2D\,L^{D-1}}\sum_{\text{walls}} f_n^{c}.$$

  **SoftPack note.** It follows from $\sum_i \mathbf r_i\cdot\mathbf F_i = 0$ with the
  origin in a corner. Checked on the walls packing of the worked example below: the two
  forms agree to $4\times10^{-10}$ relative, and the pair sum alone is 6.4% too low
  (the 50 wall contacts carry a share of the pressure).
- Not designed yet for `Walls`: whether a wall contact counts toward the contact number
  of the rattler rules (§9). The tangential effective mass at a wall is in §8.

```julia
pack(initial_state = Dilute(packing_fraction = 0.25))
```

**Decision.** Start from random, non-touching particles at a low packing fraction
$\varphi_0$ = `packing_fraction`, all at rest. No two particles overlap, so every force
and the pressure are zero at the start.

- A loose start is the usual one: [Agnolin2007] "Numerical samples are most often
  produced by compression of an initially loose configuration (a granular gas) in which
  the grains do not touch."
- The box side is $L_0 = \left(\sum_i v(d_i)/\varphi_0\right)^{1/D}$, with $v(d)$ the
  particle area or volume of the packing fraction above.
- Positions come from random sequential addition. Particles are placed in order of
  decreasing diameter (equal diameters in index order). A trial position is drawn
  uniformly in the box and kept only if the gap to every placed particle is positive,
  $r_{ij} > (d_i + d_j)/2$; otherwise it is drawn again. A trial draws one number
  $u_a \in [0, 1)$ per axis, in the order $x$, $y$, $z$, with `rand(rng)`, and puts the
  center at $u_a L_0$ along axis $a$ (periodic) or at $d_i/2 + u_a\,(L_0 - d_i)$ (walls).
  After $10^4$ failed trials for one particle `pack()` throws an `ArgumentError` that
  asks for a lower `packing_fraction`.
- The draws of a run, in order (§10): the diameters (§3; none when `particles_diameters`
  is given), then the trials above. Nothing else in `pack()` is random.
- Largest first: **SoftPack choice**, so the particles that need the most room are placed
  while there is room.
- All at rest: **SoftPack choice**. Nothing moves until the first compression step makes
  a force.
- $\varphi_0 = 0.25$: **SoftPack choice**, low enough that every start is quick and
  non-touching. **SoftPack note.** In a Python test (256 particles, 50:50 mixture of 1.0
  and 1.4, seeds 1 to 5, NumPy's generator) every placement finished at $\varphi_0 = 0.25$,
  with at most 14 trials for any one particle in 2D (periodic or walls) and at most 169
  in 3D, and about 2 trials per particle on average in 2D. Placements still finished up
  to $\varphi_0 = 0.55$ in 2D and 0.30 in 3D under the $10^4$ cap.

```julia
pack(protocol = IsotropicCompression(strain_step = 1e-2))
```

**Decision.** Compress the box in isotropic steps until the pressure is within
`pressure_tolerance` of the target (§5). Call $\epsilon$ the step, starting at
`strain_step`, and the accepted state the box side $L_a$ and positions $\mathbf r_{a,i}$,
starting as the initial state. Repeat:

1. Trial. Set $L = (1 - \epsilon)\,L_a$ and $\mathbf r_i = (1 - \epsilon)\,\mathbf r_{a,i}$
   (the walls move with the box), with every velocity zero.
2. Minimize at this $L$ with `algorithm`, from rest with its counters reset, until
   `convergence` holds (§5).
3. Read $P$ (§2). Within the band, which is
   $\lvert P - P_\text{target}\rvert \le \epsilon_P\,P_\text{target}$: done, and the trial
   is the returned packing. Below the band: the trial becomes the accepted state. Above
   the band: the trial is rejected, $\epsilon \to \epsilon/2$, and the step starts again
   from the same accepted state.

- **SoftPack choice** for the rule. It needs only the target and `pressure_tolerance`,
  gives the same steps for the same inputs, and approaches the target from below, since
  the accepted state always lies below the band. $\epsilon$ is not enlarged again.
- Every minimization counts toward `steps_max` (§5). A run that reaches it, or one
  whose $\epsilon$ falls below $10^{-14}$, is returned with `converged = false` (§6).
- Force floor. With no contact, $\langle f_n\rangle = 0$ and the test of
  `RelativeForce` (§5) can never hold; with a few contacts $\langle f_n\rangle$ is
  tiny and the test asks for forces below round-off. So `RelativeForce` reads
  $\max_i \lvert\mathbf F_i\rvert < \epsilon_F \max(\langle f_n\rangle, f_\text{floor})$
  with $f_\text{floor} = P_\text{target}\,d^{D-1}/10$, and the same floor times
  $\langle d\rangle$ for torques. **SoftPack note.** Without the floor the probe's
  minimization used its whole $2\times10^{6}$-step cap at the first contacts, with
  $P$ below $2\times10^{-17}$ (5 to 12 contacts). At the target the floor does not act:
  $\langle f_n\rangle \approx 1.1\times10^{-4}$ against $f_\text{floor} = 10^{-5}$.
- The other `convergence` options end the minimization as §5 says, each deciding rest at
  the trial box; the band above decides the rest. `RestartTest` runs its watch once, on
  the trial that lies in the band, before it is returned. **SoftPack note.** Not probed:
  friction, drag, 3D, `DampedDynamics` and the other `convergence` options.
- `strain_step = 1e-2`: **SoftPack choice**. **SoftPack note.** On the worked example
  below (periodic) the compression steps and FIRE steps were 222 and 72 561 at
  $\epsilon = 0.003$, 88 and 67 242 at 0.01, 47 and 105 379 at 0.03, and 37 and 48 735 at
  0.1: the cost has no clear trend in $\epsilon$. The end packing changes with it,
  $\varphi$ from 0.8358 to 0.8417 with no trend, so `strain_step` is a setting that every
  output records (§11).
- `StokesDrag(during = :compression)` (§8) is on in every minimization of this protocol,
  for velocity and spin together, and goes off when the pressure first lies within the
  band. The run then minimizes once more with drag off until `convergence` holds, and
  `RestartTest` (§5) then runs its watch. If the pressure has left the band by then, the
  packing is returned with `converged = false`.
- The state a restart needs (§6): the accepted state, $\epsilon$, the counts of accepted
  and rejected steps, and whether drag is on.
- Worked example (**SoftPack note**; the initial state is from `StableRNG(1)` in Julia,
  the compression is a Python probe with FIRE 2.0, not SoftPack code). The 256 particles
  have total area 297.57, so $L_0 = 34.50$ at $\varphi_0 = 0.25$. Periodic: 493 trials
  (at most 19 for one particle, smallest gap $1.8\times10^{-3}$); the first contact
  appears at compression step 45 ($\varphi = 0.618$); the packing is within the band at
  step 88 (70 accepted, 18 rejected; 67 242 FIRE steps in all), at $L = 18.825$,
  $\varphi = 0.8397$, $P = 1.0001\times10^{-4}$, 501 contacts ($z = 3.91$ before any
  rattler is removed), $\langle f_n\rangle = 1.149\times10^{-4}$ and a largest net force
  of $1.1\times10^{-12}$, below $\epsilon_F\langle f_n\rangle = 1.15\times10^{-12}$. Walls:
  514 trials; within the band at step 82 (64 accepted, 18 rejected; 62 411 FIRE steps),
  at $L = 19.158$, $\varphi = 0.8108$ (the box holds a wall layer), 442 pair and 50 wall
  contacts.

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
  (a stationary point of the energy, a minimum unless it is a saddle that `RestartTest`
  (§5) can detect) and known checks (jamming packing fraction, $z \to 4$ in 2D);
  frictional packings depend on the preparation path (see §7). Friction models are
  in §13.

## 3. Particle size distribution and length unit

Sizes are diameters everywhere. `particles_size_distribution` chooses the law the
diameters are drawn from; `particles_diameters` gives the diameters themselves. Each
distribution sets its own length unit in its defaults: `Bidisperse` makes the small
diameter 1 (the jamming convention); polydisperse distributions make the mean diameter
1 (the Leiden convention). That diameter is the reference diameter $d_\text{ref}$, the
one particle scale the other sections use; for `particles_diameters` it is the mean of
the list. The mean of the diameters actually drawn is $\langle d\rangle$: 1.2 for the
default mixture, $d_\text{ref}$ for `Monodisperse`, and $d_\text{ref}$ up to sampling
scatter for `UniformPolydisperse`. Every output stores each particle's diameter,
$d_\text{ref}$ and $\langle d\rangle$.

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
- The drawn diameters are not rescaled to make their sample mean exactly
  $d_\text{mean}$: **SoftPack choice**. The sample mean scatters around $d_\text{mean}$ with
  standard deviation $d_\text{mean}\,s/\sqrt{3N}$, which is $0.0072\,d_\text{mean}$ for $N = 256$ and
  $s = 0.2$, so the output stores $\langle d\rangle$. [Somfai2005] write only "the average
  grain diameter", which does not say whether it is the sample or the distribution mean.

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
or to another code's particles. The reference diameter $d_\text{ref}$ is the mean of the
list: **SoftPack choice**, because no cited paper defines a scale for an arbitrary list and the
mean is the Leiden convention for polydisperse packings.

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
pack(mass = Density(1.0))
```

**Decision.** The option: mass from a material density times the particle's area in 2D
(a disk) or volume in 3D (a sphere).

- Density-based mass (DEM convention): [LAMMPSset] "density/disc value = particle
  density for a 2d disc or ellipse (mass/distance^2 units)"; [Somfai2005] "The unit
  of mass is set by asserting that the material of the grains has unit density."
  That is the reason for the default density 1.0.
- No `shape` keyword: **SoftPack choice**. The shape follows the dimension, disks in 2D
  and spheres in 3D, so every call that can be made is valid and no (dimension, shape)
  pair needs an error. A shape option can be added later without changing the meaning
  of any call made today (§15).
- Spheres whose centers are confined to a plane are not an option. That is the Leiden
  2D convention: [Somfai2005] "2D samples containing 600 spheres (their centers being
  confined to a plane)". SoftPack's 2D particles are disks, so a Leiden 2D packing
  matches in sizes but not in masses (§15).

**Reference mass.** The mass scale $m_\text{ref}$ is the `EqualMass` value (1 by default)
and, with `Density`, the mean mass $\frac1N\sum_i m_i$. The time unit is
$\tau = \sqrt{m_\text{ref}\,d_\text{ref}^{2-\alpha}/k}$ (§2 "Units"), which is
$\sqrt{m_\text{ref}/k}$ for Hookean contacts and $\sqrt{m_\text{ref}\,d_\text{ref}^{1/2}/k}$
for Hertzian ones (§8).

- **SoftPack choice**: no cited paper sets a mass or time scale from a small or smallest
  particle. [OHern2003] give every particle the same mass, so $m_\text{ref}$ is that mass,
  and [Somfai2005] "The speed of sound of the pressure waves inside the grains becomes
  unity (for zero Poisson ratio). This sets our unit of time", a scale of the grain
  material and not of one grain.
- The time step still uses the smallest particle mass (§12). That is a stability bound,
  not a unit.

**Moment of inertia.** With friction the particles rotate. A uniform disk or sphere has

$$I = \kappa\,m R^2, \qquad \kappa = \tfrac12\ \text{(disk, 2D)}, \qquad \kappa = \tfrac25\ \text{(sphere, 3D)},$$

with $R = d/2$. It sets the tangential effective mass $M_t$ (§8), the matched stiffness
ratio (§13) and the time step with friction (§12).

- **SoftPack choice**: the uniform-body value of the particle shape of this section, with
  no keyword. The constants the design already uses follow from it: the matched
  stiffness ratio $1/(1 + mR^2/I)$ is 1/3 and 2/7, which needs $mR^2/I = 2$ and $5/2$
  (§13).
- `EqualMass` uses the same $\kappa$: it sets the mass by hand, and the particle is still a
  uniform disk or sphere.
- A user-given $I$ and a thin ring ($\kappa = 1$) are not options: neither keeps the 1/3 and
  2/7 constants (a ring gives 1/2), and a ring is not a uniform particle of the stated
  mass.

## 5. Convergence (stopping) criterion

One rule for frictionless and frictional packings. A packing is accepted, and returned
with `converged = true`, only when two things hold in the same state: the `convergence`
option says it is at rest at the current box, and the pressure (§2) is within
`pressure_tolerance` of the target. The option decides rest only, force balance or
motion. The pressure check is part of no option: the compression protocol (§2) reads $P$
after every minimization, so it applies to every option, a user function included. A run
stops after `steps_max` steps at most. Options: `LeidenAcceleration`, `KineticEnergy`,
`RestartTest`, or any function of the run state that returns true when the packing is at
rest.

- What each option does to the `RelativeForce` force test: `LeidenAcceleration` and a
  user function replace it, and `KineticEnergy` and `RestartTest` add a check to it at
  its defaults. **SoftPack choice.**
- When the option is tested: at the end of every step, after the position and velocity
  update, and at step 0 of a restart, so a converged packing restarted with the same
  settings stops at once with `converged = true`. **SoftPack choice.**
- A state whose velocities a FIRE reset has just zeroed is never tested, because zero
  velocity would pass a motion test (wiki, Convergence criterion, "What a kinetic-energy
  test measures").

```julia
pack(convergence = RelativeForce(tolerance = 1e-8))
```

**Decision.** With $\epsilon_F$ = `tolerance`, a packing has converged when

$$\max_i \left|\mathbf{F}_i\right| < \epsilon_F\,\langle f_n\rangle \qquad \text{and, with friction,} \qquad \max_i \left|\mathbf{T}_i\right| < \epsilon_F\,\langle f_n\rangle\,\langle d\rangle,$$

where $\mathbf{F}_i$ and $\mathbf{T}_i$ are the net elastic force and torque on
particle $i$, $\langle f_n\rangle$ is the mean normal contact force over all contacts
(the force behind the pressure, §2), and $\langle d\rangle$ is the mean diameter of the
packing (§3).

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
- During the compression (§2) the same test ends the minimization after every step. Its
  scale $\langle f_n\rangle$ has a floor $P_\text{target}\,d^{D-1}/10$ there, because
  with no contact or a few contacts the test would never hold; at the target pressure
  the floor does not act. With no contact $\langle f_n\rangle$ is $0/0$ and is read as
  0, so the floor sets the scale and the test holds when every force is zero.

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
$10^{-10}$, the Leiden rule. It replaces the force test, and the pressure check follows
it.

- [Somfai2005] "Our packings
  are considered to have converged to mechanical equilibrium when all grains have
  acceleration less than 10^-10 in our reduced units". [Shundyak2007] builds its
  packings "As in [16]", reference 16 being [Somfai2005]. The number $10^{-10}$ only
  reproduces the Leiden rule in Leiden units ($E^* = 1$, mean diameter 1, density 1).

```julia
pack(convergence = KineticEnergy(tolerance = 1e-8))
```

**Decision.** The option's default: with $\epsilon_K$ = `tolerance`, the packing is at
rest when the `RelativeForce` test (default tolerance $10^{-8}$) holds and the mean
kinetic energy per particle satisfies
$\frac{1}{N}\sum_i E_i^\text{kin} < \epsilon_K\,P_\text{target}\,d_\text{ref}^{D}$
($N$ the number of particles, $d_\text{ref}$ the reference diameter (§3), $D$ the dimension).

- The energy scale $d_\text{ref}^{D}$ and the torque scale $\langle d\rangle$ differ for the
  default mixture (1 and 1.2): **SoftPack note**.

- The [Agnolin2007] value above, used together with a force bound as they do;
  [Xiong2019] stop each minimization on a maximum per-disk kinetic energy.
- It adds to the force test because it passed alone with unbalanced forces up to
  $0.22\langle f_n\rangle$ in a FIRE probe (wiki, Convergence criterion). **SoftPack note.**
- $P_\text{target}$ replaces the measured $P$: $P$ is 0 before the first contact, and at
  the target the two agree to $\epsilon_P$. [Agnolin2007]'s $P$ is the prescribed value.
- The force tolerance is that of `RelativeForce`'s default and has no keyword of its own;
  another pair of tolerances is a user function. **SoftPack choice.**

```julia
pack(convergence = RestartTest())
```

**Decision.** The option: the `RelativeForce` test (default tolerance) ends every
minimization, and once, on the final packing, zero all velocities and check that the
kinetic energy and the unbalanced forces do not grow back. It has no settings.

- [Agnolin2007] "On setting all velocities to zero,
  it is observed that the sample does not regain kinetic energy beyond that value,
  while the unbalanced force level does not increase."
- Once, because the watch needs about 2,100 steps on the probe packing (wiki, Convergence
  criterion) and has no threshold that could end a minimization. **SoftPack choice.**
- It runs after the force test and the pressure band hold with drag off (§2). If the
  energy or the forces grow back, the packing is not accepted and the run continues from
  the state where the watch ended. Every step of the watch counts toward `steps_max`.
  **SoftPack choice.**
- It is the check for saddles: a rest state is a stationary point of the energy, a
  minimum unless it is a saddle, and no force test can tell the two apart.

```julia
pack(convergence = my_test)   # my_test(state) returns true when the packing is at rest
```

**Option.** Any function of the run state that returns true when the packing is at rest
at the current box (**SoftPack choice**, so convergence tests are plug-ins like rattler
rules, §9).

- `state` is a read-only `RunState` (§11): the function cannot change the run, and a
  write throws an error. **SoftPack choice.**
- It is called at the end of every step, as for every option, so it should be cheap.
- A `true` ends the current minimization, not the run: the pressure check of the
  protocol (§2) follows, and `converged = true` still needs the pressure in the band.

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
  velocities, rotations and spins; the contact history (tangential springs and their sliding flags, wall contacts included); the box and its boundary;
  the algorithm's internal state (FIRE's current step and mixing coefficient and its
  counters); the state of the compression protocol (§2: the accepted state, the strain
  step, the counts of accepted and rejected steps, and whether drag is on); the step
  count; every setting; and
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
  depend on velocity too, so the file records which `DampedDynamics` integrator wrote it
  and stores that integrator's state (§8, "Integrator"). The lagged velocity Verlet
  stores the forces and torques of the last evaluation, because they were built from a
  half-step velocity and cannot be rebuilt from the stored positions and velocities;
  the centered velocity Verlet and the semi-implicit Euler store only positions and
  velocities. The exact-continuation test runs for each integrator. **SoftPack choice.**
- On a different SoftPack or Julia version the restart runs but warns that it may not
  be exact, as LAMMPS does: [LAMMPSreadrestart] "Several things can prevent exact
  restarts due to round-off effects, in which case the trajectories in the 2 runs will
  slowly diverge."
- Only run-control settings may change on a restart: `steps_max` (a new budget,
  counted from the restart), `failure_action`, `convergence`, `restart_file`,
  `snapshots` and `movie`, e.g. `pack(restart_packing = "packing.h5", steps_max = 2 * 10^7)`. Any other keyword
  raises an error, because it would change the protocol halfway through and the
  packing would match neither setting. This includes `integrator`: a file written with
  one integrator is refused by a run that asks for another. **SoftPack choice.**
- A converged packing can be restarted too, for example with a tighter `convergence`
  tolerance. The test of §5 runs at step 0, so the same settings stop at once. The output
  records each restart (file and step).

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
law plus friction, holding the contact history) and algorithms exchange
positions/rotations and forces/torques, and the force model also hands the algorithm a
table with a row per contact (below); velocities never go into the force model. FIRE
with friction is allowed and recorded, but documented as non-standard. The algorithm
defaults to `FIRE()` (§2).

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
- `DampedDynamics` has an `integrator` setting with three values, and the default is
  the centered velocity Verlet (§8, "Integrator"). FIRE's integrator is a separate
  setting (§14).

### The contact table and the contact history

**Decision.** The force model owns the contact list and the contact history. After each
force evaluation it hands out one table with a row per contact, which the algorithm, the
pressure, the convergence test and the rattler rules read. Damping stays a setting of the
algorithm (§8): the algorithm combines the table with the velocities it holds, and the
force model never receives a velocity. **SoftPack choice.**

- Why: a contact dashpot needs the contact data, which only the force model has, and the
  velocities, which only the algorithm has. Handing the contact data out keeps the force
  model independent of the integrator (§8, "Integrator"), and the same table serves the
  pressure (§2), $\langle f_n\rangle$ (§5) and the rattler rules (§9).
- The other option was to pass the velocities into the force model, which returns the
  elastic and dashpot forces. It keeps the whole contact law in one place, but it moves
  damping out of the algorithm, ties the force model to the velocity each integrator uses
  ($\mathbf v_n$, $\mathbf v_{n+1/2}$ or $\mathbf v_{n+1}$), and the centered velocity
  Verlet would still need $\boldsymbol\Gamma$ while the pressure and the rattler rules
  would still need the table. LAMMPS is organized that way, with an explicit integrator
  only: its granular pair style reads the velocities from the shared atom arrays and
  computes the dashpot inside the contact model (our reading of `pair_granular.cpp` and
  `granular_model.cpp`, 2026-11-24). **SoftPack note.**

The table has one row per contact; a wall contact counts like a pair contact (§2). The
columns, with what needs each:

| Column | Needed by |
|---|---|
| the two particles (a particle and a wall for a wall contact) | the contact network of the rattler rules (§9); which velocities a dashpot uses |
| unit normal $\hat{\mathbf n}$ | the directions of the dashpot forces; the friction cone of the rattler rules (§9) |
| lever arms $R_i$, $R_j$ | the slip speed and the rotational rows of $\boldsymbol\Gamma$ (§8) |
| branch vector $\boldsymbol\ell$ (a wall contact: the vector from the particle's center to the wall, of length $h$) | the pressure (§2) |
| normal stiffness $k_n(\delta)$ and tangential stiffness $k_t$ | the critical dashpot values (§8); for `Hertzian` and `Mindlin` they change with the overlap |
| elastic normal force $F_n^\text{el}$ | the pressure (§2), $\langle f_n\rangle$ (§5), the force floor of the rattler rules (§9) |
| sliding flag | the tangential dashpot is off while it is set (§8) |

- The algorithm forms $\gamma_n$ and $\gamma_t$ from its damping setting, the two
  stiffnesses and the masses and moments of inertia it holds, and the relative speeds from
  its velocities, $\hat{\mathbf n}$ and the lever arms. A wall contact uses the particle
  mass alone, $M_n = m_i$ (§2).
- The centered velocity Verlet also assembles $\boldsymbol\Gamma$ from the rows, because it
  solves $\left(\mathbf M + \tfrac{\Delta t}{2}\boldsymbol\Gamma\right)\mathbf v_{n+1} = \ldots$
  every step (§8, "Integrator"); $\boldsymbol\Gamma$ changes with the sliding flags, so
  the flags are read before the solve. The lagged velocity Verlet and the semi-implicit
  Euler only evaluate each dashpot with the velocity they use.
- The table is not part of the restart state (§6): it is a function of the positions, the
  box and the contact history, and the force model rebuilds it at every evaluation.
- Not designed: `coulomb_limit = :total` (§8) caps the tangential force with the total
  normal force, which includes the normal dashpot that the algorithm computes, and the
  table does not carry it back. One way is a second call to the force model that passes
  the normal dashpot forces back.
- The cost of writing and reading the table, and of assembling $\boldsymbol\Gamma$ from it
  every step, has not been measured. **SoftPack note.**

**Contact history.** For each contact the force model keeps the tangential spring stretch
$\xi$ and the sliding flag. At every force evaluation it projects $\xi$ onto the new
tangent plane, adds the relative tangential displacement of the two contact points over the
step (from the positions and rotations alone, no velocity), and clips the result at the
Coulomb cap. The rules:

- Reset: $\xi$ is created at 0 when the contact forms ($\delta > 0$) and set to 0 when the
  two particles stop overlapping ($\delta \le 0$). It is not reset when the total normal
  force reaches zero. **SoftPack choice.**
  - With the default `attractive = false` the total normal force of a damped collision at
    $\zeta = 0.98$ reaches zero while $\delta > 0$ (§8), and a reset there would erase the
    spring while the particles still overlap.
  - [Xiong2019]: the displacement "is set to zero when the pair of disks i and j is no
    longer in contact". LAMMPS also zeroes the history of every pair that is not touching
    (our reading of `pair_granular.cpp`, 2026-11-24).
- Cap: the clip is at $\mu F_n^\text{el}$ with $F_n^\text{el} = k_n\delta$ under
  `coulomb_limit = :elastic` (the default, §8), and at $\mu F_n$ with the total normal
  force under `:total`. Under `:elastic` a contact whose total normal force is clipped to
  zero while it still overlaps therefore still carries tangential force.
- Slip and sticking: while the update is clipped, $\xi$ sits at the cap,
  $\xi = \operatorname{sign}(\xi^\text{trial})\,\mu F_n^\text{el}/k_t$ (wiki, Algorithms and
  combinations). When a later update is not clipped the contact sticks again, and $\xi$
  continues from the value it had.
- Sliding flag: the flag is set when the update is clipped and cleared when it is not. It is
  stored with $\xi$ for every contact, wall contacts included, and saved in the restart
  state (§6). The algorithm reads the flag stored at the end of the previous step, so
  $\boldsymbol\Gamma$ is fixed before the centered solve. **SoftPack choice.**
  - Consequence: the tangential dashpot lags a slip by one step. It is still on in the first
    step of a slip and still off in the first step after the contact sticks again (§8 lists
    the overshoot). **SoftPack note.**
  - The other choice, the flag from the cap in the current evaluation, removes the lag. With
    `:elastic` it needs only positions, but with `:total` it would depend on the dashpot and
    need iteration, so one rule was kept for both. **SoftPack note.**
- Rotation, the same in 2D and 3D: the projection onto the new tangent plane removes the
  component of $\xi$ along the new normal ([Silbert2001]'s Eq. 5 keeps the spring in the
  tangent plane as the pair rotates). In 2D it multiplies the scalar $\xi$ by
  $\hat{\mathbf t}^\text{old}\cdot\hat{\mathbf t}^\text{new} = \cos\Delta\theta_c$, which is
  second order in the rotation $\Delta\theta_c$ of the contact in one step. **SoftPack
  choice**: one code path for both dimensions. Whether the projected vector is rescaled to
  its old length (LAMMPS does) is not designed.

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
- A particle touching nothing is a zero mode of $\mathbf K_0$, so the $b$ term gives it
  no damping at all: its velocity is constant. With `drag = nothing` such a particle
  drifts forever, and a `KineticEnergy()` test can never pass (the force tests do not
  see a uniform drift). Drag, the $a$ term, damps every particle.

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
- The value 0.98: [Agnolin2007] "The present study being focussed on statics, we generally use a strong dissipation,
  ζ = 0.98, to approach equilibrium faster.", and "This particular value is admittedly rather arbitrary: the initial motivation for
  choosing ζ < 1 is the computational inefficiency of overdamped contacts with ζ > 1 in
  the case of linear contact elasticity." For Hooke contacts, $\zeta = 0.98$ gives a restitution
  coefficient $e = \exp\left(-\pi\zeta/\sqrt{1-\zeta^2}\right) \approx 2\times10^{-7}$ if
  the dashpot may pull; with the default `attractive = false` (§8, "No attractive
  force") the contact ends when the total force first turns tensile, and $e = 0.139$
  (our integration, §8 "Restitution"). Either way a loose particle is nearly stopped
  after one or two impacts.
- The packing does not depend much on the exact value: [Agnolin2007] "In the linear case, the restitution coefficient in a binary collision varies as a very
  fastly decreasing function of ζ, and changes of ζ in the range between 0.7 and 1 have
  virtually no detectable effect.", and "a value of
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
  $j$ with masses $m$, radii $R$ and moments of inertia $I = \kappa\,mR^2$ (§4), the tangential and
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
- In 2D (disks) $M_t = M_n/3$ and in 3D (spheres) $M_t = M_n/3.5$: with $I = \kappa\,mR^2$,
  $R^2/I = 1/(\kappa\,m)$, so $1/M_t = (1 + 1/\kappa)/M_n$ for any two particles, not only equal
  ones (**SoftPack note**, our derivation). A ratio measured
  on the pair mass $M_n$ would really be $0.98\sqrt{3} \approx 1.7$ for disks and
  $0.98\sqrt{3.5} \approx 1.8$ for spheres, which is overdamped and slow. Measuring it
  on $M_t$ makes 0.98 mean 0.98. **SoftPack choice**, from the rigid-body mechanics
  of two particles in contact.
- At a wall contact only the particle's own terms remain, since the wall is flat, rigid
  and does not rotate: $1/M_n = 1/m_i$ and $1/M_t = 1/m_i + R_i^2/I_i$, so
  $M_t = M_n\,\kappa/(1 + \kappa)$ with $M_n = m_i$ (§2). The ratio $M_t/M_n$ is the same as in a
  pair, 1/3 in 2D and 2/7 in 3D; only the masses differ. **SoftPack note**, our
  derivation.
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
  force, with its tangential dashpot off (the sliding flag, §7).
- This is not a Coulomb law on the total force while the packing moves. **SoftPack note**
  (our derivation, wiki Damping page):
  - While a stuck contact is loaded toward its limit the spring force and the dashpot
    force point the same way, so the total tangential force can briefly exceed
    $\mu F_n^\text{el}$ before the contact slips.
  - The dashpot lags a slip by one step (§7), so the same overshoot can occur in the first
    step of a slip.
  - The limit uses $F_n^\text{el}$, so for a separating contact ($v_n > 0$) the sliding
    force $\mu F_n^\text{el}$ is larger than $\mu$ times the total normal force.
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
  when the motion turns uphill: [Guenole2020] "Since the velocities are reset to zero at the beginning of the pseudo-dynamic run and
  also periodically during the run in FIRE 2.0, it turns out that both integrators are
  almost identical, as also confirmed by preliminary simulations.". Adding damping is not needed for FIRE to stop. **SoftPack choice**; both
  settings take the same values as for `DampedDynamics`.

### Options

Every option below is a setting of `pack()`; any of them combines with any algorithm,
contact law and friction model.

| Option | Setting | Used by |
|---|---|---|
| Any other contact damping ratios | `ContactDamping(normal = ratio, tangential = ratio)` | |
| Moderate contact damping (restitution 0.57) | `ContactDamping(normal = 0.2, tangential = 0.2)` | $\zeta = 0.2$; [Santos2024]'s rate 0.5 is the same strength, $\zeta = 0.177$, restitution 0.61 |
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
$\tau = \sqrt{m_\text{ref}/k}$ for Hookean contacts (Hertzian: $\sqrt{m_\text{ref}\,d_\text{ref}^{1/2}/k}$,
§2 "Units"; $m_\text{ref}$ the reference mass (§4), $k$ the normal stiffness constant).

- The default values are [Santos2024]'s, $r_n = r_s = 0.5/\tau$ (their $\gamma_n$,
  $\gamma_s$, LAMMPS rates) with $\tau = \sqrt{m/k_n}$, as are the equal values for
  both directions (quote above). For equal masses ($m_\text{eff} = m/2$) this is
  $\zeta = \tfrac{r}{2}\sqrt{m_\text{eff}/k} = 0.177$, a restitution coefficient of
  0.61 with the default `attractive = false` (our integration, §8 "Restitution";
  without the clip the dashpot would give $\exp(-\pi\zeta/\sqrt{1-\zeta^2}) = 0.57$).
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
- `during = :compression`: drag on, for velocity and spin together, in every
  minimization of the compression protocol (§2) until the pressure is first within
  `pressure_tolerance` of the target, then off, and the packing settles under contact
  damping alone. The
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

### Integrator

```julia
pack(algorithm = DampedDynamics(integrator = :centered_velocity_verlet))
```

**Decision.** `DampedDynamics` takes an `integrator` with three values, and the default
is the centered velocity Verlet. A dashpot force depends on velocity, but at the end of a
step the velocity $\mathbf v_{n+1}$ is only known after the force that determines it.
The three values differ in which velocity the dashpot uses. FIRE's integrator is a
separate setting (§14).

| Value | Dashpot force uses | Cost per step | Stable step, one damped oscillator | Restart stores |
|---|---|---|---|---|
| `:centered_velocity_verlet` (default) | end-of-step velocity $\mathbf v_{n+1}$ (implicit) | a linear solve over the contacts | $\omega\,\Delta t \le 2$ at every $\zeta$ | positions, velocities |
| `:lagged_velocity_verlet` | half-step velocity $\mathbf v_{n+1/2}$ (explicit) | one force evaluation | $\omega\,\Delta t \le 2\left(\sqrt{1+\zeta^2}-\zeta\right)$ | positions, velocities, forces and torques of the last evaluation |
| `:semi_implicit_euler` | previous velocity $\mathbf v_n$ (explicit) | one force evaluation | the same as lagged | positions, velocities |

- Each value has its own page with the steps and equations: [centered](https://github.com/ColtonKawamura/SoftPack/wiki/Centered-velocity-Verlet), [lagged](https://github.com/ColtonKawamura/SoftPack/wiki/Lagged-velocity-Verlet), [semi-implicit Euler](https://github.com/ColtonKawamura/SoftPack/wiki/Semi-implicit-Euler-for-DampedDynamics).
- Why centered is the default: of the three it is the most accurate, and its stable step does not shrink as damping grows. **SoftPack choice.**
  - One damped oscillator (our test, 2026-11-24; measured against the exact solution): the centered form converges at second order at $\zeta = 0.01$, $0.05$, $0.3$ and $0.98$.
  - The lagged form and the semi-implicit Euler converge at first order at $\zeta = 0.3$ and $0.98$, with nearly the same error; the lagged form is better than the Euler only at weak damping ($\zeta \le 0.05$).
  - The measured stable steps of the lagged form and the Euler agree with the formula above at $\zeta = 0.3$, 0.7, 0.98 and 2.
  - Its restart needs only positions and velocities, as for the Euler.
- The lagged form is how LAMMPS evaluates granular dashpots: [LAMMPSreadrestart] "the forces they compute depend on atom velocities, which are used at half-step values every timestep when forces are computed."
- The stable-step formula of the lagged form is the central-difference result with the damping term lagged: the Code_Aster manual [CodeAster] (§6.2) gives "Δt < 2/ωmax (√(1+ξ²) − ξ)" with ξ the damping ratio, and says the same lagged approximation is valid for weak damping and loses second-order accuracy when damping is large (our translation from the French). [NAFEMSstable] on damping and the stable increment: "one might be tempted to think that it can increase the critical time increment, but we will show that it is not the case, rather the opposite."
- Velocity Verlet with a velocity-dependent force is first order: [Golshan2023] "When the force depends on the velocity ... the scheme is first-order accurate for both position and velocity", and still more accurate than the explicit Euler in practice.
- The cost of the centered form: it needs a linear solve over the contacts every step, $\left(\mathbf M + \tfrac{\Delta t}{2}\boldsymbol\Gamma\right)\mathbf v_{n+1} = \mathbf M\mathbf v_{n+1/2} + \tfrac{\Delta t}{2}\mathbf F(\mathbf r_{n+1})$. [Samiei2013] find in DEM that "though the implicit integration enables larger time steps ... the overall speed up is overruled by higher computational costs of the implicit method". **SoftPack note**: the default is to be checked against the cost on packings (a benchmark is planned); if the solve dominates, the default changes.
- The algorithm assembles $\boldsymbol\Gamma$ from the contact table of §7: each contact's normal and tangential dashpot coefficients from its stiffnesses and the masses, its normal and lever arms, and its sliding flag. The force model therefore does not need to know which integrator runs. **SoftPack choice.**
- The half-step state is defined per integrator. Only the lagged form has one: the forces and torques of the last evaluation, because they used $\mathbf v_{n-1/2}$. For the other two, the forces and torques are a function of the stored positions, velocities and contact history (sliding flags included), and a restart recomputes them. The exact-continuation test (§6) runs for each integrator, and a failure means a piece of state is missing. **SoftPack choice.**
- Failure mechanism: each integrator blows up when $\Delta t$ exceeds its stable step. The lagged form and the Euler lose stable step as damping grows; the centered form does not. The run-time check of §12 compares $\Delta t$ with the stable step of the chosen integrator and warns; it does not change the step.
- We did not find a paper that compares these three for relaxing jammed packings with contact dashpots (a few searches, 2026-11-24). Related work: [Rougier2004], [Hanley2016], [Vyas2025] and [deKlerk2022] on DEM integrators, and [Martys1999] and [GronbechJensen2013] on Verlet schemes with velocity-dependent or linear friction forces. A benchmark of the three is planned for the SoftPack paper.

### Time step with damping

The stable step depends on the integrator (§8, "Integrator"). For one damped oscillator
of angular frequency $\omega$ and damping ratio $\zeta$, the default centered form is
stable up to

$$
\omega\,\Delta t
 \le
\underbrace{
2
}_\text{no damping penalty}
$$

and the lagged form and the Euler up to

$$
\omega\,\Delta t
 \le
\underbrace{
2
}_\text{undamped limit}
\underbrace{
\left(\sqrt{1+\zeta^2} - \zeta\right)
}_\text{damping shrinks it}
$$

With the defaults ($\zeta = 0.98$) a single contact is stable up to about
$0.64\,t_\text{col}$ for the centered form, 32 times the default step $t_\text{col}/50$
(§12), and up to $0.27\,t_\text{col}$ for the lagged form, 13 times the default step.
In a packing the fastest vibration can be up to $\sqrt{z}$ times faster than one
contact ($z$ the contact number). For the centered form the worst case is about
$0.32\,t_\text{col}$ in 2D ($z = 4$) and $0.26\,t_\text{col}$ in 3D ($z = 6$), 16 and 13
times the default step. For the lagged form and the Euler, contact damping damps the
fastest vibration more strongly too, and the worst case is about $0.08\,t_\text{col}$ in
2D and $0.05\,t_\text{col}$ in 3D, 3.8 and 2.6 times the default step; with near-critical
contact damping, keep the step fraction at or below about $1/20$ for those two.
**SoftPack note**: estimates, to be checked once `DampedDynamics` runs. For
`ContactDamping` with its defaults the damping is exactly proportional to the
stiffness (above), so the modes decouple and each mode obeys the one-oscillator bound;
for the other damping settings, and for Hertzian and Mindlin contacts, the bound is an
estimate (our derivation).

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
seed and RNG. The default seed is 1. One generator, created from the seed, makes every
draw, in this order: the diameters (§3), then the positions of the initial state (§2).
Nothing after that is random.

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
`rattlers = nothing` there is one file with every particle and no rattler flag.

- **SoftPack choice**: the second file doubles the output.
- The second file is named after the main file: `_rattlers` goes before the extension,
  so `packing.h5` gives `packing_rattlers.h5`, in the same directory. A path without an
  extension gets `_rattlers` at the end. There is no separate keyword for its path.
  **SoftPack choice.**
- `rattlers_file = true` with `rattlers = nothing`: `write_packing` warns that no
  rattler rule was run, then writes both files. They hold the same particles, and the
  flag in the second file marks none of them as a rattler. **SoftPack choice.**

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
write_packing("packing.h5", packing; overwrite = false)
```

**Decision.** `write_packing` stops with an error if a file it would write already
exists, unless `overwrite = true`. It checks both paths (the main file and, with
`rattlers_file = true`, the second file) before it writes either.

- A silent overwrite could destroy a file that `restart_packing` (§6) still needs: a
  run restarted from `packing.h5` that writes back to `packing.h5` has to say
  `overwrite = true`. **SoftPack choice.**
- The periodic saves of `restart_file` (§6) are not affected: they rewrite their own
  file by design.

**Safe writes.** `write_packing` writes each file to a temporary file in the same
directory as its path, then renames it over the path, as `restart_file` does (§6). A
job killed during a write leaves any existing file intact. The temporary file sits in
the same directory because a rename is atomic only within one file system. With two
files, both temporary files are written first and then renamed one after the other; a
kill between the two renames can leave the new main file next to an old or missing
second file. **SoftPack choice.**

```julia
pack(snapshots = nothing)
pack(movie = nothing)
```

**Decision.** No snapshots and no movie by default. `pack()` can record snapshots
during the run (`snapshots = Snapshots(every = interval)`) and render a GIF or video
from them (`movie = Movie(path; every = interval)`).

- **SoftPack choice**: both cost time and disk. `every` has no default: a useful
  interval depends on how long the run is.

**State passed to a user function.** `convergence = my_test` (§5) receives a `RunState`,
a read-only view of the run state (§6). **SoftPack choice**, and the names are mine.

- Per particle: `positions`, `velocities`, `rotations`, `spins`, `diameters` and
  `masses`.
- Per particle, from the contacts: `forces` and `torques`, the net elastic force and
  torque ($\mathbf F_i$, $\mathbf T_i$ of §5; dashpot and drag forces are not included).
- Per contact: the two particle indices (the wall for a wall contact), `overlaps`,
  `normal_forces` and `tangential_forces`.
- The box: its side `L` and its `boundary` (§2).
- The run: `pressure` ($P$ of §2), `step` (counted from the start of the packing, as in §6)
  and `settings`.

## 12. Time step

```julia
pack(timestep = CollisionTime(fraction = 1/50))
```

**Decision.** The time step is 1/50 of the shortest binary collision time

$$t_\text{col} = \pi\sqrt{\frac{m_\text{eff}}{k}},$$

taken over the smallest particle mass, the stiffest contact (normal, or tangential
with rotation when friction is on), and for Hertzian contacts the stiffness at the
largest overlap expected; a run-time check warns if a contact becomes stiffer than
the chosen `timestep` resolves. For `DampedDynamics` the check uses the stable step of
the chosen `integrator` (§8, "Integrator"). A fixed value can be given instead. For
FIRE this is the starting step; FIRE then adapts it (§14).

- The smallest particle mass sets the step because stability needs the shortest
  collision time: **SoftPack note**. The time unit $\tau$ uses $m_\text{ref}$ instead (§4),
  since a unit has no such requirement.
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
- Damping does not shrink the stable step of the default centered integrator, which
  keeps a margin of at least about 13 in the 3D worst case. It does shrink it for the
  lagged and Euler options, where the margin falls to about 2.6 (estimates in §8, "Time
  step with damping").

## 13. Friction models

`friction = nothing` (frictionless, §2) is the default. Two friction models are
options. Keyword names follow §1 (full words, no symbols). How damping and the
Coulomb limit interact is in §8. The contact history (when it resets, which normal force
caps it, the sliding flag and its rotation) is in §7.

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

$$\frac{k_t}{k_n} = \frac{1}{1 + mR^2/I} = \frac{\kappa}{1 + \kappa},$$

with $I = \kappa\,mR^2$ (§4). It makes the tangential contact vibration (sliding plus
rotation, §8) exactly as fast as the normal one for two equal particles. That is 1/3 in
2D (disks) and 2/7 in 3D (spheres).

- The same holds for any two particles of one shape, and for a particle at a wall,
  because $1/M_t = (1 + 1/\kappa)/M_n$ in each case (§8). **SoftPack note**, our derivation.

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
  at $b\,\omega_\ell^2/2$ (Hookean contacts of equal particles, so that $b$ is the same at
  every contact; for Hertzian contacts $k$ differs between contacts, §8). With another ratio the tangential constant $b_t = \gamma_t/k_t$
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

## 15. Roadmap: other particle shapes

Nothing in this section is designed, and none of it is promised for a first release.
It records what is planned and what the design keeps open, so that it can be added
without changing the meaning of any call made today.

- Cylinders (3D disks): a disk with a thickness, in a 3D box. Planned.
- User-defined shapes: the user passes their own shape functions (below). Planned.
- Spheres confined to a plane, the Leiden 2D convention (§4): one more 2D shape, with
  sphere mass and $\kappa = 2/5$. It would come back as a shape, not as a `Density` keyword.

A shape is more than a mass formula. Everything in the design that assumes a disk or a
sphere is listed here, with what another shape would have to supply instead:

| Quantity | Disk and sphere today | Any other shape |
|:---|:---|:---|
| Size | one diameter $d_i$ (§3) | shape parameters (a cylinder: diameter and thickness) |
| Mass | $\rho\,\pi d^2/4$ or $\rho\,\pi d^3/6$ (§4) | $\rho$ times the shape's area or volume |
| Moment of inertia | the scalar $I = \kappa\,mR^2$ (§4) | in 3D an inertia tensor about the center of mass |
| Rotation state | an angle (2D) or a spin vector (3D, §7) | an orientation and a spin vector |
| Contact | overlap $\delta = (d_i + d_j)/2 - r_{ij}$ along the line of centers (§2) | a function that returns the overlap, the contact normal and the contact point, for a pair and for a wall |
| Effective masses | $M_n$ from the masses alone, $M_t$ adds $R^2/I$ (§8) | both include rotation: each particle adds $(\mathbf r\times\hat{\mathbf e})^\top\mathbf I^{-1}(\mathbf r\times\hat{\mathbf e})$ to $1/m$, with $\mathbf r$ the vector to the contact point and $\hat{\mathbf e}$ the force direction |
| Pressure | a tangential force drops out because the normal lies along $\boldsymbol\ell^{c}$ (§2) | in general it does not drop out |
| Stored output | diameters and masses (§11) | the shape kind, its parameters and the orientations |

The functions a user would pass are the right-hand column: the area or volume, the
inertia, and the contact test.

**Rules for the first implementation.** All **SoftPack choice**.

- Every shape-specific quantity in the table sits behind one shape interface, with the
  disk and the sphere as its first two members. No other code writes $\pi d^2/4$,
  $R^2/I$ or $(d_i + d_j)/2 - r_{ij}$.
- The contact laws, friction models and dashpots read the overlap, the normal, the
  contact point and the effective masses from the shape's contact, not the diameters.
  Torques are $\mathbf r\times\mathbf f$ about the contact point, which for a disk or a
  sphere is $R\hat{\mathbf n}$.
- Output and restart files (§6, §11) record a shape kind beside each diameter, so a file
  written today still reads after more shapes exist.
- A new shape arrives as an addition, a new value or constructor with today's disk or
  sphere as the default, so no call written today changes meaning.

Open for any shape other than a disk or a sphere: the contact test and the neighbor
search for non-round shapes, how a shape sets the length unit and the packing fraction
(§3), the contact laws (the Hertz law depends on the curvatures at the contact), and
the rattler counts (§9).
