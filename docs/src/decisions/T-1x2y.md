# T-1x2y: section 0 and the public types

*Up:* [Design decisions](index.md)

**Question.** Section 0 was meant to list every setting but omitted keywords used
elsewhere, and several public types were never defined.

**Choice.** Every keyword appears once in [`PackParams`](../pack/PackParams.md) with its
default, the `Packing` fields are listed on [its page](../pack/Packing.md), and the
Documenter tree gives each setting a page. The suffix `max` is allowed (`steps_max`,
`uphill_max`, `timestep_max`) because it reads as a statement and no better word is
shorter.

**Why.** A list of defaults is only useful if it is complete: a user who has to grep the
source for a default will not trust the list for the next setting either. `max` was the
only naming rule that the existing keywords already broke, so the rule moved rather than
the keywords.

**Status.** In docs; the design document's section 0 gains an appendix pointing here.

## Archival reference

- [Interface and naming](https://github.com/ColtonKawamura/SoftPack/wiki/Interface-and-naming)
