#  Size distributions: draw radii with a seeded RNG. Checks species counts and
#  ratios (Bidisperse), the mean/spread of the polydisperse laws, and that the
#  same seed reproduces the same radii. (mean/std are computed inline so no extra
#  test dependency is needed.)
using Test
using StableRNGs

# inline helpers so we don't depend on the Statistics stdlib in tests
avg(r) = sum(r) / length(r)
stdev(r) = sqrt(sum((r .- avg(r)).^2) / (length(r) - 1))

@testset "size distributions" begin

    @testset "monodisperse: all radii equal the given radius" begin
        r = draw_radii(Monodisperse(0.7), StableRNG(1), 10)
        @test length(r) == 10
        @test all(==(0.7), r)
    end

    @testset "bidisperse: correct species counts and ratio" begin
        N = 5000
        r = draw_radii(Bidisperse(ratio = 1.5, fraction = 0.3), StableRNG(42), N)
        n_small = count(==(1.0), r)      # small species has unit radius
        n_large = count(==(1.5), r)      # large species has radius = ratio
        @test n_small + n_large == N
        @test n_large / N ≈ 0.7 rtol = 0.03     # 70% large
        @test n_small / N ≈ 0.3 rtol = 0.03
        @test maximum(r) / minimum(r) ≈ 1.5 rtol = 1e-6
    end

    @testset "uniform polydisperse: mean and spread" begin
        N = 8000
        r = draw_radii(UniformPolydisperse(1.0, 2.0), StableRNG(7), N)
        @test minimum(r) >= 1.0
        @test maximum(r) <= 2.0
        @test avg(r) ≈ 1.5 rtol = 0.02
        @test stdev(r) ≈ (1.0 / sqrt(12)) rtol = 0.05   # std of Uniform(1,2)
    end

    @testset "lognormal polydisperse: mean matches exp(mu + sigma^2/2)" begin
        mu, sigma = 0.0, 0.3
        N = 8000
        r = draw_radii(LogNormalPolydisperse(mu, sigma), StableRNG(11), N)
        @test minimum(r) > 0
        @test avg(r) ≈ exp(mu + sigma^2 / 2) rtol = 0.03
    end

    @testset "custom radii returned as-is; N must match" begin
        r = draw_radii(CustomRadii([0.5, 0.8, 1.1]), StableRNG(3), 3)
        @test r == [0.5, 0.8, 1.1]
        @test_throws ArgumentError draw_radii(CustomRadii([0.5, 0.8]), StableRNG(3), 3)
    end

    @testset "determinism: same seed identical, different seed differs" begin
        d = UniformPolydisperse(0.8, 1.4)
        a = draw_radii(d, StableRNG(99), 500)
        b = draw_radii(d, StableRNG(99), 500)
        c = draw_radii(d, StableRNG(100), 500)
        @test a == b
        @test a != c
    end
end
