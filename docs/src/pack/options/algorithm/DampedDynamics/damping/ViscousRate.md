# `ViscousRate()`

*Up:* [`damping`](index.md)

The dashpot is a fixed rate per unit mass (design §8):

$$\gamma_n = M_n r_n, \qquad \gamma_t = M_t r_t,$$

with $r$ in inverse time. Because the coefficient does not depend on the stiffness, it does
not change when the contact law or the stiffness changes, which makes it the right choice
when you want a relaxation time you control rather than one the contact sets.

The default rate is 0.5 for both directions, a damping time of two in reduced units.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `normal` | `0.5` | $r_n$, the normal rate |
| `tangential` | `0.5` | $r_t$, the tangential rate |
| `attractive` | `false` | whether the dashpot can pull |
| `coulomb_limit` | `:elastic` | which normal force caps the tangential dashpot |

## Archival reference

- [Viscous rate](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#viscous-rate)
