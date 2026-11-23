# `pressure_tolerance`

*Up:* [Available options](index.md)

!!! warning "Not written in the new format yet"
    This page is a placeholder in the new structure. The current text lives in the wiki: [pressure_tolerance](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion#pressure_tolerance); [Pressure test (pressure_tolerance)](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion#pressure-test-pressure_tolerance).

**Default:** `1e-4`

The pressure must be within this relative band of the target for every `convergence` choice, because the compression protocol checks it after every minimization.

## Choices

| Choice | Default |
|:---|:---|
| `1e-4` | **default** |
