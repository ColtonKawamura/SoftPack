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

## Status

Early development. The default frictionless path works end to end:

```julia
using SoftPack
packing = pack()          # 256 Hookean disks, 50:50 bidisperse (1 : 1.4), P = 1e-4
packing.converged         # true
packing.packing_fraction  # 0.8387
packing.contact_number    # 4.016, after removing 12 rattlers
```

Implemented: 2D and 3D; `Bidisperse`, `UniformPolydisperse`, `Monodisperse` or an explicit
`particles_diameters` list; `Hookean` contacts without friction; `EqualMass`; a
`Pressure` target; a `Periodic` box; the `Dilute` start; `IsotropicCompression`; FIRE 2.0
with the LAMMPS defaults and the semi-implicit Euler integrator; the `RelativeForce`
convergence test; the `ContactCount` rattler rule (or `nothing`, or any function of the
packing); `find_rattlers`; `failure_action`. The result stays in memory as a `Packing`.

Designed but not built yet (`pack()` refuses them by name): friction (`CundallStrack`,
`Mindlin`), `Hertzian` contacts, `Density` masses, `Walls`, `DampedDynamics`, contact
damping and drag, the other convergence tests and rattler rules, restarts, snapshots and
movies, and `write_packing` (HDF5).

Choices still open on the design board are coded provisionally and marked in the source;
`grep -rn PROVISIONAL src` lists them with their card.

Run the tests with `julia --project -e 'using Pkg; Pkg.test()'`.

## Documentation

- [Design decisions](docs/design-references.md): every setting of `pack()`, its
  default, and the sources behind it ([BibTeX](docs/references.bib)).
- [Wiki](https://github.com/ColtonKawamura/SoftPack/wiki): one page per design
  section, with the symbols defined, the formulas derived and the numbers worked out.

## License

MIT, see `LICENSE`.
