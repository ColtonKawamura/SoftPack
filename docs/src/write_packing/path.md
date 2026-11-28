# `path` and `format`

*Up:* [`write_packing()`](index.md)

The path is where the file goes; `format` picks what is written [HDF5jl], [h5py], [MATLABh5read].

| Choice | Default | What is written |
|:---|:---|:---|
| `format = :hdf5` | from `.h5` or `.hdf5` | one HDF5 file, read natively by Julia, Python and MATLAB |
| `format = :csv` | from `.csv` | two text files, `<base>_particles.csv` and `<base>_contacts.csv` |

The format follows the extension: `.h5` and `.hdf5` are HDF5, `.csv` is
CSV, and any other extension is an error. An explicit `format = :hdf5` or `format = :csv`
overrides the extension, for a path whose extension says nothing.

Later formats (XYZ, LAMMPS data) are on the [Roadmap](../roadmap.md).

## HDF5 layout

| Group | Contents |
|:---|:---|
| `particles` | one 1-D dataset per column: `id` (0-based), `diameter`, `mass`, `position_x` …, `force_x` … |
| `contacts` | `first`, `second` (0-based; `second = -1` marks a wall), `wall_id`, `overlap`, `normal_force`, `tangential_force`, `sliding` |
| `state` | every particle and the full dynamic state, enough for `restart_packing` |
| `snapshots` | `positions`, one column per snapshot, when `snapshots` was set |

The `particles` group holds the remaining particles after the rattler rule; with
`rattlers_file = true` the second file holds every particle and its flag.

## Example

```julia
using SoftPack

packing = pack(particles_count = 64, seed = 1)
write_packing("packing.csv", packing)  # CSV from the extension
```

## References

- **[HDF5jl]** JuliaIO. *HDF5.jl documentation*. <https://juliaio.github.io/HDF5.jl/stable/>. Accessed 2026-11-18.
- **[h5py]** The h5py developers. *Datasets, h5py documentation*. <https://docs.h5py.org/en/stable/high/dataset.html>. Accessed 2026-11-18.
- **[MATLABh5read]** The MathWorks. *h5read: Read data from HDF5 dataset, MATLAB documentation*. <https://www.mathworks.com/help/matlab/ref/h5read.html>. Accessed 2026-11-18.
