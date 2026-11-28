# Your own test function

*Up:* [`convergence`](index.md)

`convergence` also accepts a function. It is called with a `RunState` after each step and
must return `true` when the packing counts as converged:

The `RunState` carries the live arrays of the run: `positions`, `velocities`, `rotations`,
`spins`, `diameters`, `masses`, `moments_of_inertia`, `forces`, `torques`, the contact arrays
(`contact_first`, `contact_second`, `overlaps`, `normal_forces`, `tangential_forces`), `box_side`,
`boundary`, `pressure`, `step` and `settings`. The arrays are the system's own, so a
function can read them freely; writing to them is possible but unsupported.

The pressure band is still applied on top of your test: a compression step is accepted
only when your function returns `true` and the pressure is inside the band.

## Example

```julia
using SoftPack

packing = pack(
    convergence = state -> state.step >= 10_000,
    particles_count = 64,
    seed = 1,
)
packing.converged
```
