# T-zk8c: CSV, format selection and compression

*Up:* [Design decisions](index.md)

**Question.** CSV was a shipped option with no way to select it and no layout, and the
gzip level had no syntax.

**Choice.** The format follows the extension: `.h5` and `.hdf5` are HDF5, `.csv` is CSV,
anything else is an error. An explicit `format` keyword overrides the extension for a
caller that wants it. CSV writes `<base>_particles.csv` and `<base>_contacts.csv` and
cannot restart a run. Compression is `:gzip` (level 4) or `(:gzip, level)` and applies to
HDF5 only.

**Why.** An extension is the one piece of a path a user already writes, so inferring from
it makes the common call correct without a keyword. CSV is an export, not a checkpoint:
it has no place for the contact history, so promising a restart from it would be a lie.

**Status.** In code. The `format` keyword stays as an escape hatch for paths whose
extension says nothing.

## Archival reference

- [Outputs](https://github.com/ColtonKawamura/SoftPack/wiki/Outputs)
