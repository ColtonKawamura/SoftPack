# Your own test function

*Up:* [`convergence`](index.md)

`convergence` also accepts a function. It is called with a `RunState` after each step and
must return `true` when the packing counts as converged:

```
pack(convergence = state -> state.step >= 10_000)
```

The `RunState` carries the live arrays of the run: `positions`, `velocities`, `rotations`,
`spins`, `diameters`, `masses`, `moments`, `forces`, `torques`, the contact arrays
(`first`, `second`, `overlaps`, `normal_forces`, `tangential_forces`), `box_side`,
`boundary`, `pressure`, `step` and `settings`. The arrays are the system's own, so a
function can read them freely; writing to them is possible but unsupported (PROVISIONAL
T-1x2y: the design says the test is a function of the contact network and leaves the
argument open, so the arrays are handed over directly).

The pressure band is still applied on top of your test: a compression step is accepted
only when your function returns `true` and the pressure is inside the band.

## Archival reference

- [Convergence criterion](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion)
