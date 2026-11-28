# `PackParams()`

*Up:* [`pack()`](index.md)

A `PackParams` is one set of settings, built from the same keywords `pack()` takes. It
exists so a set of settings can be built once, inspected, reused, and passed to `pack`:

`pack(params)` validates the settings and runs exactly like `pack(; kwargs...)` with the
same keywords. The result's `packing.settings` is the `PackParams` of the run, and a
restart compares its stored copy with the new keywords.

The constructor stores the settings; `pack(params)` validates them before the run, so an
invalid setting raises an error at the call rather than after a minute of packing.

## The keywords

| Keyword | Default | Sets |
|:---|:---|:---|
| `dimension` | `2` | disks or spheres |
| `particles_count` | `256` | the number of particles |
| `particles_size_distribution` | `Bidisperse()` | how diameters are drawn |
| `particles_diameters` | `nothing` | an explicit list of diameters |
| `contact` | `Hookean()` | the normal force law |
| `friction` | `nothing` | the tangential model |
| `mass` | `EqualMass()` | the masses |
| `target` | `Pressure(1e-4)` | the pressure to compress to |
| `boundary` | `Periodic()` | periodic box or walls |
| `initial_state` | `Dilute(0.25)` | where the run starts |
| `protocol` | `IsotropicCompression(1e-2)` | how the box shrinks |
| `convergence` | `RelativeForce(1e-8)` | when a minimization is done |
| `pressure_tolerance` | `1e-4` | the width of the pressure band |
| `steps_max` | `10^7` | the step cap |
| `failure_action` | `:warn` | what a failed run does |
| `restart_packing` | `nothing` | continue from a file |
| `restart_file` | `nothing` | save the state during the run |
| `algorithm` | `FIRE()` | the minimizer or dynamics |
| `timestep` | `CollisionTime()` | the starting step |
| `rattlers` | `ContactCount()` | which particles are rattlers |
| `seed` | `1` | the random seed |
| `snapshots` | `nothing` | store positions at intervals |
| `movie` | `nothing` | render a movie |

## Example

```julia
using SoftPack

params = PackParams(
    dimension = 3,
    particles_count = 512,
    seed = 7,
)
packing = pack(params)
packing.packing_fraction
```
