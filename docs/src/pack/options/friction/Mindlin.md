# `Mindlin()`

*Up:* [`friction`](index.md)

The Hertz-Mindlin tangential force (design §13). The tangential stiffness is proportional
to the normal one,

$$k_t = \eta k_n, \qquad \eta = \frac{2(1 - \nu)}{2 - \nu},$$

with $\nu$ the Poisson ratio, so the tangential stiffness grows with the overlap in the
same way the Hertzian normal stiffness does. The Coulomb cap and the sliding rule are the
same as for `CundallStrack()`.

`Mindlin()` needs `Hertzian()` contacts: with a linear normal law the ratio $\eta$ has
nothing to scale. The default Poisson ratio of 0.0 gives $\eta = 1$, equal normal and
tangential stiffness at every overlap.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `friction_coefficient` | `0.5` | $\mu$ in the Coulomb cap |
| `poisson_ratio` | `0.0` | $\nu$ in $\eta = 2(1-\nu)/(2-\nu)$; must lie between -1 and 0.5 |

## Example

```
pack(contact = Hertzian(), friction = Mindlin(friction_coefficient = 0.3, poisson_ratio = 0.2))
```

## Archival reference

- [Mindlin(friction_coefficient = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Friction-models#mindlinfriction_coefficient--)
- [Mindlin](https://github.com/ColtonKawamura/SoftPack/wiki/Friction-models#mindlin)
