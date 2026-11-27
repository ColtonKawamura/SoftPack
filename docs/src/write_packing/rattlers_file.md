# `rattlers_file`

*Up:* [`write_packing()`](index.md)

The main file holds the particles that remain after the rattler rule. `rattlers_file = true`
writes a second file with *every* particle and a `rattler` flag, so the removed ones are
not lost:

```
write_packing("packing.h5", packing; rattlers_file = true)
# also writes packing_rattlers.h5
```

The second path is derived from the first: `packing.h5` gives `packing_rattlers.h5` in the
same directory, and a path without an extension gets `_rattlers` at the end. With
`format = :csv` the second file follows the same rule.

**Default:** `false`

## Choices

| Choice | Default |
|:---|:---|
| `false` | **default** |
| `true` |  |

## Archival reference

- [write_packing(rattlers_file = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#write_packingrattlers_file--)
- [Rattlers file (rattlers_file)](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#rattlers-file-rattlers_file)
- [A second file with every particle](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs#a-second-file-with-every-particle)
