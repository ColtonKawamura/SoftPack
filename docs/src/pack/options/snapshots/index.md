# `snapshots`

*Up:* [Available options](../index.md)

Store the particle positions at intervals during the run, so the path to the final packing
can be inspected or redrawn later. A snapshot is data, not a picture: it holds the
positions, and any frame can be rendered at any size afterwards with `render_frame!`.

Snapshots live in memory during the run and are written by `write_packing` into the
`snapshots` group of the HDF5 file. Nothing is stored by default.

**Default:** `nothing`

## Choices

| Choice | Default |
|:---|:---|
| `nothing` | **default** |
| [`Snapshots()`](Snapshots.md) |  |

## Archival reference

- [pack(snapshots = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#packsnapshots--)
- [Snapshots and movie](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#snapshots-and-movie)
