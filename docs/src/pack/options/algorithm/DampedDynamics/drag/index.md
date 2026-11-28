# `drag`

*Up:* [`DampedDynamics`](../index.md)

Stokes drag is a body force on every particle, proportional to its velocity, as if the
packing sat in a viscous fluid. The drag model is a **SoftPack choice**; it is
the standard Stokes drag. It is separate from the contact dashpots: the
dashpots act only where two particles touch, while drag acts on every particle, including
one that touches nothing.

Drag is the tool that fixes the long tail of damped dynamics: a free particle that the
contact dashpots cannot slow down is brought to rest by the drag.

## Choices

| Choice | Default |
|:---|:---|
| `nothing` | **default** |
| [`StokesDrag()`](StokesDrag.md) |  |

## Example

```julia
using SoftPack

packing = pack(
    algorithm = DampedDynamics(
        drag = StokesDrag(
            velocity = 1.0,
        ),
    ),
    particles_count = 64,
    seed = 1,
)
packing.converged
```
