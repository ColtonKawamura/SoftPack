#!/bin/sh
# install.sh -- install Julia (if it is not already available) and SoftPack's
# dependencies, then print a quick-start snippet. POSIX sh; works on Linux and
# macOS. On a machine that already has Julia, only the instantiate branch runs.
set -eu

# Work from the directory this script lives in, so `--project=.` is the repo.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$here"

echo "SoftPack install"
echo "----------------"

# --- Make sure Julia is on PATH ----------------------------------------------
if ! command -v julia >/dev/null 2>&1; then
    echo "Julia not found; installing juliaup..."
    # Official installer (https://juliaup.dev). Installs a current Julia.
    curl -fsSL https://install.julialang.org | sh -s -- --yes

    # juliaup puts the launcher in $HOME/.juliaup/bin; make it available for the
    # rest of this session (and leave a note for future shells).
    julia_bin="$HOME/.juliaup/bin/julia"
    if [ -x "$julia_bin" ]; then
        PATH="$HOME/.juliaup/bin:$PATH"
        export PATH
        echo "Julia installed to $julia_bin"
    else
        echo "ERROR: juliaup ran but no 'julia' launcher was found." >&2
        exit 1
    fi
else
    echo "Using julia: $(command -v julia)"
fi

# --- Install dependencies and precompile -------------------------------------
echo "Instantiating the package environment..."
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# --- Quick start -------------------------------------------------------------
echo
echo "Quick start:"
echo "    julia --project=. -e 'using SoftPack'"
echo "    julia --project=. -e 'using SoftPack; p = PackParams(); p.force_threshold = 1e-12; pack(p)'"
echo "    julia --project=. examples/example.jl"
echo
echo "Done. See README.md and docs/ for the full format specification."
