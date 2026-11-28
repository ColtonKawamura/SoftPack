# `StokesDrag()`

*Up:* [`drag`](index.md)

A drag force and torque proportional to the velocity and the spin (**SoftPack choice**):

$$F_\text{drag} = -a_v M \, v, \qquad \tau_\text{drag} = -a_s I \, \omega,$$

with $a_v$ and $a_s$ rates in inverse time. Both scale with the particle's own mass or
moment of inertia, so the drag does not change the relative motion of a large and a small
particle, only its overall decay.

`during = :always` applies the drag for the whole run. `during = :compression` applies it
while the box is being compressed and switches it off when the pressure first lands inside
the band; the final minimization then runs without drag, so the packing is brought to rest
by its contacts alone. That is the physically sensible choice when the drag stands in for
the fluid that carried the particles in, but it leaves free particles drifting, which is
why the benchmark runs use `:always` for a tight tolerance.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `velocity` | required | $a_v$, the rate on the translational velocity |
| `spin` | same as `velocity` | $a_s$, the rate on the spin |
| `during` | `:always` | `:always` or `:compression` |

## Example

```julia
using SoftPack

packing = pack(
    algorithm = DampedDynamics(
        drag = StokesDrag(
            velocity = 1.0,  # rate on the translational velocity
            spin = 0.5,      # rate on the spin
            during = :always,
        ),
    ),
    particles_count = 64,
    seed = 1,
)
packing.converged
```
