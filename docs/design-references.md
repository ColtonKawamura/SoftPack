# SoftPack design decisions and their references

Every design decision for SoftPack's `pack()`, with the sources behind it. Quotes are
copied from the papers' full texts (arXiv versions); BibTeX for every key is in
[`references.bib`](references.bib). Decisions marked **SoftPack choice** have no
literature source: they are our own call, and the reason is given.

Status: design stage (no engine code yet). Last updated 2026-11-18.
The 1/50 time-step default (§12) and HDF5-default / CSV-option formats (§11) are settled.

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
- The preparation path changes frictional packings, so the algorithm is part of the
  packing's identity and is recorded in every output: [Henkes2010] the mobilized
  contact fraction is bimodal over a range of pressures "due to the interplay of
  elastic and viscous forces during the preparation of the packings"; see also
  [Santos2024].

## 8. Damping in damped dynamics (open)

**Open.** Defaults for the damped-dynamics algorithm are not decided. The Leiden
protocol is the reference point:

- [Somfai2005] contact damping "which is at every instant a given constant fraction
  of the linear critical viscous damping, both for the normal and for the
  tangential force".
- [Somfai2007] "Once a packing is made, the additional damping force is switched
  off".

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
