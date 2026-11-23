# `Monodisperse()`

*Up:* [`particles_size_distribution`](index.md)

Every particle has the same diameter, and that diameter is the unit of length.
It is not the default, because equal disks crystallize in 2D.

## The call with every option written out

```julia
pack(                                             # run the packing
    particles_size_distribution = Monodisperse(   # every particle has the same diameter
        diameter = 1.0,                           # the one diameter; sets the length unit (default)
    )                                             # end of Monodisperse call
)                                                 # end of pack call
```

- `pack(...)` — [runs the packing](../../index.md).
- `particles_size_distribution = Monodisperse(...)` — every particle has the same diameter.
  - Equal disks crystallize in 2D, which the bidisperse default avoids.
  - [OHern2003] studied "the same bidisperse mixture as well as monodisperse systems" in 3D.
- `diameter = 1.0` **(default)** — the one diameter, which also sets the length unit.
  - **SoftPack choice**: the one diameter is the length unit.

## Theory

For now these sections are on the wiki.

- [Monodisperse law](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#monodisperse-law)
- [Monodisperse](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#monodisperse)

## References

- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
