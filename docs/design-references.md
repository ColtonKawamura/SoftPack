# SoftPack design decisions and their references

Every design decision for SoftPack's `pack()`, with the sources behind it. Quotes are
copied from the sources' full texts: the published versions for [OHern2003],
[Shundyak2007], [Somfai2007] and [Henkes2010], the arXiv versions or official docs
for the rest. BibTeX for every key is in [`references.bib`](references.bib).
Decisions marked **SoftPack choice** have no literature source: they are our own
call, and the reason is given.

Status: design stage (no engine code yet). Last updated 2026-11-18. Every setting has
a default and a reason (§0). Not designed yet: how `pack()` reaches the target
pressure (initial state and compression protocol).

---

## 0. Every default at a glance

Every setting of `pack()`, its default, the other choices, and the section that gives
the reasons. Units: small diameter 1, contact stiffness 1, particle mass 1.

| Setting | Default | Other choices | § |
|---|---|---|---|
| `dimension` | `2` | `3` | 2 |
| `particles` | `256` | any number ≥ 2 | 2 |
| `sizes` | `Bidisperse(small_diameter = 1.0, diameter_ratio = 1.4, small_fraction = 0.5)` | `UniformPolydisperse(mean_diameter = 1.0, spread = 0.2)`, `Monodisperse(diameter = 1.0)`, `CustomDiameters(diameters)` | 2, 3 |
| `contact` | `Hookean(stiffness = 1.0)` | `Hertzian(stiffness = 1.0)` | 2 |
| `friction` | `nothing` (frictionless) | `CundallStrack(friction_coefficient = 0.5, stiffness_ratio = :matched)`, `Mindlin(friction_coefficient = 0.5, poisson_ratio = 0.0)` | 2, 13 |
| `mass` | `EqualMass(1.0)` | `Density(1.0; shape = :disc)` (`:sphere` in 3D) | 4 |
| `target` | `Pressure(1e-4)` | | 2 |
| `convergence` | `RelativeForce(tolerance = 1e-8)` | `LeidenAcceleration(tolerance = 1e-10)`, `KineticEnergy(tolerance = 1e-8)`, `RestartTest()`, any function | 5 |
| `pressure_tolerance` | `1e-4` | any value | 5 |
| `max_steps` | `10^7` | any value | 5 |
| `on_failure` | `:warn` | `:error` | 6 |
| `algorithm` | `FIRE()` | `DampedDynamics()` | 7, 14 |
| `timestep` | `CollisionTime(fraction = 1/50)` | any fraction, or a fixed number | 12 |
| `DampedDynamics` `damping` | `ContactDamping(normal = 0.98, tangential = 0.98)` | other ratios, `ViscousRate(normal = 0.5, tangential = 0.5)`, `nothing` | 8 |
| `DampedDynamics` `drag` | `nothing` | `StokesDrag(velocity = rate)`, with `spin` and `during` | 8 |
| `FIRE` `damping`, `drag` | `nothing`, `nothing` | same as `DampedDynamics` | 8 |
| FIRE parameters | LAMMPS FIRE 2.0 defaults | any value | 14 |
| `rattlers` | `ContactCount(cone_test = true)` | `TwoContact()`, `ForceFloor(floor = 1e-3)`, `Unresolved(floor = :tolerance)`, `nothing`, any function | 9 |
| `seed` | `1` | any integer | 10 |
| file format | HDF5 | CSV | 11 |
| `with_rattlers` | `false` | `true` | 11 |
| `compression` | `nothing` | `:gzip` (level 4) | 11 |
| `snapshots`, `movie` | `nothing` | `Snapshots(every = interval)`, `Movie(path; every = interval)` | 11 |

## 1. Interface and naming

**Decision.** `pack()` runs with no arguments. Settings are keywords
(`pack(; particles = 2000, target = Pressure(1e-4))`) or a reusable `PackParams` value
(`pack(params)`). Any setting with its own sub-settings is a small type (`Pressure`,
`FIRE`, `CundallStrack`, ...) so algorithms, force laws and rules can be swapped by
dispatch. Names follow the Julia style guide: CamelCase types, snake_case functions
and keywords, `!` for functions that mutate an argument. Keywords are full English
words, never a symbol from one paper's notation or an abbreviation:
`friction_coefficient`, not `mu` or `friction_coeff`.

