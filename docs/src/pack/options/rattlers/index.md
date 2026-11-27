# `rattlers`

*Up:* [Available options](../index.md)

A rattler is a particle that carries no load: it touches too few neighbors, or its
contacts are arranged so that no combination of forces inside the friction cones can hold
it. Rattlers are part of the packing but not part of its backbone, and leaving them in
distorts the coordination number, so SoftPack marks them and reports the packing fraction
and coordination of the remaining particles (design §9).

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

## Archival reference

- [Rattler rules](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules)
