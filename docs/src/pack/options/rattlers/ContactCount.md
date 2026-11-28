# `ContactCount()`

*Up:* [`rattlers`](index.md)

Remove every particle that does not have enough contacts to be held (design §9). Without
friction a particle needs $D + 1$ contacts: three in 2D and four in 3D. With friction two
are enough, because a pair of contacts inside the friction cones can hold it.

The rule is applied repeatedly. Each round rebuilds the network without the particles
already removed; a neighbor that drops below the threshold goes too, and the rounds stop
when a round changes nothing. Removing a particle takes contacts away from its neighbors,
so a packing just above its rigidity threshold can lose a chain of particles from one seed.

This is the default rule because it is the one that matches the isostatic argument: at low
pressure the backbone should have exactly the number of contacts that rigidity requires.

## The cone test

With friction, a particle with exactly two contacts can only be held if its two contact
forces can point into the friction cones. The two contact directions enclose an angle
$\theta$, and a pair of forces inside the cones can only balance when

$$\theta \ge \pi - 2\arctan \mu.$$

With $\mu = 0.3$ that is $\theta \ge 146^\circ$: the two contacts must be nearly opposite.
A two-contact particle that fails the test is removed, because no force it can transmit
would hold it. `cone_test = true` (the default) applies it.

The cone test runs under every rule except `TwoContact()`, which removes two-contact
particles before the test could matter (card T-hg7w). It sees only contacts above the
rule's force floor, so a contact the rule has already declared broken cannot keep a
particle.

The cone test is also where a bug in an earlier version emptied whole frictional packings:
the direction from a particle to its contact point is $-n$ when the particle is the first
member of the pair and $+n$ when it is the second, and using $n$ for both mixed the angle
with its complement.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `cone_test` | `true` | apply the friction-cone test to two-contact particles |

## Archival reference

- [ContactCount(cone_test = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#contactcountcone_test--)
- [ContactCount (default)](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#contactcount-default)
- [Cone test geometry](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#cone-test-geometry)
