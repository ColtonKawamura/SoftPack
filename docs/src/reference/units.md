# Units and length unit

*Up:* [SoftPack](../index.md)

SoftPack works in reduced units: the numbers in a run are pure numbers, and a physical
unit is attached only at the end, when a result is compared with an experiment.

Every other unit follows from three references and the contact-law exponent $\alpha$ of
$U(\delta) = (k/\alpha)\,\delta^{\alpha}$: $\alpha = 2$ for
[`Hookean`](../pack/options/contact/Hookean.md) contacts and $5/2$ for
[`Hertzian`](../pack/options/contact/Hertzian.md) ones.

| Quantity | General | Hooke ($\alpha = 2$) | Hertz ($\alpha = 5/2$) | Default |
|:---|:---|:---|:---|:---|
| length | $d_\text{ref}$, the small diameter of the mixture | | | 1 |
| mass | $m_\text{ref}$: the `EqualMass` mass, or the mean mass with `Density` | | | 1 |
| stiffness | $k$: the `stiffness` of the contact law | | | 1 |
| force | $k\,d_\text{ref}^{\alpha-1}$ | $k\,d_\text{ref}$ | $k\,d_\text{ref}^{3/2}$ | 1 |
| energy | $k\,d_\text{ref}^{\alpha}$ | $k\,d_\text{ref}^{2}$ | $k\,d_\text{ref}^{5/2}$ | 1 |
| pressure | $k\,d_\text{ref}^{\alpha-D}$ | $k\,d_\text{ref}^{2-D}$: $k$ in 2D, $k/d_\text{ref}$ in 3D | $k\,d_\text{ref}^{1/2}$ in 2D, $k\,d_\text{ref}^{-1/2}$ in 3D | 1 |
| time | $\sqrt{m_\text{ref}\,d_\text{ref}^{2-\alpha}/k}$ | $\sqrt{m_\text{ref}/k}$ | $\sqrt{m_\text{ref}\,d_\text{ref}^{-1/2}/k}$ | 1 |

Every unit has the value 1 at the defaults, so a run quotes its numbers without a unit.
The table says what a number means: it changes with the contact law only when
$k \ne 1$ or $d_\text{ref} \ne 1$, and then the same target pressure means a different
overlap under the two laws.

The packing fraction and the coordination number are dimensionless and do not depend on
the units at all, which is why they are the numbers a run reports first.

## Changing the length unit

A run with every diameter multiplied by $\lambda$ and the same $k$ and $m$ is the same
packing: $\varphi$ and $z$ do not change, and only the time unit changes, by
$\lambda^{D/2}$ for a mass that follows the volume ($\lambda$ in 2D, $\lambda^{3/2}$ in
3D) or not at all for an equal mass.
That invariance is what lets a packing made in reduced units be quoted at any physical
size.

For a physical mapping, choose three numbers and derive the rest: for disks of 1 mm with
$k = 100\ \text{N/m}$ and $m = 1\ \text{g}$, the time unit is
$\sqrt{10^{-3}/100}\ \text{s} \approx 3\ \text{ms}$ and the 2D pressure unit is
$k/d = 10^5\ \text{N/m}$; the same numbers for spheres give $10^5\ \text{Pa}$.
