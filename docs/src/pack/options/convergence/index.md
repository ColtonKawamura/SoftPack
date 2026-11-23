# `convergence`

*Up:* [Available options](../index.md)

!!! warning "Not written in the new format yet"
    This page is a placeholder in the new structure. The current text lives in the wiki: [Convergence criterion](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion).

When to stop.

Each choice decides when the packing is at rest at the current box, and [`pressure_tolerance`](../pressure_tolerance.md) is checked after every one of them. `LeidenAcceleration()` and your own function replace the force test of `RelativeForce()`, and `KineticEnergy()` and `RestartTest()` add a check to it at its defaults.

**Default:** `RelativeForce()`

## Choices

| Choice | Default |
|:---|:---|
| [`RelativeForce()`](RelativeForce.md) | **default** |
| [`LeidenAcceleration()`](LeidenAcceleration.md) |  |
| [`KineticEnergy()`](KineticEnergy.md) |  |
| [`RestartTest()`](RestartTest.md) |  |
| [Your own test function](custom_test.md) |  |
