# `restart_file`

*Up:* [Available options](../index.md)

Write the full run state to a file during the run [LAMMPSrestart], so a job that is killed can be
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

## Example

```julia
using SoftPack

packing = pack(
    restart_file = RestartFile(
        "run.h5",
        every = 25_000,
    ),
    particles_count = 256,
    seed = 1,
)
```

## References

- **[LAMMPSrestart]** LAMMPS developers. *LAMMPS documentation: restart command*. <https://docs.lammps.org/restart.html>. Accessed 2026-11-19.
