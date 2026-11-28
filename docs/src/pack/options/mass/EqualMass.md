# `EqualMass()`

*Up:* [`mass`](index.md)

Every particle has the same mass, $m = 1$ by default [OHern2003]. The mass reference
$m_\text{ref}$ is that mass, so the run's reduced units are the ones of a single
monodisperse species.

## Why it is the default

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

## Example

```julia
using SoftPack

packing = pack(
    mass = EqualMass(
        mass = 1.0,  # every particle has mass 1
    ),
    particles_count = 256,
    seed = 1,
)
packing.masses[1]
```

## References

- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
