# `restart_file`

*Up:* [Available options](../index.md)

Write the full run state to a file during the run, so a job that is killed can be
continued from its last save instead of from the start. The file holds everything the
restart needs: positions, velocities, rotations and spins, the contact history, the
compression state, the FIRE counters, the settings and the provenance.

Nothing is saved by default; a restart file has to be asked for.

**Default:** `nothing`

## Choices

| Choice | Default |
|:---|:---|
| `nothing` | **default** |
| [`RestartFile()`](RestartFile.md) |  |

## Archival reference

- [restart_file = nothing](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#restart_file--nothing)
- [restart_file = RestartFile(...)](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#restart_file--restartfile)
- [No saves by default (restart_file)](https://github.com/ColtonKawamura/SoftPack/wiki/A-packing-that-does-not-converge#no-saves-by-default-restart_file)
