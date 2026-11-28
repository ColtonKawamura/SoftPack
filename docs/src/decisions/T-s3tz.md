# T-s3tz: exact restarts

*Up:* [Design decisions](index.md)

**Question.** The design promised a bit-for-bit continuation but listed an incomplete
state, and the restart keyword rules were ambiguous.

**Choice.** The restart file holds everything the run changes: positions, velocities,
rotations and spins, accelerations, the contact history (including the tangential springs
and the sliding flags), the wall springs, the compression state (accepted side, strain,
counters, whether a trial is open), the FIRE step and counters, the settings and the
provenance. A restart may change only `steps_max`, `failure_action`, `convergence`,
`restart_file`, `snapshots`, `movie` and `pressure_tolerance`; any other keyword is an
error even when it equals the stored value. An omitted `steps_max` starts a fresh budget
counted from the restart, and a schedule counts `every` from the step the job resumed at.

**Why.** Every item in that list is one that a run reads back; leaving one out makes the
continuation differ in the last bits, which is exactly what the promise forbids. The
strict keyword rule is the same idea: passing a physics keyword at a restart says the user
expects it to do something, and it cannot.

**Status.** In code. The test stops a run, restarts it, and compares positions with a
maximum difference of zero.

## Archival reference

- [A packing that does not converge](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge)
