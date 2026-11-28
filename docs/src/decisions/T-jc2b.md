# T-jc2b: ensembles, threads and the RNG record

*Up:* [Design decisions](index.md)

**Question.** The design left open how an ensemble is seeded, whether threads can change
a packing, and which random-number generator version a file records.

**Choice.** An ensemble is drawn from a master generator whose seeds are the member
indices, so a run of seed 7 is the same packing whatever else the ensemble contains. The
force loop is single-threaded, and identical packings are promised for a given seed.
Every packing records the generator and now its version (`rng_version`), in the file and
in the result.

**Why.** A seed is a promise about a single run, so it must not depend on how many other
runs share the machine or the session. Recording the version means a file made with an
older StableRNGs can be recognized even if the algorithm behind it later changes.

**Status.** In code (`rng_version` attribute). Threading stays single; a multithreaded
version would have to fix the reduction order and would then promise identity only for a
given thread count.

## Archival reference

- [Reproducibility](https://github.com/ColtonKawamura/SoftPack/wiki/Reproducibility)
