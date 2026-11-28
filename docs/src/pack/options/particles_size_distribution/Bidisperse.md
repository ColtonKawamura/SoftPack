# `Bidisperse()`

*Up:* [`particles_size_distribution`](index.md)

A mixture of two diameters: a fixed fraction of the particles are small, and the rest are larger by a fixed ratio.
It is the default `particles_size_distribution`, and its small diameter is SoftPack's unit of length.

## The call with every option written out

```julia
pack(                                           # run the packing
    particles_size_distribution = Bidisperse(   # two-diameter mixture (default)
        diameter_small = 1.0,                   # small diameter; sets the length unit (default)
        diameter_ratio = 1.4,                   # large diameter divided by small diameter (default)
        fraction_small = 0.5,                   # number fraction of small particles (default)
    )                                           # end of Bidisperse call
)                                               # end of pack call
```

- `pack(...)` — [runs the packing](../../index.md).
- `particles_size_distribution = Bidisperse(...)` **(default)** — a mixture of two diameters in a fixed ratio, with $N_s = f\,N$ particles small and $f$ = `fraction_small`.
  - The two-size mixture prevents crystallization in 2D [OHern2003].
- `diameter_small = 1.0` **(default)** — the small diameter, which also sets the length unit.

$$d_i \in \{d_s,\; r\,d_s\}, \qquad d_s = \texttt{diameter\_small}.$$

[OHern2003] "The diameter of the smaller particle is denoted by σ" … "lengths are measured in units of σ."

- `diameter_ratio = 1.4` **(default)** — the ratio $r = d_l/d_s$ of the large to the small diameter.
  - [OHern2003] 50-50 mixtures "with a size ratio of 1.4 in order to prevent crystallization."
- `fraction_small = 0.5` **(default)** — the number fraction of small particles.

$$N_s = f\,N \text{ small}, \qquad N_l = (1-f)\,N \text{ large}, \qquad f = \texttt{fraction\_small}.$$

The polydispersity (standard deviation over mean) of the default is $\sqrt{f(1-f)}\,(r-1)/(f+(1-f)r) = 1/6 = 0.167$ (**SoftPack note**, from the two-diameter moments).

## Why these defaults

- Why a mixture at all: equal disks crystallize in 2D, and a crystal is not the disordered packing jamming studies need.
  - A second size frustrates the hexagonal order (**SoftPack note**).
- `diameter_small = 1.0` — the small diameter as the length unit.
  - [OHern2003] "The diameter of the smaller particle is denoted by σ." ... "lengths are measured in units of σ"
- `diameter_ratio = 1.4` and `fraction_small = 0.5` — the [OHern2003] mixture.
  - [OHern2003] "In our two-dimensional (2D) simulations, we have used 50-50 mixtures of particles with a size ratio of 1.4 in order to prevent crystallization".

## Theory

For now these sections are on the wiki.

- [Bidisperse law](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#bidisperse-law)
- [Bidisperse moments](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#bidisperse-moments)
- [Changing the length unit](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#changing-the-length-unit)
- [Bidisperse default](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#bidisperse-default)
- [Worked numbers](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#worked-numbers)

## Example

```julia
using SoftPack

packing = pack(
    particles_size_distribution = Bidisperse(
        diameter_small = 1.0,  # small diameter; sets the length unit
        diameter_ratio = 1.4,  # large diameter divided by small
        fraction_small = 0.5,  # half the particles are small
    ),
    seed = 1,
)
packing.diameters
```

## References

- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
