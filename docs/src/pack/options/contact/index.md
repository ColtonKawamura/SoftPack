# `contact`

*Up:* [Available options](../index.md)

The contact law is the normal force between two particles that overlap. SoftPack's
particles are soft: an overlap $\delta = d_{ij} - r_{ij}$ (the sum of the radii minus the
center distance) stores an elastic energy, and the force pushes the particles apart. The
law acts only in compression; there is no attraction.

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

## Archival reference

- [pack(contact = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#packcontact--)
- [Hookean contacts](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#hookean-contacts)
- [Hertzian contacts](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#hertzian-contacts)
