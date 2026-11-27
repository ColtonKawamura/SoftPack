# `protocol`

*Up:* [Available options](../index.md)

How the box is brought to the target. The protocol changes the box, then lets the
algorithm restore force balance, then asks whether the pressure is where it should be; the
answer decides whether the next step grows, shrinks or stays.

**Default:** `IsotropicCompression(strain_step = 1e-2)`

## Choices

| Choice | Default |
|:---|:---|
| [`IsotropicCompression()`](IsotropicCompression.md) | **default** |

## Archival reference

- [pack(protocol = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#packprotocol--)
- [Isotropic compression](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#isotropic-compression)
- [Compression of the default packing](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#compression-of-the-default-packing)
