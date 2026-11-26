# SoftPack

SoftPack is a Julia package for generating jammed packings of soft particles for granular and soft-matter simulations.
The goal is one well-documented, reproducible place to make packings, so that packings used across studies are built the same way and described by the same metadata.

Status: design stage. The engine implements the default frictionless path (see the README); the pages describe the planned interface.

## Start here

SoftPack has two functions you call. Each page opens with every default written out and goes deeper only as far as you follow the links.

- [`pack()`](pack/index.md): create a packing. It starts from the call with every default, then lists every option, then each option's choices, then each choice's own settings.
- [`write_packing()`](write_packing/index.md): save a packing to disk. It starts from the call with every default, then each option.

## Reference

- [Naming rules](reference/naming.md): how keywords and types are named.
- [Units and length unit](reference/units.md): the units every page uses.
- [Theory pages](reference/theory.md): models, derivations and worked numbers behind the defaults.
- [Notation](reference/notation.md): every symbol, its meaning and units.
- [References](reference/references.md): full citations for every source.

## Roadmap

- [Roadmap](roadmap.md): planned particle shapes (cylinders, user-defined shapes) and what the design keeps open for them.

## Conventions

- **Notation** follows [Notation](reference/notation.md): $\gamma$ is a dashpot coefficient (force per velocity), rates are $r$ and $a$, and $c$ is never damping.
- **Equations** are LaTeX: inline `$...$`, display `$$...$$`.
- **Sources** are cited by key, for example [Somfai2005], with the full citation at the bottom of each page.
- **Quotes** are copied verbatim from the sources' full texts and keep the sources' own symbols.
- **SoftPack choice** marks a decision with no literature source, and **SoftPack note** marks our own derivation, estimate or unit conversion.

## Where these pages live

The pages are Markdown files in `docs/src/` of the [SoftPack repository](https://github.com/ColtonKawamura/SoftPack), and this site is built from them with Documenter.jl.
The [design document](https://github.com/ColtonKawamura/SoftPack/blob/main/docs/design-references.md) states each decision with its reasons and sources.
