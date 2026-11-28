# `friction`

*Up:* [Available options](../index.md)

Friction is the tangential force at a contact. With friction on, two touching particles
also carry a tangential spring: the tangential displacement since the contact was made is
stored, the spring pulls back along it, and the force is capped by Coulomb's condition

$$|f_t| \le \mu f_n,$$

with $\mu$ the friction coefficient (design §13). A contact whose tangential force sits
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

## Archival reference

- [Friction models](https://github.com/ColtonKawamura/SoftPack/wiki/Friction-models)
- [Frictionless contacts](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#frictionless-contacts)
