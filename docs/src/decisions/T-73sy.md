# T-73sy: the seed contract

*Up:* [Design decisions](index.md)

**Question.** The design promised more than the code delivered, and pages disagreed about
the allowed seed range.

**Choice.** A seed must lie between 0 and `typemax(Int)`; anything else is an error,
because a silent modulo would map two seeds to the same packing. One stream draws every
random number, in the order the compression protocol fixes. The same seed gives the same
packing across Julia versions on the same machine, and the test suite pins the default
packing's step count and bits on 1.10, 1.12 and 1.13.

**Why.** The range check turns a typo into an error instead of a duplicate run. The
version promise is stronger than the card asked for: the determinism rules (in-order sums,
no SIMD dots) were written precisely so a seed survives a Julia upgrade, and they were
verified.

**Status.** In code (`validate`); the promise is tested by the pinned default run.

## Archival reference

- [Reproducibility](https://github.com/ColtonKawamura/SoftPack/wiki/Reproducibility)
