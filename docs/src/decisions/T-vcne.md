# T-vcne: FIRE core rules

*Up:* [Design decisions](index.md)

**Question.** The design text and the wiki's pseudocode disagreed by one step on the
delay and uphill counters and on when the mixing coefficient shrinks and resets, so the
default FIRE trajectory was not defined.

**Choice.** The wiki's Algorithm 2, which is what LAMMPS `min_fire.cpp` does. The step
grows only after *more than* `delay` downhill steps, and the run stops after *more than*
`uphill_max` uphill steps. The mixing coefficient shrinks on every downhill step after
the delay, including while the step sits at its ceiling; every counted uphill step resets
it. A shrink that would cross `timestep_min` is skipped rather than clamped. Uphill steps
inside the initial delay change nothing. The mixing acts on the kicked velocity, its
magnitude is the speed before the kick, and the forces are evaluated again after the half
step back.

**Why.** The pseudocode is the version that has a derivation, and it matches the LAMMPS
source, so a reader can check one implementation against another. The alternative was to
keep the prose and change the pseudocode, which would have left the default trajectory
defined only by a sentence.

**Status.** In code (`src/fire.jl`); the default run's 87,757 steps pin it.

## Archival reference

- [FIRE settings](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings)