- [JuliaStyle] "modules and type names use capitalization and camel case"
- [JuliaStyle] "Function names should be written in snake case"
- No abbreviations: [JuliaStyle] "conciseness is valued, but avoid abbreviation
  (indexin rather than indxin) as it becomes difficult to remember whether and how
  particular words are abbreviated." (coef or coeff?)
- No notation symbols, because papers name the same quantity differently.
  [Santos2024] "the tangential forces are referred to by the letter 's' to indicate
  that we include sliding friction between the particles", where [Silbert2001] write
  k_t and γ_t for the same springs and dashpots; LAMMPS calls the friction coefficient
  `xmu` [LAMMPSgran]. **SoftPack choice.**

## 2. Default packing

**Decision.** 2D, `particles = 256`, 50:50 bidisperse with diameter ratio 1.4, frictionless
Hookean contacts with `stiffness = 1`, target pressure `1e-4`, FIRE.

- 50:50 bidisperse, ratio 1.4: [OHern2003] "In our two-dimensional (2D) simulations,
  we have used 50-50 mixtures of particles with a size ratio of 1.4 in order to
  prevent crystallization".
- 2D: **SoftPack choice.** 2D packings are the cheapest to make and to check by eye,
  and the bidisperse mixture above is the standard 2D one. `dimension = 3` is an option.
- `particles = 256`: **SoftPack choice.** Small enough that `pack()` with no arguments
  finishes in seconds, and inside the range of jamming studies: [OHern2003] "We
  have studied the finite-size effects by varying the number of particles in the
  sample between 4 < N < 4096 in 2D and 3D." Production runs should set `particles`.
- Hookean contacts: [OHern2003] study both "α = 2 for repulsive harmonic springs"
  and "α = 5/2 for repulsive Hertzian interactions". Hookean is the default
  (**SoftPack choice**) because its stiffness does not change with overlap, so the
  collision time, time step and damping ratio are fixed for the whole run.
  `Hertzian` is an option.
- `stiffness = 1`: **SoftPack choice.** Sets the force unit. For Hookean contacts the
  pressure `1e-4` then means P = 10^-4 k in 2D and P = 10^-4 k/d in 3D (k the stiffness,
  d the small diameter).
- Pressure `1e-4`: **SoftPack choice**, near jamming but high enough to converge
  quickly. Frictional jamming studies span pressures from 10^-6 to 10^-3
  [Henkes2010] (Hertz-Mindlin grains, so their pressure unit differs from ours).
- FIRE: introduced in [Bitzek2006]; assessed and implemented in LAMMPS in
  [Guenole2020].
- Frictionless as the default (rather than frictional): **SoftPack choice**. FIRE on
  a frictionless packing has a well-defined end state (an energy minimum) and known
  checks (jamming packing fraction, z → 4 in 2D); frictional packings depend on the
  preparation path (see §7).

## 3. Sizes and length unit

**Decision.** Sizes are diameters everywhere. Each size distribution sets its own
unit in its defaults: `Bidisperse(small_diameter = 1.0, ...)` makes the small diameter 1
(the jamming convention); polydisperse distributions default to mean diameter 1
(the Leiden convention). Files store the actual diameters.

Built-in distributions and their defaults:
- `Bidisperse(small_diameter = 1.0, diameter_ratio = 1.4, small_fraction = 0.5)`, `small_fraction` being the number
  fraction of small particles (the default packing, §2).
- `UniformPolydisperse(mean_diameter = 1.0, spread = 0.2)`: diameters uniform between
  mean_diameter × (1 − spread) and mean_diameter × (1 + spread).
- `Monodisperse(diameter = 1.0)`.
- `CustomDiameters(diameters)`: any list of diameters.

- Diameters, small-diameter unit: [OHern2003] "The diameter of the smaller particle
  is denoted by σ." ... "lengths are measured in units of σ"
- Mean-diameter unit: [Somfai2005] "Our unit of length is the average grain
  diameter." [Shundyak2007] "our units are such that the mass density, the average
  particle diameter, and the Young's modulus of the grains are 1."
- `spread = 0.2`: [Somfai2005] "For the 2D simulations the spheres have
  polydispersity to avoid crystallization: the diameters are uniformly distributed
  between 0.8 and 1.2 times their average."
- `Monodisperse` is an option, not the default, because equal disks crystallize in 2D
  (the reason for the bidisperse mixture, §2). In 3D, [OHern2003] "we have studied the
  same bidisperse mixture as well as monodisperse systems".
- DEM software takes diameters: [LAMMPSset] "diameter value = diameter of spherical
  particle (distance units)"

## 4. Mass

