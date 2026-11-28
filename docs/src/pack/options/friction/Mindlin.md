# `Mindlin()`

*Up:* [`friction`](index.md)

The Hertz-Mindlin tangential force [Somfai2005], [Shundyak2007]. The tangential stiffness is proportional
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

```julia
using SoftPack

packing = pack(
    contact = Hertzian(),
    friction = Mindlin(
        friction_coefficient = 0.3,
        poisson_ratio = 0.0,  # eta = 1, so k_t = k_n
    ),
    particles_count = 256,
    seed = 1,
)
packing.contact_number
```

## References

- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
- **[Shundyak2007]** Kostya Shundyak, Martin van Hecke, Wim van Saarloos (2007). *Force mobilization and generalized isostaticity in jammed packings of frictional grains*. Physical Review E **75**, 010301. [doi:10.1103/physreve.75.010301](https://doi.org/10.1103/physreve.75.010301).
