# `drag`

*Up:* [`DampedDynamics`](../index.md)

Stokes drag is a body force on every particle, proportional to its velocity, as if the
packing sat in a viscous fluid (design §8). It is separate from the contact dashpots: the
dashpots act only where two particles touch, while drag acts on every particle, including
one that touches nothing.

Drag is the tool that fixes the long tail of damped dynamics: a free particle that the
contact dashpots cannot slow down is brought to rest by the drag.

## Choices

| Choice | Default |
|:---|:---|
| `nothing` | **default** |
| [`StokesDrag()`](StokesDrag.md) |  |

## Archival reference

- [Stokes drag](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#stokes-drag)