**Decision.** `mass = EqualMass(1.0)`: every particle has mass 1, which sets the mass
unit (**SoftPack choice**). Option: `Density(1.0; shape)`, mass from a material
density, with `shape = :disc` (area) the default in 2D and `:sphere` (volume) in 3D.
Per-particle masses are stored in the output so spectra computed later use the same
masses.

- Equal mass (jamming / soft-sphere convention): [OHern2003] "... where all
  particles have equal mass m."
- Density-based mass (DEM convention): [LAMMPSset] "density/disc value = particle
  density for a 2d disc or ellipse (mass/distance^2 units)"; [Somfai2005] "The unit
  of mass is set by asserting that the material of the grains has unit density."
  That is the reason for the default density 1.0.
- `shape = :disc` in 2D: **SoftPack choice**, because SoftPack's 2D particles are
  disks. `shape = :sphere` in 2D gives the Leiden convention: [Somfai2005] "2D
  samples containing 600 spheres (their centers being confined to a plane)".

## 5. Convergence (stopping) criterion

**Decision.** `convergence = RelativeForce(tolerance = 1e-8)`, one rule for frictionless
and frictional packings: the largest net force on any particle (and the largest net
torque when friction is on) must be below `tolerance` times the mean contact force. The
pressure must also be within `pressure_tolerance = 1e-4` (relative) of the target, and a
run stops after `max_steps = 10^7` steps at most. Options: `LeidenAcceleration(tolerance =
1e-10)`, `KineticEnergy(tolerance = 1e-8)`, `RestartTest()`, or any function of the
packing state that returns true when done. The default `tolerance = 1e-8` is provisional
(**SoftPack choice**, to be timed on frictional packings).

- A tolerance relative to the typical force: [Agnolin2007] "Calculations are
  stopped when the net elastic force on each particle is below 10^-4 a^2 P, the
  elastic contributions to the stress components equal the prescribed value P with
  relative error smaller than 10^-4 and the kinetic energy per particle is below
  10^-8 P a^3." [Gilabert2007] "the net force on each disk is less than 10^-4 F_1,
  and the total moment is lower than 10^-4 F_1 a" (with F_1 = max(F_0, P a), the
  typical intergranular force).
- `LeidenAcceleration(tolerance = 1e-10)`: [Somfai2005] "Our packings
  are considered to have converged to mechanical equilibrium when all grains have
  acceleration less than 10^-10 in our reduced units". [Shundyak2007] builds its
  packings "As in [16]", reference 16 being [Somfai2005]. The number 1e-10 only
  reproduces the Leiden rule in Leiden units (E* = 1, mean diameter = 1, density 1).
- `KineticEnergy(tolerance = 1e-8)` (kinetic energy per particle below tolerance × P d^D, the
  [Agnolin2007] value above); [Xiong2019] stop each minimization on a maximum
  per-disk kinetic energy.
- `RestartTest()` (zero all velocities, then check that the kinetic energy and the
  unbalanced forces do not grow back): [Agnolin2007] "On setting all velocities to zero,
  it is observed that the sample does not regain kinetic energy beyond that value,
  while the unbalanced force level does not increase."
