# `restart_packing`

*Up:* [Available options](index.md)

Continue a run from a file written by `write_packing` or by a `RestartFile`:

```
pack(restart_packing = "run.h5")
```

The stored state is loaded and the run continues from it: the compression state, the FIRE
counters, the contact history and the settings all come back, so the continuation is the
same run, not a new one. A restart redoes the compression trial that was in progress from
the accepted state, which is why continuing a finished packing leaves it unchanged and why
an interrupted run resumes exactly where it stopped.

Only run-control settings may differ from the stored ones: `steps_max`, `failure_action`,
`convergence`, `restart_file`, `snapshots` and `movie`. Anything else that differs raises
an error, because changing the physics halfway through would make the result a mixture of
two runs.

A restart is also the clean way to tighten a tolerance: run to $10^{-4}$, then continue to
$10^{-8}$ without paying for the first part twice.

**Default:** `nothing`

## Choices

| Choice | Default |
|:---|:---|
| `nothing` | **default** |
| `path to a file` |  |

## Archival reference

- [restart_packing = nothing](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#restart_packing--nothing)
- [restart_packing = path](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#restart_packing--path)
- [No restart by default (restart_packing)](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#no-restart-by-default-restart_packing)
