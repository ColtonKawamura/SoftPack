# Naming rules

*Up:* [SoftPack](../index.md)

The interface follows one pattern, so a setting can be guessed instead of looked up
[JuliaStyle].

- **Types are CamelCase.** A setting is a type, and its name says what it is:
  `Hookean`, `CundallStrack`, `DampedDynamics`, `RestartFile`.
- **Keywords and fields are snake_case.** `particles_count`, `pressure_tolerance`,
  `friction_coefficient`.
- **Object, then property.** A keyword is named for the thing it sets and then the aspect:
  `particles_count`, `particles_size_distribution`, `particles_diameters`. The plural
  object comes first, because the keyword is a field of the run, not a verb.
- **Booleans read as statements.** `friction = false` on a wall is read as "wall friction
  is off"; the keyword is not `no_friction`.
- **No abbreviations and no units in names.** `stiffness`, not `k`; `strain_step`, not
  `deps`. A name never carries a unit, because the run is in reduced units and a name with
  a unit would lie when the unit changes.
- **Functions are verbs.** `write_packing`, `find_rattlers`, `render_frame!`. A function
  that changes its argument ends in `!`.
- **A page is named after the thing it documents.** The page for a keyword is the keyword
  (`dimension.md`); the page for a choice is the constructor (`Hookean.md`).

The rules are enforced by review, not by the compiler; a new setting that breaks them
should be renamed before it is merged.

## References

- **[JuliaStyle]** The Julia Project. *Style Guide, The Julia Language manual*. <https://docs.julialang.org/en/v1/manual/style-guide/>. Accessed 2026-11-18.
