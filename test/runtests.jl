#  SoftPack test entry point (julia --project -e 'using Pkg; Pkg.test()').
#  One file per area, each a nested @testset, included below.
using SoftPack
using Test

@testset "SoftPack" begin
    include("params.jl")
    include("pack.jl")
    include("io.jl")
end
