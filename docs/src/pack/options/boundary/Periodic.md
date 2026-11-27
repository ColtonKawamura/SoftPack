# `Periodic()`

*Up:* [`boundary`](index.md)

A periodic square (2D) or cube (3D) (design §2). A particle's image re-enters the box on
the opposite side, distances are minimum-image, and a pair of particles can touch across
the boundary. There is no wall, so the packing has no surface layer and every particle sees
the same environment on average.

The pressure of a periodic packing is the pair virial alone,

$$P = \frac{1}{D V}\sum_\text{pairs} f_n \, l,$$

and the frame is the box, so a movie of a periodic run shows particles crossing the edge
and reappearing on the far side.

This is the default because it is the cleanest way to measure bulk jamming: the packing
fraction of the default run, $\phi = 0.8387$, is not depressed by a container.

## Archival reference

- [pack(boundary = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#packboundary--)
