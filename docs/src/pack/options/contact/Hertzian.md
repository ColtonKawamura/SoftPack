# `Hertzian()`

*Up:* [`contact`](index.md)

The Hertz law for elastic spheres and disks [OHern2003]: the energy grows as the five-halves power of
the overlap (O'Hern's $\alpha = 5/2$),

$$U = \frac{2}{5} k \delta^{5/2},$$

so the normal force is

$$f_n = k \delta^{3/2}$$. The stiffness is one prefactor for every pair, as with `Hookean()`, but the
stiffness a contact actually presents grows with its overlap,
$\partial f_n/\partial \delta = \tfrac{3}{2} k \sqrt{\delta}$.

That overlap dependence is why `Hertzian()` is the natural partner of `Mindlin()`, whose
tangential stiffness is proportional to the normal one. A tangential model
with a fixed ratio, `CundallStrack()`, also works with Hertzian contacts, but the ratio
then refers to the normal stiffness at the current overlap.

The time step is chosen from the largest stiffness the run expects, at the largest overlap
it expects to reach, so a Hertzian run is not timed from its stiffness at
zero overlap.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `stiffness` | `1.0` | the prefactor $k$ in $f_n = k\delta^{3/2}$, in reduced units |

## Example

```julia
using SoftPack

packing = pack(
    contact = Hertzian(
        stiffness = 1.0,  # prefactor in f_n = k delta^(3/2)
    ),
    particles_count = 256,
    seed = 1,
)
packing.packing_fraction
```

## References

- **[OHern2003]** Corey S. O’Hern, Leonardo E. Silbert, Andrea J. Liu, Sidney R. Nagel (2003). *Jamming at zero temperature and zero applied stress: The epitome of disorder*. Physical Review E **68**, 011306. [doi:10.1103/physreve.68.011306](https://doi.org/10.1103/physreve.68.011306).
