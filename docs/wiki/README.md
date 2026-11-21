# SoftPack wiki

Full documentation of SoftPack's `pack()` design: one page per section of
[`design-references.md`](../design-references.md). The design doc states each
decision with its call, its reasons and its sources. The wiki explains them: it
defines every symbol, derives every formula, works out the numbers for the defaults,
and gives the full citation for every source.

Status: design stage (no engine code yet). The pages describe the planned interface.

## Pages

| § | Page | What it covers |
|---|---|---|
| 0 | [Every default at a glance](00-every-default-at-a-glance.md) | Every setting, its default and options, with links |
| 1 | [Interface and naming](01-interface-and-naming.md) | `pack()`, keywords, `PackParams`, naming rules |
| 2 | [Default packing](02-default-packing.md) | Dimension, contact law, units, pressure, frictionless default |
| 3 | [Particle size distribution and length unit](03-particle-size-distribution-and-length-unit.md) | Bidisperse mixture, diameter ratio, length unit |
| 4 | [Mass](04-mass.md) | `EqualMass` and `Density`, effective masses |
| 5 | [Convergence criterion](05-convergence-criterion.md) | Force, torque, pressure and kinetic-energy tests |
| 6 | [A packing that does not converge](06-packing-that-does-not-converge.md) | Time limits, restarts, restart files |
| 7 | [Algorithms and combinations](07-algorithms-and-combinations.md) | FIRE and damped dynamics, allowed combinations |
| 8 | [Damping](08-damping.md) | Contact dashpots, Stokes drag, critical damping, Rayleigh damping, mode decay |
| 9 | [Rattler rules](09-rattler-rules.md) | Which particles are rattlers and how they are removed |
| 10 | [Reproducibility](10-reproducibility.md) | Seeds and random-number generators |
| 11 | [Outputs](11-outputs.md) | File formats, stored fields, snapshots and movies |
| 12 | [Time step](12-time-step.md) | Collision time, step size, stability |
| 13 | [Friction models](13-friction-models.md) | Cundall–Strack and Mindlin, friction coefficient, stiffness ratio |
| 14 | [FIRE settings](14-fire-settings.md) | The FIRE 2.0 algorithm and its parameters |
| – | [Notation](notation.md) | Every symbol, its meaning and units |
| – | [References](references.md) | Full citations for every source |

## Conventions

- **Notation** follows [notation.md](notation.md). In particular, $\gamma$ is a dashpot
  coefficient (force per velocity), rates are $r$ and $a$, and $c$ is never damping.
- **Equations** are LaTeX, which GitHub renders: inline `$...$`, display `$$...$$`.
- **Sources** are cited by their key, for example [Somfai2005], with the full
  citation on each page and in [references.md](references.md).
- **Quotes** are copied verbatim from the sources' full texts and keep the sources'
  own symbols. Nothing inside quotation marks is paraphrased.
- **SoftPack choice** marks a decision with no literature source; **SoftPack note**
  marks our own derivation, estimate or unit conversion.

## Keeping the wiki current

A change to section $N$ of `design-references.md` updates wiki page $N$ in the same
commit, and [references.md](references.md) is regenerated whenever
`references.bib` changes.
