# SoftPack benchmarks

M-series Mac, Julia 1.12.7, one thread, current `main`. `phi` is the packing fraction of
all particles, `z` the contact number after rattler removal, `steps` the total integration
steps of the run, `time` the wall-clock seconds. Every run converges unless the table says
otherwise.

## Scaling, default settings (P = 1e-4, seed 1)

| D | N | phi | z | rattlers | steps | time (s) | ms per 1e3 steps |
|---|---|---|---|---|---|---|---|
| 2 | 256 | 0.8387 | 4.0164 | 12 | 86860 | 0.7 | 0.01 |
| 2 | 1024 | 0.8409 | 4.0369 | 49 | 189433 | 6.5 | 0.03 |
| 2 | 4096 | 0.8410 | 4.0470 | 178 | 722190 | 127.8 | 0.18 |
| 3 | 512 | 0.6465 | 6.1089 | 16 | 204583 | 7.3 | 0.04 |
| 3 | 4096 | 0.6467 | 6.1353 | 135 | 1637047 | 580.8 | 0.35 |

## Pressure sweep, 2D, N = 256, seeds 1-3

| P | phi (mean ± sd) | z | z - z_iso | rattlers | steps (mean) | time (s, mean) |
|---|---|---|---|---|---|---|
| 1e-02 | 0.8626 ± 0.0013 | 4.5170 | 0.5249 | 2.0 | 22412 | 0.21 |
| 1e-03 | 0.8424 ± 0.0022 | 4.1364 | 0.1444 | 6.7 | 53825 | 0.51 |
| 1e-04 | 0.8383 ± 0.0012 | 4.0217 | 0.0299 | 10.7 | 100492 | 0.96 |
| 1e-05 | 0.8381 ± 0.0012 | 3.9918 | -0.0000 | 12.0 | 142186 | 1.35 |

## Friction, 2D, N = 256, P = 1e-4, FIRE (the non-standard combination of design §7)

With friction the isostatic coordination of disks is about 3, so `z - z_iso` uses 3 here,
not the frictionless finite-size value.

| mu | phi | z | z - z_iso | rattlers | steps | time (s) |
|---|---|---|---|---|---|---|
| CundallStrack(0.1) | 0.8131 | 3.7106 | 0.711 | 21 | 39137 | 0.8 |
| CundallStrack(0.3) | 0.7997 | 3.3712 | 0.371 | 27 | 66256 | 0.6 |
| CundallStrack(0.5) | 0.7856 | 3.2035 | 0.204 | 30 | 144411 | 1.3 |

## Other contact laws and boundaries, 2D, P = 1e-4

| setting | N | phi | z | steps | time (s) |
|---|---|---|---|---|---|
| Hertzian | 256 | 0.8447 | 4.1526 | 44683 | 0.7 |
| Hertzian + Mindlin | 128 | 0.7793 | 3.3950 | 80578 | 0.7 |
| Walls (friction on) | 256 | 0.8115 | 4.0328 | 85771 | 1.3 |
| Walls(friction = false), mu = 0.3 | 256 | 0.7784 | 3.5193 | 27582 | 0.7 |
| Density masses | 256 | 0.8417 | 4.0081 | 82317 | 0.7 |

## Cost of the force tolerance, 2D, N = 256, P = 1e-4

| tolerance | phi | steps (mean of 2 seeds) | time (s, mean) |
|---|---|---|---|
| 0.0001 | 0.8378 | 55224 | 0.44 |
| 1.0e-6 | 0.8378 | 70886 | 0.56 |
| 1e-8 (default, scaling table, seed 1) | 0.8387 | 86860 | 0.72 |

## Damped dynamics: the slow path

| mu | tolerance | N | converged | status | phi | P reached | steps | time (s) |
|---|---|---|---|---|---|---|---|---|
| none | 0.0001 | 32 | false | steps_max | 0.8308 | 1.16e-03 | 500000 | 59.9 |
| CundallStrack(0.3) | 0.001 | 32 | false | steps_max | 0.8143 | 2.50e-05 | 500000 | 78.6 |

Damped dynamics is stable and correct (the pair tests in the suite converge for all three
integrators), but it does not reach the tight force tolerances here in 5e5 steps with
drag during compression: the contact dashpots die out slowest on the soft modes (design
§8), and with drag off after the band the few free particles keep drifting. FIRE, which
zeroes the velocities on an uphill step, has no such tail. This is the timing card T-2brz
asks for, and it supports keeping FIRE as the default and using a looser tolerance or
`StokesDrag(during = :always)` for production frictional runs.
