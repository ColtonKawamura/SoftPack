# `particles_diameters`

*Up:* [Available options](index.md)

Give the diameters themselves instead of drawing them from `particles_size_distribution`.
By default no list is given and the diameters are drawn from the distribution.

## The call with the default written out

```julia
pack(                                # run the packing
    particles_diameters = nothing,   # draw diameters from the size distribution (default)
)                                    # end of pack call
```

- `pack(...)` — [runs the packing](../index.md).
- `particles_diameters = nothing` **(default)** — the diameters are drawn from [`particles_size_distribution`](particles_size_distribution/index.md).

## Giving the diameters

```julia
pack(                                            # run the packing with given diameters
    particles_diameters = [1.0, 1.4, 1.0, 1.4]   # exactly these diameters, one per particle; particles_count is then 4
)                                                # end of pack call
```

- `particles_diameters = [1.0, 1.4, 1.0, 1.4]` — exactly these diameters, one per particle.
  - `particles_count` is then the number of diameters, here 4.
  - Give a distribution or the diameters, not both.
- The length unit is then whatever unit the given diameters are in.
  - With $k = 1$ the pressure unit follows from it.

## Why this default

- **SoftPack choice**: an exact list is how a packing is matched to an experiment or to another code's particles.

## Theory

For now these sections are on the wiki.

- [Given diameter list](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#given-diameter-list)
- [Given diameters](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#given-diameters)
