using SoftPack
using SoftPack: SVector, StableRNG
using LinearAlgebra: dot, norm
using Test

# A brute-force copy of the probe that made the design's worked example
# (probe-compression-protocol branch, probes/compression/init_state.jl), so the
# cell-grid placement can be checked against it particle by particle.
function reference_initial_state(seed, diameters, packing_fraction, dimension)
    rng = StableRNG(seed)
    radii = diameters ./ 2
    # the side as SoftPack computes it (the probe's own sum can differ in the last bit)
    side = SoftPack.box_side_for(SoftPack.total_volume(diameters, dimension), packing_fraction, dimension)
    order = sortperm(diameters; rev = true, alg = MergeSort)
    x = zeros(length(diameters), dimension)
    placed = Int[]
    draws = 0
    for i in order
        while true
            draws += 1
            trial = [rand(rng) * side for _ in 1:dimension]
            clear = true
            for j in placed
                dx = x[j, :] .- trial
                dx .-= side .* round.(dx ./ side)
                if sqrt(sum(abs2, dx)) - (radii[j] + radii[i]) <= 0
                    clear = false
                    break
                end
            end
            if clear
                x[i, :] = trial
                push!(placed, i)
                break
            end
        end
    end
    return x, side, draws
end

# Elastic energy of a configuration, every pair checked (for finite differences).
function brute_energy(positions, diameters, side, stiffness)
    energy = 0.0
    for i in 1:length(positions)-1, j in i+1:length(positions)
        dx = SoftPack.minimum_image(positions[i] - positions[j], side)
        overlap = (diameters[i] + diameters[j]) / 2 - norm(dx)
        overlap > 0 && (energy += stiffness * overlap^2 / 2)
    end
    return energy
end

# A random overlapping configuration (no compression, just positions).
function random_system(dimension; count = 60, packing_fraction = 0.9, seed = 3)
    rng = StableRNG(seed)
    diameters = [isodd(i) ? 1.0 : 1.4 for i in 1:count]
    volume = sum(SoftPack.particle_volume(d, dimension) for d in diameters)
    side = (volume / packing_fraction)^(1 / dimension)
    positions = [SVector{dimension,Float64}(ntuple(_ -> rand(rng) * side, dimension))
                 for _ in 1:count]
    return SoftPack.System(positions, diameters, ones(count), side, Hookean())
end

@testset "SoftPack" begin

@testset "defaults are the design's (§0)" begin
    p = PackParams()
    @test p.dimension == 2
    @test p.particles_count == 256
    @test p.particles_size_distribution == Bidisperse(1.0, 1.4, 0.5)
    @test p.contact == Hookean(1.0)
    @test p.friction === nothing
    @test p.mass == EqualMass(1.0)
    @test p.target == Pressure(1e-4)
    @test p.boundary == Periodic()
    @test p.initial_state == Dilute(0.25)
    @test p.protocol == IsotropicCompression(1e-2)
    @test p.convergence == RelativeForce(1e-8)
    @test p.pressure_tolerance == 1e-4
    @test p.steps_max == 10^7
    @test p.failure_action === :warn
    @test p.timestep == CollisionTime(1 / 50)
    @test p.rattlers == ContactCount(true)
    @test p.seed == 1
    f = FIRE()
    @test (f.timestep_max, f.timestep_min, f.delay, f.timestep_grow, f.timestep_shrink,
           f.mixing_coefficient, f.mixing_shrink, f.uphill_max) ==
          (10.0, 0.02, 20, 1.1, 0.5, 0.25, 0.99, 2000)
    @test f.inertia_correction && f.delay_initial
    @test f.integrator === :semi_implicit_euler
end

@testset "diameters and scales (§3, §4)" begin
    d = SoftPack.draw_diameters(Bidisperse(), 256, StableRNG(1))
    @test count(==(1.0), d) == 128 && count(==(1.4), d) == 128
    @test sum(SoftPack.particle_volume(x, 2) for x in d) ≈ 297.5716561 atol = 1e-6
    u = SoftPack.draw_diameters(UniformPolydisperse(), 1000, StableRNG(2))
    @test all(0.8 .<= u .<= 1.2)
    @test abs(sum(u) / 1000 - 1) < 0.02
    @test SoftPack.draw_diameters(Monodisperse(diameter = 2.0), 3, nothing) == [2.0, 2.0, 2.0]
    @test SoftPack.diameter_reference(PackParams(), d) == 1.0
    @test SoftPack.diameter_reference(PackParams(particles_diameters = [1.0, 3.0]),
                                      [1.0, 3.0]) == 2.0
