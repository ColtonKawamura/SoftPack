# `FIRE()`

*Up:* [`algorithm`](index.md)

FIRE (fast inertial relaxation engine) is a minimization that behaves like a damped
oscillator with a memory [Bitzek2006], [Guenole2020]. Each step moves the particles with a semi-implicit
Euler step, then mixes the velocity toward the direction of the force:

$$v \leftarrow (1 - \alpha) v + \alpha \, |v| \, \frac{F}{|F|},$$

with $\alpha$ starting at the mixing coefficient. When the power $W = F \cdot v$ (the FIRE papers write $P$, which SoftPack uses for the
pressure) is
positive the algorithm is going downhill, so the step is allowed to grow and $\alpha$ is
shrunk; when the power is negative it is going uphill, so the step is cut and $\alpha$ is
reset.

## Why it is the default

FIRE therefore needs no tuning of its time step for a new packing, which is why it
is the default.

The first ten parameters are the standard FIRE 2.0 scheme, with the LAMMPS values;
`integrator`, `displacement_max`, `damping` and `drag` are SoftPack additions. You
rarely need to touch them.

| Option | Default | Meaning |
|:---|:---|:---|
| `timestep_max` | `10.0` | upper bound of the adaptive step, in multiples of the starting step |
| `timestep_min` | `0.02` | lower bound; a run that reaches it is stuck |
| `delay` | `20` | steps of downhill before the step is allowed to grow |
| `timestep_grow` | `1.1` | factor applied to the step on a downhill step |
| `timestep_shrink` | `0.5` | factor applied on an uphill step |
| `mixing_coefficient` | `0.25` | the starting $\alpha$ |
| `mixing_shrink` | `0.99` | factor applied to $\alpha$ on each downhill step |
| `uphill_max` | `2000` | uphill steps tolerated before the run stops with `:uphill_max` |
| `inertia_correction` | `true` | whether an uphill move steps back half a step (LAMMPS `halfstepback`) |
| `delay_initial` | `true` | whether the first `delay` steps are taken before growth |
| `integrator` | `:semi_implicit_euler` | the only integrator FIRE implements |
| `displacement_max` | `0.1` | the largest displacement of one step, in reference diameters |
| `damping` | `nothing` | optional contact dashpots, see [damping](DampedDynamics/damping/index.md) |
| `drag` | `nothing` | optional Stokes drag, see [drag](DampedDynamics/drag/index.md) |

## Checks

The mixing is mass-weighted: the speed is
$\sqrt{\sum_i m_i|v_i|^2 + \sum_i I_i|\omega_i|^2}$, the force direction is
$F_i/m_i$ and $\tau_i/I_i$, and the power that decides downhill is taken from the elastic
forces alone, so a dashpot or drag cannot steer the minimization. With equal masses and no
rotation this reduces to the unweighted rule, bit for bit.

FIRE validates its own parameters at the call: `timestep_min` must not
exceed `timestep_max`, `timestep_grow` must be at least 1, `timestep_shrink` must lie in
$(0, 1]$, and `delay` and `uphill_max` must be positive. With `damping` set, the step
ceiling is clamped to the damped stability limit measured from the packing's stiffest
contact. FIRE with friction runs but warns that the combination is
non-standard; the rotational mixing is provisional.

## Stopping

FIRE stops when the convergence test holds, when `steps_max` is reached, or when it has
spent `uphill_max` steps without finding a downhill direction. The last case is reported
as `stop_reason = :uphill_max`; it usually means the packing is stuck on a saddle and a
restart with a different seed or a looser tolerance is the way forward.

## Example

```julia
using SoftPack

packing = pack(
    algorithm = FIRE(
        delay = 20,             # downhill steps before growth
        timestep_grow = 1.1,
        mixing_coefficient = 0.25,
    ),
    particles_count = 256,
    seed = 1,
)
packing.converged
```

## References

- **[Bitzek2006]** Erik Bitzek, Pekka Koskinen, Franz Gähler, Michael Moseler, Peter Gumbsch (2006). *Structural Relaxation Made Simple*. Physical Review Letters **97**, 170201. [doi:10.1103/physrevlett.97.170201](https://doi.org/10.1103/physrevlett.97.170201).
- **[Guenole2020]** Julien Guénolé, Wolfram G. Nöhring, Aviral Vaid, Frédéric Houllé, Zhuocheng Xie, Aruna Prakash, Erik Bitzek (2020). *Assessment and optimization of the fast inertial relaxation engine (fire) for energy minimization in atomistic simulations and its implementation in lammps*. Computational Materials Science **175**, 109584. [doi:10.1016/j.commatsci.2020.109584](https://doi.org/10.1016/j.commatsci.2020.109584).
