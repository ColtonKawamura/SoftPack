# `failure_action`

*Up:* [Available options](index.md)

What a run does when it stops without converging. The default is a **SoftPack choice**.

| Choice | Default | Behavior |
|:---|:---|:---|
| `:warn` | **default** | log a warning and return the packing with `converged = false` |
| `:error` |  | throw an error instead |

The default returns the packing because a run that stopped at `steps_max` or `:uphill_max`
still holds a physically meaningful state, and because a batch of seeds should not die on
one bad one: the results say which runs failed and the caller decides what to do.

`:error` is the choice for a production run where a failed packing must not enter an
ensemble silently.

**Default:** `:warn`

## Options

| Choice | Default |
|:---|:---|
| `:warn` | **default** |
| `:error` |  |

## Example

```julia
using SoftPack

packing = pack(
    failure_action = :error,  # throw PackingError instead of warning
    particles_count = 256,
    seed = 1,
)
```
