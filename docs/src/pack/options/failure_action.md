# `failure_action`

*Up:* [Available options](index.md)

What a run does when it stops without converging.

| Choice | Default | Behaviour |
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

## Archival reference

- [failure_action = :warn](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#failure_action--warn)
- [failure_action = :error](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#failure_action--error)
- [Warn and return (failure_action)](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#warn-and-return-failure_action)
