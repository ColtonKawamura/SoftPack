# SoftPack design decisions and their references

Every design decision for SoftPack's `pack()`, with the sources behind it. Quotes are
copied from the papers' full texts (arXiv versions); BibTeX for every key is in
[`references.bib`](references.bib). Decisions marked **SoftPack choice** have no
literature source: they are our own call, and the reason is given.

Status: design stage (no engine code yet). Last updated 2026-11-18.
The 1/50 time-step default (§12), HDF5-default / CSV-option formats (§11) and the
damping defaults (§8) are settled.

---

## 1. Interface and naming

**Decision.** `pack()` runs with no arguments. Settings are keywords
(`pack(; n = 2000, target = Pressure(1e-4))`) or a reusable `PackParams` value
(`pack(params)`). Any setting with its own sub-settings is a small type (`Pressure`,
`FIRE`, `CundallStrack`, ...) so algorithms, force laws and rules can be swapped by
dispatch. Names follow the Julia style guide: CamelCase types, snake_case functions
and keywords, `!` for functions that mutate an argument.

- [JuliaStyle] "modules and type names use capitalization and camel case"
- [JuliaStyle] "Function names should be written in snake case"

## 2. Default packing

**Decision.** 2D, `n = 256`, 50:50 bidisperse with diameter ratio 1.4, frictionless
Hookean contacts, target pressure `1e-4`, FIRE.

- 50:50 bidisperse, ratio 1.4: [OHern2003] "In our two-dimensional (2d) simulations
  we have used 50-50 mixtures of particles with a size ratio of 1.4 in order to
  prevent crystallization."
- 2D: **SoftPack choice.** 2D packings are the cheapest to make and to check by eye,
  and the bidisperse mixture above is the standard 2D one. `dim = 3` is an option.
- `n = 256`: **SoftPack choice.** Small enough that `pack()` with no arguments
  finishes in seconds, and inside the range of jamming studies: [OHern2003] "We
  have studied the finite-size effects by varying the number of particles in the
  sample between 4 < N < 4096 in 2d and 3d." Production runs should set `n`.
- Hookean contacts: [OHern2003] study both "α = 2 for repulsive harmonic springs"
  and "α = 5/2 for repulsive Hertzian interactions". Hookean is the default
  (**SoftPack choice**) because its stiffness does not change with overlap, so the
  collision time, time step and damping ratio are fixed for the whole run.
  `Hertzian` is an option.
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
unit in its defaults: `Bidisperse(small = 1.0, ...)` makes the small diameter 1
(the jamming convention); polydisperse distributions default to mean diameter 1
(the Leiden convention). Files store the actual diameters.

- Diameters, small-diameter unit: [OHern2003] "The diameter of the smaller particle
  is denoted by σ." ... "lengths are measured in units of σ"
- Mean-diameter unit: [Somfai2005] "Our unit of length is the average grain
  diameter." [Shundyak2007] "our units are such that the mass density, the average
  particle diameter and the Young's modulus of the grains are 1."
- DEM software takes diameters: [LAMMPSset] "diameter value = diameter of spherical
  particle (distance units)"

## 4. Mass

**Decision.** Equal mass for every particle by default. Option: mass from a material
density (2D disc area or 3D sphere volume). Per-particle masses are stored in the
output so spectra computed later use the same masses.

- Equal mass (jamming / soft-sphere convention): [OHern2003] "... where all
  particles have equal mass m."
- Density-based mass (DEM convention): [LAMMPSset] "density/disc value = particle
  density for a 2d disc or ellipse (mass/distance^2 units)"; [Somfai2005] "The unit
  of mass is set by asserting that the material of the grains has unit density."

## 5. Convergence (stopping) criterion

**Decision.** One rule for frictionless and frictional packings: the largest net
force on any particle (and the largest net torque when friction is on) must be below
`tol` times the mean contact force, and the pressure must be within `pressure_tol`
of the target. Options: the Leiden absolute-acceleration rule, and kinetic-energy
tests. The default `tol = 1e-8` is provisional (**SoftPack choice**, to be timed on
frictional packings).

- A tolerance relative to the typical force: [Agnolin2007] "Calculations are
  stopped when the net elastic force on each particle is below 10^-4 a^2 P, the
  elastic contributions to the stress components equal the prescribed value P with
  relative error smaller than 10^-4 and the kinetic energy per particle is below
  10^-8 P a^3." [Gilabert2007] "the net force on each disk is less than 10^-4 F_1,
  and the total moment is lower than 10^-4 F_1 a" (with F_1 = max(F_0, P a), the
  typical intergranular force).
- Leiden absolute rule (option `LeidenAcceleration`): [Somfai2005] "Our packings
  are considered to have converged to mechanical equilibrium when all grains have
  acceleration less than 10^-10 in our reduced units". [Shundyak2007] builds its
  packings "As in [16]", reference 16 being [Somfai2005]. The number 1e-10 only
  reproduces the Leiden rule in Leiden units (E* = 1, mean diameter = 1, density 1).
