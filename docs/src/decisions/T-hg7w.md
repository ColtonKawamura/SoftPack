# T-hg7w: rattler rules

*Up:* [Design decisions](index.md)

**Question.** The four rules differed in small ways the design did not decide, so the
same packing could give different backbones.

**Choice.** Every rule repeats until nothing changes, including `Unresolved`. `ForceFloor`
needs $D+1$ contacts without friction, like `ContactCount`, and two with friction. The
cone test sees only contacts above the rule's force floor, and it applies to every rule
except `TwoContact`, which has no `cone_test` because it removes two-contact particles
before the test could matter. `Unresolved` with `floor = :tolerance` refuses a convergence
test that has no force tolerance (such as `RestartTest`) and asks for an explicit floor.

**Why.** A rule that removes particles once leaves a backbone that depends on the order
of the pass; repeating makes the result a fixed point. Requiring $D+1$ without friction is
the isostatic argument, and a force floor that ignores the floor when building the network
would test geometry of contacts it has already declared broken.

**Status.** In code (`src/rattlers.jl`). The `ForceFloor` minimum changed in this
decision, so a frictionless `ForceFloor` run now removes the same particles as
`ContactCount` when the floors agree.

## Archival reference

- [Rattler rules](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules)
