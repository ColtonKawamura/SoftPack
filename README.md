# SoftPack

SoftPack is a Julia package for generating jammed packings of soft particles for
granular and soft-matter (DEM) research. The goal is for it to become the
standard place to make packings: one well-documented recipe system, so that the
same settings give the same kind of packing in every group, and every packing is
self-describing — the algorithm, contact law, stop criterion, rattler rule, seed
and version are all recorded with the output.

## Install

One command installs Julia (if you do not have it) and the package
dependencies:

```sh
sh install.sh
```

## Quick start

```julia
using SoftPack
p = PackParams()                        # every field has a default
p.force_threshold = 1e-12
pk = pack(p)                            # v0.1: throws "not implemented yet"
write_packing(pk, "./packing")          # softpack-1 folder: particles.csv, contacts.csv, metadata.toml
```

## Status

Early development (v0.1.0-DEV). The settings object (with early, actionable
validation), the softpack-1 read/write format (exact floating-point round-trip)
and the install script work today. The packing engine itself — the `pack()`
algorithms — is added in the next milestone, so `pack()` currently throws a
clear "not implemented yet" error.

## Planned

- Packing algorithms: FIRE compression to a target pressure (next milestone),
  then damped molecular dynamics with pressure control, Lubachevsky–Stillinger,
  Jodrey–Tory, random sequential addition and gravity deposition
- Hookean and Hertzian contact forces with Cundall–Strack and Hertz–Mindlin
  friction (the setting types exist today; the physics engine is planned)
- Force-threshold convergence criteria and rattler handling
- 2D and 3D periodic boxes with monodisperse, bidisperse, polydisperse and
  custom radii
- GPU backends (CUDA and Apple Metal as optional package extensions, so CPU
  users never install them)
- A command-line interface, TOML input files, HPC helpers and exporters

## Documentation

- Documentation site: <https://ColtonKawamura.github.io/SoftPack/stable/>
  (built and deployed from `main` by CI)
- softpack-1 format specification:
  <https://ColtonKawamura.github.io/SoftPack/stable/format/>
  (source: [`docs/src/format.md`](docs/src/format.md))

## License

MIT, see `LICENSE`.
