# `Pressure()`

*Up:* [`target`](index.md)

Run the compression until the measured pressure reaches `pressure` (design §2). The
pressure of a configuration is

$$P = \frac{1}{D V}\left(\sum_\text{pairs} f_n \, l + \sum_\text{walls} f_n \, h\right),$$

with $l$ the branch vector of a pair contact, $h$ the distance from a particle's center to
the wall it touches, $V = L^D$ the box volume and $D$ the dimension. The sum runs in index
order, so the same configuration always gives the same pressure to the last bit.

The run accepts a compression step when $|P - P_\text{target}| \le$ `pressure_tolerance`
times $P_\text{target}$; the default tolerance is $10^{-4}$, so the pressure lands within
one part in ten thousand.

Because a soft packing is compressed, the packing fraction depends on the pressure you ask
for. In 2D at $N = 256$ (mean of three seeds, with $z_\text{iso} = 3.992$ the finite-size
isostatic value used in `benchmarks/results.md`):

| $P$ | $\phi$ | $z - z_\text{iso}$ |
|:---|---:|---:|
| $10^{-2}$ | 0.8626 | 0.5249 |
| $10^{-3}$ | 0.8423 | 0.1419 |
| $10^{-4}$ | 0.8383 | 0.0325 |
| $10^{-5}$ | 0.8380 | 0.0027 |

The default $P = 10^{-4}$ sits where the backbone is almost isostatic and the packing is
still cheap to reach: the default run takes 0.7 s.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `pressure` | `1e-4` | the target pressure, in reduced units |

Both `Pressure()` and `Pressure(1e-3)` work.

## Archival reference

- [Target pressure](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#target-pressure)
- [Stress and pressure](https://github.com/ColtonKawamura/SoftPack/wiki/Default-packing#stress-and-pressure)
