# T-2brz: values to time or measure

*Up:* [Design decisions](index.md)

**Question.** Several defaults are provisional until something is measured, and two
convergence tests had unspecified content.

**Choice.** Keep $10^{-8}$ as the default tolerance and treat the frictional timing as a
release gate; warn at run start when the Float64 floor makes that tolerance unreachable.
`KineticEnergy` counts translational and rotational energy per particle; the rotational
term was fixed for 3D in this decision. `LeidenAcceleration` stays translational.
`RestartTest` is the force test plus a second minimization, and its watch length, growth
factor and energy scale are now keywords (`watch`, `growth`, `energy_tolerance`) with the
values the first implementation hard-coded. The measured data are in
[`benchmarks/results.md`](https://github.com/ColtonKawamura/SoftPack/blob/main/benchmarks/results.md): FIRE reaches $10^{-4}$ in
about 55,000 steps and $10^{-8}$ in 87,000, while damped dynamics does not reach
$10^{-4}$ (frictionless, $N = 32$) in $5 \times 10^5$ steps.

**Why.** Lowering the default to $10^{-4}$ would hide the tail that the release gate is
supposed to measure. The measurements already show that damped dynamics needs a looser
tolerance or drag `during = :always`; that is a documented caveat, not a reason to change
the default for the FIRE path.

**Status.** In code and measured.

## Archival reference

- [Convergence criterion](https://github.com/ColtonKawamura/SoftPack/wiki/Convergence-criterion)
