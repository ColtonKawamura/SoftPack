# `RelativeVelocityDamping()`

*Up:* [`damping`](index.md)

One dashpot on the full relative velocity, normal and tangential at once [Vagberg2014]:

$$f_\text{damp} = -M r \, v_\text{rel},$$

with a single rate $r$ (default 0.5). Because the force follows the velocity vector rather
than the contact normal, it damps sliding and approach together and needs no separate
tangential spring.

It is the simplest model to reason about and the one that most resembles a viscous fluid;
it is not the model of a contact, so its damping does not scale with the stiffness.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `rate` | `0.5` | $r$, the damping rate |
| `attractive` | `false` | whether the dashpot can pull |
| `coulomb_limit` | `:elastic` | which normal force caps the tangential part |

## Example

```julia
using SoftPack

packing = pack(
    algorithm = DampedDynamics(
        damping = RelativeVelocityDamping(
            rate = 0.5,  # one dashpot on the full relative velocity
        ),
    ),
    particles_count = 64,
    seed = 1,
)
packing.converged
```

## References

- **[Vagberg2014]** Daniel Vågberg, Peter Olsson, S. Teitel (2014). *Dissipation and Rheology of Sheared Soft-Core Frictionless Disks Below Jamming*. Physical Review Letters **112**, 208303. [doi:10.1103/PhysRevLett.112.208303](https://doi.org/10.1103/PhysRevLett.112.208303). arXiv:1311.4902.
