# `RelativeForce()`

*Up:* [`convergence`](index.md)

A minimization has converged when no particle feels a net force [Agnolin2007], [Gilabert2007]:

$$\max_i |F_i| < \varepsilon \, \langle f_n \rangle,$$

with $\langle f_n \rangle$ the mean normal contact force of the configuration and
$\varepsilon$ the tolerance. With friction on, each particle must also carry no net
torque:

$$\frac{\sqrt{T_i \cdot T_i}}{I_i} \, d_\text{ref} < \varepsilon \, \langle f_n \rangle,$$

where $I_i$ is the moment of inertia and $d_\text{ref}$ the small diameter of the mixture.
Dividing by $I_i$ and multiplying by a diameter turns the torque into the force scale it
would produce, so the same $\varepsilon$ means the same thing for translation and rotation.

## Why it is the default

This is the default test because it is the one that describes jamming directly: a jammed
packing is one where every particle can be balanced by its contacts.

The default $\varepsilon = 10^{-8}$ is provisional: it is kept until
frictional runs have been timed, because the tail of a frictional minimization is much
longer than a frictionless one.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `tolerance` | `1e-8` | $\varepsilon$, relative to the mean contact force |

## Cost

2D, $N = 256$, $P = 10^{-4}$, mean of two seeds: $10^{-4}$ takes 55,000 steps,
$10^{-6}$ 71,000 and $10^{-8}$ 87,000.

## Example

```julia
using SoftPack

packing = pack(
    convergence = RelativeForce(
        tolerance = 1e-8,  # max force divided by the mean contact force
    ),
    particles_count = 256,
    seed = 1,
)
packing.force_residual
```

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[Gilabert2007]** F. A. Gilabert, J.-N. Roux, A. Castellanos (2007). *Computer simulation of model cohesive powders: Influence of assembling procedure and contact laws on low consolidation states*. Physical Review E **75**, 011303. [doi:10.1103/physreve.75.011303](https://doi.org/10.1103/physreve.75.011303).
