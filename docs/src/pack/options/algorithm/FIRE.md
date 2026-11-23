# `FIRE()`

*Up:* [`algorithm`](index.md)

!!! warning "Not written in the new format yet"
    This page is a placeholder in the new structure. The current text lives in the wiki: [FIRE settings](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings); [Defaults and their reasons](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings#defaults-and-their-reasons).

11 parameters, each a section on this page.

This is the default for `algorithm`.

## Options

- `timestep_max`
- `timestep_min`
- `delay`
- `timestep_grow`
- `timestep_shrink`
- `mixing_coefficient`
- `mixing_shrink`
- `uphill_max`
- `inertia_correction`
- `delay_initial`
- `integrator`

## Damping and drag

- [`damping`](DampedDynamics/damping/index.md): contact dashpots for FIRE (default `nothing`).
- [`drag`](DampedDynamics/drag/index.md): Stokes drag for FIRE (default `nothing`).
