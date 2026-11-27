# `Unresolved()`

*Up:* [`rattlers`](index.md)

A contact whose normal force is below the run's convergence tolerance, times the mean
contact force, does not count as a contact (design §9). The particle then needs two
effective contacts and the removal cascades.

The idea is that a contact below the tolerance is one the minimization did not resolve: it
may be an artifact of the final numbers rather than a physical contact, so a particle held
only by such contacts is not really held. Because the threshold follows the convergence
tolerance, a loose run removes more particles than a tight one, which is the honest
behaviour: a loose run cannot tell a weak contact from a resolved one.

`floor = :tolerance` (the default) uses the convergence tolerance; a number overrides it.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `floor` | `:tolerance` | the threshold relative to the mean force, or `:tolerance` |
| `cone_test` | `true` | accepted; the cone test currently runs only for `ContactCount()` |

## Archival reference

- [Unresolved(floor = …, cone_test = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#unresolvedfloor---cone_test--)
- [Unresolved](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#unresolved)
