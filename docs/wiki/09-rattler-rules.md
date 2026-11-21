# 9. Rattler rules

Design decision source: [design-references.md §9](../design-references.md#9-rattler-rules).
Status: design stage (no engine code yet).

## Summary

A rattler is a particle that carries no load in the finished packing. [Agnolin2007]:
"The rattlers are defined as the grains that do not participate in carrying forces and
remain, therefore, free to “rattle” within the cage formed by their force-carrying,
rigidly fixed neighbors." The rest of the packing, the force-carrying network, is the
backbone. A rattler rule decides which particles are rattlers. `pack()` removes them
by default with `ContactCount(cone_test = true)`: it repeatedly removes every particle
with fewer than $D + 1$ contacts without friction ($D$ the dimension), or fewer than 2
with friction. The cone test also removes a two-contact particle whose friction cones
cannot hold it. Three other rules are built in (`TwoContact`, `ForceFloor`,
`Unresolved`), `rattlers = nothing` keeps every particle, and any function of the
contact network can be given instead. `find_rattlers(packing, rule)` applies a rule to
a finished packing, which works because every output keeps the full state from before
the removal ([§11](11-outputs.md)).

## Settings

| Setting | Default | Options | Details |
|---|---|---|---|
| `rattlers` | `ContactCount(cone_test = true)` | `TwoContact()`, `ForceFloor(floor = 1e-3)`, `Unresolved(floor = :tolerance)`, `nothing`, any function | [ContactCount](#contactcount-default), [Options](#options) |
| `cone_test` (a setting of every rule) | `true` | `false` | [Cone test](#cone-test) |
| `ForceFloor` `floor` | `1e-3` (a fraction of the mean contact force) | any number | [ForceFloor](#forcefloor) |
| `Unresolved` `floor` | `:tolerance` (the packing's force tolerance) | the design doc names no other value | [Unresolved](#unresolved) |
| `find_rattlers(packing, rule)` | – | any rule above | [find_rattlers](#find_rattlers) |

The mean contact force $\langle f\rangle$ used by the rules is taken over all contacts
before anything is removed.

## Model

Symbols used on this page:

- $D$: dimension (2 or 3). $N$: number of particles. Particle $i$ has center
  $\mathbf x_i$ and radius $R_i$.
- Contact $c = (i, j)$: two particles that overlap. $z_i$: contact number of particle
  $i$, the number of its contacts. $\hat{\mathbf n}_c$: unit vector from the center of
  $i$ toward the center of $j$. The contact point of $i$ is
  $\mathbf x_i + R_i\hat{\mathbf n}_c$.
- $\mathbf f_c$: contact force on $i$ from $j$,
  $\mathbf f_c = -f_n\,\hat{\mathbf n}_c + \mathbf f_t$, with normal force $f_n \ge 0$
  (cohesionless particles only push) and tangential force $\mathbf f_t$ perpendicular
  to $\hat{\mathbf n}_c$ ($\mathbf f_t = 0$ without friction).
- $\mu$: friction coefficient ([§13](13-friction-models.md)). Coulomb's condition is
  $\lvert\mathbf f_t\rvert \le \mu f_n$. $\psi = \arctan\mu$ is the friction angle
  (the ϕ of [Gilabert2007] in the quote below; we write $\psi$ because $\phi$ is the
  packing fraction). The friction cone of a contact is the set of forces whose angle
  with the inward normal $-\hat{\mathbf n}_c$ is at most $\psi$.
- $\langle f\rangle$: mean contact force over all contacts, before removal.
- $\theta$: for a particle with two contacts, the angle between the two directions
  $\hat{\mathbf n}_1$ and $\hat{\mathbf n}_2$ from its center to its contact points
  ($0 < \theta \le \pi$).

A rule is a function of the contact network that returns one true/false value per
particle, true for a rattler. A particle can carry load only if nonzero contact forces
can hold it in equilibrium with no other force acting on it:

$$\sum_{c \in i}\mathbf f_c = 0, \qquad \sum_{c \in i} R_i\,\hat{\mathbf n}_c \times \mathbf f_c = 0,$$

with every $\mathbf f_c$ inside its friction cone (or along $-\hat{\mathbf n}_c$ without
friction). The sums run over the contacts of particle $i$. The torque balance only
involves tangential forces, because $\hat{\mathbf n}_c \times \hat{\mathbf n}_c = 0$.
The contact-count rules are counting versions of this condition, derived next.

## Derivations

### Minimum contact number without friction

Without friction every contact force is $-f_n^c\,\hat{\mathbf n}_c$, so force balance
reads

$$\sum_{c \in i} f_n^c\,\hat{\mathbf n}_c = 0, \qquad f_n^c \ge 0.$$

1. In a disordered packing any $D$ of the normals are linearly independent (exceptions
   need exact alignments). With $z_i \le D$ contacts the only solution is then
   $f_n^c = 0$ for every contact: the particle carries no load.
2. With $z_i = D + 1$ contacts there is a one-parameter family of solutions. All its
   forces are positive only when the origin lies inside the convex hull of the normals,
   that is, when the normals are not confined to an open half-space (no direction
   $\mathbf u$ with $\mathbf u\cdot\hat{\mathbf n}_c > 0$ for every contact). If they
   are, the particle could only be pushed away from that side.
3. Hence a frictionless particle needs at least $D + 1$ contacts: 3 for disks, 4 for
   spheres.

[Agnolin2007] use this count for their frictionless sphere packings: "First, we regard
as rattlers all spheres having less than four contacts: less than three contacts
implies a mechanism, and only three is impossible if forces are all strictly
compressive."

The count is necessary, not sufficient: a particle with $D + 1$ or more contacts whose
normals all lie in one half-space cannot be in balance either. In a converged packing
its contact forces must then all be below the force tolerance, which is what
`Unresolved` detects. **SoftPack note.**

Checked numerically (Python, linear programming): for 20 000 random sets of
2 to 6 normals in 2D, a positive force balance existed exactly when the largest angular
gap between neighboring normals was at most $\pi$ (not in an open half-plane); sets of
$D$ random normals never had one, in 2D or 3D.

### Minimum contact number with friction

With friction each contact force has $D$ components and torque balance adds equations.
Count unknowns and equations for one particle whose neighbors are held fixed:

| Contacts | Unknown force components | Equations | Result |
|---|---|---|---|
| 1, any $D$ | $D$ | $D$ (force) + torque | force balance alone gives $\mathbf f = 0$ |
| 2, $D = 2$ | 4 | 2 + 1 = 3 | rank 3: one self-balanced force state, no mechanism |
| 2, $D = 3$ | 6 | 3 + 3 = 6 | rank 5: one self-balanced force state and one mechanism |

The ranks were computed numerically (equilibrium matrix of a particle with two contacts).
The self-balanced state always exists. Force balance makes the two forces opposite,
$\mathbf f_2 = -\mathbf f_1$. Torque balance about the center, with contact points
$\mathbf r_1 = R\hat{\mathbf n}_1$ and $\mathbf r_2 = R\hat{\mathbf n}_2$, then gives

$$\mathbf r_1 \times \mathbf f_1 + \mathbf r_2 \times \mathbf f_2 = (\mathbf r_1 - \mathbf r_2) \times \mathbf f_1 = 0,$$

so both forces lie along the chord joining the two contact points. [Agnolin2007]:
"Self-balanced contact forces (see first part of Fig. 10) are oriented along the line
joining the two contacts". That is why two contacts can carry load with friction,
"spheres with as few as two contacts may carry forces (even large ones, as we shall
see) and should not be regarded as rattlers" [Agnolin2007], and one contact never can.
In 3D the one mechanism is the sphere rolling about the chord (their Fig. 10); it does
not remove the force state.

### Cone test geometry

Whether the chord forces are allowed depends on the friction cones. The triangle formed
by the particle's center and its two contact points has two sides of length $R$, so it
is isosceles with apex angle $\theta$. Its base angles are

$$\alpha = \frac{\pi - \theta}{2},$$

and $\alpha$ is the angle between the chord and each contact normal. The chord force at
contact 1 points from contact 1 toward contact 2, which is inward:
$(\mathbf r_2 - \mathbf r_1)\cdot(-\hat{\mathbf n}_1) = R(1 - \cos\theta) > 0$. Its angle
with the inward normal is $\alpha$, and the same holds at contact 2. Coulomb's
condition $\lvert\mathbf f_t\rvert \le \mu f_n$ means this angle may be at most $\psi$, so
a two-contact particle can carry load if and only if

$$\alpha \le \psi \quad\Longleftrightarrow\quad \theta \ge \pi - 2\psi = \pi - 2\arctan\mu.$$

This is the condition in both sources the design doc quotes: [Gilabert2007] restrict
"the angle between the directions of the 2 contacts to values between π − 2ϕ and π",
and [Agnolin2007] require the angle α "between the line joining the centers of 1 and 2
and the one joining the contact points be smaller than the angle of friction" (in their
Fig. 10, sphere 1 is the two-contact sphere, so the line of centers of 1 and 2 is a
contact normal). The result does not depend on the neighbors' sizes, only on the
particle's own radius, and holds in 3D because the center and the two contact points
span a plane that contains both forces.

Limits: as $\mu \to 0$, $\theta_\text{min} \to \pi$ (only exactly opposite contacts,
which never occur in practice, so every frictionless two-contact particle fails); as
$\mu \to \infty$, $\theta_\text{min} \to 0$ (every two-contact particle passes).

Checked numerically: a linear program for the forces of a two-contact disk (normal
forces $\ge 0$, $\lvert f_t\rvert \le \mu f_n$, force and torque balance, total normal
force 1) was feasible exactly when $\theta \ge \pi - 2\arctan\mu$, in 20 000 random cases
with $10^{-2} \le \mu \le 10^{1.5}$. **SoftPack note** (our derivation of the quoted
condition).

### Iterative removal

Removing a particle also removes its contacts, so its neighbors' contact numbers drop
and some of them may now fail the rule. The count rules are therefore applied until
nothing changes (the design doc says "repeatedly" for `ContactCount` and
`TwoContact`). [Agnolin2007]: "Then, all the contacts of eliminated spheres being also
removed, other spheres might (although this is an extremely rare occurrence) have less
than four contacts, so the procedure is iterated (twice at most is enough in our
samples, although one such sweep is usually enough) until no more rattler is
detected." [Xiong2019] "recursively remove" and [Ishima2023] "repeat these processes
until the number of rattlers is converged" (quotes below).

Pseudocode for the built-in count rules (the design doc gives no code; this shows how
the rules combine):

```text
find_rattlers(packing, rule):
    f_mean  = mean contact force over ALL contacts            # before any removal
    active  = contacts that the rule counts                   # ForceFloor: force >= floor * f_mean
    rattler = false for every particle
    repeat
        z = contact numbers over active contacts whose two particles are not rattlers
                                                              # (repeat assumed for ForceFloor, see Open questions)
        new = particles i, not yet rattlers, with
                z[i] < z_min                                   # ContactCount: D+1 or 2; TwoContact: 3
                or (cone_test and z[i] == 2 and theta_i < pi - 2*atan(mu))
        mark new as rattlers
    until new is empty
    return rattler                                            # one true/false per particle
```

`z_min` is $D + 1$ without friction and 2 with friction for `ContactCount`, 3 for
`TwoContact` (it removes two or fewer), and 2 for `ForceFloor`. The forces of the
remaining contacts are not recomputed: removal is bookkeeping on the finished packing,
not a new relaxation. **SoftPack note.**

`Unresolved` on its own needs no repeat: a particle is removed only if every one of its
contacts is below the floor, so every contact it shares with a remaining particle is
also below the floor, and removing it cannot change whether a neighbor has a contact
above the floor. **SoftPack note.**

## Defaults and their reasons

### ContactCount (default)

```julia
pack(rattlers = ContactCount(cone_test = true))
```

**Decision.** Repeatedly remove particles with fewer than $D + 1$ contacts when
frictionless or fewer than 2 when frictional.

- [Xiong2019] "we recursively remove rattler disks with fewer than three contacts for
  frictionless disks or fewer than two contacts for frictional disks."
- For frictional particles, [Agnolin2007] note that "spheres with as few as two
  contacts may carry forces (even large ones, as we shall see) and should not be
  regarded as rattlers."
- $D + 1$ is the frictionless minimum in any dimension ([derivation](#minimum-contact-number-without-friction)).
  [Xiong2019] is the 2D case (three contacts); [Agnolin2007]'s "less than four
  contacts" rule for frictionless spheres is the 3D case. 2 is the frictional minimum
  ([derivation](#minimum-contact-number-with-friction)).
- Removing rattlers by default is a **SoftPack choice** (the design doc gives no
  source). The papers above remove them before measuring contact numbers and forces.
  Every output still holds the full pre-removal state ([§11](11-outputs.md)).

### Cone test

```julia
pack(rattlers = ContactCount(cone_test = true))  # cone_test is a setting of every rule
```

**Decision.** `cone_test = true` in every rule: a two-contact particle is removed when
no forces inside its friction cones can hold it, that is when
$\theta < \pi - 2\arctan\mu$ ([derivation](#cone-test-geometry)).

- [Gilabert2007] "Without cohesion, the Coulomb condition restricts the angle between
  the directions of the 2 contacts to values between π − 2ϕ and π, where ϕ is the
  friction angle (tan ϕ = µ)."
- [Agnolin2007]: the angle α "between the line joining the centers of 1 and 2 and the
  one joining the contact points be smaller than the angle of friction, for the total
  contact force to stay within the Coulomb cone."
- On by default for every rule: **SoftPack choice** (a particle that fails it cannot
  carry load). `cone_test = false` gives back the published contact-count rule.
- With `ContactCount` it matters only with friction: without friction, two-contact
  particles are already below the $D + 1$ minimum.

## Options

### TwoContact

```julia
pack(rattlers = TwoContact(cone_test = true))
```

**Decision.** The option: repeatedly remove particles with two or fewer contacts.

- [Ishima2023] regard particles with $Z_i \le Z_\text{Th}$ as rattlers and "repeat these
  processes until the number of rattlers is converged", with $Z_\text{Th} = 2$.
  [Shimada2026] "we refer to particles with two contacts as pseudo-rattlers to
  distinguish them from true rattlers", and count samples "remaining jammed after
  removing rattlers and pseudo-rattlers".
- When to use it: to compare with those papers, or to study the backbone without the
  two-contact particles that do carry load with friction.
- Every two-contact particle is removed by the count itself, so `cone_test` changes
  nothing here (see [Open questions](#open-questions)).

### ForceFloor

```julia
pack(rattlers = ForceFloor(floor = 1e-3, cone_test = true))
```

**Decision.** The option's default: contacts with force below
$10^{-3}\,\langle f\rangle$ count as broken, then particles with fewer than two
contacts are removed.

- [Shundyak2007] "we always take out rattlers by considering contact forces less than
  10^-3 times the average force broken and removing particles, with less than two
  contacts."
- What it changes: contacts that carry almost nothing do not count, so a particle held
  only by near-zero forces is removed even if it touches several neighbors.
- When to use it: to reproduce the Leiden frictional packings ([Shundyak2007] is
  frictional). Its minimum is 2 contacts whether or not friction is on; on a
  frictionless packing the cone test then removes two-contact particles in 2D (since
  $\theta_\text{min} = \pi$ at $\mu = 0$), but three-contact spheres in 3D stay (see
  [Open questions](#open-questions)).

### Unresolved

```julia
pack(rattlers = Unresolved(floor = :tolerance, cone_test = true))
```

**Decision.** The option's default: remove particles whose contacts all carry less
than the packing's force tolerance.

- [Agnolin2007] "We also discard from the backbone all spheres with only forces
  smaller than the tolerance." Tying the floor to the packing's own tolerance
  (`floor = :tolerance`) is a **SoftPack choice**: the rule means "below the stopping
  rule's noise".
- With the default convergence test, `RelativeForce(tolerance = 1e-8)`
  ([§5](05-convergence-criterion.md)), the force tolerance is
  $\epsilon_F\langle f_n\rangle = 10^{-8}\langle f_n\rangle$, with $\epsilon_F$ the
  `tolerance` and $\langle f_n\rangle$ the mean normal contact force.
- Why the tolerance is the natural floor: a force below the convergence tolerance
  cannot be told apart from the residual forces the stopping rule allows. [Agnolin2007]
  warn that "very small forces on the backbone might be confused with forces below
  tolerance between rattler and backbone grains, or between two rattlers."

### No removal and custom rules

```julia
pack(rattlers = nothing)
```

**Option.** Keep every particle. Any function of the contact network that returns one
true/false value per particle (true for a rattler) can be given instead of a built-in
rule; it then plays the role of the rule in the pseudocode above.

### find_rattlers

```julia
packing = pack(rattlers = nothing)
rattler = find_rattlers(packing, ForceFloor(floor = 1e-3))
```

**Option.** Apply any rule to a finished packing. Since every output keeps every
particle and every contact from before removal ([§11](11-outputs.md),
[§6](06-packing-that-does-not-converge.md)), rules can be compared on the same packing
without packing again.

## Worked numbers

Minimum angle $\theta_\text{min} = \pi - 2\arctan\mu$ between the two contact
directions of a two-contact particle (computed):

| $\mu$ | friction angle $\psi$ | $\theta_\text{min}$ | note |
|---|---|---|---|
| 0.1 | 5.711° | 168.579° | |
| 0.3 | 16.699° | 146.602° | [Agnolin2007]'s value |
| 0.5 | 26.565° | 126.870° | SoftPack default ([§13](13-friction-models.md)) |
| 1.0 | 45.000° | 90.000° | |
| 10 | 84.289° | 11.421° | |

Floors in the default units (2D, $k = 1$, small diameter $d = 1$, $P = 10^{-4}$). The
mean normal force from the 2D relation of [§2](02-default-packing.md),
$\langle f_n\rangle = \pi P d/(z\phi)$ with $z = 4$ and $\phi = 0.84$, is
$9.35\times10^{-5}$ (our conversion). Then:

| Rule | Floor | Value |
|---|---|---|
| `ForceFloor(floor = 1e-3)` | $10^{-3}\langle f\rangle$ | $9.35\times10^{-8}$ |
| `Unresolved(floor = :tolerance)` with `RelativeForce(tolerance = 1e-8)` | $10^{-8}\langle f_n\rangle$ | $9.35\times10^{-13}$ |

Illustration (our test packings, made by plain energy minimization, not by SoftPack's
protocol): frictionless 256-disk bidisperse packings (diameter ratio 1.4) at packing
fractions 0.845 and 0.86 had 2 to 5 rattlers under the frictionless `ContactCount`
rule; 256 spheres at packing fraction 0.66 had 7. One sweep was enough in every case,
as [Agnolin2007] report for theirs.

## Open questions

- The cone test is defined for two-contact particles only. With friction, spheres with
  three contacts in 3D also need friction to carry load: [Agnolin2007] "Spheres with
  three contacts therefore need some mobilization of friction to transmit non-vanishing
  forces in an equilibrium configuration", and "The Coulomb condition then restricts
  such possible configurations to flat enough tetrahedra for contact forces to remain
  within the friction cone." Whether `cone_test` should cover them is not designed.
- `TwoContact(cone_test = true)`: the count already removes every two-contact particle,
  so the cone test has no effect.
- Which contacts the cone test looks at in `ForceFloor` and `Unresolved` (all contacts,
  or only those above the floor) is not stated.
- `ForceFloor` uses a minimum of 2 contacts with or without friction, while
  `ContactCount` uses $D + 1$ without friction. The design doc also does not say whether
  `ForceFloor` repeats its removal.
- $\langle f\rangle$ (this section) and $\langle f_n\rangle$ (§5): whether the floors use
  the normal force or the magnitude of the total contact force is not stated.
- `floor = :tolerance` assumes the convergence test has a force tolerance.
  `LeidenAcceleration` has an acceleration tolerance, and `KineticEnergy`,
  `RestartTest` and user functions have none.
- [Agnolin2007] check that the backbone stays rigid after removal: "If one eliminates
  too many particles, the identified backbone might become floppy (hypostatic)." The
  design doc has no such check.

## Related pages

- [5. Convergence criterion](05-convergence-criterion.md): the force tolerance behind
  `Unresolved`.
- [11. Outputs](11-outputs.md): what is written when rattlers are removed
  (`rattlers_file`).
- [13. Friction models](13-friction-models.md): $\mu$ and the friction cone.
- [2. Default packing](02-default-packing.md): pressure and mean contact force.
- [Notation](notation.md), [References](references.md).

## References

- **[Agnolin2007]** Ivana Agnolin, Jean-Noël Roux (2007). *Internal states of model isotropic granular packings. I. Assembling process, geometry, and contact networks*. Physical Review E **76**, 061302. [doi:10.1103/physreve.76.061302](https://doi.org/10.1103/physreve.76.061302).
- **[Gilabert2007]** F. A. Gilabert, J.-N. Roux, A. Castellanos (2007). *Computer simulation of model cohesive powders: Influence of assembling procedure and contact laws on low consolidation states*. Physical Review E **75**, 011303. [doi:10.1103/physreve.75.011303](https://doi.org/10.1103/physreve.75.011303).
- **[Ishima2023]** Daisuke Ishima, Kuniyasu Saitoh, Michio Otsuki, Hisao Hayakawa (2023). *Theory of rigidity and numerical analysis of density of states of two-dimensional amorphous solids with dispersed frictional grains in the linear response regime*. Physical Review E **107**, 054902. [doi:10.1103/physreve.107.054902](https://doi.org/10.1103/physreve.107.054902).
- **[Shimada2026]** Masanari Shimada, Yusuke Hara, Shihori Koyama, Ryohei Seto, Maria Yokota (2026). *Linear stability and viscoelastic response in weakly jammed frictional granular systems*. arXiv:2608.30151. <https://arxiv.org/abs/2608.30151>.
- **[Shundyak2007]** Kostya Shundyak, Martin van Hecke, Wim van Saarloos (2007). *Force mobilization and generalized isostaticity in jammed packings of frictional grains*. Physical Review E **75**, 010301. [doi:10.1103/physreve.75.010301](https://doi.org/10.1103/physreve.75.010301).
- **[Xiong2019]** Fansheng Xiong, Philip Wang, Abram H. Clark, Thibault Bertrand, Nicholas T. Ouellette, Mark D. Shattuck, Corey S. O’Hern (2019). *Comparison of shear and compression jammed packings of frictional disks*. Granular Matter **21**, 109. [doi:10.1007/s10035-019-0964-9](https://doi.org/10.1007/s10035-019-0964-9).
