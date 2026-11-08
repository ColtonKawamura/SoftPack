# Home

SoftPack is a Julia package for generating **jammed packings of soft particles**
for granular and soft-matter (DEM) research. The goal is one well-documented,
reproducible place to make packings, so that packings produced across studies are
built the same way and described by the same metadata.

## Status

Early development (v0.1.0-DEV). The package skeleton, settings, and output format
land in the current milestone; the packing algorithms themselves are added in
following milestones.

## Quick start

```julia
using SoftPack

# 1. Build a settings object and tweak what you need.
p = PackParams()
p.algorithm = :fire_compress
p.force_threshold = 1e-12

# 2. Run the packing.
pk = pack(p)

# 3. Write it to disk in the self-describing softpack-1 format.
write_packing(pk, "./packing")
```

## Key ideas

- **Reproducible.** Every packing records its algorithm, contact law, stop
  criterion, rattler rule, seed and version. See the [format
  specification](format.md).
- **Self-describing output.** One folder per packing with `particles.csv`,
  `contacts.csv` and `metadata.toml`, readable from any language.
- **Portable.** CPU by default; CUDA and Metal later, via package extensions so
  CPU users never install them.

## License

MIT, see the repository `LICENSE`.
