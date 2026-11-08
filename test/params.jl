#  PackParams: defaults, keyword constructor, mutability and validate().
#  `validate` is not exported, so it is called as SoftPack.validate.
@testset "PackParams" begin
    # ---- defaults ----
    p = PackParams()
    @test p.algorithm == :fire_compress
    @test p.dim == 2
    @test p.N == 256
    @test p.sizes == Bidisperse(ratio = 1.4, fraction = 0.5)
    @test p.contact == Hookean(k = 1.0)
    @test p.pressure == 1e-4
    @test p.pressure_tol == 1e-2
    @test p.force_threshold == 1e-12
    @test p.max_steps == 10^7
    @test p.rattlers == :remove
    @test p.backend == :cpu
    @test p.precision == Float64
    @test p.seed == 1
    @test p.friction === nothing
    @test p.verbose == false

    # ---- mutable: one field can be tweaked after construction ----
    p2 = PackParams()
    p2.force_threshold = 1e-14
    @test p2.force_threshold == 1e-14

    # ---- keyword constructor: build from kwargs only ----
    p3 = PackParams(; algorithm = :fire_compress, dim = 3, N = 16, precision = Float32)
    @test p3.dim == 3
    @test p3.N == 16
    @test p3.precision == Float32

    # ---- validate() returns true for a well-formed pack ----
    @test SoftPack.validate(p) === true

    # ---- validate(): each rule throws a clear ArgumentError ----
    # dim must be 2 or 3
    try
        SoftPack.validate(PackParams(; dim = 1))
        @test false
    catch e
        @test e isa ArgumentError
        @test occursin("dim must be 2 or 3", e.msg)
    end
    # N must be positive
    try
        SoftPack.validate(PackParams(; N = 0))
        @test false
    catch e
        @test e isa ArgumentError
        @test occursin("N must be a positive integer", e.msg)
    end
    # pressure must be positive
    try
        SoftPack.validate(PackParams(; pressure = -1.0))
        @test false
    catch e
        @test e isa ArgumentError
        @test occursin("pressure must be positive", e.msg)
    end
    # unknown algorithm lists the valid ones
    try
        SoftPack.validate(PackParams(; algorithm = :luche_rolling))
        @test false
    catch e
        @test e isa ArgumentError
        @test occursin("unknown algorithm", e.msg)
        @test occursin("fire_compress", e.msg)
    end
    # unknown backend lists the valid ones
    try
        SoftPack.validate(PackParams(; backend = :openmp))
        @test false
    catch e
        @test e isa ArgumentError
        @test occursin("unknown backend", e.msg)
        @test occursin("cuda", e.msg)
    end
    # unknown rattlers lists the valid ones
    try
        SoftPack.validate(PackParams(; rattlers = :drop))
        @test false
    catch e
        @test e isa ArgumentError
        @test occursin("unknown rattlers", e.msg)
        @test occursin("keep", e.msg)
    end
    # :metal backend does not support Float64
    try
        SoftPack.validate(PackParams(; backend = :metal, precision = Float64))
        @test false
    catch e
        @test e isa ArgumentError
        @test occursin("Float64", e.msg)
    end
    # friction is not supported in 3D for v1
    try
        SoftPack.validate(PackParams(; dim = 3, friction = :coulomb))
        @test false
    catch e
        @test e isa ArgumentError
        @test occursin("friction", e.msg)
        @test occursin("3D", e.msg)
    end
end
