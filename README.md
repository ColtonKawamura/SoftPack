# SoftPack

SoftPack is a Julia package for generating jammed packings of soft particles for
granular and soft-matter simulations. The goal is one well-documented, reproducible
place to make packings, so that packings used across studies are built the same way
and described by the same metadata.

## Status

The engine implements every setting of the design ([`docs/design-references.md`](docs/design-references.md)):

```julia
using SoftPack
packing = pack()          # 256 Hookean disks, 50:50 bidisperse (1 : 1.4), P = 1e-4
packing.converged         # true
packing.packing_fraction  # 0.8387
packing.contact_number    # 4.016, after removing 12 rattlers
```

- Contacts: `Hookean` and `Hertzian`; `CundallStrack` and `Mindlin` friction with
  particle rotation; `EqualMass` or `Density` masses.
- Boundaries: periodic squares and cubes, or `Walls(friction = true/false)`.
- Algorithms: FIRE 2.0 with the LAMMPS defaults, and `DampedDynamics` with the centered
  velocity Verlet (default), lagged velocity Verlet or semi-implicit Euler, with
  `ContactDamping`, `ViscousRate`, `RelativeVelocityDamping` and `StokesDrag`.
- Particle sizes: `Bidisperse`, `UniformPolydisperse`, `Monodisperse`, or an explicit
  `particles_diameters` list; 2D disks and 3D spheres.
- Convergence: `RelativeForce`, `LeidenAcceleration`, `KineticEnergy`, `RestartTest`, or
  any function of a read-only `RunState`.
- Rattlers: `ContactCount`, `TwoContact`, `ForceFloor`, `Unresolved`, the friction-cone
  test, or any function of the packing.
- Restarts and output: `restart_packing`, `RestartFile`, `write_packing` (HDF5 or CSV,
  gzip, a second rattler file, safe writes), `Snapshots`, and `Movie` (MP4 or GIF through
  ffmpeg).

Damped dynamics is correct but much slower to reach the tight force tolerance than FIRE:
the contact dashpots die out slowest on the soft modes (design §8), so a frictional run
with `DampedDynamics` usually needs `StokesDrag(during = :compression)` and a looser
`RelativeForce` tolerance. This is the timing card T-2brz asks for.

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
