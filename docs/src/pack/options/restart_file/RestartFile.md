# `RestartFile()`

*Up:* [`restart_file`](index.md)

```
pack(restart_file = RestartFile("run.h5"; every = 10_000))
```

Write the run state to `path` every `every` steps (design §6). `every` can also be a
`Dates` period, in which case the save happens on wall-clock time.

The write is atomic: the state goes to a temporary file in the same directory and is
renamed over the path, so a job killed during a save leaves the previous file intact. A
save costs one HDF5 write of the state arrays, which for the default run is a few
milliseconds and is why the default schedule is every 10,000 steps rather than every step.

A restart file is the same format as the main file `write_packing` writes, so a packing
saved at the end of a run can be continued too; the difference is only when the file is
written.

## Options

| Option | Default | Meaning |
|:---|:---|:---|
| `path` | required | where to write the state |
| `every` | required | steps (an integer) or a wall-clock period between saves |

## Archival reference

- [restart_file = RestartFile(...)](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#restart_file--restartfile)
- [Save during the run (restart_file = RestartFile(...))](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#save-during-the-run-restart_file--restartfile)
