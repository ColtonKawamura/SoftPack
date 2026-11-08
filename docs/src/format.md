# softpack-1 format specification

**Status:** v1 · **Latest version:** `softpack-1`

The `softpack-1` format describes a single jammed packing as a folder of three
plain-text files. It is deliberately plain (CSV + TOML) so a packing can be read
and written from any language without Julia, and so every packing is
self-describing: the algorithm, contact law, stop criterion, rattler rule, seed
and version are all recorded on disk.

**What exists in v0.1 (M0).** The writer and reader of this format are
implemented and tested: 2D and 3D, frictionless and frictional, `Float64` and
`Float32`, with an exact floating-point round-trip. No packing algorithm exists
yet (`pack()` throws "not implemented yet"), so files in circulation today are
written from hand-built `Packing`s (see `examples/example.jl`). Metadata keys
that the engine fills in are marked *planned* below.

## Layout

One folder per packing, containing exactly:

| File            | Purpose                                             |
| --------------- | --------------------------------------------------- |
| `particles.csv` | Every particle's position, size and rattler flag.   |
| `contacts.csv`  | Every pairwise contact (normal and tangential).     |
| `metadata.toml` | Machine-readable notes about the run and its output. |

## Conventions and units

- **Quantities are nondimensional.** There is no SI unit attached to the output.
- **Length unit (planned with the engine).** Engine-produced packings will
  express lengths in units of the mean particle radius
  `⟨R⟩ = (Σᵢ rᵢ) / N` unless the run specifies otherwise. With that convention a
  monodisperse packing of radius `r` has `⟨R⟩ = r`, so coordinates and radii are
  O(1); overlaps are in the same units. Forces and pressure are in units of the
  contact-stiffness parameter (e.g. the Hookean constant `k`). Until the engine
  lands, files carry the raw values the caller supplied.
- **Periodic box.** The domain is a cube (2D: square) with side lengths `L_d`
  per axis, with periodic boundary conditions. A coordinate `x` satisfies
  `0 ≤ x < L` (half-open interval `[0, L)`); particles are wrapped into the box.
- **Particle ids** are **1-based** and run from `1` to `N`.
- **All `N` particles are always written.** Rattlers (particles that touch no
  one) are flagged in `particles.csv` and are **never silently dropped** by the
  writer.

## File encoding

All three files are ASCII text with LF line endings. The CSV files have one
header row, then one data row per record, with fields separated by a comma and a
single space (`, `). Standard CSV readers (pandas, MATLAB `readtable`, ...)
handle that whitespace automatically; a hand-rolled C++ reader should trim
leading whitespace from each field. Floating-point values are written with the
exact round-trip precision for the stored type (`%.17g` for `Float64`, `%.9g`
for `Float32`), so parsing recovers the stored numbers exactly.

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

The spatial dimension is inferred from the header: it is the number of
coordinate columns between `id` and `radius` (2 or 3).

## `contacts.csv`

One header row, then one row per contact. Contact ids `i, j` are the 1-based
particle ids; each unordered contact appears once, with `i < j`.

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

- The dimension is inferred from the header: it is the number of `nx/ny/nz`
  normal columns (2 or 3).
- If **any** contact in the file carries friction, **every** row has the `ft`
  column; a frictionless pair inside a frictional file has `ft = 0`.

## `metadata.toml`

A single TOML table with the keys in three groups.

**Present in every file:**

| Key                | Type            | Meaning                                             |
| ------------------ | --------------- | --------------------------------------------------- |
| `format`           | string          | `"softpack-1"`.                                     |
| `softpack_version` | string          | SoftPack version that wrote the file.               |
| `git_commit`       | string (opt.)   | Short git commit of the run (omitted if unknown,    |
|                    |                 | e.g. when running from a source archive).           |
| `box`              | array of float  | Side lengths `L_d`, one per axis.                   |

**The settings of the run.** The engine records every `PackParams` field.
*Planned with the engine:* until it lands, these keys are present only if the
caller put them in the `Packing` metadata.