end

@testset "box" begin
    side = 10.0
    @test SoftPack.minimum_image(SVector(6.0, -6.0), side) == SVector(-4.0, 4.0)
    @test SoftPack.minimum_image(SVector(1.25, -2.5), side) == SVector(1.25, -2.5)
    @test SoftPack.wrap(SVector(-1.0, 12.5), side) == SVector(9.0, 2.5)
    @test SoftPack.wrap(SVector(-1e-17, 0.0), side)[1] < side
end

@testset "initial state reproduces the design's worked example (§2)" begin
    d = SoftPack.draw_diameters(Bidisperse(), 256, StableRNG(1))
    rng = StableRNG(1)
    positions, side, trials, most = SoftPack.place_dilute(Val(2), d, 0.25, rng)
    @test side ≈ 34.50 atol = 0.005
    @test trials == 493
    @test most == 19
    # the same bits on every Julia version (design §10): StableRNGs plus in-order sums
    @test side == 34.50053078710678
    @test positions[1] == SVector(10.822840694660744, 25.047196478189626)
    gaps = [norm(SoftPack.minimum_image(positions[i] - positions[j], side)) -
            (d[i] + d[j]) / 2 for i in 1:255 for j in i+1:256]
    @test minimum(gaps) > 0
    @test minimum(gaps) ≈ 1.8e-3 atol = 1e-4
    x, side_reference, draws = reference_initial_state(1, d, 0.25, 2)
    @test side == side_reference && trials == draws
    @test all(positions[i] == SVector(x[i, 1], x[i, 2]) for i in 1:256)
    # 3D, against the same brute-force reference
    d3 = SoftPack.draw_diameters(Bidisperse(), 100, nothing)
    positions3, side3, trials3, _ = SoftPack.place_dilute(Val(3), d3, 0.2, StableRNG(5))
    x3, side3_reference, draws3 = reference_initial_state(5, d3, 0.2, 3)
    @test trials3 == draws3
    @test all(positions3[i] == SVector(x3[i, 1], x3[i, 2], x3[i, 3]) for i in 1:100)
    @test_throws ArgumentError SoftPack.place_dilute(Val(2), d, 0.9, StableRNG(1);
                                                     trials_max = 100)
end

@testset "neighbor list finds every contact" begin
    for dimension in (2, 3)
        s = random_system(dimension; count = 400, packing_fraction = 0.8)
        SoftPack.evaluate_forces!(s)
        found = Set(zip(s.table.first, s.table.second))
        expected = Set{Tuple{Int,Int}}()
        for i in 1:399, j in i+1:400
            dx = SoftPack.minimum_image(s.positions[i] - s.positions[j], s.side)
            norm(dx) < (s.diameters[i] + s.diameters[j]) / 2 && push!(expected, (i, j))
        end
        @test found == expected
        @test length(found) > 100
    end
end

@testset "forces are minus the energy gradient; pressure is -dU/dV (§2)" begin
    for dimension in (2, 3)
        s = random_system(dimension)
        SoftPack.evaluate_forces!(s)
        @test s.energy ≈ brute_energy(s.positions, s.diameters, s.side, 1.0)
        @test norm(sum(s.forces)) < 1e-12                     # Newton's third law
        h = 1e-6
        worst = 0.0
        for i in (1, 7, 30), a in 1:dimension
            shift = SVector{dimension,Float64}(ntuple(b -> b == a ? h : 0.0, dimension))
            plus = copy(s.positions); plus[i] += shift
            minus = copy(s.positions); minus[i] -= shift
            gradient = (brute_energy(plus, s.diameters, s.side, 1.0) -
                        brute_energy(minus, s.diameters, s.side, 1.0)) / (2h)
            worst = max(worst, abs(s.forces[i][a] + gradient))
        end
        @test worst < 1e-7
        # affine dilation by lambda: V = lambda^D V0, so P = -(dU/dlambda) / (D V0)
        energy_at = lambda -> brute_energy(lambda .* s.positions, s.diameters,
                                           lambda * s.side, 1.0)
        dU = (energy_at(1 + h) - energy_at(1 - h)) / (2h)
        pressure = SoftPack.contact_pressure(s.table, s.side, dimension)
        @test pressure ≈ -dU / (dimension * s.side^dimension) rtol = 1e-6
    end
