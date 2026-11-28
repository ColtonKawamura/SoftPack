# T-3qkf: FIRE with friction, density masses, damping

*Up:* [Design decisions](index.md)

**Question.** FIRE was allowed with every other setting, but several combinations had no
defined behaviour: spins under mixing, masses that differ, dashpots with an adaptive
step, and a step that could grow without a displacement check.

**Choice.** All of it is in code. FIRE checks its parameters at the call, warns that FIRE
with friction is non-standard, and clamps its step to the damped stability limit when
`damping` is set. The mixing is mass-weighted: the speed is
$\sqrt{2K} = \sqrt{\sum_i m_i|v_i|^2 + \sum_i I_i|\omega_i|^2}$, the force direction is
$F_i/m_i$ and $\tau_i/I_i$, and the power is taken from the elastic forces alone.
`displacement_max` caps one step's displacement at 0.1 reference diameters.

**Why.** Mass weighting makes the mixing a statement about kinetic energy rather than
about raw velocity, which is what FIRE's derivation assumes; with equal masses and no
rotation it reduces to the old rule bit for bit, so it only changes runs that have a
reason to change. The displacement cap is the LAMMPS `dmin` default and protects a
violent step from jumping a particle across a contact.

**Status.** In code. The cap changed the default trajectory once (the run now takes 87,757
steps instead of 86,860 and a different final state in the last bits), and the pinned test
and the benchmarks were re-baselined with it.

## Archival reference

- [FIRE settings](https://github.com/ColtonKawamura/SoftPack/wiki/FIRE-settings)