| Key               | Type            | Meaning                                            |
| ----------------- | --------------- | -------------------------------------------------- |
| `algorithm`       | string          | Packing algorithm symbol.                          |
| `dim`             | int             | Spatial dimension.                                 |
| `N`               | int             | Number of particles.                               |
| `sizes`           | string          | Size-distribution description.                     |
| `contact`         | string          | Contact-law description.                           |
| `pressure`        | float           | Target mechanical pressure.                        |
| `pressure_tol`    | float           | Relative pressure convergence tolerance.           |
| `force_threshold` | float           | Residual-force convergence criterion.              |
| `max_steps`       | int             | Maximum number of iterations.                      |
| `rattlers`        | string          | `"remove"`, `"flag"` or `"keep"`.                  |
| `backend`         | string          | `"cpu"`, `"cuda"` or `"metal"`.                    |
| `precision`       | string          | `"Float32"` or `"Float64"`.                        |
| `seed`            | int             | RNG seed.                                          |
| `friction`        | string (opt.)   | Friction setting; written as `"nothing"` when the  |
|                   |                 | run has no friction.                               |
| `verbose`         | bool            | Whether progress was printed.                      |

**Computed by the engine at the end of the run.** *Planned with the engine:*
not present in v0.1.

| Key                                | Type   | Meaning                                           |
| ---------------------------------- | ------ | ------------------------------------------------- |
| `final_pressure`                   | float  | Measured pressure at the stop criterion.          |
| `packing_fraction`                 | float  | Packing fraction including rattlers.              |
| `packing_fraction_without_rattlers`| float  | Packing fraction excluding rattlers.              |
| `mean_coordination`                | float  | Mean coordination number including rattlers.      |
| `mean_coordination_without_rattlers` | float | Mean coordination number excluding rattlers.      |
| `residual_force_ratio`             | float  | Residual force divided by the mean force.         |
| `steps`                            | int    | Number of iterations used.                        |
| `wall_time`                        | float  | Wall-clock time of the run.                       |

### Value serialization notes

- Keys are written in sorted order, so the file is stable.
- TOML has no `null`, so a Julia `nothing` value (e.g. `friction = nothing`) is
  written as the string `"nothing"` and read back as `nothing`.
- TOML has no `symbol` type, so a Julia `Symbol` (e.g. `friction = :coulomb`) is
  written as its string form (`"coulomb"`) and read back as a string.

## Reading without Julia

Everything above needs only a CSV reader and a TOML reader — no Julia. The
dimension and the presence of friction are both inferable from the headers, so
the same reader works for 2D/3D and frictionless/frictional files.

### Python (pandas + tomllib, Python 3.11+)

```python
import tomllib
import pandas as pd

with open("packing/metadata.toml", "rb") as f:     # tomllib reads binary mode
    meta = tomllib.load(f)

particles = pd.read_csv("packing/particles.csv")   # id, x, y[, z], radius, is_rattler, z_contacts
contacts  = pd.read_csv("packing/contacts.csv")    # i, j, overlap, fn[, ft], nx, ny[, nz]

L            = meta["box"]                         # box side lengths, one per axis
dim          = len(L)
has_friction = "ft" in contacts.columns

if dim == 2:
    coords = particles[["x", "y"]].to_numpy()
else:
    coords = particles[["x", "y", "z"]].to_numpy()
```

`is_rattler` arrives as an `int` column of 0/1.

### MATLAB (readtable)

```matlab
T = readtable("packing/particles.csv");   % one row per particle
C = readtable("packing/contacts.csv");    % one row per contact

hasFriction = ismember("ft", C.Properties.VariableNames);
% metadata.toml is TOML, not a delimited table, so readtable does not parse
% it; until you have a TOML parser, a small regex is enough for the box:
m = regexp(fileread("packing/metadata.toml"), "box = \[(.*?)\]", "once");
L = str2num(strtrim(m));
```

`is_rattler` arrives as numeric 0/1.

### C++

Use any CSV parser. Trim leading whitespace from each field (fields are
separated by `, `), infer the dimension and the presence of friction from the
header exactly as described above, and parse the numbers with `std::stod` —
with the full round-trip precision you recover the stored values exactly.