end

@testset "FIRE step rules match LAMMPS min_fire.cpp (§14, T-vcne option 1)" begin
    fire = FIRE()
    st = SoftPack.FireState(fire, 1.0)
    for _ in 1:20
        SoftPack.downhill!(st, fire)
    end
    @test st.timestep == 1.0 && st.mixing == 0.25            # no growth through step 20
    SoftPack.downhill!(st, fire)
    @test st.timestep ≈ 1.1 && st.mixing ≈ 0.25 * 0.99       # the 21st grows
    for _ in 1:100
        SoftPack.downhill!(st, fire)
    end
    @test st.timestep == 10.0                                # capped at timestep_max
    @test st.mixing ≈ 0.25 * 0.99^101                        # mixing keeps shrinking
    # uphill: reset mixing, halve the step; a shrink below the floor is skipped
    st = SoftPack.FireState(fire, 1.0)
    steps = Float64[]
    for k in 1:8
        @test !SoftPack.uphill!(st, fire, 100 + k)
        push!(steps, st.timestep)
    end
    @test steps ≈ [0.5, 0.25, 0.125, 0.0625, 0.03125, 0.03125, 0.03125, 0.03125]
    @test st.mixing == 0.25
    # initial delay: uphill steps 1..19 change nothing, step 20 shrinks
    st = SoftPack.FireState(fire, 1.0)
    st.mixing = 0.1
    for k in 1:19
        SoftPack.uphill!(st, fire, k)
    end
    @test st.timestep == 1.0 && st.mixing == 0.1
    SoftPack.uphill!(st, fire, 20)
    @test st.timestep == 0.5 && st.mixing == 0.25
    # stop after MORE than uphill_max consecutive uphill steps
    st = SoftPack.FireState(fire, 1.0)
    @test !any(SoftPack.uphill!(st, fire, 100) for _ in 1:2000)
    @test SoftPack.uphill!(st, fire, 100)
end

@testset "FIRE minimizes a random overlapping configuration" begin
    s = random_system(2; count = 64, packing_fraction = 0.9)
    status, steps = SoftPack.minimize!(s, FIRE(), 0.05, RelativeForce(1e-10), 1e-6, 10^6)
    @test status === :converged
    @test SoftPack.largest_force(s.forces) < 1e-10 * SoftPack.mean_normal_force(s.table)
end

@testset "time step (§12, T-d66w option 1)" begin
    @test SoftPack.timestep_start(CollisionTime(), ones(4), 1.0, 1.0) ≈ pi * sqrt(0.5) / 50
    @test SoftPack.timestep_start(0.01, fill(4.0, 2), 1.0, 4.0) ≈ 0.02
end

@testset "ContactCount cascades (§9, T-hg7w option 1)" begin
    # Particles 1-4 form a well-connected cluster; 5 hangs on 3 contacts (1, 2, 6);
    # 6 has two contacts (5, 7), 7 has one. Removing 7 and 6 drops 5 to 2: it goes too.
    table = SoftPack.ContactTable{2}()
    for (i, j) in ((1, 2), (1, 3), (1, 4), (2, 3), (2, 4), (3, 4), (1, 5), (2, 5),
                   (5, 6), (6, 7))
        push!(table.first, i); push!(table.second, j)
    end
    rattlers = find_rattlers(ContactCount(), table, 7, 2, false)
    @test findall(rattlers) == [5, 6, 7]
    @test SoftPack.contact_number(table, rattlers) == 3.0
    @test find_rattlers(nothing, table, 7, 2, false) == falses(7)
end

