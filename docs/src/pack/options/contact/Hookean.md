# `Hookean()`

*Up:* [`contact`](index.md)

A harmonic repulsion. The elastic energy of a contact with overlap $\delta > 0$ is

$$U = \frac{1}{2} k \delta^2,$$

so the normal force is linear in the overlap,

$$f_n = k \delta,$$

and the stiffness $k$ is the same at every overlap and for every pair (design §2). For
$\delta \le 0$ the energy and the force are zero.

This is the default because it is the simplest law that produces jammed packings, and
because the jamming point of harmonic disks and spheres is the one with the largest body
of published results: $\phi_J \approx 0.84$ in 2D and $0.64$ in 3D at low pressure, with
$z - z_\text{iso}$ going to zero as the pressure falls.

Because the stiffness does not depend on the overlap, the elastic time scale is fixed,
$\tau = \pi\sqrt{m_\text{eff}/k}$ for a pair, and the run's time step follows from it
(design §12). That makes `Hookean()` the cheapest law to time and to debug.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `stiffness` | `1.0` | the spring constant $k$ of every pair, in reduced units |

## Example

```
pack(contact = Hookean(stiffness = 2.0))
```

Doubling the stiffness halves the elastic time scale, so the packer takes a smaller time
step; the packing fraction at a given pressure is unchanged to within the run-to-run
scatter.

## Archival reference

- [Hookean contacts](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#hookean-contacts)
- [Contact law](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#contact-law)
- [Force and stiffness from the potential](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#force-and-stiffness-from-the-potential)
