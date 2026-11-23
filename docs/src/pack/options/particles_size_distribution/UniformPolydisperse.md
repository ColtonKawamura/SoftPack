# `UniformPolydisperse()`

*Up:* [`particles_size_distribution`](index.md)

Diameters drawn uniformly around a mean, with the mean diameter as the unit of length.
It is not the default: use it to match the Leiden frictional packings [Somfai2005], [Shundyak2007].

## The call with every option written out

```julia
pack(                                                    # run the packing
    particles_size_distribution = UniformPolydisperse(   # diameters uniform around a mean
        diameter_mean = 1.0,                             # mean diameter; sets the length unit (default)
        spread        = 0.2,                             # half-width over the mean (default)
    )                                                    # end of UniformPolydisperse call
)                                                        # end of pack call
```

- `pack(...)` — [runs the packing](../../index.md).
- `particles_size_distribution = UniformPolydisperse(...)` — diameters drawn uniformly between $d_\text{mean}(1-s)$ and $d_\text{mean}(1+s)$.

$$p(d) = \frac{1}{2s\,d_\text{mean}} \quad \text{for } d_\text{mean}(1-s) \le d \le d_\text{mean}(1+s).$$

- `diameter_mean = 1.0` **(default)** — the mean diameter, which also sets the length unit: $\langle d\rangle = d_\text{mean}$.
  - [Somfai2005] "Our unit of length is the average grain diameter."
  - [Shundyak2007] "our units are such that the mass density, the average particle diameter, and the Young's modulus of the grains are 1."
- `spread = 0.2` **(default)** — the half-width over the mean, $s = \texttt{spread}$.
  - The polydispersity (standard deviation over mean) is $s/\sqrt{3}$.
  - The diameters stay positive for $s < 1$ (**SoftPack note**).
  - [Somfai2005] "For the 2D simulations the spheres have polydispersity to avoid crystallization: the diameters are uniformly distributed between 0.8 and 1.2 times their average."

## Why this option

- It matches the Leiden frictional packings ([Somfai2005], [Shundyak2007]).
  - Their 2D particles are spheres for the mass (see [`mass`](../mass/index.md)).

## Theory

For now these sections are on the wiki.

- [Uniform polydisperse law](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#uniform-polydisperse-law)
- [Uniform moments](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#uniform-moments)
- [Changing the length unit](https://github.com/ColtonKawamura/SoftPack/wiki/Particle-size-distribution-and-length-unit#changing-the-length-unit)

## References

- **[Shundyak2007]** Kostya Shundyak, Martin van Hecke, Wim van Saarloos (2007). *Force mobilization and generalized isostaticity in jammed packings of frictional grains*. Physical Review E **75**, 010301. [doi:10.1103/physreve.75.010301](https://doi.org/10.1103/physreve.75.010301).
- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
