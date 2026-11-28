# `TwoContact()`

*Up:* [`rattlers`](index.md)

Remove every particle with two or fewer contacts (design §9), repeating the removal until
the network stops changing. It is the strict version of `ContactCount()`: even a frictional
packing, where two contacts can hold a particle, loses its two-contact particles.

It has no `cone_test` (card T-hg7w): a particle with two contacts is removed whether or
not its friction cones could hold it, so the test would never be reached.

This is the rule to use when the backbone should have at least three contacts per particle
at every friction coefficient, for example when comparing with a measurement that defines
the contact network that way.

## Options

None.

## Archival reference

- [TwoContact(cone_test = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#twocontactcone_test--)
- [TwoContact](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#twocontact)
