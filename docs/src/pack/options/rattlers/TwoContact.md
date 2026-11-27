# `TwoContact()`

*Up:* [`rattlers`](index.md)

Remove every particle with two or fewer contacts (design §9), repeating the removal until
the network stops changing. It is the strict version of `ContactCount()`: even a frictional
packing, where two contacts can hold a particle, loses its two-contact particles.

This is the rule to use when the backbone should have at least three contacts per particle
at every friction coefficient, for example when comparing with a measurement that defines
the contact network that way.

The `cone_test` flag is accepted for a uniform interface, but the current implementation
applies the cone test only under `ContactCount()` (PROVISIONAL: the design intends the
cone test to accompany every rule; the other rules either already remove two-contact
particles or are force-based).

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `cone_test` | `true` | accepted; the cone test currently runs only for `ContactCount()` |

## Archival reference

- [TwoContact(cone_test = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#twocontactcone_test--)
- [TwoContact](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#twocontact)
