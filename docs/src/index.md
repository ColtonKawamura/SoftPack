# Home

SoftPack is a Julia package for generating **jammed packings of soft particles**
for granular and soft-matter (DEM) research.

## Why standardized packings?

A packing is part of the experiment: its structure and contact forces change
what a DEM simulation measures. If every group builds its initial conditions
with its own private recipe, results are hard to compare and hard to reproduce.

SoftPack makes the recipe the unit of work. All the settings are one explicit
object (algorithm, target pressure, contact law, size distribution, stop
criterion, rattler rule, seed, ...), so **the same recipe gives the same kind of
packing in every group**. And every packing is written out with its full
metadata, so a published packing is self-describing: you can reproduce it, check
exactly how it was made, and build on it.

## Status

Early development (v0.1.0-DEV). What works today:

- the settings object `PackParams`, with defaults and early, actionable
  validation (bad settings fail with a clear `ArgumentError`)
- the softpack-1 output format: `write_packing` / `read_packing` with an exact
  floating-point round-trip, 2D and 3D, frictionless and frictional, `Float64`
  and `Float32`
- the runnable example `examples/example.jl`

The packing engine (the `pack()` algorithms) is added in the next milestone;
until then `pack()` throws a clear "not implemented yet" error.

## Installation

1. Install [Julia](https://julialang.org) — e.g. with
   [juliaup](https://juliaup.dev): `curl -fsSL https://install.julialang.org | sh`.
2. Add SoftPack to your project. The package is not in the registry yet, so add
   it from the repository URL for now:

   ```julia
   julia> ] add https://github.com/ColtonKawamura/SoftPack.git
   ```

   A registry entry is planned for the first release. From a local checkout,
   `sh install.sh` does all of this in one command.

## Quick start

```julia
using SoftPack

# 1. Build a settings object and tweak what you need.
p = PackParams()
p.algorithm = :fire_compress
p.force_threshold = 1e-12
# The same settings can also be given in one line: PackParams(N = 64, pressure = 1e-3)

# 2. Run the packing (planned: the engine lands in the next milestone).
pk = pack(p)

# 3. Write it to disk in the self-describing softpack-1 format.
write_packing(pk, "./packing")
```

Invalid settings fail early with a clear `ArgumentError` (e.g. `dim must be 2
or 3, got 4`) instead of silently running the wrong thing.

## Key ideas

- **Reproducible.** Every packing records its algorithm, contact law, stop
  criterion, rattler rule, seed and version. See the [format
  specification](format.md).
- **Self-describing output.** One folder per packing with `particles.csv`,
  `contacts.csv` and `metadata.toml`, readable from any language.
- **Portable.** CPU by default; CUDA and Metal later, as optional package
  extensions so CPU users never install them.

## License

MIT, see the repository `LICENSE`.
