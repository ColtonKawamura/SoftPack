# `DampedDynamics()`

*Up:* [`algorithm`](index.md)

Damped dynamics relaxes a packing with a physical trajectory (design §8). Every contact
carries a dashpot, the box may also carry a Stokes drag, and the equations of motion are
integrated with one of three integrators. The packing comes to rest when the dissipation
has removed the energy, so the algorithm stops on a force or energy test like FIRE does,
but the path it took is a real trajectory that can be analyzed.

The motion is

$$M \ddot{x} = F - \Gamma \dot{x} - a_v M \dot{x},$$

with $F$ the elastic contact forces, $\Gamma$ the damping matrix assembled from the
contact dashpots, and $a_v$ the Stokes drag rate. Rotation gets the same treatment with
the moment of inertia in place of the mass.

Damped dynamics is the right tool when the damping model itself is the question, for
example when comparing a contact-damping run with an experiment. It is not the quickest way
to a jammed packing: the dashpots die out slowest on the soft modes of the packing, and
after the compression band is reached the few free particles keep drifting, so the tail is
long. In the benchmarks it did not reach $10^{-4}$ (frictionless, $N = 32$) in
$5\times10^5$ steps, while FIRE does in about $10^5$. Use a looser tolerance or
`StokesDrag(during = :always)` for production frictional runs.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `integrator` | `:centered_velocity_verlet` | how the equations are stepped; see [integrator](integrator/index.md) |
| `damping` | `ContactDamping()` | the contact dashpots; see [damping](damping/index.md) |
| `drag` | `nothing` | optional Stokes drag; see [drag](drag/index.md) |

## Example

```
pack(algorithm = DampedDynamics(drag = StokesDrag(velocity = 1.0, during = :compression)))
```

## Archival reference

- [Damped dynamics](https://github.com/ColtonKawamura/SoftPack/wiki/Damped-dynamics)
