# 11. Outputs

Design decision source: [design-references.md §11](../design-references.md#11-outputs).
Status: design stage (no engine code yet).

## Summary

`pack()` returns a `Packing` in memory. Writing it to disk is a separate call,
`write_packing(path, packing)`. The default file is one HDF5 file that holds the
packing, its contacts, every setting, the provenance record ([§10](10-reproducibility.md))
and the full state that `restart_packing` needs to continue the run
([§6](06-packing-that-does-not-converge.md)), including every particle before rattlers
are removed. Per-particle and per-contact quantities are stored as one 1-D dataset per
column, so they read the same in Julia, MATLAB, Python and C. Arrays that must stay
multi-dimensional (snapshots, matrices) are tagged `array_order = "column-major"`, and
`pack()` warns about them at the start of the run. Compression is off by default; gzip
(level 4) is the only option. When a rattler rule runs (the default), the main datasets
hold only the remaining particles, with their original ids; `rattlers_file = true`
writes a second file with every particle and a rattler flag. CSV is the alternative
format. Snapshots and a movie can be recorded during the run; both are off by default.
The word is "particles" throughout: in the API, in the files and in the docs.

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| file format (`write_packing`) | HDF5 | CSV | [File format](#file-format-hdf5) |
| `write_packing` `rattlers_file` | `false` | `true` | [Rattlers file](#rattlers-file-rattlers_file) |
| `write_packing` `compression` | `nothing` | `:gzip` (level 4) | [Compression](#compression-compression) |
| `pack` `snapshots` | `nothing` | `Snapshots(every = interval)`; `every` has no default | [Snapshots and movie](#snapshots-and-movie) |
| `pack` `movie` | `nothing` | `Movie(path; every = interval)`; `every` has no default | [Snapshots and movie](#snapshots-and-movie) |

## Model

### The returned packing and the file

```julia
packing = pack()
write_packing("packing.h5", packing)
```

`pack()` computes and returns; writing the packing is a separate call. The design doc
names the optional snapshot and movie recording (this page) as the exceptions; the
optional `restart_file` of [§6](06-packing-that-does-not-converge.md) also writes during
the run. `write_packing` writes one `Packing` to one file (two with
`rattlers_file = true`).

### What a file holds

The design doc names three datasets (`x`, `y`, `diameter`) and the `array_order`
attribute. The other contents are required by other sections, but their dataset names
and group layout are not designed yet. Units are SoftPack's reduced units
([Units](#units)).

| Quantity | Per | Units | Required by | Name in the design doc |
|---|---|---|---|---|
| Positions $x$, $y$ (and $z$ in 3D) | particle | $d$ | §11, §6 | `x`, `y` (no 3D name given) |
| Diameter $d_i$ | particle | $d$ | §3, §11 | `diameter` |
| Original particle id | particle | – | §11 | – |
| Mass $m_i$ | particle | $m$ | §4 | – |
| Velocity | particle | $d/\tau$ | §6 | – |
| Rotation angle and spin | particle | rad, $\text{rad}/\tau$ | §6 | – |
| Rattler flag | particle | true/false | §11 (`rattlers_file`) | – |
| Contacts (the pair $i$, $j$) | contact | – | §11 | – |
| Contact history (tangential springs) | contact | not specified | §6 | – |
| Box | packing | $d$ | §6 | – |
| Algorithm state (FIRE $\Delta t$, $\alpha$, counters) | packing | $\tau$, –, – | §6, [§14](14-fire-settings.md) | – |
| State of the compression protocol | packing | – | §6 (protocol not designed) | – |
| Step count, `converged` flag, restart records (file and step) | packing | – | §6 | `converged` (a result field) |
| Every setting | packing | – | §6, §7, §11 | – |
| SoftPack version, git commit, Julia version, seed, RNG | packing | – | [§10](10-reproducibility.md) | – |
| Optional extras: time series, snapshots, matrices | – | – | §11 | – |

Every particle before rattler removal is in the file as part of the restart state
([§6](06-packing-that-does-not-converge.md)); the main per-particle datasets hold only
the particles that remain.

### Units

The defaults set the units: small diameter $d = 1$ (the mean diameter for
`UniformPolydisperse`, [§3](03-particle-size-distribution-and-length-unit.md)), contact
stiffness $k = 1$ ([§2](02-default-packing.md)) and particle mass $m = 1$
([§4](04-mass.md)). For Hookean contacts, where $f = k\,\delta$, the derived units are:

| Quantity | Unit |
|---|---|
| Length, position, diameter, overlap $\delta$ | $d$ |
| Time | $\tau = \sqrt{m/k}$ |
| Velocity | $d/\tau$ |
| Spin | $1/\tau$ (radians per $\tau$) |
| Force | $k\,d$ |
| Energy | $k\,d^2$ |
| Torque | $k\,d^2$ |
| Stress and pressure | $k\,d^{\,2-D}$ ($k$ in 2D, $k/d$ in 3D) |

For `Hertzian` contacts $f = k\,\delta^{3/2}$, so the force unit is $k\,d^{3/2}$ and the
others follow the same way.

### Stress tensor and pressure

The pressure of a packing is the elastic contact (virial) pressure of
[§2](02-default-packing.md):

$$P = \frac{1}{D\,V}\sum_{c}\mathbf f^{c}\cdot\boldsymbol\ell^{c} = \frac{1}{D\,V}\sum_{c} f_n^{c}\,\ell^{c},$$

the trace, divided by $D$, of the contact stress tensor

$$\sigma_{\alpha\beta} = \frac{1}{V}\sum_{c} f^{c}_{\alpha}\,\ell^{c}_{\beta}.$$

Here the sums run over all contacts $c$ between particles $i$ and $j$;
$\boldsymbol\ell^{c} = \mathbf r_i - \mathbf r_j$ is the vector between their centers
(nearest periodic image) and $\ell^{c} = \lvert\boldsymbol\ell^{c}\rvert$ its length;
$\mathbf f^{c}$ is the elastic contact force on $i$ from $j$ and $f_n^{c}$ its normal
part; $V$ is the volume of the box (its area in 2D); $D$ is the dimension; and
$\alpha, \beta$ are Cartesian indices (here not the contact exponent). Only elastic
forces enter: no dashpot forces and no velocity term. A repulsive contact gives
$\mathbf f^{c}\cdot\boldsymbol\ell^{c} > 0$, so compression is positive pressure. This is
the static part of [Agnolin2007] Eq. (8),
$\sigma_{\alpha\beta} = \frac{1}{\Omega}\left(\sum_i m_i v_{i\alpha}v_{i\beta} + \sum_{i<j} F_{ij}^{(\alpha)} r_{ij}^{(\beta)}\right)$
(their $\Omega$ is our $V$), with the velocity term dropped because the target is a
static packing ([§2](02-default-packing.md)).

Whether a file stores $P$ and $\sigma_{\alpha\beta}$ or only the positions and forces to
compute them is not specified ([Open questions](#open-questions)).

## Derivations

### The virial pressure is minus the energy change per volume

Take a frictionless packing with energy $E = \sum_c U(\delta_c)$ and contact overlaps
$\delta_c = (d_i + d_j)/2 - \ell^{c}$. Dilate the box and every center-to-center vector
by a factor $1 + \varepsilon$. Then $\ell^{c} \to (1+\varepsilon)\,\ell^{c}$, so
$d\delta_c/d\varepsilon = -\ell^{c}$, and $V \to (1+\varepsilon)^{D}\,V$, so
$dV/d\varepsilon = D\,V$ at $\varepsilon = 0$. With $f_n^{c} = dU/d\delta_c$,

$$\frac{dE}{d\varepsilon} = \sum_c \frac{dU}{d\delta_c}\,\frac{d\delta_c}{d\varepsilon} = -\sum_c f_n^{c}\,\ell^{c}, \qquad P = -\frac{dE}{dV} = -\frac{dE/d\varepsilon}{dV/d\varepsilon} = \frac{1}{D\,V}\sum_c f_n^{c}\,\ell^{c}.$$

The virial formula is the mechanical pressure $-\partial E/\partial V$ under a uniform
(affine) compression. Checked numerically on a random periodic 2D configuration of 30
disks (79 contacts), for Hookean and Hertzian contacts: the virial sum and a
finite-difference $-dE/dV$ agree to a relative $4\times10^{-10}$. **SoftPack note.**

### Tangential forces drop out of the pressure

For disks and spheres the contact normal $\hat{\mathbf n}$ lies along the line of
centers, $\boldsymbol\ell^{c} = \ell^{c}\,\hat{\mathbf n}$. Write the contact force as
$\mathbf f^{c} = f_n^{c}\,\hat{\mathbf n} + f_t^{c}\,\hat{\mathbf t}$ with
$\hat{\mathbf t}\perp\hat{\mathbf n}$. Then

$$\mathbf f^{c}\cdot\boldsymbol\ell^{c} = f_n^{c}\,\ell^{c} + f_t^{c}\,\ell^{c}\,(\hat{\mathbf t}\cdot\hat{\mathbf n}) = f_n^{c}\,\ell^{c}.$$

Friction changes the off-diagonal stress components but not the pressure. Checked on
a square lattice with an added tangential force: the trace was unchanged.
**SoftPack note.**

### Units of the pressure

$[P] = [f]\,[\ell]/[V] = (k\,d)(d)/d^{D} = k\,d^{\,2-D}$: a force per length ($k$) in
2D and a force per area ($k/d$) in 3D, as in [§2](02-default-packing.md).

### Why multi-dimensional arrays read transposed

Julia stores an $n_1\times n_2$ array in column-major order: element $(i, j)$ sits at
linear position $(i-1) + (j-1)\,n_1$. HDF5 records the dimensions in C (row-major)
order, so the file says $n_2\times n_1$. A row-major reader (C, NumPy through h5py)
maps position $p$ to row $\lfloor p/n_1\rfloor = j-1$ and column $p \bmod n_1 = i-1$:
it sees the transpose. MATLAB is column-major like Julia [HDF5jl]; how its readers show
such a dataset was not checked here. A 1-D dataset has one dimension and reads the same
everywhere. Checked with HDF5.jl: a
$3\times2$ Julia array was stored with dataspace dimensions $(2, 3)$, and a vector of
length 3 with $(3)$. **SoftPack note.** [HDF5jl] give the fix for readers: "To read a
multidimensional array into the original shape from an HDF5 file written by Python
(numpy and h5py) or C/C++/Objective-C, simply reverse the dimensions."

### Why compressed datasets cannot be memory-mapped

Compression needs chunked storage: [HDF5jl] "Compression requires chunking, and
heuristic chunking is automatically used if you specify compression but don't specify
chunking." Memory mapping needs the opposite, [HDF5jl] "when the dataset is an array of
standard 'bits' types (e.g., Float64 or Int32) and no chunking/compression is being
used." So `compression = :gzip` gives up memory mapping. Compression is lossless either
way: [h5py] "Filters enabled with the compression keywords are lossless; what comes out
of the dataset is exactly what you put in."

## Defaults and their reasons

### File format: HDF5

```julia
packing = pack()
write_packing("packing.h5", packing)
```

**Decision.** `pack()` returns a `Packing`; `write_packing` writes it, by default as
HDF5. One binary file holds the packing, the contacts, all settings and any optional
extras (time series, snapshots, matrices), with exact floating-point values. Every file
also holds the full state for `restart_packing`
([§6](06-packing-that-does-not-converge.md)).

- MATLAB, Python and Julia read HDF5 without extra software: [MATLABh5read] `h5read`
  is built into MATLAB ("Introduced in R2011a"); [h5py] "Datasets are very similar to
  NumPy arrays."; [HDF5jl] Julia's JLD/JLD2 files "are still both regular HDF5 files
  and are therefore compatible with any HDF5 reader or writer."
- MATLAB `.mat` and JLD2 are not offered: MATLAB reads HDF5 directly [MATLABh5read]
  and JLD2 files are HDF5 files [HDF5jl]. **SoftPack choice.**
- "Particles", never "grains", in the API, the files and the docs. **SoftPack choice.**

### One 1-D dataset per column

**Decision.** Per-particle and per-contact quantities are stored as one 1-D dataset per
column (`x`, `y`, `diameter`, ...), not as $N\times D$ matrices.

- [HDF5jl] "Julia, like Fortran and MATLAB, stores multidimensional arrays in
  column-major order, while other languages, including C and Python (NumPy), use
  row-major order. Therefore when reading an array in Julia from row-major order
  language the dimensions may be inverted." 1-D datasets read the same in every
  language ([derivation](#why-multi-dimensional-arrays-read-transposed)).
  **SoftPack choice.**

### Multi-dimensional outputs are tagged and announced

**Decision.** When an option stores a genuinely multi-dimensional array (snapshots as
frames × particles, dense matrices), `pack()` prints a warning when the run starts,
naming those outputs and saying that Python and C readers will see them transposed,
and each such dataset carries the attribute `array_order = "column-major"`.

- **SoftPack choice**, from the [HDF5jl] note above.

### gzip only

**Decision.** The only compression filter is gzip (deflate).

- [h5py] the GZIP filter is "Available with every installation of HDF5, so it's best
  where portability is required."
- [HDF5jl] warns that Blosc-compressed datasets cannot be read by "vanilla HDF5
  distributions".

### Rattlers file (`rattlers_file`)

```julia
write_packing("packing.h5", packing; rattlers_file = false)
```

**Decision.** When a rattler rule is applied (the default, [§9](09-rattler-rules.md)),
the main datasets hold only the remaining particles, with their original ids.
`rattlers_file = true` also writes a second file with every particle and a rattler
flag, in the same layout. With `rattlers = nothing` there is one file with every
particle.

- **SoftPack choice.** Original ids let a reader match a particle in the main file to
  the same particle in the rattlers file and in the restart state.

### Compression (`compression`)

```julia
write_packing("packing.h5", packing; compression = nothing)
```

**Decision.** No compression by default.

- Packing files are small ([Worked numbers](#worked-numbers)), and uncompressed
  datasets can be memory-mapped: [HDF5jl] "This is possible only under particular
  conditions: when the dataset is an array of standard 'bits' types (e.g., Float64 or
  Int32) and no chunking/compression is being used."
- `compression = :gzip` uses level 4 unless a level is given: [h5py] "compression_opts
  sets the compression level and may be an integer from 0 to 9, default is 4."

### Snapshots and movie

```julia
pack(snapshots = nothing)
pack(movie = nothing)
```

**Decision.** No snapshots and no movie by default. `snapshots = Snapshots(every =
interval)` records snapshots during the run; `movie = Movie(path; every = interval)`
renders a GIF or video from them.

- **SoftPack choice**: both cost time and disk. `every` has no default: a useful
  interval depends on how long the run is ([Worked numbers](#worked-numbers)).

## Options

### CSV

**Option.** CSV, for spreadsheets or for reading without an HDF5 library. How the
format is selected, the column names, the number of files, and how contacts, settings,
provenance and the restart state are written in CSV are not designed
([Open questions](#open-questions)). **SoftPack choice.**

### A second file with every particle

```julia
write_packing("packing.h5", packing; rattlers_file = true)
```

**Option.** Writes the main file (remaining particles) and a second file with every
particle plus a rattler flag. Use it to look at rattlers or to apply another rule with
`find_rattlers(packing, rule)` ([§9](09-rattler-rules.md)) outside Julia. The second
file's name is not designed.

### gzip compression

```julia
write_packing("packing.h5", packing; compression = :gzip)
```

**Option.** gzip level 4, lossless, readable by every HDF5 installation. Costs memory
mapping ([derivation](#why-compressed-datasets-cannot-be-memory-mapped)). Worth it for
large outputs: snapshots, dense matrices, very large packings.

### Snapshots and movie

```julia
pack(snapshots = Snapshots(every = 10^4))
pack(movie = Movie("run.gif"; every = 10^4))
```

**Option.** `every` is required. The snapshot array (frames × particles) is a
multi-dimensional output, so it is tagged `array_order = "column-major"` and announced
at the start of the run.

### Formats that may come later

Extended XYZ (for OVITO) and LAMMPS data files may be added later. **SoftPack choice.**

## Worked numbers

Raw data sizes, Float64 (8 bytes) per value, HDF5 metadata not included. Contacts are
estimated as $N z/2$. Computed in Python. **SoftPack note.**

| Packing | One per-particle column | Contacts | One per-contact column | Positions per snapshot frame |
|---|---|---|---|---|
| $N = 256$, 2D ($z \approx 4$) | 2.0 KiB | 512 | 4.0 KiB | 4.0 KiB |
| $N = 10^5$, 2D ($z \approx 4$) | 781 KiB | $2\times10^5$ | 1.5 MiB | 1.5 MiB |
| $N = 10^4$, 3D ($z \approx 6$) | 78 KiB | $3\times10^4$ | 234 KiB | 234 KiB |

The default packing with a dozen per-particle columns is about 24 KiB of data: small,
as the compression decision assumes. Snapshots are what grow. For $N = 256$ in 2D,
positions alone take 4.0 KiB per frame: with `steps_max` $= 10^7$ and `every = 10^4`
that is at most 1000 frames, 3.9 MiB; with `every = 10` it would be up to $10^6$
frames, 3.8 GiB. This is why `every` has no default.

Pressure of a simple packing, to check units and signs: a periodic square lattice of
equal disks of diameter $d$ with spacing $a = d - \delta$ has $2N$ contacts, each with
$f_n = k\,\delta$ and $\ell = a$, in a box of area $V = N a^2$. The virial formula gives

$$P = \frac{1}{2\,N a^2}\,(2N)\,k\,\delta\,a = \frac{k\,\delta}{a},$$

the force per contact divided by the spacing, as a direct count of forces across a
line gives. For $\delta = 10^{-4}\,d$: $P = 1.0001\times10^{-4}\,k$, the default target
([§2](02-default-packing.md)). Checked with a 16-particle lattice. **SoftPack note.**

## Open questions

- **HDF5 layout.** Dataset names other than `x`, `y` and `diameter` (ids, masses,
  velocities, rotations, spins, contacts, contact history, box, the 3D coordinate),
  groups, and where settings and provenance go (datasets or attributes; [HDF5jl] "The
  HDF5 standard recommends against storing large objects as attributes.").
- **Restart state.** Where the full pre-removal state sits in the file, next to the
  main datasets that hold only the remaining particles.
- **CSV.** Column names, number of files, how the format is chosen (file extension or a
  keyword), and whether a CSV output can be restarted. The design doc says every file
  holds the full restart state; a CSV layout for that is not designed.
- **Compression level.** How a level other than 4 is given.
- **Rattlers file.** Its name or path, and what `rattlers_file = true` does when
  `rattlers = nothing`.
- **Stress and pressure.** Whether the file stores $P$, $\sigma_{\alpha\beta}$, $z$ and
  $\varphi$, or only what is needed to compute them.
- **Snapshots.** What a frame holds (positions only, or rotations and forces too),
  whether snapshots are kept in the `Packing` and written by `write_packing` or
  written during the run (`Snapshots` takes no path), and how `Movie` chooses GIF or
  video.
- **Safe writes.** `restart_file` writes to a temporary file and renames it
  ([§6](06-packing-that-does-not-converge.md)); whether `write_packing` does the same
  is not specified.

## Related pages

- [§2 Default packing](02-default-packing.md): the pressure definition and units.
- [§3 Particle size distribution and length unit](03-particle-size-distribution-and-length-unit.md):
  the length unit stored with the diameters.
- [§4 Mass](04-mass.md): per-particle masses in the file.
- [§6 A packing that does not converge](06-packing-that-does-not-converge.md): restart
  state, `restart_file`, `converged`.
- [§9 Rattler rules](09-rattler-rules.md): which particles leave the main datasets.
- [§10 Reproducibility](10-reproducibility.md): the provenance record.
- [§14 FIRE settings](14-fire-settings.md): FIRE state stored for restarts.
- [§0 Every default at a glance](00-every-default-at-a-glance.md),
  [Notation](notation.md), [References](references.md).

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[h5py]** The h5py developers. *Datasets, h5py documentation*. <https://docs.h5py.org/en/stable/high/dataset.html>. Accessed 2026-11-18.
- **[HDF5jl]** JuliaIO. *HDF5.jl documentation*. <https://juliaio.github.io/HDF5.jl/stable/>. Accessed 2026-11-18.
- **[MATLABh5read]** The MathWorks. *h5read: Read data from HDF5 dataset, MATLAB documentation*. <https://www.mathworks.com/help/matlab/ref/h5read.html>. Accessed 2026-11-18.
