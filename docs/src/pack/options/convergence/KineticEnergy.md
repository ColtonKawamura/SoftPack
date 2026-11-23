# `KineticEnergy()`

*Up:* [`convergence`](index.md)

!!! warning "Not written in the new format yet"
    This page is a placeholder in the new structure. The current text lives in the wiki: [KineticEnergy(tolerance = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion#kineticenergytolerance--); [KineticEnergy](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion#kineticenergy).

It holds when the `RelativeForce()` test (default tolerance) holds and the mean kinetic energy per particle is below `tolerance` times $P_\text{target}\,d^{D}$.

## Options

- `tolerance`
