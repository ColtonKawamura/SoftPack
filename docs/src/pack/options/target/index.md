# `target`

*Up:* [Available options](../index.md)

The target is what the compression runs to. SoftPack stops when the pressure measured from
the contacts is inside a band around the target and the convergence test holds, so the
target is the pressure at which the packing is defined, not a packing fraction: the
packing fraction that comes out is the answer, not the input.

The pressure is the elastic virial of the contact forces divided by the volume; it counts
the pair contacts and, for a `Walls` box, the wall contacts.

**Default:** `Pressure(1e-4)`

## Choices

| Choice | Default |
|:---|:---|
| [`Pressure()`](Pressure.md) | **default** |

## Archival reference

- [pack(target = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#packtarget--)
- [Target pressure](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#target-pressure)
