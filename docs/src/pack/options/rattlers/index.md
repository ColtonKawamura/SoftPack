# `rattlers`

*Up:* [Available options](../index.md)

A rattler is a particle that carries no load [Xiong2019], [Gilabert2007]: it touches too few neighbors, or its
contacts are arranged so that no combination of forces inside the friction cones can hold
it. Rattlers are part of the packing but not part of its backbone, and leaving them in
distorts the coordination number, so SoftPack marks them and reports the packing fraction
and coordination of the remaining particles.

Every rule in this section works the same way: build the effective contact network, remove
the particles that do not have enough contacts, rebuild without them, and repeat until
nothing changes. Removing a particle takes a contact away from its neighbors, which can
push them below the threshold in turn, so the removal cascades. The flags of every particle
are written to the file even when the remaining ones are what the main datasets hold.

`nothing` removes no particle at all, which is useful for debugging a rule or for keeping a
dilute packing intact.

**Default:** `ContactCount()`

## Choices

| Choice | Default | Rule |
|:---|:---|:---|
| [`ContactCount()`](ContactCount.md) | **default** | fewer than $D+1$ contacts frictionless, fewer than 2 with friction |
| [`TwoContact()`](TwoContact.md) |  | two or fewer contacts |
| [`ForceFloor()`](ForceFloor.md) |  | contacts below a fraction of the mean force do not count |
| [`Unresolved()`](Unresolved.md) |  | contacts below the convergence tolerance do not count |
| [Your own rule function](custom_rule.md) |  | any function of the packing |
| `nothing` |  | remove none |
| [`find_rattlers()`](find_rattlers.md) |  | apply any rule to a finished packing |

## Example

```julia
using SoftPack

packing = pack(
    rattlers = ContactCount(
        cone_test = true,
    ),
    particles_count = 256,
    seed = 1,
)
count(packing.rattlers)
```

## References

- **[Xiong2019]** Fansheng Xiong, Philip Wang, Abram H. Clark, Thibault Bertrand, Nicholas T. Ouellette, Mark D. Shattuck, Corey S. O’Hern (2019). *Comparison of shear and compression jammed packings of frictional disks*. Granular Matter **21**, 109. [doi:10.1007/s10035-019-0964-9](https://doi.org/10.1007/s10035-019-0964-9).
- **[Gilabert2007]** F. A. Gilabert, J.-N. Roux, A. Castellanos (2007). *Computer simulation of model cohesive powders: Influence of assembling procedure and contact laws on low consolidation states*. Physical Review E **75**, 011303. [doi:10.1103/physreve.75.011303](https://doi.org/10.1103/physreve.75.011303).
