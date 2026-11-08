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
include("io/csv.jl")
include("io/metadata.jl")
include("io/write.jl")
include("io/read.jl")

# Public API.
export PackParams, pack, Packing, Contact
export Monodisperse, Bidisperse, UniformPolydisperse, LogNormalPolydisperse, CustomRadii
export Hookean, Hertzian
export write_packing, read_packing

end # module
