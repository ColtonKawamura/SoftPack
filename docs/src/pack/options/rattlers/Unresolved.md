# `Unresolved()`

*Up:* [`rattlers`](index.md)

A contact whose normal force is below the run's convergence tolerance, times the mean
contact force, does not count as a contact [Agnolin2007]. The particle then needs two
effective contacts and the removal cascades.

Two contacts, not the $D + 1$ of `ContactCount()` and `ForceFloor()`, is [Agnolin2007]'s
rule: they remove a particle held by fewer than two contacts, and the cascade repeats.
It is stricter than the isostatic count for a frictionless packing in 2D, so run this
rule alongside `ContactCount()` if the isostatic count is the number you need.

The idea is that a contact below the tolerance is one the minimization did not resolve: it
may be an artifact of the final numbers rather than a physical contact, so a particle held
only by such contacts is not really held. Because the threshold follows the convergence
tolerance, a loose run removes more particles than a tight one, which is the honest
behavior: a loose run cannot tell a weak contact from a resolved one.

`floor = :tolerance` (the default) uses the convergence tolerance; a number overrides it.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `floor` | `:tolerance` | the threshold relative to the mean force, or `:tolerance` |
| `cone_test` | `true` | accepted; the cone test currently runs only for `ContactCount()` |

## Example

```julia
using SoftPack

packing = pack(
    rattlers = Unresolved(
        floor = :tolerance,
        cone_test = true,
    ),
    particles_count = 256,
    seed = 1,
)
count(packing.rattlers)
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
