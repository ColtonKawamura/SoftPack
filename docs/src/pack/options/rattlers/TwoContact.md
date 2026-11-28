# `TwoContact()`

*Up:* [`rattlers`](index.md)

Remove every particle with two or fewer contacts [Ishima2023], repeating the removal until
the network stops changing. It is the strict version of `ContactCount()`: even a frictional
packing, where two contacts can hold a particle, loses its two-contact particles.

It has no `cone_test`: a particle with two contacts is removed whether or
not its friction cones could hold it, so the test would never be reached.

This is the rule to use when the backbone should have at least three contacts per particle
at every friction coefficient, for example when comparing with a measurement that defines
the contact network that way.

## Options

None.

## Example

```julia
using SoftPack

packing = pack(
    rattlers = TwoContact(),
    particles_count = 256,
    seed = 1,
)
count(packing.rattlers)
```

## References

- **[Ishima2023]** Daisuke Ishima, Kuniyasu Saitoh, Michio Otsuki, Hisao Hayakawa (2023). *Theory of rigidity and numerical analysis of density of states of two-dimensional amorphous solids with dispersed frictional grains in the linear response regime*. Physical Review E **107**, 054902. [doi:10.1103/physreve.107.054902](https://doi.org/10.1103/physreve.107.054902).
