# `Hookean()`

*Up:* [`contact`](index.md)

A harmonic repulsion. The elastic energy of a contact with overlap $\delta > 0$ is

$$U = \frac{1}{2} k \delta^2,$$

so the normal force is linear in the overlap,

$$f_n = k \delta,$$

and the stiffness $k$ is the same at every overlap and for every pair. For
$\delta \le 0$ the energy and the force are zero.

## Why it is the default

`Hookean()` is the default because it is the simplest law that produces a jammed packing,
and because its jamming point is the one the literature has measured most often. In 2D the
harmonic bidisperse mixture jams near $\phi_J \approx 0.84$ and in 3D near $0.64$, with
$z - z_\text{iso} \to 0$ as the pressure falls [OHern2003]. Those are the reference values
against which a new packing, a new seed or a new code is usually checked, so making them
the default gives every user the same starting point.

The law is also the cheapest to run. Because $k$ does not depend on the overlap, every
contact has the same elastic time,
$\tau = \pi\sqrt{m_\text{eff}/k}$, so the time step is fixed for the whole run and the
damping ratio does not change as the packing compresses. A Hertzian contact
stiffens as its overlap grows, which forces a smaller step at large overlaps and makes the
run more expensive for the same packing.

`Hookean()` is a model choice, not a claim that real grains have linear contacts. The
difference is in the force law, not in the packing protocol: both laws jam at the same
$\phi_J$ in the zero-pressure limit [OHern2003], but at a finite pressure the overlap and
the pressure coefficient differ. Use `Hertzian()` when the contact law itself is the
question, for example when comparing with an experiment or when the tangential model is
`Mindlin()`; use `Hookean()` when the question is the packing and a fixed, cheap contact
time is an advantage.

SoftPack uses one stiffness $k$ for every pair. [OHern2003] scale the pair stiffness by
the particle size, $\epsilon/\sigma_{ij}^{\alpha}$; that changes the pressure coefficient
at a fixed $\Delta\phi$ but not the jamming packing fraction (the design document, §2,
records the difference).

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `stiffness` | `1.0` | the spring constant $k$ of every pair, in reduced units |

## Example

```julia
using SoftPack

packing = pack(
    contact = Hookean(
        stiffness = 2.0,  # spring constant of every pair
    ),
    particles_count = 256,
    seed = 1,
)
packing.packing_fraction
```

Doubling the stiffness halves the elastic time scale, so the packer takes a smaller time
step; the packing fraction at a given pressure is unchanged to within the run-to-run
scatter.

## References

- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
