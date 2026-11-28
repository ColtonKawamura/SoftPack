# `ForceFloor()`

*Up:* [`rattlers`](index.md)

A contact whose normal force is below a fraction of the mean contact force does not count
as a contact (design §9):

$$f_n < \text{floor} \times \langle f_n \rangle .$$

The particle then needs $D + 1$ effective contacts without friction, or two with
friction, exactly like `ContactCount()` (card T-hg7w), and the removal cascades as usual.
With the default floor $10^{-3}$, contacts that carry a thousandth of the mean force are
treated as broken, so a particle held only by such contacts is removed.

The rule is a compromise: `ContactCount()` ignores forces and can keep a particle that is
barely touching, while `Unresolved()` uses the convergence tolerance and can be too strict
at a loose tolerance. `ForceFloor()` puts the threshold where you set it.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `floor` | `1e-3` | the force threshold, relative to the mean contact force |
| `cone_test` | `true` | apply the friction-cone test to two-contact particles |

## Archival reference

- [ForceFloor(floor = …, cone_test = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#forcefloorfloor---cone_test--)
- [ForceFloor](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#forcefloor)
