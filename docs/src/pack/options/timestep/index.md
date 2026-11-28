# `timestep`

*Up:* [Available options](../index.md)

The starting time step. FIRE starts at it and adapts it as it goes; damped dynamics keeps
it fixed for the whole run. It is chosen from the shortest contact time of the lightest
pair, so that the fastest oscillation in the packing is resolved.

The default rule is `CollisionTime()`, which scales the elastic contact time. A number is
also accepted; it is interpreted in units of $\sqrt{m_{\mathrm{min}}/k}$.

**Default:** `CollisionTime()`

## Choices

| Choice | Default |
|:---|:---|
| [`CollisionTime()`](CollisionTime.md) | **default** |
| a number |  |

## Archival reference

- [pack(timestep = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Time-step)
- [Time step](https://github.com/ColtonKawamura/SoftPack/wiki/Time-step#time-step)
