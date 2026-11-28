# SoftPack benchmarks

M-series Mac, Julia 1.12.7, one thread, current `main`. `phi` is the packing fraction of
all particles, `z` the contact number after rattler removal, `steps` the total integration
steps of the run, `time` the wall-clock seconds. Every run converges unless the table says
otherwise.

## Scaling, default settings (P = 1e-4, seed 1)

| D | N | phi | z | rattlers | steps | time (s) | ms per 1e3 steps |
|---|---|---|---|---|---|---|---|
| 2 | 256 | 0.8387 | 4.0164 | 12 | 87757 | 0.7 | 0.01 |
| 2 | 1024 | 0.8410 | 4.0429 | 46 | 206737 | 7.5 | 0.04 |
| 2 | 4096 | 0.8415 | 4.0452 | 201 | 612676 | 112.6 | 0.18 |
| 3 | 512 | 0.6403 | 6.1087 | 15 | 206020 | 7.2 | 0.03 |
| 3 | 4096 | 0.6464 | 6.1318 | 165 | 661770 | 238.3 | 0.36 |

These numbers were re-measured after the FIRE mixing became mass-weighted (card
T-3qkf). The mixing is exact-arithmetic equivalent for equal masses without rotation,
but the last bits change and a chaotic trajectory lands in a different jammed state;
single-seed frictional values move by a few percent between such changes, which is why
they are quoted with the rule that produced them.

The 3D N = 512 row is one seed: the packing fraction of a 512-sphere packing
fluctuates by about 0.005 between seeds, so the N = 4096 row or an ensemble is the
value to quote.

## Pressure sweep, 2D, N = 256, seeds 1-3

| P | phi (mean ± sd) | z | z - z_iso | rattlers | steps (mean) | time (s, mean) |
|---|---|---|---|---|---|---|
| 1e-02 | 0.8626 ± 0.0013 | 4.5170 | 0.5249 | 2.0 | 22479 | 0.20 |
| 1e-03 | 0.8423 ± 0.0023 | 4.1339 | 0.1419 | 7.0 | 56701 | 0.51 |
| 1e-04 | 0.8383 ± 0.0012 | 4.0244 | 0.0325 | 10.3 | 81800 | 0.73 |
| 1e-05 | 0.8380 ± 0.0012 | 3.9945 | 0.0027 | 10.3 | 146133 | 1.30 |

## Friction, 2D, N = 256, P = 1e-4, FIRE (the non-standard combination of design §7)

With friction the isostatic coordination of disks is about 3, so `z - z_iso` uses 3 here,
not the frictionless finite-size value.

| mu | phi | z | z - z_iso | rattlers | steps | time (s) |
|---|---|---|---|---|---|---|
| CundallStrack(0.1) | 0.8160 | 3.7009 | 0.701 | 22 | 32538 | 0.9 |
| CundallStrack(0.3) | 0.7927 | 3.3482 | 0.348 | 32 | 35601 | 0.4 |
| CundallStrack(0.5) | 0.7825 | 3.1786 | 0.179 | 32 | 66249 | 0.6 |

## Other contact laws and boundaries, 2D, P = 1e-4

| setting | N | phi | z | steps | time (s) |
|---|---|---|---|---|---|
| Hertzian | 256 | 0.8447 | 4.1526 | 44485 | 0.8 |
| Hertzian + Mindlin | 128 | 0.8006 | 3.3097 | 128464 | 1.1 |
| Walls (friction on) | 256 | 0.8115 | 4.0415 | 95151 | 1.5 |
| Walls(friction = false), mu = 0.3 | 256 | 0.7781 | 3.5085 | 67024 | 1.3 |
| Density masses | 256 | 0.8355 | 4.0244 | 83791 | 0.8 |

## Cost of the force tolerance, 2D, N = 256, P = 1e-4

| tolerance | phi | steps (mean of 2 seeds) | time (s, mean) |
|---|---|---|---|
| 0.0001 | 0.8378 | 58138 | 0.52 |
| 1.0e-6 | 0.8378 | 63806 | 0.56 |
| 1e-8 (default, scaling table, seed 1) | 0.8387 | 87757 | 0.70 |

## Damped dynamics: the slow path

| mu | tolerance | N | converged | status | phi | P reached | steps | time (s) |
|---|---|---|---|---|---|---|---|---|
| none | 0.0001 | 32 | false | steps_max | 0.8308 | 1.16e-03 | 500000 | 64.0 |
| CundallStrack(0.3) | 0.001 | 32 | false | steps_max | 0.8143 | 2.50e-05 | 500000 | 79.6 |

Damped dynamics is stable and correct (the pair tests in the suite converge for all three
integrators), but it does not reach the tight force tolerances here in 5e5 steps with
drag during compression: the contact dashpots die out slowest on the soft modes (design
§8), and with drag off after the band the few free particles keep drifting. FIRE, which
zeroes the velocities on an uphill step, has no such tail. This is the timing card T-2brz
asks for, and it supports keeping FIRE as the default and using a looser tolerance or
`StokesDrag(during = :always)` for production frictional runs.
