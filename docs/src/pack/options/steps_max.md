# `steps_max`

*Up:* [Available options](index.md)

The cap on the number of integration steps in one call is a **SoftPack choice**. A run that reaches it stops with
`stop_reason = :steps_max` and `converged = false`, and the packing it has reached is
returned; `failure_action` decides whether that is a warning or an error.

The cap exists so a run that cannot converge ends instead of running forever. It is not a
target: a run that converges uses whatever it needs, and the default $10^7$ is high enough
that a normal run never reaches it. The default packing needs 87,000 steps.

If a run does reach the cap, the useful next steps are to look at the pressure and the
residual in the result, loosen the tolerance, or continue from a restart file with a higher
cap.

**Default:** `10^7`

## Options

| Value | Meaning |
|:---|:---|
| any integer | the maximum number of steps |

## Example

```julia
using SoftPack

packing = pack(
    steps_max = 10^7,  # cap per call
    particles_count = 256,
    seed = 1,
)
packing.steps
```
