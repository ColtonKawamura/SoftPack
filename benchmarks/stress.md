# Stress test results

Wide parameter sweep and large packings, run on the MacBook (18 cores, 137 GB, Julia
1.12.7, one thread per run, `main` plus the fixes on `stress-test-sweep`). Each run appends
one CSV row as soon as it ends, so a killed process keeps every finished row.

Run a section with

```sh
julia --project=. benchmarks/stress.jl corners
julia --project=. benchmarks/stress.jl physics small3d medium targets record
```

`STRESS_CSV=<path>` redirects the rows. Statuses: `ok`, `nonconverged` (returned but did
not meet the tests), `invalid` (returned with a non-physical number), `error` (threw), and
`refused` (an expected `PackingError`).

## Coverage

| section | attempts | ok | nonconverged | refused |
|---|---|---|---|---|
| corners (extreme single settings, N = 32) | 87 | 66 | 15 | 6 |
| corners2 (size extremes, low P, recording) | 19 | 12 | 4 | 3 |
| physics (law x friction x mass x boundary x D) | 60 | 60 | 0 | 0 |
| small3d (tests, rattlers, algorithms in 3D) | 14 | 12 | 2 | 0 |
| medium (common production combinations) | 16 | 12 | 4 | 0 |
| targets (P x tolerance, 2D and 3D) | 24 | 24 | 0 | 0 |
| record (output, snapshots, movie, restarts) | 9 | 8 | 1 | 0 |
| coverage regression (`benchmarks/coverage.jl`) | 267 | 267 | 0 | 0 |

The remaining `nonconverged` rows are settings that are meant to fail or that need more
steps: zero damping, a 1e-6 fixed step, a 1e-12 tolerance below the Float64 floor, a target
pressure above the dense limit, and `DampedDynamics` at a 1e-4 tolerance. The refusals are
periodic systems with N <= 4 (the nearest-image guard, design card T-c822) and extreme size
ratios whose largest particle exceeds half the box.

## Large packings

Default settings (P = 1e-4, tolerance 1e-8, pressure band 1e-4), unless noted. Times are
wall clock with several runs sharing the machine, so compare step counts where the number
matters.

| D | N | setting | phi | z | steps | time (s) |
|---|---|---|---|---|---|---|
| 2 | 16384 | default | 0.8414 | 4.0454 | 1 384 367 | 2186 |
| 2 | 8192 | mu = 0.3, FIRE | 0.8043 | 3.3695 | 218 239 | 256 |
| 2 | 8192 | Walls | 0.8364 | 4.0468 | 1 207 040 | 1173 |
| 3 | 4096 | default | 0.6464 | 6.1318 | 661 770 | 396 |
| 3 | 2048 | mu = 0.3, FIRE | 0.5808 | 4.7031 | 196 317 | 117 |
| 3 | 2048 | Hertzian | 0.6521 | 6.5159 | 189 720 | 92 |
| 3 | 2048 | Walls | 0.6046 | 6.1181 | 661 901 | 294 |

The 2D and 3D values continue the benchmark trends (2D phi -> 0.8415 and z -> 4.045, 3D phi
-> 0.646 and z -> 6.13). A restart file written by the 4096-particle 3D run, taken at 80 000
steps, continued to convergence at 155 200 steps with the same packing fraction to the
printed digits.

## Failure points found and fixed

1. **Frictional starting time step used the wrong tangential mass.** `timestep_start` used
   `M_t = M_n/(1 + 1/inertia_ratio)` instead of `M_t = M_n/(1 + inertia_ratio)` (design
   §8: `M_t = M_n/3` in 2D, `M_n/3.5` in 3D). The tangential collision time was therefore
   1.41 times too long in 2D and 1.58 in 3D, so every frictional run started with too large
   a step. Fixed; frictional traversals changed (step counts and end states), frictionless
   trajectories are bit-identical.
2. **3D Hertzian expected overlap used the 2D force formula.** The typical force at the
   target is `P pi d/(z phi)` in 2D but `P pi d^2/(z phi)` in 3D, so non-unit diameters got
   the wrong starting step. Fixed; unit diameters are unchanged.
3. **`TwoContact` crashed every write.** `rattlers_dict` read `rule.cone_test`, a field the
   type does not have, so `write_packing` and any restart file threw a `FieldError`. Fixed
   and covered by a write + restart test.
4. **Wall-clock recording intervals crashed.** `Schedule` had no three-argument method for
   `Dates.Period`, so `Snapshots`, `RestartFile` and `Movie` with a `Millisecond`/`Second`
   interval threw a `MethodError` before the run started. Fixed and tested.
5. **Unreachable target pressures produced nonsense or a misleading error.** `P = 1` at
   N = 32 returned `converged = true` with phi = 2.19 (particles overlapping more than their
   diameter), while a very soft law or `P = 100` died inside the neighbor list's
   nearest-image guard with "use more particles". A trial at phi >= 1 is now rejected and
   the strain halved, like an over-pressure trial; if the step cannot shrink the run ends
   with `stop_reason = :packing_fraction_max`, `converged = false` and a warning, on the
   last accepted packing. Large `strain_step` values (0.5) still work.
6. **CSV export was not atomic.** `write_csv` wrote straight to the target, so a killed
   export truncated the existing file, contradicting the safe-write contract in §11. It now
   writes a temporary file and renames it.
7. **Mid-run restart files rewrote every snapshot frame.** `record_step!` passed the whole
   snapshot history to `write_state` at every interval, making the I/O quadratic in the
   frame count. Mid-run restarts now skip snapshots; the final restart file and
   `write_packing` still store them.
8. **Zero or negative recording intervals were accepted.** `Snapshots(every = 0)` recorded a
   frame on every step and would exhaust memory on a large run. `Snapshots`, `Movie` and
   `RestartFile` intervals (and the movie size and fps) are now validated as positive.
9. **A custom rattler function was silently dropped on restart.** The stored settings wrote
   `nothing` for a function, and a restart then applied no rule at all. Restart now refuses
   with a clear `ArgumentError`, like a custom convergence function.

## Known limitations (not fixed)

- **Periodic systems with N <= 4** at the default start are refused by the nearest-image
  guard: with the neighbor skin, the box is smaller than two cutoffs. The guard is
  deliberate (card T-c822); a smaller `packing_fraction` or more particles works.
- **`DampedDynamics` with the centered velocity Verlet solve does not scale.** The sparse
  Cholesky costs about 2 ms per step at N = 128 (3D) and 55 ms at N = 4096 (2D), so large
  production runs must use FIRE (or an explicit integrator); this is the design's known
  slow path, not a new bug. In the sweep, N = 128 in 3D with drag took 23 minutes for
  300 000 steps and still did not reach a 1e-4 tolerance.
- **`DampedDynamics` needs a looser tolerance or always-on drag** to finish; this matches
  the existing benchmark note in `results.md`.
- **The Float64 force floor** still limits very large N at low target pressure, as
  documented on card T-2brz; `float64_floor_warning` announces it at run start.