- `pressure_tolerance = 1e-4`: the [Agnolin2007] value above (stress equal to P "with
  relative error smaller than 10^-4"). [Gilabert2007] use the same 10^-4 level for
  the pressure, scaled by their typical force F_1.
- `max_steps = 10^7`: **SoftPack choice.** A safety cap, not a convergence test: a run
  that hits it is returned with `converged = false` (§6). The value is twice the
  5 × 10^6 cap of GranEJulia's packer, which SoftPack replaces and which stops at a
  looser force tolerance (10^-4 against 10^-8 here).

## 6. A packing that does not converge

**Decision.** `pack()` prints a warning and returns the packing with
`converged = false`. Retrying with other seeds is the caller's job. **SoftPack
choice**: never discard or silently save an unfinished packing; let the caller see
and count failures (replacing failures conditions an ensemble on convergence).

Option: `on_failure = :error` throws an error instead (default `:warn`), for batch
scripts that should stop at the first failure. **SoftPack choice.**

## 7. Algorithms and combinations

**Decision.** Every combination of algorithm, contact law, friction model, target,
convergence test and rattler rule is allowed in one `pack()`. Force models (normal
law plus friction, holding the contact history) and algorithms only exchange
positions/rotations and forces/torques. FIRE with friction is allowed and recorded,
but documented as non-standard.

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
  [Henkes2010], on the relation between the friction coefficient and n_m (the
  fraction of fully mobilized contacts): "Our simulations indicate that this relation
  depends significantly on the preparation method of the sample, where packings
  prepared with higher viscous damping have larger n_m"; see also [Santos2024].

## 8. Damping

Damping sets how damped molecular dynamics (`DampedDynamics`) removes energy. FIRE removes
energy with its own velocity rules, so its default is no damping, but it accepts the
same settings (§7: any combination is allowed).

### Energy-loss channels

| Channel | What it damps | Setting |
|---|---|---|
| Normal contact dashpot | Approach and separation speed of touching particles | `ContactDamping(normal = ...)` |
| Tangential contact dashpot | Sliding speed at the contact point (friction on only) | `ContactDamping(tangential = ...)` |
| Stokes drag on velocity | Each particle's absolute velocity | `StokesDrag(velocity = ...)` |
| Stokes drag on spin | Each particle's absolute spin | `StokesDrag(spin = ...)` |
| Coulomb sliding | Built into friction | not a setting |

Contact damping and Stokes drag fail in opposite ways on the slow, collective (soft)
modes, which are the last motion left when a run nears its stopping rule. Contact
damping grows with stiffness, so a mode's damping ratio is roughly ζ ω_mode/ω_contact:
soft modes are barely damped and keep ringing. Stokes drag is the same for every mode,
so a mode's damping ratio is γ/(2 ω_mode): soft modes are overdamped and creep.
**SoftPack note** (standard result for damping proportional to stiffness or to mass;
not taken from a cited paper).

### Defaults

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

Every default and the reason for it:

**`normal = 0.98`: each contact's normal dashpot is 0.98 of its critical value.**
- A ratio to critical damping, not a raw coefficient, so it means the same for Hooke
  and Hertz contacts: [Gilabert2007] "We choose its value as a constant fraction ζ of
  the critical damping coefficient" ... "This is equivalent to the choice of a
  constant restitution coefficient in normal collisions if F₀ = 0." (F₀ is their
  maximum cohesive force, zero for SoftPack's particles.) [Agnolin2007]
  use the same form, their Eq. (5): α(h) = ζ sqrt(2 m K_N(h)), which grows as
  h^(1/4) for Hertz contacts.
- The value 0.98: [Agnolin2007] "we generally use a strong dissipation, ζ = 0.98, to
  approach equilibrium faster", and "the initial motivation for choosing ζ < 1 is the
  computational inefficiency of overdamped contacts with ζ > 1 in the case of linear
  contact elasticity." For Hooke contacts, ζ = 0.98 gives a restitution coefficient
  of about 2 × 10^-7 (our conversion): a loose particle stops at its first impact.
- The packing does not depend much on the exact value: [Agnolin2007] "changes of ζ in
  the range between 0.7 and 1 have virtually no detectable effect", and "a value of
  the damping parameter ten times as small as the standard one ζ = 0.98 results in
  quite similar configuration properties".

**`tangential = 0.98`: tangential dashpot on, same ratio as the normal one.**
- Without it, a stuck contact's back-and-forth sliding is damped only when it slips.
  The Leiden protocol damps both directions: [Somfai2005] "which is at every instant
  a given constant fraction of the linear critical viscous damping, both for the
  normal and for the tangential force". [Silbert2001], whose baseline has no
  tangential damping, report for their flow simulations: "Making γt/γn non-zero
  quickens the approach to the steady state by draining out more energy."
- Equal normal and tangential damping is also the LAMMPS-based choice of
  [Santos2024]: "The normal (n) and tangential (s) particle spring (k) and damping
  (γ) parameters are set equal to each other".
- It applies only when friction is on. Frictionless contacts carry no tangential
  force, so there is nothing to damp.

**`tangential_mass = :with_rotation`: the tangential critical value uses the true
sliding mass.**
- A tangential force at the contact both pushes and spins the two particles, so the
  sliding motion responds like a lighter mass than the pair:
  1/M_t = 1/m_i + 1/m_j + R_i²/I_i + R_j²/I_j, against 1/M_n = 1/m_i + 1/m_j for the
  normal direction. For equal disks M_t = M_n/3, for equal spheres M_t = M_n/3.5.
  A ratio measured on the pair mass M_n would really be 0.98 × sqrt(3) ≈ 1.7 for
  disks and 0.98 × sqrt(3.5) ≈ 1.8 for spheres, which is overdamped and slow.
  Measuring it on M_t makes 0.98 mean 0.98. **SoftPack choice**, from the rigid-body
  mechanics of two particles in contact.
- For Mindlin contacts the critical value uses the contact's current tangential
  stiffness, as the normal one does for Hertz.

**`attractive = false`: the dashpot never makes a contact pull.**
- When two touching particles separate, the normal dashpot can outweigh the spring.
  [Somfai2005] "We impose that the total radial force, which now also contains the
  viscous contribution, never becomes attractive." LAMMPS offers the same switch:
  [LAMMPSgran] "If two particles are moving away from each other while in contact,
  there is a possibility that the particles could experience an effective attractive
  force due to damping. If the limit_damping keyword is used, this option will zero
  out the normal component of the force if there is an effective attractive force."
- Default `false` because these are cohesionless particles: a pulling contact is an
  artifact of the dashpot, not physics.

**`coulomb_limit = :elastic`: the friction limit applies to the spring forces only.**
- The elastic tangential force is capped at μ times the elastic normal force. A
  sliding contact carries exactly that force, and its tangential dashpot is off while
  it slides, so the tangential force never exceeds the Coulomb limit.
- Following [Agnolin2007] "We do not introduce any tangential viscous force, and
  impose the Coulomb inequality to elastic force components only." At rest every
  dashpot force is zero, so the finished packing's forces are purely elastic and
  satisfy the Coulomb limit exactly.
- Switching the dashpot off while sliding is a **SoftPack choice** (Agnolin and
  Roux have no tangential dashpot to switch): slip already removes energy, and it
  keeps the sliding force at the Coulomb limit.

**`drag = nothing`: no Stokes drag.**
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

**FIRE: `damping = nothing`, `drag = nothing`.**
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
| Moderate contact damping (restitution about 0.5) | `ContactDamping(normal = 0.2, tangential = 0.2)` | ζ ≈ 0.18 is our conversion of [Santos2024] |
| Normal damping only | `ContactDamping(normal = 0.98, tangential = 0)` | [Agnolin2007] |
| Tangential ratio on the pair mass | `ContactDamping(tangential_mass = :pair)` | the usual raw-coefficient convention |
| Raw damping rates instead of ratios | `ViscousRate(normal = 0.5, tangential = 0.5)` | [Santos2024], [LAMMPSgran] |
| No contact damping | `damping = nothing` | FIRE default |
| Dashpot allowed to pull | `attractive = true` | LAMMPS without `limit_damping` [LAMMPSgran] |
| Friction limit on total forces | `coulomb_limit = :total` | [LAMMPSgran] |
| Stokes drag, always on | `drag = StokesDrag(velocity = rate)` | [Shimada2026], [Xiong2019] |
| Stokes drag while compressing only | `drag = StokesDrag(velocity = rate, during = :compression)` | Leiden-style, [Somfai2007] |
| Overdamped Stokes drag | `drag = StokesDrag(velocity = rate)` with a rate large compared with the soft-mode frequencies | [Xiong2019] |
| Spin drag only (for rolling) | `drag = StokesDrag(velocity = 0, spin = rate)` | |

The options' own defaults and the reasons:

- **`ViscousRate(normal = 0.5, tangential = 0.5)`:** dashpot force −m_eff γ v, with γ
  in units of 1/τ, τ = sqrt(m/k) (m the small-particle mass, k the normal stiffness
  constant). The default values are [Santos2024]'s, γn = γs = 0.5/τ with
  τ = sqrt(m/kn), as are the equal values for both directions (quote above). For
  equal masses this is ζ ≈ 0.18, a restitution coefficient of about 0.57 (our
  conversion). A raw rate damps Hertz contacts less as they compress; use
  `ContactDamping` for a fixed ratio. `ViscousRate` takes the same `attractive` and
  `coulomb_limit` keywords with the same defaults.
- **`coulomb_limit = :total`:** the total tangential force (spring plus dashpot) is
  capped at μ times the total normal force, as in LAMMPS: [LAMMPSgran] "the Coulomb
  criterion Ft = xmu*Fn, where Ft and Fn are the total tangential and normal force
  components in the formulas above."
- **Tangential damping off** is LAMMPS's `dampflag` switch: [LAMMPSgran] "dampflag = 0
  or 1 if tangential damping force is excluded or included".
- **`StokesDrag(velocity, spin = velocity, during = :always)`:** force −γv m v and
  torque −γs I ω, rates in units of 1/τ.
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
  - `during = :compression`: drag on until the pressure is within `pressure_tolerance` of
    the target, then off, and the packing settles under contact damping alone. The
    Leiden packings are made with drag that is later removed: [Somfai2007] "The
    packings are constructed by cooling while slowly inflating the particle radii in
    the presence of a linear damping force", and "Once a packing is made, the
    additional damping force is switched off". Where to switch it off during
    preparation is a **SoftPack choice**; the paper does not give one.
- **Spin drag only:** contact dashpots do not damp pure rolling (one particle rolling
  over another has no sliding speed at the contact), so runs with friction that stall
  on rolling motion can add a small spin drag. **SoftPack note.**

### Time step with damping

An explicit integrator's stable step shrinks as damping grows: for one damped
oscillator, ω dt ≤ 2 (sqrt(1 + ζ²) − ζ). With the defaults (ζ = 0.98) a single contact
is stable up to about 0.27 t_col, 13 times the default step t_col/50 (§12). In a
packing the fastest vibration can be up to sqrt(z) times faster than one contact, and
contact damping then damps it more strongly too. The worst case is about 0.08 t_col
in 2D (z = 4) and 0.05 t_col in 3D (z = 6), still 3.8 and 2.6 times the default step.
With near-critical contact damping, keep the step fraction at or below about 1/20.
**SoftPack note**: estimates, to be checked once `DampedDynamics` runs.

## 9. Rattler rules

**Decision.** `rattlers` takes any function of the contact network that returns a
true/false mask per particle. Built-in rules: `ContactCount()` (default),
`TwoContact()`, `ForceFloor(floor = 1e-3)`, `Unresolved(floor = :tolerance)`. Every rule takes a
`cone_test` option, on by default. Rattlers are removed by default.
`find_rattlers(packing, rule)` applies a rule to a finished packing. The mean force
`<f>` is taken over all contacts before anything is removed.

- `ContactCount`, frictionless < d + 1 and frictional < 2 contacts, applied
  repeatedly: [Xiong2019] "we recursively remove rattler disks with fewer than three
  contacts for frictionless disks or fewer than two contacts for frictional disks."
  For frictional particles, [Agnolin2007] note that "spheres with as few as two contacts
  may carry forces (even large ones, as we shall see) and should not be regarded as
  rattlers."
- `TwoContact` (remove particles with two or fewer contacts, repeated): [Ishima2023]
  regard particles with Z_i ≤ Z_Th as rattlers and "repeat these processes until the
  number of rattlers is converged", with Z_Th = 2. [Shimada2026] "we refer to
  particles with two contacts as pseudo-rattlers to distinguish them from true
  rattlers", and count samples "remaining jammed after removing rattlers and
  pseudo-rattlers".
- `ForceFloor` (contacts below floor·<f> count as broken), default `floor = 1e-3`:
  [Shundyak2007] "we always take out rattlers by considering contact forces less than
  10^-3 times the average force broken and removing particles, with less than two
  contacts."
- `Unresolved` (particles whose contacts all carry less than the force tolerance):
  [Agnolin2007] "We also discard from the backbone all spheres with only forces
  smaller than the tolerance." Tying the floor to the packing's own tolerance (`floor = :tolerance`) is a
  **SoftPack choice**: the rule means "below the stopping rule's noise".
- Cone test (a two-contact particle is removed when no forces inside its friction cones
  can hold it): [Gilabert2007] "Without cohesion, the Coulomb condition restricts
  the angle between the directions of the 2 contacts to values between π − 2ϕ and
  π, where ϕ is the friction angle (tan ϕ = µ)." [Agnolin2007]: the angle α "between
  the line joining the centers of 1 and 2 and the one joining the contact points be
  smaller than the angle of friction, for the total contact force to stay within the
  Coulomb cone." On by default for every rule: **SoftPack choice** (a particle that
  fails it cannot carry load). `cone_test = false` gives back the published
  contact-count rule.

