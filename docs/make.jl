using SoftPack
using Documenter

# SoftPack documentation. The pages below are placeholders for M0; their content
# is filled in by later cards (the docs card). This file must keep building.
meta = Dict(
    "authors"       => ["Colton Kawamura"],
    "maintainers"   => ["Colton Kawamura"],
    "repo"          => "https://github.com/ColtonKawamura/SoftPack/blob/{commit},{path}#{line}",
    "reponame"      => "SoftPack",
    "develop_msg"   => "Main",
    "release_msg"   => "Release",
    "taglines"      => ["Reproducible jammed packings for DEM research"],
)

makedocs(
    authors = "Colton Kawamura",
    sitename = "SoftPack",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        collapselevel = 1,
    ),
    pages = [
        "Home"             => "index.md",
        "Format specification" => "format.md",
        "Developer guide"  => "developer.md",
    ],
)

# API documentation (from docstrings in src/) is added by the docs card. It is left
# out now so the skeleton builds without requiring every exported symbol to be
# documented.

# Only deploy the built site to GitHub Pages when explicitly asked (the CI
# Documentation workflow sets DOCS_DEPLOY=true on push to main). A plain local
# `julia --project=docs docs/make.jl` therefore builds the site but never pushes.
if get(ENV, "DOCS_DEPLOY", "false") == "true"
    deploydocs(
        repo = "github.com/ColtonKawamura/SoftPack.git",
        target = "build",
        branches = ["gh-pages"],
        versions = "stable",
    )
end
