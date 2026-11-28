# `snapshots`

*Up:* [Available options](../index.md)

Store the particle positions at intervals during the run, so the path to the final packing
can be inspected or redrawn later. A snapshot is data, not a picture: it holds the
positions, and any frame can be rendered at any size afterwards with `render_frame!`.

Snapshots live in memory during the run and are written by `write_packing` into the
`snapshots` group of the HDF5 file. Nothing is stored by default (**SoftPack choice**).

**Default:** `nothing`

## Choices

| Choice | Default |
|:---|:---|
| `nothing` | **default** |
| [`Snapshots()`](Snapshots.md) |  |

## Example

```julia
using SoftPack

packing = pack(
    snapshots = Snapshots(
        every = 10_000,
    ),
    particles_count = 256,
    seed = 1,
)
write_packing("packing.h5", packing)
```
