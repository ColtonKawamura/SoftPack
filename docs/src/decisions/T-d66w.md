# T-d66w: the time-step rule

*Up:* [Design decisions](index.md)

**Question.** The default step was defined three slightly different ways, and a fixed
time step had no unit.

**Choice.** The step is a fraction of the shortest contact time of the lightest pair:
$M = \mathrm{min}_i m_i / 2$, and the step is
$\pi \times \text{fraction} \times \mathrm{min}(\sqrt{M/k_n}, \sqrt{M_t/k_t})$. For a Hertzian
law the stiffness is evaluated at the largest overlap the run expects, and the run-time
check warns when a contact turns out stiffer than that. A fixed number is in units of
$\tau = \sqrt{m_{\mathrm{min}}/k}$.

**Why.** The lightest pair sets the fastest oscillation, so it sets the step; using the
mean mass would let a few small particles destabilize the run. The tangential term
matters because $M_t$ includes the rotation, so a Mindlin contact with $\nu = 0$ has a
shorter tangential time than the normal one. The fixed-step unit uses $m_{\mathrm{min}}$ rather
than $m_\text{ref}$ because a fixed number must mean the same physical time whatever the
mass distribution; with `EqualMass` the two are identical.

**Status.** In code (`src/timestep.jl`); the unit of a fixed step changed in this
decision.

## Archival reference

- [Time step](https://github.com/ColtonKawamura/SoftPack/wiki/Time-step)
