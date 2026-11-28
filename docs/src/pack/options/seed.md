# `seed`

*Up:* [Available options](index.md)

The seed of the random number generator [StableRNGs], [JuliaRandom]. SoftPack draws the initial placement from one
`StableRNG` stream, and nothing else in the run is random: the compression is
deterministic once the start is fixed. The same seed therefore gives the same packing to
the last bit, on Julia 1.10, 1.12 and 1.13, because every reduction in the trajectory runs
in a fixed order.

A seed must lie between 0 and `typemax(Int)`; anything outside raises an error rather
than wrapping, because a silent modulo would map two seeds to the same packing. Use a different seed to get an independent member of the ensemble; use the same
seed to reproduce a run or to compare two settings on the same start.

**Default:** `1`

## Options

| Value | Meaning |
|:---|:---|
| any integer | the seed of the single `StableRNG` stream |

The result records the seed and the generator, so a packing file says how to reproduce it.

## Example

```julia
using SoftPack

packing = pack(
    seed = 7,  # independent member of the ensemble
    particles_count = 256,
)
packing.packing_fraction
```

## References

- **[StableRNGs]** JuliaRandom. *StableRNGs.jl*. <https://github.com/JuliaRandom/StableRNGs.jl>. Accessed 2026-11-18.
- **[JuliaRandom]** The Julia Project. *Random Numbers, The Julia Language manual (Reproducibility section)*. <https://docs.julialang.org/en/v1/stdlib/Random/>. Accessed 2026-11-18.
