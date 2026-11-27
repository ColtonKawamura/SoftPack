# `KineticEnergy()`

*Up:* [`convergence`](index.md)

A test for dynamics rather than minimization (design §5): the packing must be at rest,

$$\frac{1}{N}\sum_i \tfrac{1}{2} m_i |v_i|^2 < \varepsilon \, P_\text{target} \, d_\text{ref}^D,$$

and the ordinary `RelativeForce` test must hold at its default tolerance. The right-hand
side is the energy scale of the target pressure, so a run at a lower pressure is asked for
a correspondingly lower kinetic energy.

It exists for damped dynamics, where the velocities are physical and a packing can be
mechanically balanced while one particle still drifts. FIRE manages its velocities itself,
so with FIRE the plain force test is the natural one.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `tolerance` | `1e-8` | $\varepsilon$, relative to the pressure energy scale |

## Archival reference

- [KineticEnergy(tolerance = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion#kineticenergytolerance--)
