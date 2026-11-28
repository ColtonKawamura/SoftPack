# Saving a packing with `write_packing()`

*Up:* [SoftPack](../index.md)

`pack()` returns a `Packing` in memory and writes no file.
`write_packing()` is the separate call that writes one `Packing` to disk.
Every option has a default, so the shortest call is the path and the packing.

## The call with every default written out

```julia
write_packing(                  # write one Packing to disk
    "my_packing.h5",            # output path; the extension picks HDF5 or CSV
    my_packing;                 # the Packing returned by pack(); the ; starts the keyword arguments
    rattlers_file = false,      # write only the remaining particles (default)
    compression   = nothing,    # leave the datasets uncompressed (default)
    overwrite     = false       # stop with an error if a file already exists (default)
)                               # end of write_packing call
```

- `write_packing(...)` — writes one `Packing` to disk, as a call separate from `pack()`.
  - For details, see [the Packing page](../pack/Packing.md).
- `"my_packing.h5"` — the output path; `.h5` or `.hdf5` writes HDF5, `.csv` writes CSV.
  - HDF5 is the default format, read natively by Julia, Python and MATLAB [HDF5jl], [h5py], [MATLABh5read].
  - For details, see [path and file format](path.md).
- `my_packing` — the `Packing` to write.
  - The `;` ends the positional arguments and starts the keyword arguments (Julia syntax).
- `rattlers_file = false` **(default)** — write only the particles that remain after the rattler rule has run.
  - With `true`, a second file also holds every particle with a rattler flag.
  - The second file is named after the main file: `my_packing.h5` gives `my_packing_rattlers.h5`, in the same directory.
  - For details, see [`rattlers_file`](rattlers_file.md).
- `compression = nothing` **(default)** — leave the datasets uncompressed, so they can be memory-mapped.
  - With `:gzip`, the datasets are compressed with lossless gzip at level 4.
  - For details, see [`compression`](compression.md).
- `overwrite = false` **(default)** — stop with an error if a file it would write already exists.
  - With `true`, the existing file is replaced.
  - Each file is written to a temporary file and then renamed, so a job killed during a write leaves an existing file intact.
  - For details, see [`overwrite`](overwrite.md).

## Where next

- [path and file format](path.md): HDF5 and CSV.
- [`rattlers_file`](rattlers_file.md): the second file with every particle.
- [`compression`](compression.md): gzip.
- [`overwrite`](overwrite.md): replacing an existing file, and safe writes.
- [`pack()`](../pack/index.md): creating the packing to write.

## Example

```julia
using SoftPack

packing = pack(particles_count = 64, seed = 1)
write_packing(
    "packing.h5",
    packing;
    rattlers_file = false,
    compression = nothing,
    overwrite = false,
)
```

## References

- **[HDF5jl]** JuliaIO. *HDF5.jl documentation*. <https://juliaio.github.io/HDF5.jl/stable/>. Accessed 2026-11-18.
- **[h5py]** The h5py developers. *Datasets, h5py documentation*. <https://docs.h5py.org/en/stable/high/dataset.html>. Accessed 2026-11-18.
- **[MATLABh5read]** The MathWorks. *h5read: Read data from HDF5 dataset, MATLAB documentation*. <https://www.mathworks.com/help/matlab/ref/h5read.html>. Accessed 2026-11-18.