## 10. Reproducibility

**Decision.** Seeds use StableRNGs.jl so a seed gives the same packing on every
Julia version; every output records the SoftPack version, git commit, Julia version,
seed and RNG. Default `seed = 1`, so `pack()` with no arguments gives the same packing
every time (**SoftPack choice**).

- [JuliaRandom] "a minor release of Julia (e.g. 1.3 to 1.4) *may change* the
  sequence of pseudorandom numbers generated from a specific seed."
- [StableRNGs] the package the Julia manual points to for stable streams.

## 11. Outputs

**Decision.** `pack()` returns a `Packing` in memory. Writing files is a separate
call (`write_packing`), except for the optional movie and snapshot recording below.
The word is "particles" throughout (API, files, docs).

**Default file format: HDF5.** One binary file holds the packing, the contacts, all
settings and any optional extras (time series, snapshots, matrices), with exact
floating-point values. It is read natively by MATLAB, Python and Julia:

- [MATLABh5read] `h5read` is built into MATLAB ("Introduced in R2011a").
- [h5py] Python reads datasets as NumPy arrays: "Datasets are very similar to NumPy
  arrays."
- [HDF5jl] Julia's JLD/JLD2 files "are still both regular HDF5 files and are
  therefore compatible with any HDF5 reader or writer."

