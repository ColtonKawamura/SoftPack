# `ContactDamping()`

*Up:* [`damping`](index.md)

The dashpot coefficient follows the contact time (design §8):

$$\gamma_n = 2 \zeta_n \sqrt{k_n M_n}, \qquad \gamma_t = 2 \zeta_t \sqrt{k_t M_t},$$

with $M_n$ the reduced mass of the pair and $M_t$ the tangential effective mass. The
default ratio is $\zeta = 0.98$ for both directions, close to critical damping: the
contact is almost critically damped, so it neither rings nor crawls.

The tangential mass includes the particle's rotation,
$M_t = M_n/(1 + 1/\kappa)$ with $\kappa = 1/2$ for a disk and $2/5$ for a sphere, because
the tangential spring turns the particles as well as translating them. With equal masses
the coefficient is proportional to $\sqrt{k}$ for both directions, so `ContactDamping` on a
single contact law gives a stiffness-proportional damping matrix, $\Gamma \propto K$, and
the dashpots scale with the stiffness when the stiffness changes.

With friction, a contact that is sliding drops its tangential dashpot: the tangential
force is on the Coulomb cap, so a tangential velocity cannot do work against it.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `normal` | `0.98` | $\zeta_n$, the normal damping ratio |
| `tangential` | `0.98` | $\zeta_t$, the tangential damping ratio |
| `tangential_mass` | `:with_rotation` | $M_t$ includes rotation; `:pair` uses the pair mass |
| `attractive` | `false` | whether the dashpot can pull |
| `coulomb_limit` | `:elastic` | which normal force caps the tangential dashpot |

## Archival reference

- [Contact damping](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#contact-damping)
