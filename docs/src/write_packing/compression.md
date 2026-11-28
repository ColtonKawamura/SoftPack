# `compression`

*Up:* [`write_packing()`](index.md)

Compress the HDF5 datasets to make the file smaller [HDF5jl], [h5py]. Nothing is compressed by
default, so the datasets stay memory-mappable and a reader can open a large file without
decompressing all of it.

| Choice | Default | Meaning |
|:---|:---|:---|
| `nothing` | **default** | uncompressed |
| `:gzip` |  | gzip at level 4 |
| `(:gzip, level)` |  | gzip at the given level, 1 to 9 |

gzip is lossless and is applied per dataset, so a compressed file reads exactly like an
uncompressed one. The price is that a dataset must be read as a whole: a compressed file
cannot be memory-mapped.

`compression` applies to HDF5 only. With `format = :csv` it is ignored, because the CSV
path writes text.

## Example

```julia
using SoftPack

packing = pack(particles_count = 64, seed = 1)
write_packing(
    "packing.h5",
    packing;
    compression = :gzip,
)
```

## References

- **[HDF5jl]** JuliaIO. *HDF5.jl documentation*. <https://juliaio.github.io/HDF5.jl/stable/>. Accessed 2026-11-18.
- **[h5py]** The h5py developers. *Datasets, h5py documentation*. <https://docs.h5py.org/en/stable/high/dataset.html>. Accessed 2026-11-18.
