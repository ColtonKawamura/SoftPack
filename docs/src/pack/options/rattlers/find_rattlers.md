# `find_rattlers()`

*Up:* [`rattlers`](index.md)

Apply a rattler rule to a finished packing, without running it again:

The first argument is a `Packing`, the second any rule: `ContactCount()`, `TwoContact()`,
`ForceFloor()`, `Unresolved()`, `nothing`, or a function of the packing. The result is a
`BitVector` with one entry per particle, `true` for a rattler, in particle order.

It is the same code the packer runs when it applies the rule at the end of a run, so it is
the way to ask "what would a different rule say about this packing?" without repacking. The
packing's own rule is in `packing.settings.rattlers`, and its result is
`packing.rattlers`.

## Example

```julia
using SoftPack

packing = pack(
    particles_count = 64,
    seed = 1,
)
mask = find_rattlers(packing, ContactCount())
count(mask)
```
