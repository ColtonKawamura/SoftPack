#  Geometry: the periodic box, minimum-image wrapping, coordinate wrapping and
#  affine rescaling. Each testset has a plain-language comment on what it checks.
using LinearAlgebra

@testset "geometry" begin

    # ---- PeriodicBox: construction, sizing and volume --------------------------
    @testset "PeriodicBox" begin
        # A single length vector builds a box whose dimension is the vector length.
        b2 = PeriodicBox([4.0, 6.0])
        @test b2 isa PeriodicBox{2,Float64}
        @test b2.sides == [4.0, 6.0]
        @test length(b2) == 2

        # A cube constructor: side length and dimension.
        b3 = PeriodicBox(3.0, 3)
        @test b3 isa PeriodicBox{3,Float64}
        @test b3.sides == [3.0, 3.0, 3.0]

        # Volume is the product of the sides (area in 2D, volume in 3D).
        @test volume(b2) == 24.0
        @test volume(b3) == 27.0

        # Element type is generic: a Float32 box stays Float32 (Float64 is not
        # silently forced on it).
        bf = PeriodicBox(Float32[1.0, 2.0])
        @test bf isa PeriodicBox{2,Float32}
        @test eltype(bf.sides) == Float32
    end

    # ---- minimum_image!: wrap a displacement into the central cell -----------
    @testset "minimum_image 2D" begin
        b = PeriodicBox([10.0, 10.0])
        # A displacement larger than half the box wraps to its minimum image.
        @test isapprox(minimum_image([9.0, -3.0], b), [-1.0, -3.0])
        # Exactly at L wraps to 0.
        @test minimum_image([10.0, 0.0], b) == [0.0, 0.0]
        # A displacement of exactly L/2 is its own minimum image (kept positive).
        @test minimum_image([5.0, 5.0], b) == [5.0, 5.0]
        # Mutating version returns the same vector.
        d = [13.0, 17.0]
        @test isapprox(minimum_image!(d, b), [3.0, -3.0])
        @test isapprox(d, [3.0, -3.0])
    end

    @testset "minimum_image 3D" begin
        b = PeriodicBox([8.0, 12.0, 10.0])
        @test isapprox(minimum_image([7.0, -11.0, 3.0], b), [-1.0, 1.0, 3.0])
        # Every component lands in [-L_d/2, L_d/2].
        d = minimum_image([100.3, -200.7, 37.5], b)
        @test all(abs.(d) .<= b.sides ./ 2 .+ eps(Float64))
    end

    # ---- wrap!: fold coordinates into the half-open box [0, L) ---------------
    @testset "wrap 2D" begin
        b = PeriodicBox([4.0, 6.0])
        # 2 x N matrix: row d is axis d (L_d = box.sides[d]); each column is one
        # particle. Columns test the boundaries 0 and L, a negative and an over-L
        # coordinate, on both axes.
        x = Matrix([ 0.0  4.0 -1.0  5.0;
                     0.0  6.0 -2.0  7.0])
        y = wrap(x, b)
        @test y[:, 1] == [0.0, 0.0]            # 0 stays 0 on both axes
        @test y[:, 2] == [0.0, 0.0]            # 4 (==L_x) and 6 (==L_y) wrap to 0
        @test y[:, 3] == [3.0, 4.0]            # negatives wrap: -1 -> 3, -2 -> 4
        @test isapprox(y[:, 4], [1.0, 1.0])    # over-L wraps: 5 -> 1, 7 -> 1
        @test all(0 .<= y .< b.sides)
        # Mutating Vector version on a single particle's 2 coordinates.
        v = [-2.0, 6.5]
        wrap!(v, b)
        @test isapprox(v, [2.0, 0.5])
    end

    @testset "wrap 3D" begin
        b = PeriodicBox([2.0, 3.0, 5.0])
        # 3 x 4 matrix of coordinates (row d, column i).
        x = Matrix([1.5 -1 2 0;
                    3.2  0 6 1;
                   -5.5 2.5 5 4])
        y = wrap(x, b)
        @test isapprox(y[:, 1], [1.5, 0.2, 4.5])
        @test isapprox(y[:, 2], [1.0, 0.0, 2.5])
        @test y[:, 3] == [0.0, 0.0, 0.0]       # all exactly at cell boundaries
        @test y[:, 4] == [0.0, 1.0, 4.0]
        @test all(0 .<= y .< b.sides)
    end

    # ---- affine rescale of the box and the positions --------------------------
    @testset "rescale!" begin
        b = PeriodicBox([4.0, 4.0])
        x = Matrix([1.0 2.0; 3.0 4.0])        # 2 x 2
        rescale!(b, x, 2.0)
        @test b.sides == [8.0, 8.0]           # box sides doubled
        @test x == [2.0 4.0; 6.0 8.0]         # positions scaled by the same factor
        # Isotropic scale keeps the packing fraction constant: V scales like L^D.
        b2 = PeriodicBox([2.0, 2.0])
        x2 = Matrix([0.5 1.5; 0.5 1.5])
        vol_before = volume(b2)
        rescale!(b2, x2, 3.0)
        @test volume(b2) == 9.0 * vol_before
    end
end
