# `friction`

*Up:* [Available options](../index.md)

Friction is the tangential force at a contact. With friction on, two touching particles
also carry a tangential spring: the tangential displacement since the contact was made is
stored, the spring pulls back along it, and the force is capped by Coulomb's condition

$$|f_t| \le \mu f_n,$$

with $\mu$ the friction coefficient [Somfai2005], [Santos2024]. A contact whose tangential force sits
on the cap is sliding; the strain it has stored then stops growing. The stored
displacement is dropped when the contact breaks.

Friction is a model with history, so it needs the contact table to carry one tangential
spring per pair, and the particles to carry rotation: one angle per particle in 2D and a
rotation vector in 3D. It is also what makes packings marginal: at the same pressure a
frictional packing is looser and its coordination number falls toward the isostatic value
$z_\text{iso} = D + 1$, which is 3 for disks and 4 for spheres, instead of the
frictionless $2D$.

**Default:** `nothing` (frictionless)

## Choices

| Choice | Default | Tangential stiffness |
|:---|:---|:---|
| `nothing` | **default** | no tangential force |
| [`CundallStrack()`](CundallStrack.md) |  | fixed ratio to the normal one |
| [`Mindlin()`](Mindlin.md) |  | Hertz-Mindlin, growing with the overlap; needs `Hertzian()` |

## Measured effect

At $P = 10^{-4}$, $N = 256$, 2D, FIRE: $\phi = 0.8160$ at $\mu = 0.1$, $0.7927$ at
$\mu = 0.3$ and $0.7825$ at $\mu = 0.5$, against $0.8387$ frictionless.

## Example

```julia
using SoftPack

packing = pack(
    friction = CundallStrack(
        friction_coefficient = 0.3,
    ),
    particles_count = 256,
    seed = 1,
)
packing.packing_fraction
```

## References

- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
- **[Santos2024]** A. P. Santos, Ishan Srivastava, Leonardo E. Silbert, Jeremy B. Lechman, Gary S. Grest (2024). *Protocol-dependent frictional granular jamming simulations: cyclical, compression, and expansion*. Frontiers in Soft Matter **3**, 1326756. [doi:10.3389/frsfm.2023.1326756](https://doi.org/10.3389/frsfm.2023.1326756).
