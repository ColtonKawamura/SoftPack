# `Walls()`

*Up:* [`boundary`](index.md)

Rigid walls on every side of the box [LAMMPSgran]. A particle that reaches a wall is
pushed back by the same contact law, with the wall as an infinite-mass partner; the
contact's branch vector is the distance from the particle's center to the wall, and its
lever arm is the particle radius.

`Walls(friction = true)` is the default for the type: wall contacts then carry a
tangential spring and a Coulomb cap like particle contacts, using the same friction model.
`Walls(friction = false)` keeps the normal force only, which is the cleaner choice when
wall friction would confuse a measurement of the bulk.

The pressure includes the wall virial,

$$P = \frac{1}{D V}\left(\sum_\text{pairs} f_n \, l + \sum_\text{walls} f_n \, h\right),$$

and the walls move with the box during compression, so the container shrinks with the
packing.

Counting a wall contact like a pair contact in the coordination number is provisional:
the design leaves that open for `Walls`.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `friction` | `true` | whether wall contacts carry the tangential model |

## Example

```julia
using SoftPack

packing = pack(
    boundary = Walls(
        friction = false,  # normal wall contacts only
    ),
    particles_count = 256,
    seed = 1,
)
packing.packing_fraction
```

## References

- **[LAMMPSgran]** LAMMPS developers. *LAMMPS documentation: pair_style gran/hooke, gran/hooke/history, gran/hertz/history*. <https://docs.lammps.org/pair_gran.html>. Accessed 2026-11-18.
