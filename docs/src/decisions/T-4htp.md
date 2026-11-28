# T-4htp: CundallStrack and Mindlin under Hertzian contacts

*Up:* [Design decisions](index.md)

**Question.** `CundallStrack` had no stated normal stiffness under Hertz contacts,
`Mindlin` was defined only for $\nu = 0$, and "every combination is allowed" conflicted
with "Mindlin needs Hertzian".

**Choice.** `Mindlin` with a non-Hertzian contact is an error that names the fix.
`CundallStrack` with Hertzian contacts uses the instantaneous Hertz stiffness times
`stiffness_ratio`, so the tangential spring stiffens with the overlap exactly as the
normal one does. `Mindlin` uses the general rule $k_t = \eta k_n$ with
$\eta = 2(1-\nu)/(2-\nu)$, and $\nu$ must lie between -1 and 0.5.

**Why.** A fixed tangential stiffness under a Hertzian normal force would make the ratio
between the two change with the overlap, which is not a model anyone can quote. The
instantaneous ratio is the rule of the source model, and it keeps the contact time — and
so the step — set by the same overlap the normal force uses.

**Status.** In code (`tangential_stiffness`, `validate_friction`).

## Archival reference

- [Friction models](https://github.com/ColtonKawamura/SoftPack/wiki/Friction-models)
