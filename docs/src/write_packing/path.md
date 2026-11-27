# `path` and `format`

*Up:* [`write_packing()`](index.md)

The path is where the file goes; `format` picks what is written.

| Choice | Default | What is written |
|:---|:---|:---|
| `format = :hdf5` | **default** | one HDF5 file, read natively by Julia, Python and MATLAB |
| `format = :csv` |  | two text files, `<base>_particles.csv` and `<base>_contacts.csv` |

The format is *not* inferred from the extension: writing `"packing.csv"` without
`format = :csv` writes HDF5 into a file named `.csv`. The extension is a convention for
the reader, and the explicit keyword is what decides.

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

## Archival reference

- [write_packing file format](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#write_packing-file-format)
- [File format: HDF5](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#file-format-hdf5)
- [CSV](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#csv)