- Kinetic-energy tests (candidate options): [Agnolin2007] and [Gilabert2007] above;
  [Xiong2019] stop each minimization on a maximum per-disk kinetic energy.
- Restart test (candidate option): [Agnolin2007] "On setting all velocities to zero,
  it is observed that the sample does not regain kinetic energy beyond that value,
  while the unbalanced force level does not increase."

## 6. A packing that does not converge

**Decision.** `pack()` prints a warning and returns the packing with
`converged = false`. Retrying with other seeds is the caller's job. **SoftPack
choice**: never discard or silently save an unfinished packing; let the caller see
and count failures (replacing failures conditions an ensemble on convergence).

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
  settings (§8) are part of the packing's identity and are recorded in every output: [Henkes2010] the mobilized
  contact fraction is bimodal over a range of pressures "due to the interplay of
  elastic and viscous forces during the preparation of the packings"; see also
  [Santos2024].

## 8. Damping

Damping sets how damped molecular dynamics (`DampedMD`) removes energy. FIRE removes
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
DampedMD(
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
  settings take the same values as for `DampedMD`.

### Options

Every option below is a setting of `pack()`; any of them combines with any algorithm,
contact law and friction model.

| Option | Setting | Used by |
|---|---|---|
| Any other contact damping ratios | `ContactDamping(normal = ζn, tangential = ζt)` | |
| Moderate contact damping (restitution about 0.5) | `ContactDamping(normal = 0.2, tangential = 0.2)` | ζ ≈ 0.18 is our conversion of [Santos2024] |
| Normal damping only | `ContactDamping(normal = 0.98, tangential = 0)` | [Agnolin2007] |
| Tangential ratio on the pair mass | `ContactDamping(tangential_mass = :pair)` | the usual raw-coefficient convention |
| Raw damping rates instead of ratios | `ViscousRate(normal = 0.5, tangential = 0.5)` | [Santos2024], [LAMMPSgran] |
| No contact damping | `damping = nothing` | FIRE default |
| Dashpot allowed to pull | `attractive = true` | LAMMPS without `limit_damping` [LAMMPSgran] |
| Friction limit on total forces | `coulomb_limit = :total` | [LAMMPSgran] |
| Stokes drag, always on | `drag = StokesDrag(velocity = γv)` | [Shimada2026], [Xiong2019] |
| Stokes drag while compressing only | `drag = StokesDrag(velocity = γv, during = :compression)` | Leiden-style, [Somfai2007] |
| Overdamped Stokes drag | `drag = StokesDrag(velocity = γv)` with γv large compared with the soft-mode frequencies | [Xiong2019] |
| Spin drag only (for rolling) | `drag = StokesDrag(velocity = 0, spin = γs)` | |

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
  - `during = :compression`: drag on until the pressure is within `pressure_tol` of
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
**SoftPack note**: estimates, to be checked once `DampedMD` runs.

## 9. Rattler rules

**Decision.** `rattlers` takes any function of the contact network that returns a
true/false mask per particle. Built-in rules: `ContactCount()` (default),
`TwoContact()`, `ForceFloor(floor)`, `Unresolved(floor = :tol)`. Every rule takes a
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
- `ForceFloor` (contacts below floor·<f> count as broken): [Shundyak2007] "we always
  take out rattlers, by considering contact forces less than 10^-3 times the average
  force broken and removing particles with less than two contacts."
- `Unresolved` (particles whose contacts all carry less than the force tolerance):
  [Agnolin2007] "We also discard from the backbone all spheres with only forces
  smaller than the tolerance." Tying the floor to the packing's own tolerance (`floor = :tol`) is a
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
seed and RNG.

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

Two rules follow from the sources:

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
file holds only the remaining particles, with their original ids. An option writes
a second file with every particle and a rattler flag. With `rattlers = nothing`
there is one file with every particle. **SoftPack choice**.

**Movies and snapshots.** `pack()` can record snapshots during the run and render a
GIF or video from them; off by default. **SoftPack choice**.

**Formats.** HDF5 is the default. CSV is an option, for spreadsheets or reading
without an HDF5 library. MATLAB `.mat` and JLD2 are not offered: MATLAB reads HDF5
directly [MATLABh5read] and JLD2 files are HDF5 files [HDF5jl]. Extended XYZ (for
OVITO) and LAMMPS data files may be added later. **SoftPack choice.**

## 12. Time step

**Decision.** `dt` is a setting. Default: 1/50 of the shortest binary collision
time t_col = π sqrt(m_eff / k), taken over the smallest particle mass, the stiffest
contact (normal, or tangential with rotation when friction is on), and for Hertzian
contacts the stiffness at the largest overlap expected; a run-time check warns if a
contact becomes stiffer than the chosen `dt` resolves. A fixed value can be given
instead. For FIRE this is the starting step; FIRE then adapts it.

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
