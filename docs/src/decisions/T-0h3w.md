# T-0h3w: what to inherit from GranEJulia

*Up:* [Design decisions](index.md)

**Question.** The old generator differs from the design in ten verified ways; each one
was a choice between staying compatible with existing data and starting clean.

**Choice.** Keep the design on every point. Parity with old packings is checked
statistically, not bit-for-bit, because the old code has no determinism guarantee and its
trajectories cannot be reproduced. No presets were added: a preset would be a second,
silently different physics, and the only reason to add one is a parity test that needs it,
and no such test exists yet. The `10^7` step cap is justified against the frictional path,
as the card asks, not against the old code's timings.

**Why.** A preset is a compatibility promise that has to be maintained and tested for
every later change. The old packings are still readable as data; the way to compare them
with SoftPack results is an ensemble comparison (packing fraction, coordination, contact
statistics), not a trajectory match, which the old code never made reproducible.

**Status.** Recorded; no code. The design document records why JLD2 is not offered (section 11).

## Archival reference

- [GranE](https://github.com/ColtonKawamura/GranE)
