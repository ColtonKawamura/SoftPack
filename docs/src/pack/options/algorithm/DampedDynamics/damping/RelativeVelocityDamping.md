# `RelativeVelocityDamping()`

*Up:* [`damping`](index.md)

One dashpot on the full relative velocity, normal and tangential at once (design §8):

$$f_\text{damp} = -M r \, v_\text{rel},$$

with a single rate $r$ (default 0.5). Because the force follows the velocity vector rather
than the contact normal, it damps sliding and approach together and needs no separate
tangential spring.

It is the simplest model to reason about and the one that most resembles a viscous fluid;
it is not the model of a contact, so its damping does not scale with the stiffness.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `rate` | `0.5` | $r$, the damping rate |
| `attractive` | `false` | whether the dashpot can pull |
| `coulomb_limit` | `:elastic` | which normal force caps the tangential part |

## Archival reference

- [Relative velocity damping](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#relative-velocity-damping)
