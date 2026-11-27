# `CollisionTime()`

*Up:* [`timestep`](index.md)

The starting step is a fraction of the elastic contact time of the lightest pair (design
§12). For a linear contact law the time of a half oscillation is
$\pi\sqrt{M/k}$, so

$$\Delta t_0 = \text{fraction} \times \pi \sqrt{\frac{M}{k}},$$

with $M$ the reduced mass of the lightest pair, $\tfrac{1}{2}\min_i m_i$. For a Hertzian
law the stiffness is evaluated at the largest overlap the run expects, which is estimated
from the target pressure, because the stiffness at zero overlap is zero.

With friction the tangential contact can be the stiffer one, so the rule takes the
smaller of the normal and tangential times,

$$\Delta t_0 = \text{fraction} \times \pi \min\left(\sqrt{\frac{M_n}{k_n}}, \sqrt{\frac{M_t}{k_t}}\right),$$

where the tangential mass $M_t = M_n/(1 + 1/\kappa)$ includes the particle's rotation
($\kappa = 1/2$ for a disk, $2/5$ for a sphere).

The default fraction is $1/50$, a twentieth of the collision time, which is a safe step for
FIRE's semi-implicit Euler and for the lagged integrators.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `fraction` | `1/50` | the fraction of the contact time |

## A fixed step instead

```
pack(timestep = 0.02)
```

A number is read in units of $\sqrt{m_\text{ref}/k}$; with the default stiffness and
equal masses that is the same number as the `CollisionTime` value with fraction 0.02.

## Archival reference

- [Time step](https://github.com/ColtonKawamura/SoftPack/wiki/Time-step)
