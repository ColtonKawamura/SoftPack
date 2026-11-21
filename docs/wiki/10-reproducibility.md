# 10. Reproducibility

Design decision source: [design-references.md §10](../design-references.md#10-reproducibility).
Status: design stage (no engine code yet).

## Summary

Everything random in `pack()` comes from one pseudorandom number generator (RNG),
seeded with the keyword `seed`, default 1, so `pack()` with no arguments gives the same
packing every time. The generator is `StableRNG` from StableRNGs.jl, whose stream of
numbers for a given seed does not change between Julia versions; Julia's own
generators make no such promise. Every output records the SoftPack version, the git
commit, the Julia version, the seed and the RNG, so a packing can be traced to the
code that made it.

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| `seed` | `1` | any integer (design doc); `StableRNG` accepts $0 \le$ `seed` $\le 2^{64}-1$ | [Seed](#seed-seed) |
| random number generator | `StableRNG` (StableRNGs.jl) | none (not a setting) | [Generator](#generator-stablerng) |
| recorded in every output | SoftPack version, git commit, Julia version, seed, RNG | – | [Provenance](#provenance-record) |

## Model

### What is random in `pack()`

- The diameters, when they are drawn from `particles_size_distribution`
  ([§3](03-particle-size-distribution-and-length-unit.md)). With
  `particles_diameters` given, or `Monodisperse`, no diameter is random.
- The initial state from which `pack()` compresses to the target pressure. It is not
  designed yet (design doc, status line), so its random draws are not specified.

All of them come from one generator created from `seed`. Retrying a failed run with
other seeds is the caller's job ([§6](06-packing-that-does-not-converge.md)).

### A pseudorandom generator

A generator has a hidden state $s_n$, updated at every draw, and returns a number
computed from the state. The seed sets the first state. The same seed therefore gives
the same sequence of numbers, as long as the update and output rules do not change.

`StableRNG` is currently an alias of `LehmerRNG` [StableRNGs], a multiplicative
(Lehmer) linear congruential generator on 128-bit integers. From the package source
(StableRNGs 1.1.0):

$$s_0 = 2\,\text{seed} + 1, \qquad s_{n} = a\,s_{n-1} \bmod 2^{128}, \qquad u_n = \left\lfloor s_n / 2^{64} \right\rfloor,$$

with $a = \texttt{0x45a31efc5a35d971261fd0407a968add}$ and $u_n$ the $n$-th raw 64-bit
output; floating-point, normal and other draws are built from these outputs. The
state stays odd, and the seed must satisfy $0 \le \text{seed} \le 2^{64}-1$: the
package throws `ArgumentError("seed must be non-negative")` otherwise. Checked: a
Python implementation of these three formulas returns the same first output for
seed 1 as `rand(StableRNG(1), UInt64)` in Julia, 15053665437044804691. **SoftPack
note.**

### What a packing depends on

A packing is a deterministic function of

$$\text{packing} = \mathcal F\big(\text{settings},\ \text{seed},\ \text{SoftPack code},\ \text{Julia and its libraries},\ \text{hardware}\big).$$

`StableRNG` removes the Julia version from the **random numbers** only. Everything
after the draws (force sums, integration, the stopping test) is floating-point
arithmetic, and its rounding can change with the compiler, the libraries, the
hardware, or the order of a sum. A packing near jamming can end in a different minimum
after such a change. [§6](06-packing-that-does-not-converge.md) states the precise
guarantee for restarts: "on the same machine and versions".

## Derivations

### Two levels of reproducibility

1. **Same random numbers on every Julia version.** Guaranteed by StableRNGs within a
   major version of the package ([Generator](#generator-stablerng)). This fixes the
   diameters and the initial state.
2. **Same final packing, bit for bit.** Expected only with the same SoftPack version,
   Julia version and machine. LAMMPS describes the same limit for its restarts:
   [LAMMPSreadrestart] "Several things can prevent exact restarts due to round-off
   effects, in which case the trajectories in the 2 runs will slowly diverge."

Level 1 follows from the generator being plain integer arithmetic defined inside the
package (the formulas above), not Julia's default RNG. Level 2 cannot follow from the
seed alone. **SoftPack note.**

### Consecutive seeds give related streams

From the recurrence, the $n$-th state for seed $q$ is
$s_n(q) = a^n\,(2q + 1) \bmod 2^{128}$. For the next seed,

$$s_n(q+1) - s_n(q) \equiv 2\,a^n \pmod{2^{128}},$$

which does not depend on $q$. The $n$-th output of seed $q + 1$ is therefore the $n$-th
output of seed $q$ shifted by a fixed amount (up to a carry of 1 in the last bit), for
every $q$. The floating-point draws inherit this. Checked in Julia 1.12.7 with
StableRNGs 1.1.0: the first `rand(StableRNG(q))` for $q = 1, \dots, 6$ steps by
0.3901297614749457 (mod 1) from each seed to the next, and the second draw by
0.0515586230460747, so the second draws of seeds 1 to 5 are 0.077, 0.129, 0.180,
0.232, 0.284. Each packing is still made from a well-mixed stream; but an ensemble made
with seeds 1, 2, 3, … is a one-parameter family in which the $k$-th random number
advances by the same step from one member to the next. Whether that matters for
ensemble statistics has not been studied ([Open questions](#open-questions)).
**SoftPack note.**

## Defaults and their reasons

### Seed (`seed`)

```julia
pack(seed = 1)
```

**Decision.** The default seed is 1.

- **SoftPack choice**, so `pack()` with no arguments gives the same packing every time.
- `StableRNG` has no default seed of its own: [StableRNGs] "Currently, this RNG requires
  explicit seeding (in the constructor or via `Random.seed!`), i.e. no random seed will
  be chosen for the user as is the case in e.g. `MersenneTwister()`."

### Generator (`StableRNG`)

**Decision.** Seeds use StableRNGs.jl, so the random numbers for a seed are the same on
every Julia version.

- Julia's own generators may change their streams: [JuliaRandom] "a minor release of
  Julia (e.g. 1.3 to 1.4) *may change* the sequence of pseudorandom numbers generated
  from a specific seed." The manual gives the reason: "Rationale: guaranteeing that
  pseudorandom streams never change prohibits many algorithmic improvements."
- The manual points to StableRNGs for stable streams: [JuliaRandom] "Software tests
  that rely on *specific* 'random' data should also generally either save the data,
  embed it into the test code, or use third-party packages like StableRNGs.jl."
- What the package promises: [StableRNGs] "This package intends to provide a simple RNG
  with *stable* streams, suitable for tests in packages which need reproducible streams
  of random numbers across Julia versions." and "The `StableRNG` type provided by this
  package strives for stability, but if bugs which require breaking this promise are
  found, a new major version will be released with the fix."
- Only part of the API is stable: [StableRNGs] "The stable (guaranteed) API is"
  construction, seeding, `rand`, `randn` and `randexp` for the standard bit types, their
  array versions, `rand(rng, ::AbstractArray)`, `shuffle` and `randperm`. SoftPack's
  draws must use only these calls, and in a fixed order. **SoftPack note.**

### Provenance record

**Decision.** Every output records the SoftPack version, the git commit, the Julia
version, the seed and the RNG. Together with every setting
([§6](06-packing-that-does-not-converge.md), [§7](07-algorithms-and-combinations.md)) and
every particle's diameter and mass ([§3](03-particle-size-distribution-and-length-unit.md),
[§4](04-mass.md)), this identifies how the packing was made.

- The Julia manual's advice for exact reproducibility is to keep the data and the
  versions: [JuliaRandom] "If you need to guarantee exact reproducibility of random
  data, it is advisable to simply *save the data* (e.g. as a supplementary attachment
  in a scientific publication). (You can also, of course, specify a particular Julia
  version and package manifest, especially if you require bit reproducibility.)" The
  output file is that saved data ([§11](11-outputs.md)).
- The git commit identifies code between releases; the SoftPack version alone does not.
  **SoftPack choice.**

## Options

```julia
pack(seed = 42)
```

Any allowed seed gives another packing from the same distribution of packings. There
is no option to choose another generator.

## Worked numbers

Computed in Julia 1.12.7 with StableRNGs 1.1.0, and checked against the formulas above
in Python. **SoftPack note.**

| Quantity | Value |
|---|---|
| Largest allowed seed | $2^{64}-1 = 18446744073709551615$ |
| Number of allowed seeds | $2^{64} \approx 1.8\times10^{19}$ |
| First state for `seed = 1` | $s_0 = 3$ |
| `rand(StableRNG(1), UInt64)` | 15053665437044804691 |
| `rand(StableRNG(1), 3)` | `[0.5851946422124186, 0.07733793456911231, 0.7166282400543453]` |
| Step of the first `rand` between consecutive seeds | 0.3901297614749457 (mod 1) |
| Step of the second `rand` between consecutive seeds | 0.0515586230460747 (mod 1) |

The `rand(StableRNG(1), 3)` row can serve as a stream check in SoftPack's tests: it
must not change when Julia is upgraded.

## Open questions

- **Seed range.** The design doc's §0 allows "any integer"; `StableRNG` rejects
  negative seeds and seeds above $2^{64}-1$. Whether `pack()` checks the seed itself or
  maps other integers into the allowed range is not designed.
- **Seeds for an ensemble.** Consecutive seeds give related streams
  ([derivation](#consecutive-seeds-give-related-streams)). Options include drawing
  per-run seeds from one master `StableRNG`, or scrambling the seed before use. Not
  designed; to be checked against ensemble statistics.
- **What "RNG" records.** Whether the record includes the StableRNGs package version,
  which changes when the stream changes (new major version).
- **Order of draws.** Which quantities are drawn first (diameters, then the initial
  state) is part of SoftPack's own stream; changing it changes every packing for a
  given seed. It depends on the initial state, which is not designed.
- **Threads.** Whether a run gives the same packing with a different number of threads
  (summation order) is not specified.

## Related pages

- [§3 Particle size distribution and length unit](03-particle-size-distribution-and-length-unit.md):
  the random diameters.
- [§6 A packing that does not converge](06-packing-that-does-not-converge.md): exact
  restarts, retries with other seeds.
- [§11 Outputs](11-outputs.md): where the provenance record is stored.
- [§0 Every default at a glance](00-every-default-at-a-glance.md),
  [Notation](notation.md), [References](references.md).

## References

- **[JuliaRandom]** The Julia Project. *Random Numbers, The Julia Language manual (Reproducibility section)*. <https://docs.julialang.org/en/v1/stdlib/Random/>. Accessed 2026-11-18.
- **[LAMMPSreadrestart]** LAMMPS developers. *LAMMPS documentation: read_restart command*. <https://docs.lammps.org/read_restart.html>. Accessed 2026-11-19.
- **[StableRNGs]** JuliaRandom. *StableRNGs.jl*. <https://github.com/JuliaRandom/StableRNGs.jl>. Accessed 2026-11-18.
