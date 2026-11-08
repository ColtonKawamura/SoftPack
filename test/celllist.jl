#  Cell-list pair finder vs. the brute-force reference. Checks that the cell list
#  returns exactly the same pair set as brute force across 2D/3D boxes with 1, 2,
#  3 and many cells per axis (monodisperse and bidisperse), that indices obey
#  i < j with no duplicates, and that a Verlet skin only grows the candidate set.
using Test
using StableRNGs

@testset "cell list pair finder" begin

    # Compare two pair lists as sets of (i, j) tuples (order-independent).
    pair_set(ii, jj) = sort!(unique(Tuple{Int,Int}[(ii[k], jj[k]) for k in eachindex(ii)]))

    same_pairs(x, radii, box) =
        pair_set(pairlist(CellList(x, radii, box), x, radii)...) ==
        pair_set(brute_force_pairlist(x, radii, box)...)

    @testset "2D: 1, 2, 3 and many cells per axis" begin
        # Monodisperse r = 1 -> cellsize = 2 -> nx = floor(L / 2).
        for (L, _) in ((3.0, 1), (5.0, 2), (7.0, 3), (15.0, 7))
            N = 40
            box = PeriodicBox(L, 2)
            x = random_positions(fill(1.0, N), box, StableRNG(1))
            @test same_pairs(x, fill(1.0, N), box)
        end

        # Bidisperse (radii 1.0, 1.5) -> cellsize = 3 -> nx = floor(L / 3).
        for (L, seed) in ((4.5, 101), (7.5, 102), (10.5, 103))
            N = 40
            box = PeriodicBox(L, 2)
            radii = draw_radii(Bidisperse(1.5, 0.5), StableRNG(seed), N)
            x = random_positions(radii, box, StableRNG(seed + 1))
            @test same_pairs(x, radii, box)
        end
    end

    @testset "3D: several cell counts, plus a rectangular low-cell fallback" begin
        for L in (6.0, 9.0, 20.0)      # cellsize = 2 -> nx = 3, 3, 6
            N = 60
            box = PeriodicBox(L, 3)
            x = random_positions(fill(1.0, N), box, StableRNG(5))
            @test same_pairs(x, fill(1.0, N), box)
        end
        # nx = (3, 2): one axis below 3 cells triggers the brute-force fallback.
        box = PeriodicBox([7.0, 5.0])
        radii = fill(1.0, 40)
        x = random_positions(radii, box, StableRNG(6))
        @test same_pairs(x, radii, box)
    end

    @testset "dense bidisperse 2D agrees with brute force" begin
        N = 100
        box = PeriodicBox(12.0, 2)      # nx = 6, cell-list path used
        radii = draw_radii(Bidisperse(1.3, 0.4), StableRNG(20), N)
        x = random_positions(radii, box, StableRNG(21))
        cl = CellList(x, radii, box)
        @test pair_set(pairlist(cl, x, radii)...) ==
              pair_set(brute_force_pairlist(x, radii, box)...)
    end

    @testset "indices obey i < j with no duplicates" begin
        N = 80
        box = PeriodicBox(10.0, 2)
        radii = draw_radii(Bidisperse(1.4, 0.5), StableRNG(30), N)
        x = random_positions(radii, box, StableRNG(31))
        cl = CellList(x, radii, box)
        ii, jj = pairlist(cl, x, radii)
        @test all(ii .< jj)              # every emitted pair has i < j
        @test length(unique(pair_set(ii, jj))) == length(ii)
    end

    @testset "verlet skin: skin > 0 only adds candidates (superset)" begin
        N = 60
        box = PeriodicBox(11.0, 2)      # nx = 5
        radii = fill(1.0, N)
        x = random_positions(radii, box, StableRNG(40))
        c0 = pair_set(pairlist(CellList(x, radii, box; skin = 0.0), x, radii)...)
        c1 = pair_set(pairlist(CellList(x, radii, box; skin = 0.3), x, radii)...)
        @test all(p -> p in c1, c0)
        @test length(c1) >= length(c0)
    end

    @testset "verlet rebuild trigger" begin
        N = 30
        box = PeriodicBox(9.0, 2)       # cellsize = 2, use skin = 0.4
        radii = fill(1.0, N)
        x = random_positions(radii, box, StableRNG(50))
        cl = CellList(x, radii, box; skin = 0.4)
        @test !needs_rebuild!(cl, x, x)          # nothing moved
        x_moved = copy(x)
        x_moved[1, 1] += 0.5                     # 0.5 > skin/2 = 0.2 -> rebuild
        @test needs_rebuild!(cl, x, x_moved)
        x_tiny = copy(x)
        x_tiny[1, 1] += 0.1                      # 0.1 < 0.2 -> no rebuild
        @test !needs_rebuild!(cl, x, x_tiny)
    end
end
