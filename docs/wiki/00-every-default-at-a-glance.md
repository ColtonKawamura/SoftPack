# 0. Every default at a glance

Design decision source: [design-references.md §0](../design-references.md#0-every-default-at-a-glance).
Status: design stage (no engine code yet).

## Summary

`pack()` with no arguments makes a 2D packing of 256 frictionless Hookean disks, a
50:50 bidisperse mixture with diameter ratio 1.4, compressed with FIRE to the pressure
$P = 10^{-4}$, with rattlers removed. Every setting below has a default and a reason.
This page lists them all in one place: the default, what it means as an equation, the
other choices, the main source, and the wiki section that explains it. Sources are
cited by key and listed in full at the end; **SoftPack choice** marks a default with no
literature source.

Units throughout: small diameter $d = 1$, contact stiffness $k = 1$, particle mass
$m = 1$, so lengths are in $d$, forces in $k\,d$ (Hookean), pressures in $k\,d^{2-D}$
and times in $\tau = \sqrt{m/k}$ ([§2](02-default-packing.md#units),
[§4](04-mass.md#time-unit-and-contact-time-scales)). Symbols are defined in
[notation.md](notation.md).

## The default packing in one call

Every default written out:

```julia
pack(
    dimension                   = 2,
    particles_count             = 256,
    particles_size_distribution = Bidisperse(diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5),
    particles_diameters         = nothing,
    contact                     = Hookean(stiffness = 1.0),
    friction                    = nothing,
    mass                        = EqualMass(1.0),
    target                      = Pressure(1e-4),
    convergence                 = RelativeForce(tolerance = 1e-8),
    pressure_tolerance          = 1e-4,
    steps_max                   = 10^7,
    failure_action              = :warn,
    restart_packing             = nothing,
    restart_file                = nothing,
    algorithm                   = FIRE(),          # LAMMPS FIRE 2.0 defaults, no damping, no drag
    timestep                    = CollisionTime(fraction = 1/50),
    rattlers                    = ContactCount(cone_test = true),
    seed                        = 1,
    snapshots                   = nothing,
    movie                       = nothing,
)
```

and, for files, `write_packing(path, packing; rattlers_file = false, compression = nothing)`,
which writes HDF5 ([§11](11-outputs.md#file-format-hdf5)).

## Particles and contacts

| Setting | Default | Meaning | Other choices | Main source | Details |
|---|---|---|---|---|---|
| `dimension` | `2` | disks, $D = 2$ | `3` (spheres) | **SoftPack choice** | [§2](02-default-packing.md#two-dimensions) |
| `particles_count` | `256` | $N = 256$ | any $N \ge 2$ | **SoftPack choice** | [§2](02-default-packing.md#256-particles) |
| `particles_size_distribution` | `Bidisperse(diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5)` | half the particles have $d = 1$, half $1.4\,d$ | `UniformPolydisperse(diameter_mean = 1.0, spread = 0.2)`: $d_i$ uniform on $[0.8, 1.2]$; `Monodisperse(diameter = 1.0)` | [OHern2003]; [Somfai2005] for the uniform law | [§3](03-particle-size-distribution-and-length-unit.md#bidisperse-default) |
| `particles_diameters` | `nothing` | diameters drawn from the distribution | a vector, one diameter per particle | **SoftPack choice** | [§3](03-particle-size-distribution-and-length-unit.md#given-diameters) |
| `contact` | `Hookean(stiffness = 1.0)` | $U(\delta) = \tfrac12 k\delta^2$, $f = k\delta$ while the overlap $\delta > 0$ | `Hertzian(stiffness = 1.0)`: $U = \tfrac25 k\delta^{5/2}$, $f = k\delta^{3/2}$ | [OHern2003] | [§2](02-default-packing.md#hookean-contacts) |
| `friction` | `nothing` | frictionless: normal forces only | `CundallStrack`, `Mindlin` (next table) | **SoftPack choice** | [§2](02-default-packing.md#frictionless-contacts), [§13](13-friction-models.md) |
| `mass` | `EqualMass(1.0)` | $m_i = 1$ for every particle | `Density(1.0; shape = :disc)`: $m_i = \rho\,\pi d_i^2/4$ (`:sphere` in 3D: $\rho\,\pi d_i^3/6$) | **SoftPack choice**; [LAMMPSset] for density masses | [§4](04-mass.md#equal-masses) |
| `target` | `Pressure(1e-4)` | $P = \dfrac{1}{D\,\Omega}\sum_{c} \mathbf f^{c}\cdot\boldsymbol\ell^{c} = 10^{-4}$ ($\boldsymbol\ell^c$ the branch vector, $\Omega$ the box area or volume), elastic forces only | any pressure | [Agnolin2007] (stress formula) | [§2](02-default-packing.md#target-pressure) |

With friction on, the friction models' own defaults:

| Setting | Default | Meaning | Main source | Details |
|---|---|---|---|---|
| `CundallStrack(friction_coefficient = 0.5, stiffness_ratio = :matched)` | $\mu = 0.5$, $k_t/k_n = 1/(1 + mR^2/I)$ | linear tangential spring capped at $\lvert F_t^\text{el}\rvert \le \mu F_n^\text{el}$; $k_t/k_n = 1/3$ for disks, $2/7$ for spheres | [Somfai2005], [Silbert2001]; [Santos2024] for the model | [§13](13-friction-models.md) |
| `Mindlin(friction_coefficient = 0.5, poisson_ratio = 0.0)` | $\mu = 0.5$, $\nu = 0$ | Hertz–Mindlin tangential force (needs `Hertzian`); $\nu = 0$ gives $k_t = k_n$ | [Somfai2005], [Shundyak2007] | [§13](13-friction-models.md) |

## Stopping, failure and restarts

| Setting | Default | Meaning | Other choices | Main source | Details |
|---|---|---|---|---|---|
| `convergence` | `RelativeForce(tolerance = 1e-8)` | $\max_i \lvert\mathbf F_i\rvert < \epsilon_F\langle f_n\rangle$ and, with friction, $\max_i \lvert\mathbf T_i\rvert < \epsilon_F\langle f_n\rangle\langle d\rangle$, with $\epsilon_F = 10^{-8}$ | `LeidenAcceleration(tolerance = 1e-10)`, `KineticEnergy(tolerance = 1e-8)`, `RestartTest()`, any function | [Agnolin2007], [Gilabert2007] | [§5](05-convergence-criterion.md#force-and-torque-test-relativeforce) |
| `pressure_tolerance` | `1e-4` | $\lvert P - P_\text{target}\rvert \le \epsilon_P P_\text{target}$, $\epsilon_P = 10^{-4}$ | any value | [Agnolin2007] | [§5](05-convergence-criterion.md#pressure-test-pressure_tolerance) |
| `steps_max` | `10^7` | at most $10^7$ steps per call | any value | **SoftPack choice** | [§5](05-convergence-criterion.md#step-cap-steps_max) |
| `failure_action` | `:warn` | warn and return the packing with `converged = false` | `:error` | **SoftPack choice** | [§6](06-packing-that-does-not-converge.md) |
| `restart_packing` | `nothing` | start from scratch | path to a file written by `write_packing` | [LAMMPSreadrestart] (precedent) | [§6](06-packing-that-does-not-converge.md) |
| `restart_file` | `nothing` | no state saved during the run | `RestartFile(path; every = interval)`, `every` required | [LAMMPSrestart] (precedent) | [§6](06-packing-that-does-not-converge.md) |

The options' own defaults: `LeidenAcceleration` from [Somfai2005], `KineticEnergy`
(mean kinetic energy per particle below $\epsilon_K P d^D$) from [Agnolin2007] and
[Xiong2019], `RestartTest` (zero the velocities, check the forces do not grow back)
from [Agnolin2007] ([§5](05-convergence-criterion.md#options)).

## Algorithm and time step

| Setting | Default | Meaning | Other choices | Main source | Details |
|---|---|---|---|---|---|
| `algorithm` | `FIRE()` | FIRE 2.0 minimization with the LAMMPS defaults (next table) | `DampedDynamics()`: $\mathbf M\ddot{\mathbf r} = \mathbf F(\mathbf r) - \boldsymbol\Gamma\dot{\mathbf r}$ | [Bitzek2006], [Guenole2020] | [§2](02-default-packing.md#fire), [§7](07-algorithms-and-combinations.md), [§14](14-fire-settings.md) |
| `timestep` | `CollisionTime(fraction = 1/50)` | $\Delta t = t_\text{col}/50$, with $t_\text{col} = \pi\sqrt{M_n/k_n}$ for the lightest pair and stiffest contact (undamped Hooke) | any fraction, or a fixed number | [Silbert2001] | [§12](12-time-step.md#collisiontime-default) |

FIRE's parameters ([§14](14-fire-settings.md)), all from the LAMMPS FIRE 2.0 defaults
in [Guenole2020] (Table 1), with $\Delta t_\text{start}$ the step from `timestep`:

| `FIRE` setting | Default | Meaning | Details |
|---|---|---|---|
| `timestep_max` | `10` | $\Delta t_\text{max} = 10\,\Delta t_\text{start}$ | [§14](14-fire-settings.md#largest-step-timestep_max) |
| `timestep_min` | `0.02` | $\Delta t_\text{min} = 0.02\,\Delta t_\text{start}$ | [§14](14-fire-settings.md#smallest-step-timestep_min) |
| `delay` | `20` | $N_\text{delay} = 20$ downhill steps before the step may grow | [§14](14-fire-settings.md#delay-delay) |
| `timestep_grow` | `1.1` | $\Delta t \leftarrow \min(1.1\,\Delta t, \Delta t_\text{max})$ | [§14](14-fire-settings.md#growth-and-shrink-factors) |
| `timestep_shrink` | `0.5` | $\Delta t \leftarrow 0.5\,\Delta t$ after an uphill move, if that stays $\ge \Delta t_\text{min}$ | [§14](14-fire-settings.md#growth-and-shrink-factors) |
| `mixing_coefficient` | `0.25` | $\alpha_\text{start} = 0.25$ in $\mathbf v \leftarrow (1-\alpha)\mathbf v + \alpha\lvert\mathbf v\rvert\hat{\mathbf F}$ | [§14](14-fire-settings.md#mixing-coefficient-and-its-shrink-factor) |
| `mixing_shrink` | `0.99` | $\alpha \leftarrow 0.99\,\alpha$ on each growth step | [§14](14-fire-settings.md#mixing-coefficient-and-its-shrink-factor) |
| `uphill_max` | `2000` | stop, unconverged, after 2000 consecutive uphill moves | [§14](14-fire-settings.md#uphill-limit-uphill_max) |
| `inertia_correction` | `true` | move back half a step after an uphill move (LAMMPS `halfstepback`) | [§14](14-fire-settings.md#half-step-back-inertia_correction) |
| `delay_initial` | `true` | apply the delay at the start of the run too | [§14](14-fire-settings.md#initial-delay-delay_initial) |
| `integrator` | `:semi_implicit_euler` | semi-implicit (symplectic) Euler; `:velocity_verlet` is the option | [§14](14-fire-settings.md#integrator-integrator) |
| `damping`, `drag` | `nothing`, `nothing` | FIRE removes energy by its own velocity rules | [§8](08-damping.md#fire-no-damping) |

## Damping (damped dynamics)

| Setting | Default | Meaning | Main source | Details |
|---|---|---|---|---|
| `damping` | `ContactDamping(normal = 0.98, tangential = 0.98)` | $\gamma_n = 0.98 \cdot 2\sqrt{k_n M_n}$, $\gamma_t = 0.98 \cdot 2\sqrt{k_t M_t}$ | [Agnolin2007] (0.98), [Gilabert2007] (ratio form), [Somfai2005] (both directions) | [§8](08-damping.md#normal-ratio-098), [§8](08-damping.md#tangential-ratio-098) |
| `tangential_mass` | `:with_rotation` | $1/M_t = 1/m_i + 1/m_j + R_i^2/I_i + R_j^2/I_j$ ($M_t = M_n/3$ for equal disks) | **SoftPack choice** | [§8](08-damping.md#tangential-critical-value-on-the-sliding-mass) |
| `attractive` | `false` | $F_n = \max(0,\, k_n\delta - \gamma_n v_n)$ | [Somfai2005], [LAMMPSgran] | [§8](08-damping.md#dashpots-never-pull) |
| `coulomb_limit` | `:elastic` | $\lvert F_t^\text{el}\rvert \le \mu F_n^\text{el}$; tangential dashpot off while sliding | [Agnolin2007] | [§8](08-damping.md#friction-limit-on-spring-forces) |
| `drag` | `nothing` | no Stokes drag ($a = 0$ in $\boldsymbol\Gamma = a\mathbf M + b\mathbf K_0$) | **SoftPack choice** | [§8](08-damping.md#no-stokes-drag) |

With these defaults and Hookean contacts the damping is exactly stiffness-proportional,
$\boldsymbol\Gamma = b\,\mathbf K_0$ with $b = 2\zeta/\omega_c$, so every underdamped mode
decays at $\beta_\ell = b\,\omega_\ell^2/2$
([§8](08-damping.md#6-when-contactdamping-is-exactly-stiffness-proportional)).

The options' own defaults: `ViscousRate(normal = 0.5, tangential = 0.5)`, rates
$r = 0.5/\tau$ with $\gamma = m_\text{eff}\,r$ [Santos2024];
`RelativeVelocityDamping(rate = 0.5)`, $\mathbf F_{ij} = -\gamma(\mathbf v_i - \mathbf v_j)$
(the CD model of [Vagberg2014]); `StokesDrag(velocity = rate)`, $\mathbf F = -a_v m\mathbf v$,
with no default rate ([§8](08-damping.md#options)).

## Rattlers

| Setting | Default | Meaning | Other choices | Main source | Details |
|---|---|---|---|---|---|
| `rattlers` | `ContactCount(cone_test = true)` | repeatedly remove particles with fewer than $D + 1$ contacts (frictionless) or fewer than 2 (frictional); with the cone test, also remove two-contact particles that cannot be in balance | `TwoContact()`, `ForceFloor(floor = 1e-3)`, `Unresolved(floor = :tolerance)`, `nothing`, any function | [Xiong2019], [Gilabert2007] | [§9](09-rattler-rules.md#contactcount-default), [§9](09-rattler-rules.md#cone-test) |

The options' sources: `TwoContact` [Ishima2023], `ForceFloor` [Shundyak2007],
`Unresolved` [Agnolin2007] ([§9](09-rattler-rules.md#options)).

## Reproducibility and outputs

| Setting | Default | Meaning | Other choices | Main source | Details |
|---|---|---|---|---|---|
| `seed` | `1` | random numbers from `StableRNG(1)`, the same stream on every machine and Julia version | any integer (`StableRNG` accepts $0 \le \text{seed} \le 2^{64} - 1$) | **SoftPack choice** (value); [StableRNGs], [JuliaRandom] (generator) | [§10](10-reproducibility.md#seed-seed) |
| file format (`write_packing`) | HDF5 | one binary file, read natively by Julia, Python and MATLAB | CSV | [HDF5jl], [h5py], [MATLABh5read] | [§11](11-outputs.md#file-format-hdf5) |
| `write_packing` `rattlers_file` | `false` | the file holds the packing without rattlers only | `true`: a second file with every particle | **SoftPack choice** | [§11](11-outputs.md#rattlers-file-rattlers_file) |
| `write_packing` `compression` | `nothing` | uncompressed, so datasets can be memory-mapped | `:gzip` (level 4) | [HDF5jl], [h5py] | [§11](11-outputs.md#compression-compression) |
| `snapshots`, `movie` | `nothing`, `nothing` | nothing recorded during the run | `Snapshots(every = interval)`, `Movie(path; every = interval)` | **SoftPack choice** | [§11](11-outputs.md#snapshots-and-movie) |

## Not designed yet

How `pack()` reaches the target pressure (the initial state and the compression
protocol) is the one part of the design with no default yet
([design doc, status line](../design-references.md)).

## Related pages

- [README](README.md): the index of every page.
- [§1 Interface and naming](01-interface-and-naming.md): how settings are passed.
- [Notation](notation.md) and [References](references.md).

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
