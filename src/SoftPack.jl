module SoftPack

# Standard-library dependencies, kept minimal:
#   * LinearAlgebra, Random  -- numerical work that later milestones need
#   * TOML, Printf           -- the softpack-1 output format
#   * StableRNGs             -- seeded results identical across Julia versions
using LinearAlgebra
using Random
using TOML
using Printf
using StableRNGs

# Source files, included in dependency order.
include("types.jl")
include("params.jl")
include("pack.jl")
# M1 core engine: geometry, particle distributions and contact laws.
include("geometry/box.jl")
include("geometry/pbc.jl")
include("particles/distributions.jl")
include("contacts/hookean.jl")
include("contacts/hertzian.jl")
include("contacts/forces.jl")
include("geometry/celllist.jl")
include("io/csv.jl")
include("io/metadata.jl")
include("io/write.jl")
include("io/read.jl")

# Public API.
export PackParams, pack, Packing, Contact
export Monodisperse, Bidisperse, UniformPolydisperse, LogNormalPolydisperse, CustomRadii
export Hookean, Hertzian
export PeriodicBox, volume
export minimum_image, minimum_image!, wrap, wrap!, rescale!
export draw_radii, box_for_phi, random_positions
export compute_forces!, virial_pressure, virial_stress
export CellList, pairlist, brute_force_pairlist, needs_rebuild!
export write_packing, read_packing

end # module
