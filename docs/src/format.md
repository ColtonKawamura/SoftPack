# softpack-1 format specification

**Status:** v1 · **Latest version:** `softpack-1`

The `softpack-1` format describes a single jammed packing as a folder of three
files. It is deliberately plain (CSV + TOML) so a packing can be read and written
from any language, and so every packing is self-describing: the algorithm, contact
law, stop criterion, rattler rule, seed and version are all recorded on disk.

## Layout

One folder per packing, containing exactly:

| File            | Purpose                                             |
| --------------- | --------------------------------------------------- |
| `particles.csv` | Every particle's position, size and rattler flag.   |
| `contacts.csv`  | Every pairwise contact (normal and tangential).     |
| `metadata.toml` | Machine-readable notes about the run and its output. |

## Conventions and units

- **Quantities are nondimensional.** There is no SI unit attached to the output.
- **Length unit.** Lengths are expressed in units of the mean particle radius
  `⟨R⟩ = (Σᵢ rᵢ) / N` unless the run specifies otherwise. With that convention a
  monodisperse packing of radius `r` has `⟨R⟩ = r`, so coordinates and radii are
  O(1). Overlaps are therefore also in units of `⟨R⟩`; forces and pressure are in
  units of the contact-stiffness parameter (e.g. the Hookean constant `k`).
- **Periodic box.** The domain is a cube (2D: square) with side lengths `L_d` per
  axis, with periodic boundary conditions. A coordinate `x` satisfies `0 ≤ x < L`
  (half-open interval `[0, L)`); particles are wrapped into the box.
- **Particle ids** are **1-based** and run from `1` to `N`.
- **All `N` particles are always written.** Rattlers (particles that touch no one)
  are flagged in `particles.csv` and are **never silently dropped** by the writer.

## `particles.csv`

One header row, then one row per particle, in id order `1 … N`:

```
id, x, y[, z], radius, is_rattler, z_contacts
```

| Column        | Type      | Meaning                                                        |
| ------------- | --------- | -------------------------------------------------------------- |
| `id`          | int       | 1-based particle id.                                           |
| `x, y[, z]`   | float     | Wrapped coordinates in the periodic box (`[0, L)` per axis).   |
| `radius`      | float     | Particle radius (in units of `⟨R⟩`).                           |
| `is_rattler`  | 0/1 int   | `1` if the particle is a rattler, else `0`.                    |
| `z_contacts`  | int       | Coordination number: how many contacts touch the particle.     |

## `contacts.csv`

One header row, then one row per contact. Contact ids `i, j` are the 1-based particle
ids; each unordered contact appears once (with `i < j`).

```
i, j, overlap, fn[, ft], nx, ny[, nz]
```

| Column    | Type   | Meaning                                                                 |
| --------- | ------ | ----------------------------------------------------------------------- |
| `i, j`    | int    | The two particle ids in the contact (`i < j`).                          |
| `overlap` | float  | `rᵢ + rⱼ − distance` (> 0 while the particles are in contact).          |
| `fn`      | float  | Normal force magnitude.                                                 |
| `ft`      | float  | **Optional.** Tangential (friction) force magnitude; present only when  |
|           |        | the packing carried friction, i.e. only when the header includes it.    |
| `nx, ny[, nz]` | float | Unit contact normal pointing from `i` toward `j`.                 |

The number of coordinate columns (`y` vs `y, z`) and the presence of the `ft` column
are inferred from the header, so `2` and `3` and frictionless and frictional files
all parse unambiguously.

## `metadata.toml`

A single TOML table. The following keys are always present:

| Key                          | Type            | Meaning                                            |
| ---------------------------- | --------------- | -------------------------------------------------- |
| `format`                     | string          | `"softpack-1"`.                                     |
| `softpack_version`           | string          | SoftPack version that wrote the file.              |
| `git_commit`                 | string (opt.)   | Short git commit of the run (omitted if unknown).  |
| `box`                        | array of float  | Side lengths `L_d`, one per axis.                  |
| `algorithm`                  | string          | Packing algorithm symbol.                          |
| `dim`                        | int             | Spatial dimension.                                 |
| `N`                          | int             | Number of particles.                               |
| `sizes`                      | string          | Size-distribution description.                     |
| `contact`                    | string          | Contact-law description.                           |
| `pressure`                   | float           | Target mechanical pressure.                        |
| `pressure_tol`               | float           | Relative pressure convergence tolerance.           |
| `force_threshold`            | float           | Residual-force convergence criterion.              |
| `max_steps`                  | int             | Maximum number of iterations.                      |
| `rattlers`                   | string          | `:remove`, `:flag` or `:keep` (written as a string).|
| `backend`                    | string          | `:cpu`, `:cuda` or `:metal` (as a string).         |
| `precision`                  | string          | `Float32` or `Float64`.                            |
| `seed`                       | int             | RNG seed.                                           |
| `friction`                   | string (opt.)   | Friction setting, or `"nothing"` when set.         |
| `verbose`                    | bool            | Whether progress was printed.                      |

The following are written once the core engine computes them (populated by later
milestones; `M0` writes them as provided by the caller, if at all):

| Key                             | Type   | Meaning                                           |
| ------------------------------- | ------ | ------------------------------------------------- |
| `final_pressure`                | float  | Measured pressure at the stop criterion.          |
| `packing_fraction`              | float  | Packing fraction including rattlers.              |
| `packing_fraction_without_rattlers` | float | Packing fraction excluding rattlers.          |
| `mean_coordination`             | float  | Mean coordination number including rattlers.      |
| `mean_coordination_without_rattlers` | float | Mean coordination number excluding rattlers. |
| `residual_force_ratio`          | float  | Residual force divided by the mean force.         |
| `steps`                         | int    | Number of iterations used.                         |
| `wall_time`                     | float  | Wall-clock time of the run.                        |

### Value serialization notes

- TOML has no `null`, so a Julia `nothing` value is written as the string
  `"nothing"` and read back as `nothing`.
- TOML has no `symbol` type, so a Julia `Symbol` (e.g. `friction = :coulomb`) is
  written as its string form (`"coulomb"`) and read back as a string.
- Coordinates are written with the exact round-trip precision for the element type
  (`%.17g` for `Float64`, `%.9g` for `Float32`) so a write → read cycle recovers the
  stored numbers exactly.
