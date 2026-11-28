# `contact`

*Up:* [Available options](../index.md)

The contact law is the normal force between two particles that overlap. SoftPack's
particles are soft: an overlap $\delta = d_{ij} - r_{ij}$ (the sum of the radii minus the
center distance) stores an elastic energy, and the force pushes the particles apart. The
law acts only in compression; there is no attraction [OHern2003].

With friction off, the normal force is the whole contact. With friction on, the law fixes
the normal stiffness that the tangential model scales from, so the two settings are
chosen together: `Mindlin()` needs `Hertzian()`, while `CundallStrack()` works with
either law.

The stiffness is one number for every pair, in the run's reduced units, where the
reference mass is 1 and the reference diameter is the small diameter of the mixture. Its
size sets the elastic time scale $\tau \sim \sqrt{m_\text{ref}/k}$, and therefore the
time step of the run; it does not change the jamming packing fraction.

**Default:** `Hookean()`

## Choices

| Choice | Default | Contact force |
|:---|:---|:---|
| [`Hookean()`](Hookean.md) | **default** | $f = k\delta$ |
| [`Hertzian()`](Hertzian.md) |  | $f = k\delta^{3/2}$ |

## Example

```julia
using SoftPack

packing = pack(
    contact = Hertzian(
        stiffness = 1.0,
    ),
    particles_count = 256,
    seed = 1,
)
packing.packing_fraction
```

## References

- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
