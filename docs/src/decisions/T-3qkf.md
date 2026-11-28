# T-3qkf: FIRE with friction, density masses, damping

*Up:* [Design decisions](index.md)

**Question.** FIRE was allowed with every other setting, but several combinations had no
defined behaviour: spins under mixing, masses that differ, dashpots with an adaptive
step, and a step that could grow without a displacement check.

**Choice.** The parts that are in code now: FIRE checks its parameters at the call
(`timestep_min <= timestep_max`, `timestep_grow >= 1`, `0 < timestep_shrink <= 1`,
non-negative delay), warns once that FIRE with friction is non-standard, and clamps its
step to the damped stability limit when `damping` is set. The rest of the card is adopted
but not yet coded: the mass-weighted mixing norm, spins scaled by $\sqrt{I/m}$ so the
norm is twice the kinetic energy, and the `displacement_max` keyword with its 0.1 $d$
default.

**Why.** The parameter checks and the damping cap are safety rules that cannot change a
valid run, so they ship now. The mass-weighted mixing changes the trajectory whenever the
masses differ, and it needs its own tests and a re-baselined default; doing it in the same
change as the rest would have hidden a physics change inside a validation patch.

**Status.** Partly in code; the mixing and `displacement_max` are queued.

## Archival reference

- [FIRE settings](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings)
