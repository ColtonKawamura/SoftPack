# `LeidenAcceleration()`

*Up:* [`convergence`](index.md)

The test used by the Leiden group [Somfai2005], [Shundyak2007]: every particle's
acceleration must be below a tolerance in reduced units,

$$\max_i |a_i| < \varepsilon \, \frac{k \, d_\text{ref}}{m_\text{ref}},$$

with $k$ the contact stiffness and $d_\text{ref}$, $m_\text{ref}$ the reference diameter
and mass. The right-hand side is the acceleration a contact force of $k d_\text{ref}$
would give the reference mass, so $\varepsilon$ is again relative.

With friction the rotational part counts too: the angular acceleration
$|\mathbf T_i|/I_i$, times $d_\text{ref}$ so that it carries the same units, must be below
the same threshold. The paper states the translational rule only; including the rotation
is a SoftPack choice, since a particle spinning in place is not at rest.

`LeidenAcceleration()` replaces the `RelativeForce` test for the force balance; the
pressure band is asked separately, as for every test.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `tolerance` | `1e-10` | $\varepsilon$, relative to the contact acceleration |

## Example

```julia
using SoftPack

packing = pack(
    convergence = LeidenAcceleration(
        tolerance = 1e-10,  # acceleration in reduced units
    ),
    particles_count = 256,
    seed = 1,
)
packing.converged
```

## References

- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
- **[Shundyak2007]** Kostya Shundyak, Martin van Hecke, Wim van Saarloos (2007). *Force mobilization and generalized isostaticity in jammed packings of frictional grains*. Physical Review E **75**, 010301. [doi:10.1103/physreve.75.010301](https://doi.org/10.1103/physreve.75.010301).
