# `FIRE()`

*Up:* [`algorithm`](index.md)

FIRE (fast inertial relaxation engine) is a minimization that behaves like a damped
oscillator with a memory (design §14). Each step moves the particles with a semi-implicit
Euler step, then mixes the velocity toward the direction of the force:

$$v \leftarrow (1 - \alpha) v + \alpha \, |v| \, \frac{F}{|F|},$$

with $\alpha$ starting at the mixing coefficient. When the power $P = F \cdot v$ is
positive the algorithm is going downhill, so the step is allowed to grow and $\alpha$ is
shrunk; when the power is negative it is going uphill, so the step is cut and $\alpha$ is
reset. FIRE therefore needs no tuning of its time step for a new packing, which is why it
is the default.

The 11 parameters are the ones of the standard scheme; their defaults are the LAMMPS
values. You rarely need to touch them.

| Option | Default | Meaning |
|:---|:---|:---|
| `timestep_max` | `10.0` | upper bound of the adaptive step |
| `timestep_min` | `0.02` | lower bound; a run that reaches it is stuck |
| `delay` | `20` | steps of downhill before the step is allowed to grow |
| `timestep_grow` | `1.1` | factor applied to the step on a downhill step |
| `timestep_shrink` | `0.5` | factor applied on an uphill step |
| `mixing_coefficient` | `0.25` | the starting $\alpha$ |
| `mixing_shrink` | `0.99` | factor applied to $\alpha$ on each downhill step |
| `uphill_max` | `2000` | uphill steps tolerated before the run stops with `:uphill_max` |
| `inertia_correction` | `true` | whether $\alpha$ follows the standard FIRE schedule |
| `delay_initial` | `true` | whether the first `delay` steps are taken before growth |
| `integrator` | `:semi_implicit_euler` | the only integrator FIRE implements |
| `damping` | `nothing` | optional contact dashpots, see [damping](DampedDynamics/damping/index.md) |
| `drag` | `nothing` | optional Stokes drag, see [drag](DampedDynamics/drag/index.md) |

## Checks

FIRE validates its own parameters at the call (card T-3qkf): `timestep_min` must not
exceed `timestep_max`, `timestep_grow` must be at least 1, `timestep_shrink` must lie in
$(0, 1]$, and `delay` and `uphill_max` must be positive. With `damping` set, the step
ceiling is clamped to the damped stability limit measured from the packing's stiffest
contact (card T-tx4b). FIRE with friction runs but warns that the combination is
non-standard (design §7); the rotational mixing is provisional.

## Stopping

FIRE stops when the convergence test holds, when `steps_max` is reached, or when it has
spent `uphill_max` steps without finding a downhill direction. The last case is reported
as `stop_reason = :uphill_max`; it usually means the packing is stuck on a saddle and a
restart with a different seed or a looser tolerance is the way forward.

## Archival reference

- [FIRE settings](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings)
- [Defaults and their reasons](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings#defaults-and-their-reasons)