Three rules follow from the sources:

- Store per-particle and per-contact quantities as one 1-D dataset per column
  (`x`, `y`, `diameter`, ...), not as N x D matrices: [HDF5jl] "Julia, like Fortran
  and MATLAB, stores multidimensional arrays in column-major order, while other
  languages, including C and Python (NumPy), use row-major order. Therefore when
  reading an array in Julia from row-major order language the dimensions may be
  inverted." 1-D datasets read the same in every language. **SoftPack choice.**
- When an option stores a genuinely multi-dimensional array (for example snapshots
  as frames x particles, or dense matrices), `pack()` prints a warning when the run
  starts, naming those outputs and saying that Python and C readers will see them
  transposed, and each such dataset carries an `array_order = "column-major"`
  attribute. **SoftPack choice**, from the [HDF5jl] note above.
- Compress only with gzip/deflate: [h5py] the GZIP filter is "Available with every
  installation of HDF5, so it's best where portability is required." [HDF5jl] warns
  that Blosc-compressed datasets cannot be read by "vanilla HDF5 distributions".

**Rattlers in the output.** When a rattler rule is applied (the default), the main
file holds only the remaining particles, with their original ids. `with_rattlers =
true` also writes a second file with every particle and a rattler flag (default
`false`). With `rattlers = nothing` there is one file with every particle.
**SoftPack choice**.

