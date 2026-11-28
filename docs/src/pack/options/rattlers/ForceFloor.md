# `ForceFloor()`

*Up:* [`rattlers`](index.md)

A contact whose normal force is below a fraction of the mean contact force does not count
as a contact [Shundyak2007]:

$$f_n < \text{floor} \times \langle f_n \rangle.$$

The particle then needs $D + 1$ effective contacts without friction, or two with
friction, exactly like `ContactCount()`, and the removal cascades as usual.
With the default floor $10^{-3}$, contacts that carry a thousandth of the mean force are
treated as broken, so a particle held only by such contacts is removed.

The rule is a compromise: `ContactCount()` ignores forces and can keep a particle that is
barely touching, while `Unresolved()` uses the convergence tolerance and can be too strict
at a loose tolerance. `ForceFloor()` puts the threshold where you set it.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `floor` | `1e-3` | the force threshold, relative to the mean contact force |
| `cone_test` | `true` | apply the friction-cone test to two-contact particles |

## Example

```julia
using SoftPack

packing = pack(
    rattlers = ForceFloor(
        floor = 1e-3,
        cone_test = true,
    ),
    particles_count = 256,
    seed = 1,
)
count(packing.rattlers)
```

## References

- **[Shundyak2007]** Kostya Shundyak, Martin van Hecke, Wim van Saarloos (2007). *Force mobilization and generalized isostaticity in jammed packings of frictional grains*. Physical Review E **75**, 010301. [doi:10.1103/physreve.75.010301](https://doi.org/10.1103/physreve.75.010301).
