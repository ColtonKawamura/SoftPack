# T-tx4b: stability with damping

*Up:* [Design decisions](index.md)

**Question.** The design called its stability margins "worst case" and "at least about
2.6", while the wiki says they are estimates from the mean contact number; FIRE's
adaptive step could also exceed the damped stability limit.

**Choice.** The margins are estimates from the mean coordination, and the pages now say
so instead of claiming a bound. The 1/20 rule is dropped. `DampedDynamics` computes the
stable step from the measured largest contact frequency and warns when the chosen step
exceeds it. When `damping` is set on FIRE, FIRE's step ceiling is clamped to that same
damped limit. `steps_max` is quoted in steps only, never converted to a physical time.

**Why.** A "worst case" that is computed from a mean is not a bound, and calling it one
invites a user to trust a run that will blow up. Measuring the packing's own stiffest
contact is honest and cheap: it needs one pass over the contacts per run, and it turns
an unexplained blow-up into a warning at the start.

**Status.** In code (`check_timestep`, `fire.jl`). The numbers 0.0765, 0.0520 and
0.2675 $t_\text{col}$ stand in the reference pages.

## Archival reference

- [Damping](https://github.com/ColtonKawamura/SoftPack/wiki/Damping)
