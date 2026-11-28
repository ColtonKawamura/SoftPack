# `rattlers_file`

*Up:* [`write_packing()`](index.md)

The main file holds the particles that remain after the rattler rule. The second file is a **SoftPack choice**. `rattlers_file = true`
writes a second file with *every* particle and a `rattler` flag, so the removed ones are
not lost:

The second path is derived from the first: `packing.h5` gives `packing_rattlers.h5` in the
same directory, and a path without an extension gets `_rattlers` at the end. With
`format = :csv` the second file follows the same rule.

**Default:** `false`

## Choices

| Choice | Default |
|:---|:---|
| `false` | **default** |
| `true` |  |

## Example

```julia
using SoftPack

packing = pack(particles_count = 64, seed = 1)
write_packing(
    "packing.h5",
    packing;
    rattlers_file = true,
)
```
