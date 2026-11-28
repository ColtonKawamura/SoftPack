# `Packing`

*Up:* [`pack()`](index.md)

`pack()` returns a `Packing`: the result of one run, in memory. It holds the analysis
data, the scalar results, the full dynamic state and the provenance of the run, and it is
what `write_packing`, `find_rattlers` and a restart read.

## Per particle

Each field has one entry per particle, in particle order, and the index is the particle id.
`N_R` in the table is the number of rotational degrees of freedom: 1 in 2D and 3 in 3D.

| Field | Type | Meaning |
|:---|:---|:---|
| `positions` | $D \times N$ matrix | centers, inside the box |
| `diameters` | vector | the diameter of each particle |
| `masses` | vector | the mass of each particle |
| `forces` | $D \times N$ matrix | net elastic force |
| `torques` | $N_R \times N$ matrix | net elastic torque |
| `rattlers` | `BitVector` | `true` for a particle the rule removed |

## Contacts and results

| Field | Meaning |
|:---|:---|
| `contacts` | the final `ContactTable`: pairs, walls, overlaps, forces, sliding flags |
| `box_side` | the side of the box at the end of the run |
| `pressure` | the elastic virial pressure |
| `packing_fraction` | $\sum_i \pi d_i^D / (2^D V)$, all particles |
| `contact_number` | $z$ after the rattler removal |
| `force_residual` | $\max_i \lVert F_i \rVert / \langle f_n \rangle$ |

## Run and provenance

`converged`, `stop_reason` (`:converged`, `:steps_max`, `:uphill_max`, `:strain_step_min`),
`steps`, `compression_steps_accepted`, `compression_steps_rejected`, `strain_step_final`,
`timestep_start`, `runtime_seconds`, `diameter_reference`, `diameter_mean`,
`mass_reference`, `settings`, `seed`, `random_number_generator`, `softpack_version`,
`softpack_commit`, `julia_version`.

## The state

`system` and `control` hold everything the run would need to continue: velocities,
rotations and spins, accelerations, the contact history, the compression state and the FIRE
counters. They are not meant to be read by hand; `write_packing` and `restart_packing` use
them.

## Accessors

| Function | Returns |
|:---|:---|
| `contact_pressure(p)` | the measured pressure |
| `mean_normal_force(p)` | the mean normal force over the contacts |
| `is_converged(p)` | whether the run met its test |
| `run_state(p)` | a `RunState` of the final state, for a user test or rule |
| `find_rattlers(p, rule)` | a `BitVector`, what another rule would say |

## Example

```julia
using SoftPack

packing = pack(
    particles_count = 256,
    seed = 1,
)
(packing.packing_fraction, packing.contact_number)
```
