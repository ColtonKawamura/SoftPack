# Design decisions

*Up:* [SoftPack](../index.md)

The design cards on the board each asked one question and listed the options. This
section records the answer that is now in the code, why it was chosen, and what it
changed. The design document (`docs/design-references.md`) stays the specification; a
decision here says how an open point in it was settled.

The rule behind every choice was the same: prefer the option that makes a run easier to
reproduce and to explain, even when it costs a little speed. A packing is a scientific
result, so a setting must mean one thing, a file must say how it was made, and a run that
goes wrong must leave its work where you can look at it.

| Card | Topic | Choice | Status |
|:---|:---|:---|:---|
| [T-vcne](T-vcne.md) | FIRE counters, alpha schedule | the wiki's Algorithm 2, as in LAMMPS | in code |
| [T-d66w](T-d66w.md) | Time-step rule | lightest pair, shortest of normal and tangential, fixed step in $\sqrt{m_\min/k}$ | in code |
| [T-tx4b](T-tx4b.md) | Stability with damping | margins are estimates; measure and warn; cap FIRE with damping | in code |
| [T-c822](T-c822.md) | Validation | `ArgumentError` naming the keyword; `:error` keeps the packing | in code |
| [T-hg7w](T-hg7w.md) | Rattler rules | repeat every rule; $D+1$ frictionless; cone test everywhere but `TwoContact` | in code |
| [T-s698](T-s698.md) | Cone test in 3D, backbone, custom rule | document the 3D gap; warn on a hypostatic backbone | in code |
| [T-jc2b](T-jc2b.md) | Ensembles, threads, RNG record | single thread; record the RNG version | in code |
| [T-s3tz](T-s3tz.md) | Restarts | strict keywords; fresh step budget; schedules from the restart | in code |
| [T-73sy](T-73sy.md) | Seed contract | one stream, range checked, same packing across versions | in code |
| [T-196b](T-196b.md) | HDF5 schema | remaining particles in the main groups, full state in `state` | in code |
| [T-zk8c](T-zk8c.md) | CSV and compression | format from the extension; CSV cannot restart | in code |
| [T-1x2y](T-1x2y.md) | Section 0 and public types | every keyword and field listed; `max` allowed | in docs |
| [T-3qkf](T-3qkf.md) | FIRE with friction and density masses | mass-weighted mixing, displacement cap, checks | in code |
| [T-4htp](T-4htp.md) | CundallStrack and Mindlin under Hertz | `Mindlin` needs `Hertzian`; CS uses the instantaneous stiffness | in code |
| [T-0h3w](T-0h3w.md) | GranE parity | keep the design; parity is statistical | recorded |
| [T-2brz](T-2brz.md) | Values to measure | keep $10^{-8}$; the timings are a release gate | in code |
| [T-1m55](T-1m55.md) | Snapshots and movie | frames stay in the run; movie renders at run time | in code, deviation |

## Archival reference

- [Design reference](../reference/theory.md)
