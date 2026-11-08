# SoftPack

SoftPack is a Julia package for generating jammed packings of soft particles for
granular and soft-matter simulations. The goal is one well-documented, reproducible
place to make packings, so that packings used across studies are built the same way
and described by the same metadata.

Planned features:

- The main packing algorithms from the literature (FIRE compression to a target
  pressure, damped molecular dynamics with pressure control, Lubachevsky–Stillinger,
  Jodrey–Tory, random sequential addition, gravity deposition)
- Hookean and Hertzian contacts, with Cundall–Strack and Hertz–Mindlin friction
- Force-threshold convergence criteria and rattler removal
- 2D and 3D periodic boxes, monodisperse, bidisperse and polydisperse particles
- CPU, CUDA and Apple Metal backends
- Plain CSV + TOML output readable from any language
- Runs on laptops and HPC clusters

Status: early development. Nothing is usable yet.

## License

MIT, see `LICENSE`.
