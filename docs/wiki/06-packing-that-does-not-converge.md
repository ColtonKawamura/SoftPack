# 6. A packing that does not converge

Design decision source: [design-references.md §6](../design-references.md#6-a-packing-that-does-not-converge).
Status: design stage (no engine code yet).

## Summary

A run can end in three ways: it converges, it runs out of steps (`steps_max`, or FIRE's
`uphill_max`), or something outside `pack()` stops it (a cluster time limit, a crash).
`pack()` never throws away an unfinished packing and never saves it silently. By
default it prints a warning and returns the packing with `converged = false`
(`failure_action = :warn`); `failure_action = :error` throws instead. Any packing
written by `write_packing`, converged or not, can be continued with
`restart_packing = path`. The file holds the full run state, so a stopped and restarted
run ends with exactly the same packing, bit for bit, as a run that was never stopped
(same machine and versions). `restart_file = RestartFile(path; every = interval)` saves
that state during the run, every so many steps or every so much wall-clock time, so a
job killed by a time limit loses at most one interval of work. This page lists the
state that exact continuation needs and shows, on a small probe, why each part of it
matters.

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| `failure_action` | `:warn` | `:error` | [Warn and return](#warn-and-return-failure_action), [Throw an error](#throw-an-error-failure_action--error) |
| `restart_packing` | `nothing` | path to a file written by `write_packing` (or by `restart_file`) | [Off by default](#no-restart-by-default-restart_packing), [Continue a run](#continue-a-run-restart_packing--path) |
| `restart_file` | `nothing` | `RestartFile(path; every = interval)` | [Off by default](#no-saves-by-default-restart_file), [Save during the run](#save-during-the-run-restart_file--restartfile) |
| `RestartFile` `every` | no default (must be given) | a number of steps (`every = 10^5`) or a wall-clock time (`every = Hour(1)`) | [Interval](#save-during-the-run-restart_file--restartfile) |
| `steps_max` | `10^7` ([§5](05-convergence-criterion.md)) | any value; on a restart, a new budget counted from the restart | [Run control](#settings-that-may-change-on-a-restart) |

On a restart only the run-control settings may change: `steps_max`, `failure_action`,
`convergence`, `restart_file`, `snapshots` and `movie`. Any other keyword raises an
error.

## Model

### Symbols

| Symbol | Meaning |
|---|---|
| $n$ | step count, counted from the start of the packing (not of the call) |
| $\mathbf s_n$ | the run state after step $n$ (everything the next step reads) |
| $\Phi$ | one step of the algorithm, $\mathbf s_{n+1} = \Phi(\mathbf s_n)$ |
| $\mathbf x_i$, $\theta_i$ | position and rotation angle of particle $i$ (2D; a rotation in 3D) |
| $\mathbf v_i$, $\omega_i$ | velocity and spin of particle $i$ |
| $\mathbf F_i$, $T_i$ | total force and torque on particle $i$ (elastic plus dashpot) |
| $m_i$, $I_i$ | mass and moment of inertia |
| $\xi_c$ | tangential spring stretch of contact $c$ (the contact history, [§13](13-friction-models.md)) |
| $k_t$, $\mu$, $f_n$ | tangential stiffness, friction coefficient, elastic normal force |
| $\gamma_n$, $\gamma_t$ | normal and tangential dashpot coefficients (force per velocity, [§8](08-damping.md)) |
| $\Delta t$ | time step; for FIRE the current, adapted step ([§14](14-fire-settings.md)) |
| $\alpha$, $N_+$, $N_-$ | FIRE's mixing coefficient and its counts of consecutive downhill and uphill steps |
| $\tau = \sqrt{m/k}$ | time unit ([§12](12-time-step.md)) |

### Run outcomes

| Outcome | When | What `pack()` does | Restart file (if `restart_file` is set) |
|---|---|---|---|
| running | every step | integrates; saves the state when `every` is due | rewritten at each save (temporary file, then renamed over `path`) |
| converged | the convergence test of [§5](05-convergence-criterion.md) passes | returns the packing with `converged = true` | written at the stop |
| not converged: step budget | `steps_max` steps done in this call | `:warn`: warning, returns `converged = false`; `:error`: throws | written at the stop |
| not converged: FIRE uphill limit | more than `uphill_max = 2000` consecutive uphill FIRE steps ([§14](14-fire-settings.md)) | as for the step budget | written at the stop |
| stopped from outside | time limit, crash, killed process | nothing is returned | the last complete periodic save |

The same as pseudocode. The order of the checks inside a step is not designed yet; this
is our reading of the decisions (**SoftPack note**):

```text
state = restart_packing === nothing ? initial_state(settings, seed) : read_state(restart_packing)
steps_this_call = 0
status = :running
while status == :running
    state, uphill_limit = step(state)               # FIRE or DampedDynamics, §7
    steps_this_call += 1
    if uphill_limit                      status = :uphill_max      # FIRE only, §14
    elseif converged(state)              status = :converged       # §5
    elseif steps_this_call == steps_max  status = :steps_max       # §5
    end
    if restart_file !== nothing && save_due(restart_file, state)   # steps or wall clock
        save_atomic(restart_file.path, state)       # read-only: must not change state
    end
end
restart_file !== nothing && save_atomic(restart_file.path, state)  # also when not converged
if status != :converged
    failure_action == :warn ? warn("not converged: $status") : error("not converged: $status")
end
return Packing(state; converged = status == :converged)
```

A run stopped from outside never reaches the end of the loop. What survives is the
last file written by `save_atomic`.

### The run state

A step reads the state and nothing else, $\mathbf s_{n+1} = \Phi(\mathbf s_n)$, so a run
that resumes from an exact copy of $\mathbf s_n$ repeats the remaining steps exactly.
The design doc lists what the file holds (§6, §11): every particle including rattlers;
positions, velocities, rotations and spins; the contact history; the box; FIRE's step,
mixing coefficient and counters; the state of the compression protocol; the step count;
every setting; and the SoftPack and Julia versions. For the two algorithms the state
read by $\Phi$ is:

| Part of $\mathbf s_n$ | FIRE | DampedDynamics | Why it is needed |
|---|---|---|---|
| positions $\mathbf x_i$, rotations $\theta_i$ | yes | yes | the configuration |
| velocities $\mathbf v_i$, spins $\omega_i$ | yes | yes | inertia: the next position depends on them ([derivation](#velocities)) |
| half-step state: forces and torques of the last evaluation, or the half-step velocities they used | needed when forces depend on velocity (dashpots, drag) | yes with dashpots (the default) | [LAMMPS half-step note](#the-half-step-velocity) |
| contact history $\xi_c$, with the list of open contacts | with friction | with friction | the tangential force is $-k_t\xi_c$ ([derivation](#contact-history)) |
| which contacts are sliding | if a dashpot is switched by it | with friction and tangential dashpots | the tangential dashpot is off while sliding ([§8](08-damping.md)) |
| $\Delta t$, $\alpha$, $N_+$, $N_-$ | yes | – ($\Delta t$ fixed, from settings) | FIRE's next step depends on them ([derivation](#fires-internal-state)) |
| step count $n$ | yes (`delay_initial` tests $n < N_\text{delay}$) | yes (records, output intervals) | [derivation](#fires-internal-state) |
| box; compression-protocol state | yes | yes | the protocol is not designed yet |
| RNG state | if random numbers are drawn after the start | same | [derivation](#random-numbers) |
| order of the force sums (contact or neighbor list) | yes | yes | floating-point sums depend on order ([derivation](#summation-order)) |

The last five rows are **SoftPack notes** (our derivation): the design doc's list does not
name the sliding flags, the RNG state or the summation order (see
[Open questions](#open-questions)).

## Derivations

### Exact continuation is a property of the map

Let the unbroken run produce $\mathbf s_0, \mathbf s_1, \dots, \mathbf s_N$. A run stopped
after step $n$ writes $\mathbf s_n$; the restarted run reads $\tilde{\mathbf s}\_n$ and
computes $\tilde{\mathbf s}\_{n+j} = \Phi^{j}(\tilde{\mathbf s}\_n)$. If $\Phi$ is a fixed
sequence of floating-point operations (same code, compiler and machine) and
$\tilde{\mathbf s}\_n = \mathbf s_n$ bit for bit, then by induction
$\tilde{\mathbf s}\_{n+j} = \mathbf s_{n+j}$ bit for bit for every $j$, including the step
at which the convergence test passes. Two things break it:

- a part of $\mathbf s_n$ that is not written (or is written with rounding: the file must
  store the exact `Float64` values, as HDF5 does, [§11](11-outputs.md));
- a step $\Phi$ that is not the same function after the restart (a different summation
  order, a different version).

Any difference, however small, then grows: the packing is a chaotic dynamical system
until it settles, and a frictional packing settles into a different static state
([Worked numbers](#worked-numbers)). **SoftPack note.**

### Velocities

Both algorithms are second order in time. In velocity Verlet with time step $\Delta t$,

$$\mathbf v_i^{\,n+1/2} = \mathbf v_i^{\,n} + \frac{\Delta t}{2m_i}\mathbf F_i^{\,n}, \qquad \mathbf x_i^{\,n+1} = \mathbf x_i^{\,n} + \Delta t\,\mathbf v_i^{\,n+1/2}, \qquad \mathbf v_i^{\,n+1} = \mathbf v_i^{\,n+1/2} + \frac{\Delta t}{2m_i}\mathbf F_i^{\,n+1},$$

and the same for $\theta_i$, $\omega_i$, $T_i$ and $I_i$. The new position depends on
$\mathbf v_i^{\,n}$, so a restart with $\mathbf v = 0$ starts a different trajectory.
FIRE's step reads $\mathbf v$ in three places: the power
$P = \sum_i(\mathbf F_i\cdot\mathbf v_i + T_i\,\omega_i)$ that decides between the
downhill and uphill branches, the mixing term $\alpha\,\lvert\mathbf v\rvert\,\hat{\mathbf F}$,
and the half step back $\mathbf x \leftarrow \mathbf x - \tfrac12\Delta t\,\mathbf v$
([§14](14-fire-settings.md)).

### The half-step velocity

Dashpot and drag forces depend on velocity. In velocity Verlet the force
$\mathbf F^{\,n+1}$ is computed after the drift, when only the half-step velocity
$\mathbf v^{\,n+1/2}$ is known, so

$$\mathbf F^{\,n+1} = \mathbf F\left(\mathbf x^{\,n+1}, \mathbf v^{\,n+1/2}, \xi^{\,n+1}\right).$$

The full-step velocity $\mathbf v^{\,n+1}$ is what a file of positions and velocities
holds. Re-evaluating the forces from it at a restart gives
$\mathbf F(\mathbf x^{\,n+1}, \mathbf v^{\,n+1}, \xi^{\,n+1}) \ne \mathbf F^{\,n+1}$, and the
next half kick differs. This is the LAMMPS caveat the design doc quotes:
[LAMMPSreadrestart] "the forces they compute depend on atom velocities, which are used at
half-step values every timestep when forces are computed. When a run restarts, forces
are initially evaluated with a full-step velocity, which is different than if the run
had continued." SoftPack's dashpots depend on velocity too, so the file stores the
integrator's half-step state (design doc). Storing the forces and torques of the last
evaluation is the safest form of that state: re-evaluating them from stored half-step
velocities must also reproduce every branch the original evaluation took. In our probe
it did not, because a contact that had just been capped at the Coulomb limit was
re-evaluated as exactly at the limit, which counts as stuck, so its tangential dashpot
came back on: at the restart step 3 contacts were sliding, none were on re-evaluation,
and the springs were identical but forces differed by up to $8.8\times10^{-5}$
([Worked numbers](#worked-numbers)). **SoftPack note.**

Semi-implicit Euler (FIRE's default integrator) reads $\mathbf v^{\,n}$ and
$\mathbf F(\mathbf x^{\,n})$; without velocity-dependent forces the forces can be
recomputed from the stored positions bit for bit, so velocities, positions and FIRE's
scalars are enough.

### Contact history

With friction the tangential force on a stuck contact is the spring force of the
stored stretch, and the stretch is a sum over the contact's past
([§13](13-friction-models.md), [§7](07-algorithms-and-combinations.md)):

$$\xi_c^{\,n+1} = \operatorname{clip}\left(\xi_c^{\,n} + \Delta\xi_c^{\,n},\ -\frac{\mu f_n}{k_t},\ +\frac{\mu f_n}{k_t}\right), \qquad F_t^\text{el} = -k_t\,\xi_c,$$

with $\Delta\xi_c$ the tangential slip increment of the step, $\xi_c = 0$ when the contact
forms and when it opens. The positions do not determine $\xi_c$: two runs through the
same configuration can carry different springs ([§7](07-algorithms-and-combinations.md)
gives a one-contact example with opposite forces). A restart that sets $\xi_c = 0$
changes every stuck contact's force at once. LAMMPS keeps this state for its granular
pair styles: [LAMMPSreadrestart] "In the case of granular potentials, it is contact
information between pairs of touching particles."

### FIRE's internal state

One FIRE 2.0 step ([§14](14-fire-settings.md)) reads, besides $\mathbf x$, $\mathbf v$ and
$\mathbf F$:

- $\Delta t$: the drift is $\Delta t\,\mathbf v$, and $\Delta t$ grows by 1.1 per downhill
  step after the delay, up to $10\,\Delta t_\text{start}$;
- $\alpha$: the mixing weight, shrunk by 0.99 per downhill step after the delay, reset to
  0.25 on an uphill step;
- $N_+$: the step may grow only if $N_+ > N_\text{delay} = 20$;
- $N_-$: the run stops when $N_- > 2000$;
- the step count $n$: with `delay_initial`, an uphill step with $n < N_\text{delay}$
  neither shrinks $\Delta t$ nor resets $\alpha$.

None of these is a function of the configuration, so a restart that resets them to their
start values ($\Delta t_\text{start}$, 0.25, 0, 0, 0) runs a different minimization. In our
probe the restart point had $\Delta t = 5\,\Delta t_\text{start}$ (frictionless) and
$10\,\Delta t_\text{start}$ with $\alpha = 0.194$ (frictional); resetting them changed
the result ([Worked numbers](#worked-numbers)). The step count matters only if an uphill
step falls within $N_\text{delay}$ steps of the restart: resetting it at a point with no
such step left the run bitwise unchanged, resetting it 5 steps before an uphill step did
not. **SoftPack note.**

### Summation order

Floating-point addition is not associative, so the net force on a particle depends on
the order in which its contact forces are added. In our probe, adding the same pair
forces in a permuted order changed individual forces by up to $1.4\times10^{-17}$
(rounding level) and the converged positions by up to
$1.8\times10^{-15}$: not bitwise equal. A restart must therefore rebuild the contact
and neighbor lists in the same order as the unbroken run, or store them. Saving must not
rebuild them either. LAMMPS documents exactly this side effect of its restart output
([LAMMPSrestart]): "Writing a restart file forces a neighbor list rebuild on
that timestep" and "because changing when neighbor lists are rebuilt changes the order
in which pairwise interactions are summed, it can also lead to small differences in the
trajectory (due to the limitations of floating-point math) compared to an otherwise
identical run without restart output." The design doc's statement that "Saving does not
change the trajectory" therefore requires a save that only reads the state.
**SoftPack note.**

### Random numbers

Initial positions are drawn from the seeded StableRNG ([§10](10-reproducibility.md)). If
anything draws random numbers after step 0 (the compression protocol, not designed
yet), the generator's internal state is part of $\mathbf s_n$: re-seeding at a restart
would replay the stream from its start. If nothing random happens after step 0, the
seed alone is enough. **SoftPack note.**

### Work lost when a job is killed

Saves at a fixed wall-clock interval $T_\text{save}$ (`every = Hour(1)`): the last complete
file is at most $T_\text{save}$ plus the duration of one save older than the kill, so the
work lost per killed job is at most about $T_\text{save}$, for any system size. Saves every
$S$ steps lose at most $S$ steps, whose wall-clock cost grows with the system size. The
atomic rename means a kill during a save leaves the previous file intact. **SoftPack
note**, from the design doc's reasons.

## Defaults and their reasons

### Warn and return (`failure_action`)

```julia
pack(failure_action = :warn)
```

**Decision.** `pack()` prints a warning and returns the packing with `converged = false`.
Retrying with other seeds is the caller's job.

- **SoftPack choice**: let the caller see and count failures. Replacing failures
  conditions an ensemble on convergence: if seeds that fail within `steps_max` are
  silently replaced, the ensemble is drawn from the packings that converge fast enough,
  and any property correlated with slow convergence (low pressure, soft modes, large
  systems, [§5](05-convergence-criterion.md)) is biased. Returning the flag keeps the
  failure rate visible.
- The packing is returned, not discarded, so it can be written and continued.

### No restart by default (`restart_packing`)

```julia
pack(restart_packing = nothing)
```

**Decision.** Off by default. `restart_packing = path` loads a packing written by
`write_packing`, converged or not, with all of its settings and its full state, and
continues the run from the step where it stopped:

```julia
packing = pack(steps_max = 10^6)                # returns with converged = false
write_packing("packing.h5", packing)
packing = pack(restart_packing = "packing.h5")  # continues where it stopped
```

- Precedent: LAMMPS restart files. [LAMMPSreadrestart] "Read in a previously saved
  system configuration from a restart file. This allows continuation of a previous run."
- Everything needed is in the file ([§11](11-outputs.md)), and a restart needs no other
  input. LAMMPS does not do this: [LAMMPSwriterestart] "Although the purpose of restart
  files is to enable restarting a simulation from where it left off, not all information
  about a simulation is stored in the file." **SoftPack choice.**
- Exact continuation is a test requirement: a run stopped and restarted ends with the
  same packing as one run that was never stopped, on the same machine and versions.
  [LAMMPSreadrestart] "Restart files are saved in binary format to enable exact
  restarts, meaning that the trajectories of a restarted run will precisely match those
  produced by the original run had it continued on." Velocities and the half-step state
  are stored because of the granular-pair-style caveat quoted
  [above](#the-half-step-velocity). **SoftPack choice.**
- On a different SoftPack or Julia version the restart runs but warns that it may not be
  exact, as LAMMPS does: [LAMMPSreadrestart] "Several things can prevent exact restarts
  due to round-off effects, in which case the trajectories in the 2 runs will slowly
  diverge."
- The output records each restart (file and step).

### No saves by default (`restart_file`)

```julia
pack(restart_file = nothing)
```

**Decision.** Off by default.

- Precedent and default: [LAMMPSrestart] "Write out a binary restart file with the
  current state of the simulation on timesteps which are a multiple of N. A value of
  N = 0 means do not write out any restart files, which is the default." Off by default
  also because short runs do not need it and each save costs time and disk.

## Options

### Throw an error (`failure_action = :error`)

```julia
pack(failure_action = :error)
```

**Option.** Throws an error instead of returning, for batch scripts that should stop at
the first failure. **SoftPack choice.** With `restart_file` set, the file is written when
the run stops, converged or not (design doc), so the unfinished state is on disk even
though nothing is returned; whether this write happens before the error is thrown is our
reading ([Open questions](#open-questions)).

### Continue a run (`restart_packing = path`)

```julia
pack(restart_packing = "packing.h5", steps_max = 2 * 10^7)
```

**Option.** Continue from the stored state. Converged packings can be restarted too,
for example with a tighter `convergence` tolerance.

#### Settings that may change on a restart

Only run-control settings may change: `steps_max` (a new budget, counted from the
restart), `failure_action`, `convergence`, `restart_file`, `snapshots` and `movie`. Any
other keyword raises an error, because it would change the protocol halfway through and
the packing would match neither setting. **SoftPack choice.**

These settings decide when to stop and what to record; none of them enters $\Phi$. So a
restart with a new `steps_max` or `snapshots` still follows the unbroken trajectory, and
a new `convergence` only moves the stopping step along the same trajectory. One
exception: `RestartTest()` zeroes the velocities ([§5](05-convergence-criterion.md)), so
it does change the trajectory, and a restart in the middle of its watch needs the
test's own state. **SoftPack note.**

### Save during the run (`restart_file = RestartFile(...)`)

```julia
pack(restart_file = RestartFile("restart.h5"; every = 10^5))       # every 10^5 steps
pack(restart_file = RestartFile("restart.h5"; every = Hour(1)))    # every hour of wall-clock time
```

**Option.** Saves the run's full state to `path` while it runs, in the same format that
`restart_packing` reads.

- `every` has **no default** and must be given: the right interval depends on how long
  the run is and on the job's time limit. **SoftPack choice**, as for `Snapshots`.
- A wall-clock interval bounds the work lost when a job is killed (at most `every`) for
  any system size ([derivation](#work-lost-when-a-job-is-killed)). **SoftPack choice.**
  Saving does not change the trajectory, so the packing is the same whether or not, and
  how often, it is saved; this requires a read-only save
  ([derivation](#summation-order)).
- One file, never half-written: each save goes to a temporary file that is then renamed
  over `path`. LAMMPS gets the same safety by alternating between two files:
  [LAMMPSrestart] "If two filenames are specified, only 2 restart files will be created,
  with those names. LAMMPS will toggle between the 2 names as it writes successive
  restart files." **SoftPack choice.**
- The file is also written when the run stops, converged or not, so the last state is
  always on disk without a separate `write_packing` call. **SoftPack choice.** LAMMPS
  writes a final file only for a converged minimization: [LAMMPSrestart] "A restart file
  is written on the last timestep of a minimization if N > 0 and the minimization
  converges."
- `restart_file` is a run-control setting: a continued run keeps saving to the same file
  unless a new `restart_file` is given.

#### A job chain

The design doc's example for a cluster job with a time limit:

```julia
# job 1: stopped by the time limit
pack(particles_count = 10^5, restart_file = RestartFile("restart.h5"; every = Hour(1)))
# job 2: continues from the last save
pack(restart_packing = "restart.h5")
```

Worked timeline, with an illustrative speed of $3\times10^5$ steps per hour (not a
measured SoftPack speed), a 24-hour limit and saves taking seconds:

| Job | Starts at step | Saves | Ends | Last complete file | Work redone by the next job |
|---|---|---|---|---|---|
| 1 | 0 | at 1 h, 2 h, ..., 23 h | killed at 24 h, step $7.2\times10^6$ | 23 h, step $6.9\times10^6$ | 1 h |
| 2 | $6.9\times10^6$ (budget $10^7$, up to step $1.69\times10^7$) | every hour | killed at 24 h, step $1.41\times10^7$ | 23 h, step $1.38\times10^7$ | 1 h |
| 3 | $1.38\times10^7$ | every hour | converges at, say, step $1.50\times10^7$ (4 h) | written at the stop, `converged = true` | – |

Total 52 hours of computing for 50 hours of progress. Without `restart_file`, job 1 would
have lost all 24 hours. Exact continuation means job 3 returns the same packing as one
uninterrupted 50-hour run, even though jobs 2 and 3 started from saves an hour older
than the kills. Each restart gets a fresh `steps_max` budget counted from the restart,
so a chain can run more than $10^7$ steps in total. **SoftPack note** (arithmetic on the
design doc's rules).

## Worked numbers

Our probe (Python, not SoftPack code): 64 disks, 50:50 mixture of diameters 1 and 1.4,
packing fraction 0.85 in a periodic box (fixed box: the pressure-control protocol is not
designed), Hookean $k = 1$, $m = 1$, $I = mR^2/2$, random start. With friction:
`CundallStrack` with $\mu = 0.5$, $k_t = k/3$. Convergence: the relative force and torque
test of [§5](05-convergence-criterion.md) with tolerance $10^{-6}$. Each run is stopped
at a third of its length, restarted from a state with some parts dropped, and run to
convergence. "Bitwise" means positions, rotations and springs are identical at the same
final step.

**DampedDynamics** (velocity Verlet, forces from half-step velocities, `ContactDamping`
0.98 in both directions, $\Delta t = t_\text{col}/50 = 0.0444\,\tau$):

| Restart from | Frictional (5,636 steps, $P = 0.02494$) | Frictionless (22,761 steps, $P = 0.004602$) |
|---|---|---|
| full state, with last forces and torques | bitwise | bitwise |
| half-step velocities, forces re-evaluated | positions differ by $5.8\times10^{-6}$ (sliding flags re-evaluated, [above](#the-half-step-velocity)) | bitwise |
| full-step velocities, forces re-evaluated (the LAMMPS case) | positions differ by $6.3\times10^{-6}$ | positions differ by $2.8\times10^{-8}$ |
| everything except the contact history | different packing: $P$ 10.3% lower, positions differ by 0.107 | – |
| positions and rotations only | different packing: $P$ 10.3% lower, other contacts, positions differ by 0.108 | same packing: same contacts, $P$ equal to $7\times10^{-9}$, non-rattlers equal to $1.8\times10^{-7}$ after removing a common shift of $2.5\times10^{-4}$ (the one rattler ends elsewhere, and the center of mass is fixed) |
| full state, pair forces summed in another order | positions differ by $1.8\times10^{-15}$ | positions differ by $3.6\times10^{-15}$ |

**FIRE** (FIRE 2.0, LAMMPS defaults, semi-implicit Euler, no damping; with friction the
power, mixing and half step back act on positions and rotations together, our choice
for the probe):

| Restart from | Frictional (262 steps, $P = 0.02910$) | Frictionless (1,332 steps, $P = 0.006475$) |
|---|---|---|
| full state | bitwise | bitwise |
| velocities set to zero | 280 steps; positions differ by 0.018; $P$ +0.57% | 1,352 steps; positions differ by $1.7\times10^{-8}$ |
| $\Delta t$, $\alpha$, $N_\pm$ reset | 300 steps; positions differ by 0.013 | 1,357 steps; positions differ by $1.6\times10^{-7}$ |
| $\Delta t$ alone reset | 270 steps; positions differ by 0.0063 | 1,345 steps; positions differ by $1.7\times10^{-8}$ |
| step count reset to 0, 5 steps before an uphill step | 278 steps in total; positions differ by 0.0014 | 1,312 steps in total; positions differ by $2.0\times10^{-8}$ |
| step count reset to 0 at the stop point (no uphill step within 20 steps) | bitwise | bitwise |
| positions and rotations only | 337 steps; positions differ by 0.13; $P$ $-3.5$% | 1,368 steps; positions differ by $1.9\times10^{-8}$ |

What the tables show (**SoftPack note**, one small probe, not a statistical study):

- Only the full state gives a bitwise continuation, for both algorithms.
- Frictionless: a restart that drops part of the state ends in the same energy minimum,
  within the convergence tolerance, after a different number of steps. The result is
  then equal only up to the tolerance, not bitwise, and the step count differs.
- Frictional: dropping velocities, the contact history or FIRE's state gives a
  different static packing, with a pressure up to 10% different. The end state depends
  on the path ([§7](07-algorithms-and-combinations.md)), so the restart state decides
  which packing is produced.

Default numbers used above: $t_\text{col} = \pi\sqrt{0.5} = 2.221\,\tau$,
$\Delta t = 0.04443\,\tau$; $\gamma_n = 0.98\times2\sqrt{k\,M_n} = 1.386$ ($M_n = 1/2$) and
$\gamma_t = 0.98\times2\sqrt{k_t\,M_t} = 0.462$ ($M_t = 1/6$) ([§8](08-damping.md)).

## Open questions

- The design doc's list of stored state does not name the RNG state (needed if anything
  random happens after step 0), the order of the contact and neighbor lists (needed for
  bitwise sums), the sliding flags of contacts, the internal state of `RestartTest()`,
  or whether `drag = StokesDrag(during = :compression)` has already switched off. Each
  is needed for exact continuation in the case named.
- "The file stores the integrator's half-step state": which form (half-step velocities,
  or the last forces and torques) is not designed. Re-evaluating forces from half-step
  velocities was not bitwise in our frictional probe.
- The integrator of `DampedDynamics` is not stated ([§12](12-time-step.md)).
- If `steps_max` is not given on a restart, the design doc does not say whether the
  stored value applies as a new budget (our reading of "a new budget, counted from the
  restart") or what remains of the old one.
- Whether `failure_action = :error` writes the restart file before throwing.
- Whether `pack()` catches a scheduler's termination signal to save before it is
  killed; the design doc relies on periodic saves only.
- Whether `every` in steps counts from the start of the packing or of the call, and
  whether a wall-clock `every` restarts its clock in each job.
- How the convergence test is ordered within a step, and whether it is evaluated at
  step 0 of a restart (a converged packing restarted with the same tolerance would then
  stop at once).
- The compression protocol, whose state the file must hold, is not designed yet.

## Related pages

- [§5 Convergence criterion](05-convergence-criterion.md): the test, `steps_max`.
- [§7 Algorithms and combinations](07-algorithms-and-combinations.md): why frictional
  packings depend on the path.
- [§8 Damping](08-damping.md): dashpots, the velocity-dependent forces behind the
  half-step state.
- [§10 Reproducibility](10-reproducibility.md): seed, StableRNG, versions.
- [§11 Outputs](11-outputs.md): what a file holds.
- [§12 Time step](12-time-step.md): $\Delta t$ and the integrators.
- [§13 Friction models](13-friction-models.md): the contact history $\xi$.
- [§14 FIRE settings](14-fire-settings.md): FIRE's state and `uphill_max`.
- [Notation](notation.md), [References](references.md).

## References

- **[LAMMPSreadrestart]** LAMMPS developers. *LAMMPS documentation: read_restart command*. <https://docs.lammps.org/read_restart.html>. Accessed 2026-11-19.
- **[LAMMPSrestart]** LAMMPS developers. *LAMMPS documentation: restart command*. <https://docs.lammps.org/restart.html>. Accessed 2026-11-19.
- **[LAMMPSwriterestart]** LAMMPS developers. *LAMMPS documentation: write_restart command*. <https://docs.lammps.org/write_restart.html>. Accessed 2026-11-19.
