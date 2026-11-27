# Combination coverage

`coverage.jl` exercises every exported entry point and every legal combination of the
`pack()` options at a small system size, so that a broken branch shows up as a line in
`coverage.csv` instead of as a surprise in a production run. It is not a replacement for
`Pkg.test()`; it is the sweep that checks the settings matrix.

```
julia --project=. benchmarks/coverage.jl
```

At N = 32 (2D) and 64 (3D), P = 1e-3, a relative-force tolerance of 1e-3 and a pressure
band of 0.05, the sweep takes about six minutes and makes 267 attempts:

| Section | Attempts | What it varies |
|:---|---:|:---|
| `api` | 11 | every exported function: `pack`, the `Packing` accessors, `find_rattlers` for every rule and a user function, `write_packing` in both formats |
| `one_factor` | 25 | every setting changed on its own away from the default |
| `physics` | 60 | dimension, contact law, friction law, mass rule and boundary, crossed |
| `algorithm` | 96 | FIRE and the three damped-dynamics integrators, crossed with every damping model, every drag model and friction on or off |
| `convergence` | 20 | all five convergence tests, crossed with all four algorithms |
| `rattlers` | 10 | all five rattler rules, friction on and off |
| `output` | 20 | HDF5 and CSV, gzip levels, the rattlers file, overwrite |
| `recording` | 6 | restart file, snapshots, movie, all three at once, a continuation, and a restart that must be refused |
| `restart` | 8 | restarts with friction on or off, periodic boxes and walls, FIRE and damped dynamics |
| `refusal` | 11 | inputs that must raise `ArgumentError` |

The last run made 255 successful attempts and 12 refusals, all of them inputs that must be
refused; no legal combination failed.

## What the sweep found

- The mid-run `RestartFile` was broken for every system: `record_step!` called
  `write_state` with a `converged` keyword the function does not take. Fixed by giving
  `RunControl` the base time step and building a `RunResults` at each write.
- A restart of a `Walls` run failed with `ArgumentError: no valid permutation of
  dimensions`, because the wall tangential springs were written with `permutedims` on a
  matrix. They are now written as an explicit `(D, walls, particles)` array.
- The exported `contact_pressure`, `mean_normal_force`, `is_converged` and `run_state`
  had no method for a `Packing`; they do now.
- `Density(density = 1.0)` and `EqualMass(mass = 1.0)` were documented but only the
  positional constructors existed; both keyword forms now work.
- `find_rattlers` accepted a user function only through `pack`, not through the exported
  function itself; it now takes the same function there.

The CSV holds one row per attempt: section, name, status (`ok`, `refused` or `error`),
detail and seconds.