**Compression.** Default `compression = nothing`. Packing files are small, and
uncompressed datasets can be memory-mapped: [HDF5jl] "This is possible only under
particular conditions: when the dataset is an array of standard 'bits' types (e.g.,
Float64 or Int32) and no chunking/compression is being used." `compression = :gzip`
uses level 4 unless a level is given: [h5py] "compression_opts sets the compression
level and may be an integer from 0 to 9, default is 4."

**Movies and snapshots.** `pack()` can record snapshots during the run
(`snapshots = Snapshots(every = interval)`) and render a GIF or video from them (`movie =
Movie(path; every = interval)`); both default to `nothing`. **SoftPack choice**. `every` has
no default: a useful interval depends on how long the run is.

**Formats.** HDF5 is the default. CSV is an option, for spreadsheets or reading
without an HDF5 library. MATLAB `.mat` and JLD2 are not offered: MATLAB reads HDF5
directly [MATLABh5read] and JLD2 files are HDF5 files [HDF5jl]. Extended XYZ (for
OVITO) and LAMMPS data files may be added later. **SoftPack choice.**

## 12. Time step

**Decision.** `timestep` is a setting. Default `timestep = CollisionTime(fraction = 1/50)`: 1/50
of the shortest binary collision
time t_col = π sqrt(m_eff / k), taken over the smallest particle mass, the stiffest
contact (normal, or tangential with rotation when friction is on), and for Hertzian
contacts the stiffness at the largest overlap expected; a run-time check warns if a
contact becomes stiffer than the chosen `timestep` resolves. A fixed value can be given
instead. For FIRE this is the starting step; FIRE then adapts it (§14).

- 1/50 of the collision time: [Silbert2001] "an accurate simulation typically
  requires δt ∼ t_col/50", with t_col = π (2 k_n/m − γ_n²/4)^(-1/2).
- Other values in use: [Santos2024] "The simulation time step was set to
  ∆t = 0.02τ. A time step ∆t = 0.002τ was also tested and did not change the
  results for the pressures studied within the uncertainties." [Ishima2023] use
  ∆t = 1.0 × 10^-2 t_0 with velocity Verlet. Industrial DEM sets the step from the
  Rayleigh time instead: [EDEMtimestep] "the normal range is 10%-40% of the Rayleigh
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

**Decision.** `friction = nothing` (frictionless, §2). Options:

