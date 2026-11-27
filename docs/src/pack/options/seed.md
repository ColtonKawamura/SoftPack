# `seed`

*Up:* [Available options](index.md)

The seed of the random number generator. SoftPack draws the initial placement from one
`StableRNG` stream, and nothing else in the run is random: the compression is
deterministic once the start is fixed. The same seed therefore gives the same packing to
the last bit, on Julia 1.10, 1.12 and 1.13, because every reduction in the trajectory runs
in a fixed order (design §10).

Use a different seed to get an independent member of the ensemble; use the same seed to
reproduce a run or to compare two settings on the same start.

**Default:** `1`

## Options

| Value | Meaning |
|:---|:---|
| any integer | the seed of the single `StableRNG` stream |

The result records the seed and the generator, so a packing file says how to reproduce it.

## Archival reference

- [pack(seed = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#packseed--)
- [Reproducibility](https://github.com/ColtonKawamura/SoftPack/wiki/Reproducibility)
