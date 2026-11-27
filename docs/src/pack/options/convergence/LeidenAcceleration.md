# `LeidenAcceleration()`

*Up:* [`convergence`](index.md)

The test used by the Leiden group (design §5): every particle's acceleration must be
below a tolerance in reduced units,

$$\max_i |a_i| < \varepsilon \, \frac{k \, d_\text{ref}}{m_\text{ref}},$$

with $k$ the contact stiffness and $d_\text{ref}$, $m_\text{ref}$ the reference diameter
and mass. The right-hand side is the acceleration a contact force of $k d_\text{ref}$
would give the reference mass, so $\varepsilon$ is again relative.

`LeidenAcceleration()` replaces the `RelativeForce` test for the force balance; the
pressure band is asked separately, as for every test.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `tolerance` | `1e-10` | $\varepsilon$, relative to the contact acceleration |

## Archival reference

- [LeidenAcceleration(tolerance = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion#leidenaccelerationtolerance--)
