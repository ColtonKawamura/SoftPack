# `EqualMass()`

*Up:* [`mass`](index.md)

Every particle has the same mass, $m = 1$ by default (design §4). The mass reference
$m_\text{ref}$ is that mass, so the run's reduced units are the ones of a single
monodisperse species.

Equal masses are the usual choice for frictionless packings, where rotation does not
enter. They also make contact damping simpler: with the matched damping ratio
$\gamma_n = 2\zeta_n\sqrt{k_n M_n}$, the reduced mass $M_n$ is the same for every pair and
the dashpot constant is proportional to $\sqrt{k_n}$, so a run with equal masses and one
contact law has a stiffness-proportional damping, $\Gamma \propto K$.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `mass` | `1.0` | the mass of every particle, in reduced units |

Both `EqualMass()` and `EqualMass(mass = 2.0)` work.

## Archival reference

- [EqualMass(…)](https://github.com/ColtonKawamura/SoftPack/wiki/Mass#equalmass)
- [Equal masses make contact damping proportional to stiffness](https://github.com/ColtonKawamura/SoftPack/wiki/Mass#equal-masses-make-contact-damping-proportional-to-stiffness)
