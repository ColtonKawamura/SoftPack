# `Snapshots()`

*Up:* [`snapshots`](index.md)

Snapshots are a **SoftPack choice**. Take a snapshot every `every` steps (or every wall-clock period). The file then holds a
`snapshots/positions` dataset with one column per snapshot, so the $k$-th frame is
`snapshots/positions[:, k]`.

Snapshots are cheap: each one is $D N$ numbers, so a run with 200 snapshots of 256 disks
stores 100,000 numbers, well under a megabyte. They are the right choice when the
intermediate states matter for analysis but a movie does not.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `every` | required | steps (an integer) or a wall-clock period between snapshots |

## Example

```julia
using SoftPack

packing = pack(
    snapshots = Snapshots(
        every = 5_000,
    ),
    particles_count = 256,
    seed = 1,
)
write_packing("packing.h5", packing)
```
