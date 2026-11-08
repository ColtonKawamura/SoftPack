#  Contact laws and the virial. Checks the analytic two-particle force/energy for
#  Hooke and Hertz, F = -dU/dx by finite differences, Newton's third law, the
#  mechanical pressure of a square lattice against its analytic value, and that the
#  Float32 path agrees with Float64.
using Test
using LinearAlgebra
using StableRNGs

@testset "contact laws and virial" begin

    @testset "hookean two particles: analytic force and energy" begin
        k, delta = 2.0, 0.1
        box = PeriodicBox(10.0, 2)
        # particle 1 at origin, particle 2 at (1.9, 0): distance 1.9, overlap 0.1
        x = Matrix([0.0 1.9; 0.0 0.0])
        radii = [1.0, 1.0]
        pairs = ([1], [2])
        F = zeros(2, 2)
        energy, contacts = compute_forces!(F, x, radii, box, pairs, Hookean(k))
        @test energy ≈ 0.5 * k * delta^2
        @test length(contacts) == 1
        c = contacts[1]
        @test c.overlap ≈ delta
        @test c.force_normal ≈ k * delta
        @test all(isapprox.(c.normal, (1.0, 0.0)))  # unit normal from i to j (+x)
        @test F[:, 1] ≈ [-k * delta, 0.0]     # force on i is -fn in +x
        @test F[:, 2] ≈ [k * delta, 0.0]      # force on j is +fn in +x
    end

    @testset "hertzian two particles: analytic force and energy" begin
        k, delta, r = 3.0, 0.15, 1.0
        box = PeriodicBox(10.0, 2)
        x = Matrix([0.0 (2r - delta); 0.0 0.0])
        radii = [r, r]
        pairs = ([1], [2])
        F = zeros(2, 2)
        energy, contacts = compute_forces!(F, x, radii, box, pairs, Hertzian(k))
        R_eff = r * r / (r + r)
        fn = (4 / 3) * k * sqrt(R_eff) * delta^1.5
        U = (4 / 3) * (2 / 5) * k * sqrt(R_eff) * delta^2.5
        @test energy ≈ U
        @test contacts[1].force_normal ≈ fn
        @test norm(F[:, 1]) ≈ fn              # magnitude on i
        @test norm(F[:, 1] + F[:, 2]) < 1e-12 # Newton's third law
    end

    @testset "finite difference F = -dU/dx on a random overlapping config" begin
        N = 20
        box = PeriodicBox(box_for_phi(fill(1.0, N), 0.4, 2), 2)
        x = random_positions(fill(1.0, N), box, StableRNG(3))
        # Nudge particles off the wrap boundary so perturbing one does not switch
        # which periodic image is the minimum image (keeps U smooth in x).
        x = 0.05 * box.sides .+ 0.9 * x
        radii = fill(1.0, N)
        pairs = pairlist(CellList(x, radii, box), x, radii)
        contact = Hookean(1.0)
        F = zeros(2, N)
        compute_forces!(F, x, radii, box, pairs, contact)
        eps = 1e-7
        @inbounds for p in 1:N
            xp = copy(x); xp[1, p] += eps
            xm = copy(x); xm[1, p] -= eps
            Up, _ = compute_forces!(zeros(2, N), xp, radii, box, pairs, contact)
            Um, _ = compute_forces!(zeros(2, N), xm, radii, box, pairs, contact)
            dU = (Up - Um) / (2 * eps)
            @test F[1, p] ≈ -dU[1] rtol = 1e-5
        end
    end

    @testset "newton third law: sum of forces ~ 0" begin
        N = 40
        box = PeriodicBox(box_for_phi(fill(1.0, N), 0.35, 2), 2)
        x = random_positions(fill(1.0, N), box, StableRNG(4))
        pairs = pairlist(CellList(x, fill(1.0, N), box), x, fill(1.0, N))
        F = zeros(2, N)
        compute_forces!(F, x, fill(1.0, N), box, pairs, Hookean(1.0))
        @test norm(sum(F, dims = 2)) < 1e-10
    end

    @testset "square-lattice pressure matches the analytic virial value" begin
        r, k, a = 1.0, 1.0, 1.8       # spacing: nearest in contact, next-nearest not
        M = 5
        box = PeriodicBox(a * M, 2)
        # Lattice point (i, j) with i, j in 0:M-1 sits at linear index i*M + j + 1.
        x = zeros(2, M * M)
        @inbounds for i in 0:M-1, j in 0:M-1
            k_ = i * M + j + 1
            x[1, k_] = a * i
            x[2, k_] = a * j
        end
        radii = fill(r, M * M)
        pairs = pairlist(CellList(x, radii, box), x, radii)
        _, contacts = compute_forces!(zeros(2, M * M), x, radii, box, pairs, Hookean(k))
        delta = 2r - a
        fn = k * delta
        @test length(contacts) == 2 * M * M      # each particle has 4 neighbours
        # Analytic virial pressure: (1/(V D)) sum fn * dist, dist = a per contact.
        P_analytic = (length(contacts) * fn * a) / (a * M * a * M * 2)
        @test virial_pressure(contacts, x, box) ≈ P_analytic rtol = 1e-9
        @test virial_pressure(contacts, x, box) > 0
    end

    @testset "hertzian square lattice: positive mechanical pressure" begin
        r, k, a = 1.0, 1.0, 1.8
        M = 4
        box = PeriodicBox(a * M, 2)
        x = zeros(2, M * M)
        @inbounds for i in 0:M-1, j in 0:M-1
            k_ = i * M + j + 1
            x[1, k_] = a * i
            x[2, k_] = a * j
        end
        radii = fill(r, M * M)
        pairs = pairlist(CellList(x, radii, box), x, radii)
        _, contacts = compute_forces!(zeros(2, M * M), x, radii, box, pairs, Hertzian(k))
        @test virial_pressure(contacts, x, box) > 0
    end

    @testset "Float32 path runs and agrees with Float64" begin
        N = 30
        box64 = PeriodicBox(box_for_phi(fill(1.0, N), 0.3, 2), 2)
        x64 = random_positions(fill(1.0, N), box64, StableRNG(7))
        pairs = pairlist(CellList(x64, fill(1.0, N), box64), x64, fill(1.0, N))
        F64 = zeros(2, N)
        U64, c64 = compute_forces!(F64, x64, fill(1.0, N), box64, pairs, Hookean(1.0))

        # The identical config built in Float32.
        x32 = Float32.(x64)
        box32 = PeriodicBox(Float32.(box64.sides))
        radii32 = Float32.(fill(1.0, N))
        pairs32 = pairlist(CellList(x32, radii32, box32), x32, radii32)
        F32 = zeros(Float32, 2, N)
        U32, c32 = compute_forces!(F32, x32, radii32, box32, pairs32, Hookean(Float32(1.0)))

        @test eltype(F32) == Float32
        @test isapprox(U32, U64; rtol = 1e-4)
        @test isapprox(F32, F64; rtol = 1e-4)
        @test isapprox(virial_pressure(c32, x32, box32),
                       virial_pressure(c64, x64, box64); rtol = 1e-4)
    end
end
