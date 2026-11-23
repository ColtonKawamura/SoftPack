# `damping`

*Up:* [`DampedDynamics()`](../index.md)

!!! warning "Not written in the new format yet"
    This page is a placeholder in the new structure. The current text lives in the wiki: [DampedDynamics(damping = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#dampeddynamicsdamping--); [Normal and Tangential Contact Damping](https://github.com/ColtonKawamura/SoftPack/wiki/Damping#normal-and-tangential-contact-damping); [FIRE(damping = …, drag = …)](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings#firedamping---drag--).

Which dashpot model the algorithm uses; FIRE() and DampedDynamics() both take this keyword.

## Choices

| Choice | Default |
|:---|:---|
| [`ContactDamping()`](ContactDamping.md) | **default** |
| [`ViscousRate()`](ViscousRate.md) |  |
| [`RelativeVelocityDamping()`](RelativeVelocityDamping.md) |  |
| `nothing (FIRE default)` |  |
