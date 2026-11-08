#  softpack-1 IO: write_packing / read_packing round-trip. Every field of a
#  hand-built Packing must come back exactly equal, including the exact
#  floating-point values (full round-trip precision) and the `nothing` metadata.

# A representative metadata dict: every kind of value in the softpack-1 format,
# including an optional field serialized as nothing.
function _meta(; friction = nothing)
    Dict{String,Any}(
        "algorithm" => "fire_compress", "dim" => 2, "N" => 4,
        "pressure" => 1.0e-4, "pressure_tol" => 1.0e-2,
        "packing_fraction" => 0.4213,
        "packing_fraction_without_rattlers" => 0.4567,
        "mean_coordination" => 4.5, "residual_force_ratio" => 3.21e-15,
        "steps" => 98765, "wall_time" => 12.3456, "seed" => 7,
        "precision" => "Float64", "backend" => "cpu",
        "rattlers" => "remove", "friction" => friction, "verbose" => false)
end

# Compare every field of two Packings for exact equality. `write_packing` augments
# the metadata with the fixed softpack-1 keys (format, softpack_version,
# git_commit, box), so we assert that every value passed in survives with its
# exact value, and that the fixed keys are present on the read-back packing.
function _assert_eq(a, b)
    @test a.positions == b.positions
    @test a.radii == b.radii
    @test a.box == b.box
    @test a.is_rattler == b.is_rattler
    @test a.contacts == b.contacts
    # TOML has no symbol type, so a Symbol value (e.g. friction = :coulomb) is
    # written as its string form; allow the round-tripped value to match either
    # the original value or its string form.
    for (k, v) in a.metadata
        @test haskey(b.metadata, k) && (b.metadata[k] == v || b.metadata[k] == string(v))
    end
    @test b.metadata["format"] == "softpack-1"
    @test b.metadata["box"] == a.box
    return nothing
end

@testset "IO round-trip 2D frictionless" begin
    positions = [1.0 2.0 3.0 0.5; 1.0 1.0 1.0 2.0]   # 2 x 4
    radii = [0.3, 0.25, 0.2, 0.15]
    box = [4.0, 4.0]
    is_rattler = [false, false, true, false]          # particle 3 is a rattler
    contacts = [Contact(1, 2, 0.1, 0.5, nothing, (1.0, 0.0)),
                Contact(2, 4, 0.05, 0.25, nothing, (0.0, 1.0))]
    pk = Packing{2,Float64}(positions, radii, box, is_rattler, contacts, _meta())

    dir = mktempdir()
    write_packing(pk, dir; git_commit = "abc123def")
    @test isfile(joinpath(dir, "particles.csv"))
    @test isfile(joinpath(dir, "contacts.csv"))
    @test isfile(joinpath(dir, "metadata.toml"))

    pk2 = read_packing(dir)
    _assert_eq(pk, pk2)
    @test pk2.metadata["git_commit"] == "abc123def"
    @test pk2.metadata["friction"] === nothing          # nothing round-trips
    @test size(pk2.positions, 1) == 2
    @test length(pk2.contacts) == 2
end

@testset "IO round-trip 3D frictionless" begin
    positions = [1.0 2.0 0.5; 1.0 1.5 2.0; 0.1 0.2 0.3]   # 3 x 3
    radii = [0.3, 0.25, 0.2]
    box = [4.0, 4.0, 4.0]
    is_rattler = [false, true, false]
    contacts = [Contact(1, 3, 0.2, 1.0, nothing, (0.0, 0.0, 1.0))]
    pk = Packing{3,Float64}(positions, radii, box, is_rattler, contacts, _meta())

    dir = mktempdir()
    write_packing(pk, dir)
    pk2 = read_packing(dir)
    _assert_eq(pk, pk2)
    @test size(pk2.positions, 1) == 3
    @test pk2.contacts[1].normal == (0.0, 0.0, 1.0)
end

@testset "IO round-trip 3D frictional" begin
    positions = [1.0 2.0; 1.0 2.0; 0.5 1.5]
    radii = [0.3, 0.25]
    box = [4.0, 4.0, 4.0]
    is_rattler = [false, false]
    contacts = [Contact(1, 2, 0.2, 1.0, 0.35, (0.0, 0.0, 1.0))]   # has friction ft
    pk = Packing{3,Float64}(positions, radii, box, is_rattler, contacts, _meta(friction = :coulomb))

    dir = mktempdir()
    write_packing(pk, dir)
    pk2 = read_packing(dir)
    _assert_eq(pk, pk2)
    @test pk2.contacts[1].friction_force == 0.35
    @test pk2.metadata["friction"] == "coulomb"                    # symbol round-trips
end

@testset "IO exact float precision" begin
    # Values chosen to have long binary expansions; only full round-trip
    # precision (%.17g for Float64, %.9g for Float32) survives. This packing has
    # four particles, so radii and is_rattler also carry four entries (one per
    # particle), matching the 2 x 4 positions matrix.
    f64 = [0.1, 0.2, 0.30000000000000004, 3.14159265358979,
           2.718281828459045, 1.0e-13, 6.02214076e23, -4.9e-8]
    positions = collect(reshape(f64, (2, 4)))
    radii = [0.12345678901234567, 0.98765432109876543, 0.5555555555555556, 0.111111111111111]
    box = [12.3456789012345, 7.6543210987654]
    is_rattler = [false, true, false, false]
    contacts = [Contact(1, 2, 0.123456789012345, 0.987654321098765, nothing,
                        (0.7071067811865476, 0.7071067811865476))]
    pk = Packing{2,Float64}(positions, radii, box, is_rattler, contacts, _meta())

    dir = mktempdir()
    write_packing(pk, dir)
    pk2 = read_packing(dir)
    @test pk2.positions == pk.positions
    @test pk2.radii == pk.radii
    @test pk2.box == pk.box
    @test pk2.contacts[1].overlap == pk.contacts[1].overlap
    @test pk2.contacts[1].force_normal == pk.contacts[1].force_normal
    @test pk2.contacts[1].normal == pk.contacts[1].normal
end

@testset "IO exact float precision Float32" begin
    f32 = Float32[0.1f0, 0.2f0, 1.5f0, 1234.5678f0]
    positions = collect(reshape(f32, (2, 2)))
    radii = Float32[0.30000001f0, 0.20000005f0]
    box = Float32[4.0f0, 4.0f0]
    is_rattler = Bool[false, false]
    contacts = Contact{2,Float32}[Contact(1, 2, Float32(0.1), Float32(0.5), nothing,
                                          (Float32(1.0), Float32(0.0)))]
    pk = Packing{2,Float32}(positions, radii, box, is_rattler, contacts,
                            Dict{String,Any}("precision" => "Float32", "friction" => nothing))

    dir = mktempdir()
    write_packing(pk, dir)
    pk2 = read_packing(dir)
    @test eltype(pk2.positions) == Float32
    @test pk2.positions == pk.positions
    @test pk2.radii == pk.radii
    @test pk2.contacts[1].normal == (Float32(1.0), Float32(0.0))
end

@testset "IO missing files throw" begin
    dir = mktempdir()
    @test_throws ArgumentError read_packing(dir)   # no files present
end
