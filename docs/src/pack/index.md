# Creating a packing with `pack()`

Design decision source: [design-references.md §0](https://github.com/ColtonKawamura/SoftPack/blob/main/docs/design-references.md#0-every-default-at-a-glance).
Status: design stage. The engine implements the default frictionless path (see the README).

## Summary

`pack()` with no arguments makes a 2D packing of 256 frictionless Hookean disks, a
50:50 bidisperse mixture with diameter ratio 1.4, compressed with FIRE to the pressure
$P = 10^{-4}$, with rattlers removed. It starts from random, non-touching particles at
packing fraction 0.25 in a periodic box and shrinks the box isotropically until the
pressure reaches the target. Every setting below has a default and a reason.
This page lists them all in one place: the default, what it means as an equation, the
other choices, the main source, and the wiki section that explains it. Sources are
cited by key and listed in full at the end; **SoftPack choice** marks a default with no
literature source.

Units throughout: reference diameter $d_\text{ref} = 1$ (the small diameter of the default mixture), contact stiffness $k = 1$, reference mass
$m_\text{ref} = 1$, so lengths are in $d$, forces in $k\,d$ (Hookean), pressures in $k\,d^{2-D}$
and times in $\tau = \sqrt{m_\text{ref}/k}$ ([Units and length unit](../reference/units.md)). Symbols are defined in
[Notation](../reference/notation.md).

## The default packing in one call

Every default written out:

```julia
pack(                                                                # run the packing with every default written out
    dimension                   = 2,                                 # 2D packing of disks (use 3 for spheres)
    particles_count             = 256,                               # number of particles
    particles_size_distribution = Bidisperse(                        # two-diameter mixture
        diameter_small = 1.0,                                        # small diameter; the length unit
        diameter_ratio = 1.4,                                        # large diameter divided by small diameter
        fraction_small = 0.5                                         # number fraction of small particles (50:50)
    ),                                                               # end of Bidisperse call
    particles_diameters         = nothing,                           # draw diameters from the distribution, not an explicit list
    contact                     = Hookean(stiffness = 1.0),          # Hookean contact law, stiffness k = 1
    friction                    = nothing,                           # frictionless contacts
    mass                        = EqualMass(1.0),                    # every particle has mass 1
    target                      = Pressure(1e-4),                    # compress until the contact pressure reaches 1e-4
    boundary                    = Periodic(),                        # periodic square (2D) or cube (3D) box
    initial_state               = Dilute(packing_fraction = 0.25),   # random start at packing fraction 0.25, no particles touching
    protocol                    = IsotropicCompression(              # shrink the box in isotropic steps
        strain_step = 1e-2                                           # the box side shrinks by 1% in the first step
    ),                                                               # end of IsotropicCompression call
    convergence                 = RelativeForce(tolerance = 1e-8),   # stop when net forces are below 1e-8 of the mean contact force
    pressure_tolerance          = 1e-4,                              # relative pressure tolerance
    steps_max                   = 10^7,                              # maximum number of steps per call
    failure_action              = :warn,                             # warn and return the packing if not converged
    restart_packing             = nothing,                           # start a fresh run, no restart
    restart_file                = nothing,                           # no periodic saves during the run
    algorithm                   = FIRE(),                            # FIRE with LAMMPS FIRE 2.0 defaults, no damping, no drag
    timestep                    = CollisionTime(fraction = 1/50),    # time step is 1/50 of the collision time
    rattlers                    = ContactCount(cone_test = true),    # remove particles with too few contacts, cone test on
    seed                        = 1,                                 # random seed
    snapshots                   = nothing,                           # no snapshots recorded
    movie                       = nothing,                           # no movie rendered
)                                                                    # end of pack call
```

and, for files, `write_packing(path, packing; rattlers_file = false, compression = nothing, overwrite = false)`,
which writes HDF5 ([file format](../write_packing/path.md)).

- `pack(...)` — runs the packing with every default written out.
- Each keyword is explained in the tables below: its default, meaning, other choices, main source and a link to the section with the reasons.
  - Particles, contacts, mass and target: [Particles and contacts](#Particles-and-contacts).
  - Box, start and compression: [Box, start and compression](#Box,-start-and-compression).
  - Convergence, failure and restarts: [Stopping, failure and restarts](#Stopping,-failure-and-restarts).
  - Algorithm and time step: [Algorithm and time step](#Algorithm-and-time-step).
  - Damped dynamics: [Damping (damped dynamics)](#Damping-(damped-dynamics)).
  - Rattlers: [Rattlers](#Rattlers).
  - Seed and outputs: [Reproducibility and outputs](#Reproducibility-and-outputs).
- `write_packing(path, packing; rattlers_file = false, compression = nothing, overwrite = false)` — the file call, written with its defaults ([file format](../write_packing/path.md)).
  - `rattlers_file = false` — write only the remaining particles ([rattlers_file](../write_packing/rattlers_file.md)).
  - `compression = nothing` — leave the datasets uncompressed ([compression](../write_packing/compression.md)).
  - `overwrite = false` — stop with an error if a file already exists ([overwrite](../write_packing/overwrite.md)).

## Three ways to call `pack()`

```julia
pack()                                                  # every default
pack(particles_count = 2000, target = Pressure(1e-4))   # keywords
pack(params)                                            # a reusable PackParams value
```

- `pack()` — runs with every default.
- `pack(particles_count = 2000, target = Pressure(1e-4))` — runs with the keywords you pass, and every keyword you leave out keeps its default.
- `pack(params)` — runs with a reusable settings value, described on [the PackParams page](PackParams.md).
- `pack()` returns a `Packing`, described on [the Packing page](Packing.md).

## Where next

- [Available options](options/index.md): every keyword of `pack()` in one place, one link each, with the choices of each keyword.
- [`write_packing()`](../write_packing/index.md): saving the packing that `pack()` returns.
- [Theory pages](../reference/theory.md): the models, derivations and worked numbers behind the defaults.


## Particles and contacts

| Setting | Default | Meaning | Other choices | Main source | Details |
|:---|:---|:---|:---|:---|:---|
| `dimension` | `2` | disks, $D = 2$ | `3` (spheres) | **SoftPack choice** | [`dimension`](options/dimension.md) |
| `particles_count` | `256` | $N = 256$ | any $N \ge 2$ | **SoftPack choice** | [`particles_count`](options/particles_count.md) |
| `particles_size_distribution` | `Bidisperse(diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5)` | half the particles have $d = 1$, half $1.4\,d$ | `UniformPolydisperse(diameter_mean = 1.0, spread = 0.2)`: $d_i$ uniform on $[0.8, 1.2]$; `Monodisperse(diameter = 1.0)` | [OHern2003]; [Somfai2005] for the uniform law | [`particles_size_distribution`](options/particles_size_distribution/index.md) |
| `particles_diameters` | `nothing` | diameters drawn from the distribution | a vector, one diameter per particle | **SoftPack choice** | [`particles_diameters`](options/particles_diameters.md) |
| `contact` | `Hookean(stiffness = 1.0)` | $U(\delta) = \tfrac12 k\delta^2$, $f = k\delta$ while the overlap $\delta > 0$ | `Hertzian(stiffness = 1.0)`: $U = \tfrac25 k\delta^{5/2}$, $f = k\delta^{3/2}$ | [OHern2003] | [`contact`](options/contact/index.md) |
| `friction` | `nothing` | frictionless: normal forces only | `CundallStrack`, `Mindlin` (next table) | **SoftPack choice** | [`friction`](options/friction/index.md) |
| `mass` | `EqualMass(1.0)` | $m_i = 1$ for every particle | `Density(1.0)`: $m_i = \rho\,\pi d_i^2/4$ in 2D, $\rho\,\pi d_i^3/6$ in 3D | **SoftPack choice**; [LAMMPSset] for density masses | [`mass`](options/mass/index.md) |
| `target` | `Pressure(1e-4)` | $P = \dfrac{1}{D\,\Omega}\sum_{c} \mathbf f^{c}\cdot\boldsymbol\ell^{c} = 10^{-4}$ ($\boldsymbol\ell^c$ the branch vector, $\Omega$ the box area or volume), elastic forces only | any pressure | [Agnolin2007] (stress formula) | [`target`](options/target/index.md) |

With friction on, the friction models' own defaults:

| Setting | Default | Meaning | Main source | Details |
|:---|:---|:---|:---|:---|
| `CundallStrack(friction_coefficient = 0.5, stiffness_ratio = :matched)` | $\mu = 0.5$, $k_t/k_n = 1/(1 + mR^2/I)$ | linear tangential spring capped at $\lvert F_t^\text{el}\rvert \le \mu F_n^\text{el}$; $k_t/k_n = 1/3$ for disks, $2/7$ for spheres | [Somfai2005], [Silbert2001]; [Santos2024] for the model | [`CundallStrack()`](options/friction/CundallStrack.md) |
| `Mindlin(friction_coefficient = 0.5, poisson_ratio = 0.0)` | $\mu = 0.5$, $\nu = 0$ | Hertz–Mindlin tangential force (needs `Hertzian`); $\nu = 0$ gives $k_t = k_n$ | [Somfai2005], [Shundyak2007] | [`Mindlin()`](options/friction/Mindlin.md) |

## Box, start and compression

| Setting | Default | Meaning | Other choices | Main source | Details |
|:---|:---|:---|:---|:---|:---|
| `boundary` | `Periodic()` | periodic square (2D) or cube (3D) box of side $L$, every side scaled by the same factor | `Walls(friction = true)`: rigid flat walls, with the `contact` law and, when `friction` is set, its friction model; `Walls(friction = false)` for normal forces only | [Agnolin2007] (periodic cell); **SoftPack choice** (square or cube, walls) | [`boundary`](options/boundary/index.md) |
| `initial_state` | `Dilute(packing_fraction = 0.25)` | random particles at $\varphi_0 = 0.25$, at rest, placed by random sequential addition so that none touches | any $\varphi_0$ at which the particles fit | [Agnolin2007] (loose start); **SoftPack choice** (value) | [`initial_state`](options/initial_state/index.md) |
| `protocol` | `IsotropicCompression(strain_step = 1e-2)` | shrink the box by 1% per step and minimize; accept a step below the pressure band, reject and halve the step above it | any `strain_step` | **SoftPack choice** | [`protocol`](options/protocol/index.md) |

## Stopping, failure and restarts

| Setting | Default | Meaning | Other choices | Main source | Details |
|:---|:---|:---|:---|:---|:---|
| `convergence` | `RelativeForce(tolerance = 1e-8)` | $\max_i \lvert\mathbf F_i\rvert < \epsilon_F\langle f_n\rangle$ and, with friction, $\max_i \lvert\mathbf T_i\rvert < \epsilon_F\langle f_n\rangle\langle d\rangle$, with $\epsilon_F = 10^{-8}$ (the rest test only; the pressure row below applies to every option) | `LeidenAcceleration(tolerance = 1e-10)`, `KineticEnergy(tolerance = 1e-8)`, `RestartTest()`, any function | [Agnolin2007], [Gilabert2007] | [`convergence`](options/convergence/index.md) |
| `pressure_tolerance` | `1e-4` | $\lvert P - P_\text{target}\rvert \le \epsilon_P P_\text{target}$, $\epsilon_P = 10^{-4}$, checked after any `convergence` option | any value | [Agnolin2007] | [`pressure_tolerance`](options/pressure_tolerance.md) |
| `steps_max` | `10^7` | at most $10^7$ steps per call | any value | **SoftPack choice** | [`steps_max`](options/steps_max.md) |
| `failure_action` | `:warn` | warn and return the packing with `converged = false` | `:error` | **SoftPack choice** | [`failure_action`](options/failure_action.md) |
| `restart_packing` | `nothing` | start from scratch | path to a file written by `write_packing` | [LAMMPSreadrestart] (precedent) | [`restart_packing`](options/restart_packing.md) |
| `restart_file` | `nothing` | no state saved during the run | `RestartFile(path; every = interval)`, `every` required | [LAMMPSrestart] (precedent) | [`restart_file`](options/restart_file/index.md) |

The options' own defaults: `LeidenAcceleration` from [Somfai2005], `KineticEnergy`
(mean kinetic energy per particle below $\epsilon_K P d^D$) from [Agnolin2007] and
[Xiong2019], `RestartTest` (zero the velocities, check the forces do not grow back)
from [Agnolin2007] ([§5](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion#options)).

## Algorithm and time step

| Setting | Default | Meaning | Other choices | Main source | Details |
|:---|:---|:---|:---|:---|:---|
| `algorithm` | `FIRE()` | FIRE 2.0 minimization with the LAMMPS defaults (next table) | `DampedDynamics()`: $\mathbf M\ddot{\mathbf r} = \mathbf F(\mathbf r) - \boldsymbol\Gamma\dot{\mathbf r}$ | [Bitzek2006], [Guenole2020] | [`algorithm`](options/algorithm/index.md) |
| `timestep` | `CollisionTime(fraction = 1/50)` | $\Delta t = t_\text{col}/50$, with $t_\text{col} = \pi\sqrt{M_n/k_n}$ for the lightest pair and stiffest contact (undamped Hooke) | any fraction, or a fixed number | [Silbert2001] | [`timestep`](options/timestep/index.md) |

FIRE's parameters ([§14](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings)), all from the LAMMPS FIRE 2.0 defaults
in [Guenole2020] (Table 1), with $\Delta t_\text{start}$ the step from `timestep`:

| `FIRE` setting | Default | Meaning | Details |
|:---|:---|:---|:---|
| `timestep_max` | `10` | $\Delta t_\text{max} = 10\,\Delta t_\text{start}$ | [`FIRE()`](options/algorithm/FIRE.md) |
| `timestep_min` | `0.02` | $\Delta t_\text{min} = 0.02\,\Delta t_\text{start}$ | [`FIRE()`](options/algorithm/FIRE.md) |
| `delay` | `20` | $N_\text{delay} = 20$ downhill steps before the step may grow | [`FIRE()`](options/algorithm/FIRE.md) |
| `timestep_grow` | `1.1` | $\Delta t \leftarrow \min(1.1\,\Delta t, \Delta t_\text{max})$ | [`FIRE()`](options/algorithm/FIRE.md) |
| `timestep_shrink` | `0.5` | $\Delta t \leftarrow 0.5\,\Delta t$ after an uphill move, if that stays $\ge \Delta t_\text{min}$ | [`FIRE()`](options/algorithm/FIRE.md) |
| `mixing_coefficient` | `0.25` | $\alpha_\text{start} = 0.25$ in $\mathbf v \leftarrow (1-\alpha)\mathbf v + \alpha\lvert\mathbf v\rvert\hat{\mathbf F}$ | [`FIRE()`](options/algorithm/FIRE.md) |
| `mixing_shrink` | `0.99` | $\alpha \leftarrow 0.99\,\alpha$ on each growth step | [`FIRE()`](options/algorithm/FIRE.md) |
| `uphill_max` | `2000` | stop, unconverged, after 2000 consecutive uphill moves | [`FIRE()`](options/algorithm/FIRE.md) |
| `inertia_correction` | `true` | move back half a step after an uphill move (LAMMPS `halfstepback`) | [`FIRE()`](options/algorithm/FIRE.md) |
| `delay_initial` | `true` | apply the delay at the start of the run too | [`FIRE()`](options/algorithm/FIRE.md) |
| `integrator` | `:semi_implicit_euler` | semi-implicit (symplectic) Euler; `:velocity_verlet` is the option | [`FIRE()`](options/algorithm/FIRE.md) |
| `damping`, `drag` | `nothing`, `nothing` | FIRE removes energy by its own velocity rules | [`FIRE()`](options/algorithm/FIRE.md) |

## Damping (damped dynamics)

| Setting | Default | Meaning | Main source | Details |
|:---|:---|:---|:---|:---|
| `damping` | `ContactDamping(normal = 0.98, tangential = 0.98)` | $\gamma_n = 0.98 \cdot 2\sqrt{k_n M_n}$, $\gamma_t = 0.98 \cdot 2\sqrt{k_t M_t}$ | [Agnolin2007] (0.98), [Gilabert2007] (ratio form), [Somfai2005] (both directions) | [`ContactDamping()`](options/algorithm/DampedDynamics/damping/ContactDamping.md) |
| `tangential_mass` | `:with_rotation` | $1/M_t = 1/m_i + 1/m_j + R_i^2/I_i + R_j^2/I_j$ ($M_t = M_n/3$ for equal disks) | **SoftPack choice** | [`ContactDamping()`](options/algorithm/DampedDynamics/damping/ContactDamping.md) |
| `attractive` | `false` | $F_n = \max(0,\, k_n\delta - \gamma_n v_n)$ | [Somfai2005], [LAMMPSgran] | [`ContactDamping()`](options/algorithm/DampedDynamics/damping/ContactDamping.md) |
| `coulomb_limit` | `:elastic` | $\lvert F_t^\text{el}\rvert \le \mu F_n^\text{el}$; tangential dashpot off while sliding | [Agnolin2007] | [`ContactDamping()`](options/algorithm/DampedDynamics/damping/ContactDamping.md) |
| `drag` | `nothing` | no Stokes drag ($a = 0$ in $\boldsymbol\Gamma = a\mathbf M + b\mathbf K_0$) | **SoftPack choice** | [`drag`](options/algorithm/DampedDynamics/drag/index.md) |
| `integrator` | `:centered_velocity_verlet` | the dashpot uses the end-of-step velocity $\mathbf v_{n+1}$ (implicit); the options are `:lagged_velocity_verlet` ($\mathbf v_{n+1/2}$) and `:semi_implicit_euler` ($\mathbf v_n$) | **SoftPack choice** | [`integrator`](options/algorithm/DampedDynamics/integrator/index.md) |

With these defaults and Hookean contacts the damping is exactly stiffness-proportional,
$\boldsymbol\Gamma = b\,\mathbf K_0$ with $b = 2\zeta/\omega_c$, so every underdamped mode
decays at $\beta_\ell = b\,\omega_\ell^2/2$
([§8](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#6-when-contactdamping-is-exactly-stiffness-proportional)).

The options' own defaults: `ViscousRate(normal = 0.5, tangential = 0.5)`, rates
$r = 0.5/\tau$ with $\gamma = m_\text{eff}\,r$ [Santos2024];
`RelativeVelocityDamping(rate = 0.5)`, $\mathbf F_{ij} = -\gamma(\mathbf v_i - \mathbf v_j)$
(the CD model of [Vagberg2014]); `StokesDrag(velocity = rate)`, $\mathbf F = -a_v m\mathbf v$,
with no default rate ([§8](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#options)).

## Rattlers

| Setting | Default | Meaning | Other choices | Main source | Details |
|:---|:---|:---|:---|:---|:---|
| `rattlers` | `ContactCount(cone_test = true)` | repeatedly remove particles with fewer than $D + 1$ contacts (frictionless) or fewer than 2 (frictional); with the cone test, also remove two-contact particles that cannot be in balance | `TwoContact()`, `ForceFloor(floor = 1e-3)`, `Unresolved(floor = :tolerance)`, `nothing`, any function | [Xiong2019], [Gilabert2007] | [`rattlers`](options/rattlers/index.md) |

The options' sources: `TwoContact` [Ishima2023], `ForceFloor` [Shundyak2007],
`Unresolved` [Agnolin2007] ([§9](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#options)).

## Reproducibility and outputs

| Setting | Default | Meaning | Other choices | Main source | Details |
|:---|:---|:---|:---|:---|:---|
| `seed` | `1` | random numbers from `StableRNG(1)`, the same stream on every machine and Julia version | any integer (`StableRNG` accepts $0 \le \text{seed} \le 2^{64} - 1$) | **SoftPack choice** (value); [StableRNGs], [JuliaRandom] (generator) | [`seed`](options/seed.md) |
| file format (`write_packing`) | HDF5 | one binary file, read natively by Julia, Python and MATLAB | CSV | [HDF5jl], [h5py], [MATLABh5read] | [`path`](../write_packing/path.md) |
| `write_packing` `rattlers_file` | `false` | the file holds the packing without rattlers only | `true`: a second file with every particle | **SoftPack choice** | [`rattlers_file`](../write_packing/rattlers_file.md) |
| `write_packing` `compression` | `nothing` | uncompressed, so datasets can be memory-mapped | `:gzip` (level 4) | [HDF5jl], [h5py] | [`compression`](../write_packing/compression.md) |
| `write_packing` `overwrite` | `false` | an existing file stops the write with an error | `true`: replace the existing file | **SoftPack choice** | [`overwrite`](../write_packing/overwrite.md) |
| `snapshots`, `movie` | `nothing`, `nothing` | nothing recorded during the run | `Snapshots(every = interval)`, `Movie(path; every = interval)` | **SoftPack choice** | [`snapshots`](options/snapshots/index.md), [`movie`](options/movie/index.md) |

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[Bitzek2006]** Erik Bitzek, Pekka Koskinen, Franz Gähler, Michael Moseler, Peter Gumbsch (2006). *Structural Relaxation Made Simple*. Physical Review Letters **97**, 170201. [doi:10.1103/physrevlett.97.170201](https://doi.org/10.1103/physrevlett.97.170201).
- **[Gilabert2007]** F. A. Gilabert, J.-N. Roux, A. Castellanos (2007). *Computer simulation of model cohesive powders: Influence of assembling procedure and contact laws on low consolidation states*. Physical Review E **75**, 011303. [doi:10.1103/physreve.75.011303](https://doi.org/10.1103/physreve.75.011303).
- **[Guenole2020]** Julien Guénolé, Wolfram G. Nöhring, Aviral Vaid, Frédéric Houllé, Zhuocheng Xie, Aruna Prakash, Erik Bitzek (2020). *Assessment and optimization of the fast inertial relaxation engine (fire) for energy minimization in atomistic simulations and its implementation in lammps*. Computational Materials Science **175**, 109584. [doi:10.1016/j.commatsci.2020.109584](https://doi.org/10.1016/j.commatsci.2020.109584).
- **[h5py]** The h5py developers. *Datasets, h5py documentation*. <https://docs.h5py.org/en/stable/high/dataset.html>. Accessed 2026-11-18.
- **[HDF5jl]** JuliaIO. *HDF5.jl documentation*. <https://juliaio.github.io/HDF5.jl/stable/>. Accessed 2026-11-18.
- **[Ishima2023]** Daisuke Ishima, Kuniyasu Saitoh, Michio Otsuki, Hisao Hayakawa (2023). *Theory of rigidity and numerical analysis of density of states of two-dimensional amorphous solids with dispersed frictional grains in the linear response regime*. Physical Review E **107**, 054902. [doi:10.1103/physreve.107.054902](https://doi.org/10.1103/physreve.107.054902).
- **[JuliaRandom]** The Julia Project. *Random Numbers, The Julia Language manual (Reproducibility section)*. <https://docs.julialang.org/en/v1/stdlib/Random/>. Accessed 2026-11-18.
- **[LAMMPSgran]** LAMMPS developers. *LAMMPS documentation: pair_style gran/hooke, gran/hooke/history, gran/hertz/history*. <https://docs.lammps.org/pair_gran.html>. Accessed 2026-11-18.
- **[LAMMPSreadrestart]** LAMMPS developers. *LAMMPS documentation: read_restart command*. <https://docs.lammps.org/read_restart.html>. Accessed 2026-11-19.
- **[LAMMPSrestart]** LAMMPS developers. *LAMMPS documentation: restart command*. <https://docs.lammps.org/restart.html>. Accessed 2026-11-19.
- **[LAMMPSset]** LAMMPS developers. *LAMMPS documentation: set command*. <https://docs.lammps.org/set.html>. Accessed 2026-11-18.
- **[MATLABh5read]** The MathWorks. *h5read: Read data from HDF5 dataset, MATLAB documentation*. <https://www.mathworks.com/help/matlab/ref/h5read.html>. Accessed 2026-11-18.
- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
- **[Santos2024]** A. P. Santos, Ishan Srivastava, Leonardo E. Silbert, Jeremy B. Lechman, Gary S. Grest (2024). *Protocol-dependent frictional granular jamming simulations: cyclical, compression, and expansion*. Frontiers in Soft Matter **3**, 1326756. [doi:10.3389/frsfm.2023.1326756](https://doi.org/10.3389/frsfm.2023.1326756).
- **[Shundyak2007]** Kostya Shundyak, Martin van Hecke, Wim van Saarloos (2007). *Force mobilization and generalized isostaticity in jammed packings of frictional grains*. Physical Review E **75**, 010301. [doi:10.1103/physreve.75.010301](https://doi.org/10.1103/physreve.75.010301).
- **[Silbert2001]** Leonardo E. Silbert, Deniz Ertaş, Gary S. Grest, Thomas C. Halsey, Dov Levine, Steven J. Plimpton (2001). *Granular flow down an inclined plane: Bagnold scaling and rheology*. Physical Review E **64**, 051302. [doi:10.1103/physreve.64.051302](https://doi.org/10.1103/physreve.64.051302).
- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
- **[StableRNGs]** JuliaRandom. *StableRNGs.jl*. <https://github.com/JuliaRandom/StableRNGs.jl>. Accessed 2026-11-18.
- **[Vagberg2014]** Daniel Vågberg, Peter Olsson, S. Teitel (2014). *Dissipation and Rheology of Sheared Soft-Core Frictionless Disks Below Jamming*. Physical Review Letters **112**, 208303. [doi:10.1103/PhysRevLett.112.208303](https://doi.org/10.1103/PhysRevLett.112.208303). arXiv:1311.4902.
- **[Xiong2019]** Fansheng Xiong, Philip Wang, Abram H. Clark, Thibault Bertrand, Nicholas T. Ouellette, Mark D. Shattuck, Corey S. O’Hern (2019). *Comparison of shear and compression jammed packings of frictional disks*. Granular Matter **21**, 109. [doi:10.1007/s10035-019-0964-9](https://doi.org/10.1007/s10035-019-0964-9).