@testset "pack() with every default" begin
    p = pack()
    @test p.converged && p.stop_reason === :converged
    @test abs(p.pressure - 1e-4) <= 1e-4 * 1e-4
    @test p.force_residual < 1e-8
    @test 0.83 < p.packing_fraction < 0.85
    @test size(p.positions) == (2, 256)
    @test all(0 .<= p.positions .< p.box_side)
    # every remaining particle keeps at least D + 1 = 3 contacts among the remaining ones
    remaining = findall(!, p.rattlers)
    counts = zeros(Int, 256)
    kept = 0
    for c in eachindex(p.contacts.first)
        i, j = p.contacts.first[c], p.contacts.second[c]
        if !p.rattlers[i] && !p.rattlers[j]
            counts[i] += 1; counts[j] += 1; kept += 1
        end
    end
    @test all(counts[remaining] .>= 3)
    @test kept >= 2 * (length(remaining) - 1) + 1          # at least isostatic
    @test p.contact_number ≈ 2 * kept / length(remaining)
    @test 4.0 <= p.contact_number < 4.2
    # The same bits on every Julia version (design §10): checked by hand on 1.10, 1.12 and
    # 1.13. Update these two numbers only when a change to the trajectory is intended.
    bits = foldl((h, v) -> xor(h * 0x100000001b3, reinterpret(UInt64, v)), vec(p.positions);
                 init = 0xcbf29ce484222325)
    @test p.steps == 86860
    @test bits == 0x1cf7db36917d17d6
    # same seed, same packing; another seed, another packing
    q = pack()
    @test q.positions == p.positions && q.steps == p.steps
    r = pack(seed = 2)
    @test r.converged && r.positions != p.positions
    @test p.settings == PackParams()
    @test p.julia_version == string(VERSION)
    @test p.diameter_reference == 1.0 && p.diameter_mean ≈ 1.2
    @test find_rattlers(p, ContactCount()) == p.rattlers
    @test count(find_rattlers(p, nothing)) == 0
end

@testset "other settings" begin
    p = pack(dimension = 3, particles_count = 128)
    @test p.converged
    @test 0.60 < p.packing_fraction < 0.68
    remaining = count(!, p.rattlers)
    @test p.contact_number * remaining / 2 >= 3 * (remaining - 1) + 1
    q = pack(particles_size_distribution = UniformPolydisperse(), particles_count = 128,
             target = Pressure(1e-3))
    @test q.converged && abs(q.pressure - 1e-3) <= 1e-7
    @test q.diameter_reference == 1.0
    diameters = [isodd(i) ? 1.0 : 1.4 for i in 1:64]
    r = pack(particles_diameters = diameters, rattlers = nothing)
    @test r.converged && r.diameters == diameters && !any(r.rattlers)
    s = pack(particles_count = 64, rattlers = packing -> packing.diameters .> 1.2)
    @test s.rattlers == (s.diameters .> 1.2)
end

@testset "failure handling (§6)" begin
    p = @test_logs (:warn, r"did not converge") pack(steps_max = 500)
    @test !p.converged && p.stop_reason === :steps_max && p.steps == 500
    @test_throws ErrorException pack(steps_max = 500, failure_action = :error)
end

@testset "not-yet-implemented settings are refused by name" begin
    @test_throws ArgumentError pack(friction = 0.5)
    @test_throws ArgumentError pack(restart_packing = "packing.h5")
    @test_throws ArgumentError pack(algorithm = FIRE(integrator = :velocity_verlet))
    @test_throws ArgumentError pack(algorithm = FIRE(drag = 0.1))
    @test_throws ArgumentError pack(convergence = state -> true)
    @test_throws ArgumentError pack(dimension = 4)
    @test_throws ArgumentError pack(particles_count = 1)
    @test_throws ArgumentError pack(failure_action = :ignore)
end

@testset "Float64 floor warning (T-2brz option 1)" begin
    d = SoftPack.draw_diameters(Bidisperse(), 256, nothing)
    # target out of reach: tolerance * <f_n> ~ 1.2e-15 < 2 eps(18.8) = 7.1e-15
    @test_logs (:warn, r"force tolerance is probably out of reach") SoftPack.float64_floor_warning(
        PackParams(target = Pressure(1e-7)), d, 1.0)
    # target reachable, compression floor not: 1e-8 * 1e-6 / 10 = 1e-15 < 7.1e-15
    @test_logs (:warn, r"force floor is probably out of reach") SoftPack.float64_floor_warning(
        PackParams(target = Pressure(1e-6)), d, 1.0)
    @test_logs SoftPack.float64_floor_warning(PackParams(), d, 1.0)
    @test_logs SoftPack.float64_floor_warning(PackParams(target = Pressure(1e-5)), d, 1.0)
end

end
