# `CollisionTime()`

*Up:* [`timestep`](index.md)

The starting step is a fraction of the elastic contact time of the lightest pair
[Silbert2001], [OSullivan2004]. For a linear contact law the time of a half oscillation is
$\pi\sqrt{M/k}$, so

$$\Delta t_0 = \text{fraction} \times \pi \sqrt{\frac{M}{k}},$$

with $M$ the reduced mass of the lightest pair, $\tfrac{1}{2}\mathrm{min}_i m_i$. For a Hertzian
law the stiffness is evaluated at the largest overlap the run expects, which is estimated
from the target pressure, because the stiffness at zero overlap is zero.

With friction the tangential contact can be the stiffer one, so the rule takes the
smaller of the normal and tangential times,

$$\Delta t_0 = \text{fraction} \times \pi \mathrm{min}\left(\sqrt{\frac{M_n}{k_n}}, \sqrt{\frac{M_t}{k_t}}\right),$$

where the tangential mass $M_t = M_n/(1 + 1/\kappa)$ includes the particle's rotation
($\kappa = 1/2$ for a disk, $2/5$ for a sphere).

## Why it is the default

The default fraction is $1/50$, a twentieth of the collision time, which is a safe step for
FIRE's semi-implicit Euler and for the lagged integrators.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `fraction` | `1/50` | the fraction of the contact time |

## A fixed step instead

A number is read in units of $\tau = \sqrt{m_{\mathrm{min}}/k}$, the elastic time of the lightest
particle, so the same number is the same physical step whatever the mass
distribution; with the default stiffness and equal masses, a fixed 0.02 corresponds to
`CollisionTime(fraction = f)` with $f = 0.02\sqrt{2}/\pi \approx 0.0090$.

## Example

```julia
using SoftPack

packing = pack(
    timestep = CollisionTime(
        fraction = 1/50,  # Delta t = t_col / 50
    ),
    particles_count = 256,
    seed = 1,
)
packing.timestep_start
```

## References

- **[Silbert2001]** Leonardo E. Silbert, Deniz Ertaş, Gary S. Grest, Thomas C. Halsey, Dov Levine, Steven J. Plimpton (2001). *Granular flow down an inclined plane: Bagnold scaling and rheology*. Physical Review E **64**, 051302. [doi:10.1103/physreve.64.051302](https://doi.org/10.1103/physreve.64.051302).
- **[OSullivan2004]** Catherine O'Sullivan, Jonathan D. Bray (2004). *Selecting a suitable time step for discrete element simulations that use the central difference time integration scheme*. Engineering Computations **21**, 278--303. [doi:10.1108/02644400410519794](https://doi.org/10.1108/02644400410519794).
