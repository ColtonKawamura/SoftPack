#  pack dispatch. No algorithm is implemented in M0, so every valid pack call
#  throws an ErrorException saying "not implemented yet" and listing the options.
@testset "pack dispatch" begin
    # pack(p::PackParams) with the default algorithm.
    try
        pack(PackParams())
        @test false
    catch e
        @test e isa ErrorException
        @test occursin("not implemented yet", e.msg)
        @test occursin("fire_compress", e.msg)
    end

    # pack(; kwargs...) builds a PackParams from keywords, then dispatches.
    try
        pack(; N = 64, pressure = 1e-3)
        @test false
    catch e
        @test e isa ErrorException
        @test occursin("not implemented yet", e.msg)
    end

    # A bad algorithm fails validation before any dispatch.
    try
        pack(PackParams(; algorithm = :does_not_exist))
        @test false
    catch e
        @test e isa ArgumentError
    end
end
