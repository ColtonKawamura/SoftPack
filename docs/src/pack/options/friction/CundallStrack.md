# `CundallStrack()`

*Up:* [`friction`](index.md)

A linear tangential spring with a Coulomb cap (design §13). The tangential force is

$$f_t = -k_t \xi,$$

with $\xi$ the tangential displacement stored since the contact was made, and the force
is clipped at $\mu f_n$: once $|f_t|$ reaches the cap the contact is sliding, the stored
displacement stops growing in the direction of the cap, and the flag is reported in the
contact table.

The tangential stiffness is a fixed fraction of the normal one,
$k_t = r\,k_n$. The default, `stiffness_ratio = :matched`, gives $r = 1/3$ in 2D and
$r = 2/7$ in 3D. Those are the values that make the tangential contact time equal the
normal one when the tangential effective mass includes the particle's rotation, which is
the mass the tangential spring actually moves; with them, the normal and tangential
springs are equally stiff in time and neither sets a shorter time step than the other.

The tangential force exerts a torque on each particle, $\tau = -R \times f_t$, so rotation
and spin are part of the dynamics. Friction applies during the minimization and during
damped dynamics alike.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `friction_coefficient` | `0.5` | $\mu$ in the Coulomb cap |
| `stiffness_ratio` | `:matched` | $k_t/k_n$; `:matched` is $1/3$ in 2D and $2/7$ in 3D, or give a number |

## Example

```
pack(friction = CundallStrack(friction_coefficient = 0.3))
```

## Archival reference

- [CundallStrack(friction_coefficient = …)](https://github.com/ColtonKawamura/SoftPack/wiki/Friction-models#cundallstrackfriction_coefficient--)
- [CundallStrack](https://github.com/ColtonKawamura/SoftPack/wiki/Friction-models#cundallstrack)
