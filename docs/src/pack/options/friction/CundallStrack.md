# `CundallStrack()`

*Up:* [`friction`](index.md)

A linear tangential spring with a Coulomb cap [Somfai2005], [Silbert2001]. The tangential force is

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

```julia
using SoftPack

packing = pack(
    friction = CundallStrack(
        friction_coefficient = 0.3,  # mu in the Coulomb cap
        stiffness_ratio = :matched,  # k_t/k_n = 1/3 in 2D
    ),
    particles_count = 256,
    seed = 1,
)
packing.contact_number
```

## References

- **[Somfai2005]** Ellák Somfai, Jean-Noël Roux, Jacco H. Snoeijer, Martin van Hecke, Wim van Saarloos (2005). *Elastic wave propagation in confined granular systems*. Physical Review E **72**, 021301. [doi:10.1103/physreve.72.021301](https://doi.org/10.1103/physreve.72.021301).
- **[Silbert2001]** Leonardo E. Silbert, Deniz Ertaş, Gary S. Grest, Thomas C. Halsey, Dov Levine, Steven J. Plimpton (2001). *Granular flow down an inclined plane: Bagnold scaling and rheology*. Physical Review E **64**, 051302. [doi:10.1103/physreve.64.051302](https://doi.org/10.1103/physreve.64.051302).
