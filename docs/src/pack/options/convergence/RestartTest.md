# `RestartTest()`

*Up:* [`convergence`](index.md)

The check for saddles (design §5). It first requires the `RelativeForce` test at its
default tolerance, then zeroes the velocities on the final packing, relaxes once more, and
asks whether the kinetic energy and the unbalanced forces stay down. A packing that passes
the force test but drifts as soon as it is nudged was sitting on a saddle or on a
marginal contact, and the restart test catches it.

It has no options: the force tolerance is the `RelativeForce` default, $10^{-8}$.

This is the most expensive test of the five, because it runs a second short minimization
for every acceptance.

## Archival reference

- [RestartTest](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion#restarttest)