- `CundallStrack(friction_coefficient = 0.5, stiffness_ratio = :matched)`: a linear tangential spring with
  Coulomb slip, the "Hookean spring-dashpot-slider interaction potential (Cundall and
  Strack, 1979)" of [Santos2024]. Works with `Hookean` or `Hertzian` contacts.
- `Mindlin(friction_coefficient = 0.5, poisson_ratio = 0.0)`: the Hertz-Mindlin tangential force, whose stiffness
  grows with the overlap. Needs `Hertzian` contacts.

Keyword names follow §1 (full words, no symbols). How damping and the Coulomb limit
interact is in §8.

- `friction_coefficient = 0.5`: [Somfai2005] packings are "prepared with friction coefficient µ = 0.5
  and Poisson ratio ν = 0"; [Silbert2001] use "friction coefficient µ = 0.50". It is a
  common value, not a material constant. Frictional studies usually vary μ:
  [Henkes2010] cover μ from 10^-3 to 10^3, and [Agnolin2007] use "a moderate,
  plausible value µ = 0.3". Production runs should set `friction_coefficient`.
- `stiffness_ratio = :matched`: the tangential over the normal stiffness,
  k_t/k_n = 1/(1 + m R²/I), which makes the tangential contact
  vibration (sliding plus rotation, §8) exactly as fast as the normal one for two
  equal particles. That is 1/3 for disks and 2/7 for spheres. [Silbert2001] use
  k_t/k_n = 2/7 for spheres for this reason (equal periods of normal and shear contact
  oscillations), and LAMMPS uses 2/7 when K_t is not given [LAMMPSgran]. Applying the
  same rule to disks is a **SoftPack choice**. The tangential direction then does not
  shorten the time step (§12), and the default damping ratio (§8) gives both
  directions the same decay time. [Silbert2001], for their flows: "However, the
  contact dynamics are not very sensitive to the precise value of this ratio." Any
  number can be given instead.
- `poisson_ratio = 0.0`: the Leiden choice. [Shundyak2007] "The Poisson ratio of the grains is
  taken to be zero"; [Somfai2005] same (quote above). With ν = 0 the two stiffnesses
  are equal: [Somfai2005] "for ν = 0, the value we use in most of the simulations, the
  two effective stiffnesses dFt/dt and dFn/dn are equal". The tangential vibration is
  then faster than the normal one (sqrt(3) times for disks), so it sets the time step
  (§12). For real materials, [Silbert2001] "For Hertzian contacts [37], the ratio
  kt/kn depends on the Poisson ratio of the material, and is about 2/3 for most
  materials."

## 14. FIRE settings

**Decision.** `FIRE()` uses the FIRE 2.0 defaults of LAMMPS, listed in [Guenole2020]
(Table 1), the paper that assessed FIRE 2.0 and implemented it in LAMMPS. FIRE itself
is from [Bitzek2006].

| Setting | Default | Meaning |
|---|---|---|
| `max_timestep` | `10` | largest step, in units of the starting step (§12) |
| `min_timestep` | `0.02` | smallest step, same units |
| `delay` | `20` | steps to wait after an uphill move before the step may grow |
| `timestep_grow` | `1.1` | factor by which the step grows |
| `timestep_shrink` | `0.5` | factor by which the step shrinks after an uphill move |
| `mixing` | `0.25` | starting coefficient for mixing the velocity and force directions |
| `mixing_shrink` | `0.99` | factor by which that coefficient shrinks |
| `max_uphill` | `2000` | consecutive uphill moves before the run stops |
| `half_step_back` | `true` | move back half a step after an uphill move |
| `initial_delay` | `true` | apply the delay at the start of the run too |
| `integrator` | `:semi_implicit_euler` | `:velocity_verlet` is the option |
| `damping`, `drag` | `nothing` | see §8 |

- All values except `damping` and `drag`: [Guenole2020] Table 1 (LAMMPS `min_modify`
  defaults for FIRE 2.0).
- `integrator = :semi_implicit_euler`: [Guenole2020] "Hence we recommend the usage of
  FIRE 2.0 with an Euler Implicit integrator." (Their Euler implicit is the
  semi-implicit, or symplectic, Euler scheme.) Velocity Verlet is also suitable:
  [Guenole2020] "Symplectic schemes like Euler semi-implicit (also called symplectic
  Euler), Leapfrog or Velocity Verlet are more robust against varying timesteps".
- A run that reaches `max_uphill` is returned with `converged = false` (§6), where
  LAMMPS ends the minimization. **SoftPack choice**, to match §6.
