# Tested combinations

*Up:* [Reference](naming.md)

`Pkg.test()` checks the physics on small cases. On top of it, `benchmarks/coverage.jl`
runs every exported entry point and every legal combination of the `pack()` options at a
small size, and writes one line per attempt to `coverage.csv`. The last run made 267
attempts: 255 succeeded and 12 were inputs that must be refused, with no legal
combination failing.

The sweep covers:

- every exported function: `pack`, the `Packing` accessors, `find_rattlers` with every
  rule and with a user function, and `write_packing` in both formats;
- every setting on its own away from the default;
- dimension, contact law, friction law, mass rule and boundary, crossed;
- FIRE and the three damped-dynamics integrators, crossed with every damping model,
  every drag model and friction on and off;
- every convergence test with every algorithm;
- every rattler rule with and without friction;
- HDF5 and CSV output with every compression and rattlers-file choice;
- restart files, snapshots, movies, and restarts that must be refused;
- the inputs that must raise an `ArgumentError`.

The sweep found three defects that the unit tests had missed: the mid-run restart file
was never written (its call had a stale signature), restarts of wall systems failed on the
wall tangential springs, and four exported accessors had no method for a `Packing`.

To rerun it:

```
julia --project=. benchmarks/coverage.jl
```

The run takes about six minutes. `benchmarks/coverage.md` lists what each section varies
and what the sweep found.
