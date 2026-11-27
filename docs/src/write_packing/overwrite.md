# `overwrite`

*Up:* [`write_packing()`](index.md)

Whether an existing file may be replaced.

| Choice | Default | Behaviour |
|:---|:---|:---|
| `false` | **default** | stop with an `ArgumentError` if any file it would write exists |
| `true` |  | replace the existing file |

The default refuses, because a packing can take minutes and a typo that overwrites it
costs the whole run. The check covers every file the call would write: the main file, the
rattlers file, and both CSV files.

Every write is atomic. The file is written to a temporary file in the same directory and
renamed over the target, so a job killed during a write leaves the previous file intact;
with `overwrite = true` that means an interrupted write never leaves a half-written
packing in place of a good one.

## Archival reference

- [write_packing(overwrite = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#write_packingoverwrite--)
- [Overwrite (overwrite)](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#overwrite-overwrite)
- [Safe writes](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#safe-writes)
