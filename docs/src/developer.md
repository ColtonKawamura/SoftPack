# Developer guide

This document records the repository layout so that future milestones add files
in consistent places, and lists the common development commands. Contributors
work in short-lived worktrees on branches off `main` and open a pull request
when done; nothing here changes that workflow.

## Current layout (M0)

```
SoftPack/
├── Project.toml          # package manifest (SoftPack, deps, [extras]/[targets])
├── LICENSE, README.md, CITATION.cff
├── install.sh            # install Julia (via juliaup) then Pkg.instantiate()
├── .github/workflows/
│   ├── CI.yml            # build + test on ubuntu/macos, Julia 1.10 and 1
│   └── Documentation.yml # build on PRs, deploy to GitHub Pages on main
├── src/
│   ├── SoftPack.jl       # module: includes in order, exports the public API
│   ├── types.jl          # SizeDistribution, ContactLaw, Contact, Packing
│   ├── params.jl         # PackParams (@kwdef mutable struct) + validate()
│   ├── pack.jl           # pack(p::PackParams); Val{algorithm} dispatch registry
│   └── io/               # softpack-1 read/write (csv, metadata, write, read)
│       ├── csv.jl        #   particles.csv / contacts.csv (write + parse)
│       ├── metadata.jl   #   metadata.toml (write + parse helpers)
│       ├── write.jl      #   write_packing(pk, dir)
│       └── read.jl       #   read_packing(dir)
├── test/
│   ├── runtests.jl       # one @testset file per area, included here
│   └── params.jl, pack.jl, io.jl
├── docs/                 # Documenter.jl site (docs/Project.toml, make.jl, src/)
│   └── src/index.md, api.md, format.md, developer.md
├── examples/
│   └── example.jl        # runnable example (settings + softpack-1 round-trip)
├── app/                  # standalone apps — later
├── hpc/                  # HPC helpers/scripts — later
└── benchmark/            # timing / scaling benchmarks — later
# planned (M3): ext/ — GPU package extensions (SoftPackCUDAExt.jl, SoftPackMetalExt.jl)
```

## Common commands

All commands run from the repository root.

### Run the tests

```sh
julia --project -e 'using Pkg; Pkg.test()'
```

The suite is small by design (systems with `N <= 256`, a few seconds on a
laptop) and runs in CI on every pull request (`.github/workflows/CI.yml`, Julia
1.10 and the current release, Linux and macOS).

### Run the example

```sh
julia --project=. examples/example.jl
```

Shows the intended user workflow and exercises the working softpack-1
write/read round-trip with a small hand-built packing.

### Build the documentation

```sh
julia --project=docs -e 'using Pkg; Pkg.develop(path = "."); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

`Pkg.develop(path = ".")` links the local (unregistered) SoftPack into the docs
environment; repeat the first command only when `Project.toml` changes. The
built site lands in `docs/build/` (gitignored). The Documentation workflow
builds the site on every pull request and deploys it to GitHub Pages
(`ColtonKawamura.github.io/SoftPack`) when `main` is pushed; a local build never
deploys, because the `DOCS_DEPLOY` flag is only set by CI.

## Full intended layout (as the engine grows)

Future milestones populate `src/` along these lines. Keep files small and
cohesive; each module does one job.

```
src/
├── SoftPack.jl
├── geometry/             # box, pbc, cell lists
│   ├── box.jl            #   periodic box / box length management
│   ├── pbc.jl            #   minimum-image / wrapping
│   └── celllist.jl       #   neighbor cell lists
├── particles/            # size distributions (radii generation)
│   └── distributions.jl  #   Monodisperse, Bidisperse, *Polydisperse, CustomRadii
├── contacts/             # contact laws + friction state
│   ├── hookean.jl
│   ├── hertzian.jl
│   └── friction.jl       #   Cundall-Strack / Hertz-Mindlin (2D in v1)
├── minimizers/           # integration / compression steps
│   ├── fire.jl
│   └── damped_md.jl
├── protocols/            # one file per packing algorithm
│   └── fire_compress.jl  #   (M1); add one file per algorithm in M4
├── criteria/             # convergence / stop criteria
├── analysis/             # post-processing
│   ├── rattlers.jl       #   detect/remove rattlers
│   ├── coordination.jl   #   coordination numbers
│   ├── stress.jl         #   pressure / stress tensor
│   └── packing_fraction.jl
├── kernels/              # kernel-friendly inner loops (flat arrays)
├── io/                   # (as above) softpack-1 read/write
├── params.jl             # PackParams + validate()
├── types.jl              # Contact, Packing
└── pack.jl               # pack(p::PackParams) dispatch registry
```

### Adding an algorithm (future milestones)

`pack()` dispatches on `Val(p.algorithm)` and keeps a registry
(`ALGORITHMS` in `src/params.jl`). To add one, add the symbol to the registry
and implement one `pack(::Val{alg}, p::PackParams)` method (in a new file under
`src/protocols/` if preferred). This keeps each addition a single file plus one
method.

## Backward-compat / style notes

- Idiomatic Julia: `snake_case` functions and fields, `CamelCase` types.
- CPU code is written in a kernel-friendly style from the start: flat arrays,
  per-particle / per-pair loops, no `Dict`-heavy inner loops, and the
  floating-point type `T` (`Float32` or `Float64`) as a parameter.
- GPU backends arrive as package extensions (`ext/`) over `KernelAbstractions`
  so CPU users never install CUDA.jl / Metal.jl.
