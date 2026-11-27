# `Snapshots()`

*Up:* [`snapshots`](index.md)

```
p = pack(snapshots = Snapshots(every = 5000))
write_packing("packing.h5", p)
```

Take a snapshot every `every` steps (or every wall-clock period). The file then holds a
`snapshots/positions` dataset with one column per snapshot, so the $k$-th frame is
`snapshots/positions[:, k]`.

Snapshots are cheap: each one is $D N$ numbers, so a run with 200 snapshots of 256 disks
stores 100,000 numbers, well under a megabyte. They are the right choice when the
intermediate states matter for analysis but a movie does not.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `every` | required | steps (an integer) or a wall-clock period between snapshots |

## Archival reference

- [pack(snapshots = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#packsnapshots--)
- [Snapshots and movie](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#snapshots-and-movie)
