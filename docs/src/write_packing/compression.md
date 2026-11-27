# `compression`

*Up:* [`write_packing()`](index.md)

Compress the HDF5 datasets to make the file smaller (design §11). Nothing is compressed by
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

## Archival reference

- [write_packing(compression = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#write_packingcompression--)
- [Compression (compression)](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#compression-compression)
- [gzip compression](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#gzip-compression)
