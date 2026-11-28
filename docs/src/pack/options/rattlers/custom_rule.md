# Your own rule function

*Up:* [`rattlers`](index.md)

`rattlers` also accepts a function. It is called with the finished `Packing` and must
return one value per particle, truthy for a rattler:

```
pack(rattlers = packing -> packing.forces[1, :] .== 0)
```

A `BitVector` or a `Vector{Bool}` of length `N` is the natural return; anything that
`BitVector(...)` accepts works. The function sees the packing's `contacts` table,
`positions`, `forces`, `diameters`, `masses`, `box_side`, `settings` and the rest of the
`Packing` fields, so it can use the contact network, the forces, or both.

The function is applied once, as you wrote it: it is your job to repeat or cascade if the
rule needs it. To test a rule on a finished packing without repacking, use
[`find_rattlers(packing, rule)`](find_rattlers.md).

## Archival reference

- [No removal and custom rules](https://github.com/ColtonKawamura/SoftPack/wiki/Rattler-rules#no-removal-and-custom-rules)
