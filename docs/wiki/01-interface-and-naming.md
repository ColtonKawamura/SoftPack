# 1. Interface and naming

Design decision source: [design-references.md §1](../design-references.md#1-interface-and-naming).
Status: design stage (no engine code yet).

## Summary

`pack()` runs with no arguments: every setting has a default
([§0](00-every-default-at-a-glance.md)). Settings are changed with keywords, or
collected in a reusable `PackParams` value. A setting that has its own sub-settings is
a small type (`Pressure`, `FIRE`, `CundallStrack`, ...), so algorithms, force laws and
rules are swapped by passing a different type, and Julia's dispatch picks the code
that goes with it. Names follow the Julia style guide: CamelCase types, snake_case
functions and keywords, `!` for functions that change an argument. Keywords are full
English words, never a paper's symbol or an abbreviation, and multi-word keywords put
the object first and its property second (`timestep_max`, read as timestep.max).
Functions start with a verb (`find_rattlers`, `write_packing`).

## Settings

| Form | Example | Details |
|---|---|---|
| No arguments | `pack()` | [Every default](#every-default-pack) |
| Keywords | `pack(particles_count = 2000, target = Pressure(1e-4))` | [Keywords](#keywords) |
| A reusable value | `pack(params)`, with `params` a `PackParams` | [PackParams](#a-reusable-packparams-value) |
| Typed sub-settings | `pack(algorithm = FIRE(timestep_max = 10))` | [Types and dispatch](#types-and-dispatch) |

## Model

### The public functions

| Function | What it does | Section |
|---|---|---|
| `pack(; settings...)`, `pack(params)` | makes a packing and returns a `Packing` | §1, [§2](02-default-packing.md) |
| `write_packing(path, packing; rattlers_file, compression)` | writes a `Packing` to a file | [§11](11-outputs.md) |
| `find_rattlers(packing, rule)` | applies a rattler rule to a finished packing | [§9](09-rattler-rules.md) |

`pack(restart_packing = path)` continues a run from a file written by
`write_packing` ([§6](06-packing-that-does-not-converge.md)).

### The setting types

Each row is one role. The first type is the default; the others are options. "Any
function" means a user function can take the place of a type.

| Keyword | Types | Section |
|---|---|---|
| `particles_size_distribution` | `Bidisperse`, `UniformPolydisperse`, `Monodisperse` | [§3](03-particle-size-distribution-and-length-unit.md) |
| `contact` | `Hookean`, `Hertzian` | [§2](02-default-packing.md) |
| `friction` | `nothing`, `CundallStrack`, `Mindlin` | [§13](13-friction-models.md) |
| `mass` | `EqualMass`, `Density` | [§4](04-mass.md) |
| `target` | `Pressure` | [§2](02-default-packing.md) |
| `convergence` | `RelativeForce`, `LeidenAcceleration`, `KineticEnergy`, `RestartTest`, any function | [§5](05-convergence-criterion.md) |
| `restart_file` | `nothing`, `RestartFile` | [§6](06-packing-that-does-not-converge.md) |
| `algorithm` | `FIRE`, `DampedDynamics` | [§7](07-algorithms-and-combinations.md), [§14](14-fire-settings.md) |
| `timestep` | `CollisionTime`, or a number | [§12](12-time-step.md) |
| `damping` (inside the algorithm) | `ContactDamping`, `ViscousRate`, `RelativeVelocityDamping`, `nothing` | [§8](08-damping.md) |
| `drag` (inside the algorithm) | `nothing`, `StokesDrag` | [§8](08-damping.md) |
| `rattlers` | `ContactCount`, `TwoContact`, `ForceFloor`, `Unresolved`, `nothing`, any function | [§9](09-rattler-rules.md) |
| `snapshots`, `movie` | `nothing`, `Snapshots`, `Movie` | [§11](11-outputs.md) |

The result types are `Packing` (what `pack()` returns, [§11](11-outputs.md)) and
`PackParams` (a set of settings, this page).

### Types and dispatch

Julia chooses which method of a function runs from the types of all its arguments
(multiple dispatch). A setting type is a small struct holding that setting's own
values; code inside `pack()` calls generic functions, and the type of the setting
selects the method. Adding a contact law, a friction model or a rule means adding a
type and its methods, without touching the others. This is what allows every
combination of algorithm, contact law, friction model, target, convergence test and
rattler rule in one `pack()` ([§7](07-algorithms-and-combinations.md)).

An illustration of the mechanism, not SoftPack code (SoftPack's internal function
names are not designed). It uses the two contact laws of [§2](02-default-packing.md),
$f = k\,\delta^{\alpha-1}$ with $\alpha = 2$ (Hookean) and $\alpha = 5/2$ (Hertzian):

```julia
# Illustration only: how dispatch selects a force law.
abstract type ContactLaw end
struct Hookean <: ContactLaw
    stiffness::Float64
end
struct Hertzian <: ContactLaw
    stiffness::Float64
end
Hookean(; stiffness = 1.0) = Hookean(stiffness)
Hertzian(; stiffness = 1.0) = Hertzian(stiffness)

normal_force(law::Hookean, overlap) = law.stiffness * overlap          # k δ
normal_force(law::Hertzian, overlap) = law.stiffness * overlap^(3 / 2) # k δ^{3/2}

normal_force(Hookean(), 1e-4)   # 1.0e-4
normal_force(Hertzian(), 1e-4)  # 1.0e-6
```

The code runs as shown (checked in Julia 1.12.7). **SoftPack note.**

## Defaults and their reasons

### Every default (`pack()`)

```julia
pack()                                                  # every default
pack(particles_count = 2000, target = Pressure(1e-4))   # keywords
pack(params)                                            # a reusable PackParams value
```

**Decision.** `pack()` runs with no arguments. Settings are keywords or a reusable
`PackParams` value.

- **SoftPack choice.** A first run needs no setup, and every default has a reason
  ([§0](00-every-default-at-a-glance.md)). The explicit call that `pack()` stands for is
  written out on the [§0 page](00-every-default-at-a-glance.md#the-default-packing-in-one-call).

### Keywords

**Decision.** Each setting is a keyword argument of `pack()`, with the names of
[§0](00-every-default-at-a-glance.md). A keyword left out keeps its default.

- **SoftPack choice.** Keywords document themselves at the call site, and their order
  does not matter.

### A reusable `PackParams` value

**Decision.** The same settings can be collected in a `PackParams` value and passed as
`pack(params)`, so one set of settings can be reused for many runs (for example, many
seeds).

- **SoftPack choice.** How a `PackParams` is built and whether keywords can be added
  to `pack(params)` are not specified ([Open questions](#open-questions)).

### Types and dispatch

**Decision.** Any setting with its own sub-settings is a small type (`Pressure`,
`FIRE`, `CundallStrack`, ...), so algorithms, force laws and rules can be swapped by
dispatch.

- **SoftPack choice.** Sub-settings stay with their owner:
  `FIRE(timestep_max = 10)` cannot be confused with a `DampedDynamics` setting, and
  options that do not apply (a FIRE parameter under damped dynamics) cannot be given.

### Julia style

**Decision.** CamelCase types, snake_case functions and keywords, `!` for functions
that mutate an argument.

- [JuliaStyle] "modules and type names use capitalization and camel case"
- [JuliaStyle] "Function names should be written in snake case"
- The `!` convention, [JuliaStyle] "Append ! to names of functions that modify their
  arguments".

### Full words, no abbreviations

**Decision.** Keywords are full English words: `friction_coefficient`, not `mu` or
`friction_coeff`.

- [JuliaStyle] "conciseness is valued, but avoid abbreviation (indexin rather than
  indxin) as it becomes difficult to remember whether and how particular words are
  abbreviated." (coef or coeff?)

### No symbols from a paper's notation

**Decision.** No keyword is a symbol from one paper's notation.

- Papers name the same quantity differently. [Santos2024] "the tangential forces are
  referred to by the letter 's' to indicate that we include sliding friction between
  the particles", where [Silbert2001] write $k_t$ and $\gamma_t$ for the same springs
  and dashpots; LAMMPS calls the friction coefficient `xmu` [LAMMPSgran].
  **SoftPack choice.**
- The same letter also means different things in different sources. In SoftPack's
  own pages $\gamma$ is a dashpot coefficient, while [Silbert2001], [Santos2024] and
  LAMMPS use it for a rate ([notation](notation.md)); $\alpha$ is both the contact-law
  exponent and FIRE's mixing coefficient ([§14](14-fire-settings.md)). Keywords spelled
  as words avoid the clash: `stiffness`, `rate`, `mixing_coefficient`.

### Object first, then property

**Decision.** Multi-word keywords read like `Object.member`, the thing first and then
its property: `friction_coefficient` (friction.coefficient), `particles_count`,
`timestep_max`.

- **SoftPack choice**, so a keyword reads like a struct field (`timestep_max` as
  timestep.max) and related settings sit together when sorted:
  `timestep_max`, `timestep_min`, `timestep_grow`, `timestep_shrink`;
  `particles_count`, `particles_diameters`, `particles_size_distribution`.

### Functions start with a verb

**Decision.** Functions keep verb-first names: `find_rattlers`, `write_packing`.

- [JuliaStyle] "Function names should be written in snake case (minimum, count_zeros,
  escape_string)." The examples are verbs or verb phrases.

## Options

The interface itself has no options. Every setting's options are on its own page; the
full list is on [§0](00-every-default-at-a-glance.md).

## Worked numbers

Every keyword in the design doc, checked against the naming rules. The scan collected
every `name = value` in the doc's code and flagged one- or two-letter names and names
that start with `max_`, `min_`, `on_`, `with_`, `n_`, `k_`, `dt`, `tol` or `mu`. None was
flagged. **SoftPack note.**

| Object (prefix) | Keywords |
|---|---|
| particles | `particles_count`, `particles_diameters`, `particles_size_distribution` |
| timestep | `timestep`, `timestep_max`, `timestep_min`, `timestep_grow`, `timestep_shrink` |
| mixing (FIRE) | `mixing_coefficient`, `mixing_shrink` |
| delay (FIRE) | `delay`, `delay_initial` |
| diameter (size distributions) | `diameter`, `diameter_small`, `diameter_ratio`, `diameter_mean` |
| fraction | `fraction` (`CollisionTime`), `fraction_small` (`Bidisperse`) |
| friction | `friction`, `friction_coefficient` |
| stiffness | `stiffness`, `stiffness_ratio` |
| restart | `restart_packing`, `restart_file` |
| rattlers | `rattlers`, `rattlers_file` |
| steps, pressure, failure | `steps_max`, `pressure_tolerance`, `failure_action` |
| one word | `dimension`, `contact`, `mass`, `target`, `convergence`, `algorithm`, `damping`, `drag`, `seed`, `snapshots`, `movie`, `compression`, `tolerance`, `floor`, `rate`, `normal`, `tangential`, `velocity`, `spin`, `during`, `every`, `shape`, `spread`, `integrator`, `attractive` |
| other two-word | `poisson_ratio`, `tangential_mass`, `coulomb_limit`, `cone_test`, `uphill_max`, `inertia_correction` |

Symbol values follow the same rules: `:semi_implicit_euler`, `:velocity_verlet`,
`:with_rotation`, `:matched`, `:elastic`, `:total`, `:pair`, `:always`, `:compression`,
`:warn`, `:error`, `:tolerance`, `:gzip`, `:disc`, `:sphere`. `:with_rotation` starts
with `with_` but is a value, not a keyword. `:disc` follows LAMMPS's `density/disc`
[LAMMPSset]; the doc's prose says "disks".

## Open questions

- **`PackParams`.** How it is constructed (`PackParams(; settings...)` with the same
  keywords is the natural form, but not stated), whether it can be changed after
  construction, and whether `pack(params; seed = 2)` may override single settings.
- **User functions.** `convergence` accepts "any function of the packing state that
  returns true when done" ([§5](05-convergence-criterion.md)) and `rattlers` "any
  function of the contact network that returns a true/false mask per particle"
  ([§9](09-rattler-rules.md)). The arguments those functions receive are not designed.
- **Positional values.** `EqualMass(1.0)`, `Pressure(1e-4)` and `Density(1.0; ...)` take
  their main value by position, while most types take keywords. Whether the keyword
  form (for example `Pressure(value = 1e-4)`) is also accepted is not specified.

## Related pages

- [§0 Every default at a glance](00-every-default-at-a-glance.md): every keyword and
  its default.
- [§7 Algorithms and combinations](07-algorithms-and-combinations.md): why every
  combination of types must work.
- [§14 FIRE settings](14-fire-settings.md): the FIRE keywords.
- [Notation](notation.md), [References](references.md).

## References

- **[JuliaStyle]** The Julia Project. *Style Guide, The Julia Language manual*. <https://docs.julialang.org/en/v1/manual/style-guide/>. Accessed 2026-11-18.
- **[LAMMPSgran]** LAMMPS developers. *LAMMPS documentation: pair_style gran/hooke, gran/hooke/history, gran/hertz/history*. <https://docs.lammps.org/pair_gran.html>. Accessed 2026-11-18.
- **[LAMMPSset]** LAMMPS developers. *LAMMPS documentation: set command*. <https://docs.lammps.org/set.html>. Accessed 2026-11-18.
- **[Santos2024]** A. P. Santos, Ishan Srivastava, Leonardo E. Silbert, Jeremy B. Lechman, Gary S. Grest (2024). *Protocol-dependent frictional granular jamming simulations: cyclical, compression, and expansion*. Frontiers in Soft Matter **3**, 1326756. [doi:10.3389/frsfm.2023.1326756](https://doi.org/10.3389/frsfm.2023.1326756).
- **[Silbert2001]** Leonardo E. Silbert, Deniz Ertaş, Gary S. Grest, Thomas C. Halsey, Dov Levine, Steven J. Plimpton (2001). *Granular flow down an inclined plane: Bagnold scaling and rheology*. Physical Review E **64**, 051302. [doi:10.1103/physreve.64.051302](https://doi.org/10.1103/physreve.64.051302).
