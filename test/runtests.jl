using SoftPack
using SoftPack: SVector, StableRNG, RunControl, ConvergenceContext, run_state
using LinearAlgebra: dot, norm
using Test
using HDF5
using StaticArrays

# A brute-force copy of the probe that made the design's worked example
# (probe-compression-protocol branch, probes/compression/init_state.jl), so the
# cell-grid placement can be checked against it particle by particle.
function reference_initial_state(seed, diameters, packing_fraction, dimension)
    rng = StableRNG(seed)
    radii = diameters ./ 2
    side = SoftPack.box_side_for(SoftPack.total_volume(diameters, dimension),
                                 packing_fraction, dimension)
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
    @test p.algorithm isa FIRE
    @test p.snapshots === nothing && p.movie === nothing && p.restart_file === nothing
    @test DampedDynamics().integrator === :centered_velocity_verlet
    @test DampedDynamics().damping == ContactDamping()
    @test ContactDamping().normal == 0.98 && ContactDamping().tangential == 0.98
    @test CundallStrack().friction_coefficient == 0.5
    @test CundallStrack().stiffness_ratio === :matched
    @test Mindlin().poisson_ratio == 0.0
    f = FIRE()
    @test (f.timestep_max, f.timestep_min, f.delay, f.timestep_grow, f.timestep_shrink,
           f.mixing_coefficient, f.mixing_shrink, f.uphill_max) ==
          (10.0, 0.02, 20, 1.1, 0.5, 0.25, 0.99, 2000)
end

@testset "diameters, masses and scales (§3, §4)" begin
    d = SoftPack.draw_diameters(Bidisperse(), 256, StableRNG(1))
    @test count(==(1.0), d) == 128 && count(==(1.4), d) == 128
    @test sum(SoftPack.particle_volume(x, 2) for x in d) ≈ 297.5716561 atol = 1e-6
    u = SoftPack.draw_diameters(UniformPolydisperse(), 1000, StableRNG(2))
    @test all(0.8 .<= u .<= 1.2)
    @test abs(sum(u) / 1000 - 1) < 0.02
    @test SoftPack.draw_diameters(Monodisperse(diameter = 2.0), 3, nothing) ==
          [2.0, 2.0, 2.0]
    @test SoftPack.diameter_reference(PackParams(), d) == 1.0
    @test SoftPack.diameter_reference(PackParams(particles_diameters = [1.0, 3.0]),
                                      [1.0, 3.0]) == 2.0
    masses = SoftPack.particle_masses(Density(1.0), d, 2)
    @test masses[1] ≈ pi / 4 && masses[end] ≈ pi * 1.4^2 / 4
    @test SoftPack.mass_reference(Density(1.0), masses) ≈ sum(masses) / 256
    @test SoftPack.moment_of_inertia(1.0, 1.0, 2) ≈ 1 / 8      # disk: m d^2 / 8
    @test SoftPack.moment_of_inertia(1.0, 1.0, 3) ≈ 1 / 10     # sphere: m d^2 / 10
    @test SoftPack.inertia_ratio(2) == 2.0 && SoftPack.inertia_ratio(3) == 2.5
    @test SoftPack.tangential_stiffness(CundallStrack(), 1.0, 2) ≈ 1 / 3
    @test SoftPack.tangential_stiffness(CundallStrack(), 1.0, 3) ≈ 2 / 7
    @test SoftPack.tangential_stiffness(Mindlin(poisson_ratio = 0.0), 1.0, 2) ≈ 1.0
    @test SoftPack.tangential_stiffness(Mindlin(poisson_ratio = 0.3), 1.0, 2) ≈
          (2 * 0.7) / 1.7
end

@testset "box and rotation helpers" begin
    side = 10.0
    @test SoftPack.minimum_image(SVector(6.0, -6.0), side) == SVector(-4.0, 4.0)
    @test SoftPack.minimum_image(SVector(1.25, -2.5), side) == SVector(1.25, -2.5)
    @test SoftPack.wrap(SVector(-1.0, 12.5), side) == SVector(9.0, 2.5)
    @test SoftPack.spin_cross(SVector(2.0), SVector(1.0, 0.0)) == SVector(0.0, 2.0)
    @test SoftPack.position_cross(SVector(0.0, 1.0), SVector(1.0, 0.0)) == SVector(-1.0)
    @test SoftPack.tangent(SVector(1.0, 0.0)) == SVector(0.0, 1.0)
    @test norm(SoftPack.tangent(SVector(0.0, 0.0, 1.0))) ≈ 1
    @test SoftPack.project_onto_plane(SVector(1.0, 2.0), SVector(1.0, 0.0)) ==
          SVector(0.0, 2.0)
end

@testset "initial state reproduces the design's worked example (§2)" begin
    d = SoftPack.draw_diameters(Bidisperse(), 256, StableRNG(1))
    positions, side, trials, most = SoftPack.place_dilute(Val(2), d, 0.25, StableRNG(1))
    @test side ≈ 34.50 atol = 0.005
    @test trials == 493
    @test most == 19
    @test side == 34.50053078710678
    @test positions[1] == SVector(10.822840694660744, 25.047196478189626)
    gaps = [norm(SoftPack.minimum_image(positions[i] - positions[j], side)) -
            (d[i] + d[j]) / 2 for i in 1:255 for j in i+1:256]
    @test minimum(gaps) > 0
    @test minimum(gaps) ≈ 1.8e-3 atol = 1e-4
    x, side_reference, draws = reference_initial_state(1, d, 0.25, 2)
    @test side == side_reference && trials == draws
    @test all(positions[i] == SVector(x[i, 1], x[i, 2]) for i in 1:256)
    d3 = SoftPack.draw_diameters(Bidisperse(), 100, nothing)
    positions3, _, trials3, _ = SoftPack.place_dilute(Val(3), d3, 0.2, StableRNG(5))
    x3, _, draws3 = reference_initial_state(5, d3, 0.2, 3)
    @test trials3 == draws3
    @test all(positions3[i] == SVector(x3[i, 1], x3[i, 2], x3[i, 3]) for i in 1:100)
    # walls: the centers stay a radius inside
    wall_positions, wall_side, _, _ = SoftPack.place_dilute(Val(2), d, 0.25, StableRNG(1),
                                                            Walls())
    @test all(all(wall_positions[i] .>= d[i] / 2 .- 1e-12) for i in 1:256)
    @test all(all(wall_positions[i] .<= wall_side .- d[i] / 2 .+ 1e-12) for i in 1:256)
    @test_throws ArgumentError SoftPack.place_dilute(Val(2), d, 0.9, StableRNG(1);
                                                     trials_max = 100)
end

@testset "neighbor list finds every contact" begin
    for dimension in (2, 3)
        s = random_system(dimension; count = 300, packing_fraction = 0.8)
        SoftPack.evaluate_forces!(s)
        found = Set(zip(s.table.first, s.table.second))
        expected = Set{Tuple{Int,Int}}()
        for i in 1:299, j in i+1:300
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
        @test norm(sum(s.torques)) < 1e-12
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
        energy_at = lambda -> brute_energy(lambda .* s.positions, s.diameters,
                                           lambda * s.side, 1.0)
        dU = (energy_at(1 + h) - energy_at(1 - h)) / (2h)
        pressure = SoftPack.contact_pressure(s.table, s.side, dimension)
        @test pressure ≈ -dU / (dimension * s.side^dimension) rtol = 1e-6
    end
end

@testset "Hertzian contact law (§2)" begin
    s0 = random_system(2; count = 20, packing_fraction = 0.9)
    s = SoftPack.System(s0.positions, s0.diameters, s0.masses, s0.side,
                        Hertzian(stiffness = 2.0))
    SoftPack.evaluate_forces!(s)
    c = 1
    δ = s.table.overlaps[c]
    @test s.table.normal_forces[c] ≈ 2.0 * δ * sqrt(δ)
    @test s.table.normal_stiffnesses[c] ≈ 1.5 * 2.0 * sqrt(δ)
end

@testset "friction: a slid pair (§13, §7)" begin
    friction = CundallStrack(friction_coefficient = 0.5)
    s = SoftPack.System([SVector(0.0, 0.0), SVector(0.9, 0.0)], [1.0, 1.0], [1.0, 1.0],
                        10.0, Hookean(), friction, Periodic())
    SoftPack.evaluate_forces!(s)
    @test norm(s.table.tangential_forces[1]) == 0
    s.positions[2] = SVector(0.9, -0.02)          # slide the second disk along y
    SoftPack.evaluate_forces!(s)
    @test s.table.normals[1] ≈ SVector(-1.0, 0.0) atol = 0.03
    @test s.table.tangential_forces[1][2] < 0     # the spring pulls particle 1 along -y
    @test s.forces[2][2] > 0
    @test s.torques[1][1] < 0 && s.torques[2][1] < 0
    @test !s.table.sliding[1]                     # the stored flag lags one evaluation
    s.positions[2] = SVector(0.9, -0.25)          # a large slide reaches the Coulomb cap
    SoftPack.evaluate_forces!(s)
    cap = 0.5 * s.table.normal_forces[1]
    @test norm(s.table.tangential_forces[1]) ≈ cap rtol = 1e-6
    SoftPack.evaluate_forces!(s)                  # the flag is read on the next evaluation
    @test s.table.sliding[1]
    s.positions[2] = SVector(3.0, 0.0)            # breaking the contact resets the spring
    SoftPack.evaluate_forces!(s)
    @test isempty(s.table.first)
end

@testset "walls (§2)" begin
    s = SoftPack.System([SVector(0.4, 5.0)], [1.0], [1.0], 10.0, Hookean(), nothing,
                        Walls())
    SoftPack.evaluate_forces!(s)
    @test length(s.table) == 1
    @test s.table.normal_forces[1] ≈ 0.1          # overlap d/2 - h = 0.5 - 0.4
    @test s.forces[1] ≈ SVector(0.1, 0.0)
    @test s.table.branches[1] ≈ SVector(-0.4, 0.0)
    @test SoftPack.contact_pressure(s.table, 10.0, 2) ≈ 0.1 * 0.4 / (2 * 100)
    s2 = SoftPack.System([SVector(9.7, 5.0)], [1.0], [1.0], 10.0, Hookean(), nothing,
                         Walls())
    SoftPack.evaluate_forces!(s2)
    @test s2.forces[1] ≈ SVector(-0.2, 0.0)
    @test SoftPack.contact_pressure(s2.table, 10.0, 2) ≈ 0.2 * 0.3 / (2 * 100)
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
    st = SoftPack.FireState(fire, 1.0)
    steps = Float64[]
    for k in 1:8
        @test !SoftPack.uphill!(st, fire, 100 + k)
        push!(steps, st.timestep)
    end
    @test steps ≈ [0.5, 0.25, 0.125, 0.0625, 0.03125, 0.03125, 0.03125, 0.03125]
    @test st.mixing == 0.25
    st = SoftPack.FireState(fire, 1.0)
    st.mixing = 0.1
    for k in 1:19
        SoftPack.uphill!(st, fire, k)
    end
    @test st.timestep == 1.0 && st.mixing == 0.1
    SoftPack.uphill!(st, fire, 20)
    @test st.timestep == 0.5 && st.mixing == 0.25
    st = SoftPack.FireState(fire, 1.0)
    @test !any(SoftPack.uphill!(st, fire, 100) for _ in 1:2000)
    @test SoftPack.uphill!(st, fire, 100)
end

@testset "FIRE minimizes a random overlapping configuration" begin
    s = random_system(2; count = 64, packing_fraction = 0.9)
    ctx = ConvergenceContext(1e-6, 1.0, 1e-4, 1.0, 1.0, 1.0, 2)
    control = RunControl(collect(s.positions), s.side, PackParams())
    status, steps = SoftPack.minimize!(s, FIRE(), 0.05, RelativeForce(1e-10), ctx,
                                       control, false, 10^6)
    @test status === :converged
    @test SoftPack.largest_force(s.forces) < 1e-9
end

@testset "time step (§12, T-d66w option 1)" begin
    @test SoftPack.timestep_start(CollisionTime(), ones(4), 1.0, 1.0) ≈ pi * sqrt(0.5) / 50
    @test SoftPack.timestep_start(0.01, fill(4.0, 2), 1.0, 4.0) ≈ 0.02
    # friction shortens it: Mindlin at nu = 0 makes the tangential vibration faster
    with = SoftPack.timestep_start(CollisionTime(), ones(2), 1.0, 1.0;
                                   friction = Mindlin(poisson_ratio = 0.0), dimension = 2,
                                   law = Hertzian(), target = 1e-4)
    without = SoftPack.timestep_start(CollisionTime(), ones(2), 1.0, 1.0;
                                      dimension = 2, law = Hertzian(), target = 1e-4)
    @test with < without
end

@testset "damped dynamics: one damped oscillator (§8)" begin
    s = SoftPack.System([SVector(0.0, 0.0), SVector(0.9, 0.0)], [1.0, 1.0], [1.0, 1.0],
                        10.0, Hookean(), nothing, Periodic())
    ctx = ConvergenceContext(1e-6, 1.0, 1e-4, 1.0, 1.0, 1.0, 2)
    control = RunControl(collect(s.positions), 10.0, PackParams())
    status, steps = SoftPack.relax!(s, DampedDynamics(), 0.02, RelativeForce(1e-8), ctx,
                                    control, false, 5000)
    @test status === :converged
    @test steps < 400
    for integrator in (:lagged_velocity_verlet, :semi_implicit_euler)
        s2 = SoftPack.System([SVector(0.0, 0.0), SVector(0.9, 0.0)], [1.0, 1.0],
                             [1.0, 1.0], 10.0, Hookean(), nothing, Periodic())
        control2 = RunControl(collect(s2.positions), 10.0, PackParams())
        st, n = SoftPack.relax!(s2, DampedDynamics(integrator = integrator), 0.02,
                                RelativeForce(1e-8), ctx, control2, false, 20000)
        @test st === :converged
        @test n < 5000
    end
    # Stokes drag decays a free particle at exp(-rate t)
    s3 = SoftPack.System([SVector(0.0, 0.0), SVector(9.0, 0.0)], [1.0, 1.0], [1.0, 1.0],
                         10.0, Hookean(), nothing, Periodic())
    s3.velocities[1] = SVector(1.0, 0.0)
    control3 = RunControl(collect(s3.positions), 10.0, PackParams())
    SoftPack.relax!(s3, DampedDynamics(damping = nothing,
                                       drag = StokesDrag(velocity = 1.0)), 0.01,
                    _ -> false, ctx, control3, true, 500)
    @test norm(s3.velocities[1]) ≈ exp(-5) atol = 1e-3
end

@testset "convergence tests (§5)" begin
    params = PackParams()
    s = SoftPack.System([SVector(0.0, 0.0), SVector(3.0, 0.0)], [1.0, 1.0], [1.0, 1.0],
                        10.0, Hookean(), nothing, Periodic())
    SoftPack.evaluate_forces!(s)
    ctx = ConvergenceContext(1e-6, 1.0, 1e-4, 1.0, 1.0, 1.0, 2)
    state = run_state(s, 0.0, 0, params)
    @test is_converged(RelativeForce(1e-8), state, ctx)
    s.velocities[1] = SVector(0.1, 0.0)
    state = run_state(s, 0.0, 0, params)
    @test !is_converged(KineticEnergy(1e-8), state, ctx)
    @test is_converged(LeidenAcceleration(1e10), state, ctx)
    @test is_converged(state -> true, state, ctx)
    @test !is_converged(state -> false, state, ctx)
end

@testset "rattler rules (§9)" begin
    table = SoftPack.ContactTable{2}()
    for (i, j) in ((1, 2), (1, 3), (1, 4), (2, 3), (2, 4), (3, 4), (1, 5), (2, 5),
                   (5, 6), (6, 7))
        push!(table.first, i); push!(table.second, j)
        push!(table.wall_id, 0)
        push!(table.normals, SVector(1.0, 0.0)); push!(table.branches, SVector(0.5, 0.0))
        push!(table.overlaps, 0.01); push!(table.normal_stiffnesses, 1.0)
        push!(table.tangential_stiffnesses, 0.0); push!(table.normal_forces, 1.0)
        push!(table.tangential_forces, SVector(0.0, 0.0))
        push!(table.levers_first, 0.5); push!(table.levers_second, 0.5)
        push!(table.sliding, false)
    end
    settings = PackParams()
    rattlers = find_rattlers(ContactCount(), table, 7, settings)
    @test findall(rattlers) == [5, 6, 7]
    @test SoftPack.contact_number(table, rattlers) == 3.0
    @test find_rattlers(nothing, table, 7, settings) == falses(7)
    @test findall(find_rattlers(TwoContact(), table, 7, settings)) == [5, 6, 7]
    @test findall(find_rattlers(ForceFloor(floor = 0.5), table, 7, settings)) == [6, 7]
    @test all(find_rattlers(ForceFloor(floor = 2.0), table, 7, settings))
    # the cone test: particle 1 has exactly two contacts; its neighbours 2 and 3 keep
    # three each, so only the geometry of particle 1 decides
    function cone_table(n1, n2)
        t = SoftPack.ContactTable{2}()
        for (i, j, n) in ((1, 2, n1), (1, 3, n2), (2, 3, SVector(0.0, 1.0)),
                          (2, 4, SVector(0.0, -1.0)), (3, 4, SVector(0.0, 1.0)))
            push!(t.first, i); push!(t.second, j); push!(t.wall_id, 0)
            push!(t.normals, n); push!(t.branches, SVector(0.5, 0.0))
            push!(t.overlaps, 0.01); push!(t.normal_stiffnesses, 1.0)
            push!(t.tangential_stiffnesses, 0.0); push!(t.normal_forces, 1.0)
            push!(t.tangential_forces, SVector(0.0, 0.0))
            push!(t.levers_first, 0.5); push!(t.levers_second, 0.5)
            push!(t.sliding, false)
        end
        return t
    end
    frictional = PackParams(friction = CundallStrack(friction_coefficient = 0.5))
    opposite = cone_table(SVector(1.0, 0.0), SVector(-1.0, 0.0))
    @test !find_rattlers(ContactCount(), opposite, 4, frictional)[1]
    nearly = 0.3
    parallel = cone_table(SVector(1.0, 0.0), SVector(cos(nearly), sin(nearly)))
    @test find_rattlers(ContactCount(), parallel, 4, frictional)[1]
end

@testset "pack() with every default (regression)" begin
    p = pack()
    @test p.converged && p.stop_reason === :converged
    @test abs(p.pressure - 1e-4) <= 1e-4 * 1e-4
    @test p.force_residual < 1e-8
    @test 0.83 < p.packing_fraction < 0.85
    @test size(p.positions) == (2, 256)
    @test all(0 .<= p.positions .< p.box_side)
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
    q = pack()
    @test q.positions == p.positions && q.steps == p.steps
    r = pack(seed = 2)
    @test r.converged && r.positions != p.positions
    @test p.julia_version == string(VERSION)
    @test p.diameter_reference == 1.0 && p.diameter_mean ≈ 1.2
    @test find_rattlers(p, ContactCount()) == p.rattlers
    @test count(find_rattlers(p, nothing)) == 0
    @test count(find_rattlers(p, packing -> packing.diameters .> 1.2)) == 128
end

@testset "pack() with friction and the other settings" begin
    for (name, kwargs) in [
        ("friction FIRE", (friction = CundallStrack(friction_coefficient = 0.3),)),
        ("hertzian", (contact = Hertzian(),)),
        ("walls", (boundary = Walls(),)),
        ("walls frictionless", (boundary = Walls(friction = false),)),
        ("density masses", (mass = Density(1.0),)),
        ("monodisperse", (particles_size_distribution = Monodisperse(diameter = 1.0),)),
        ("leiden", (convergence = LeidenAcceleration(),)),
        ("restart test", (convergence = RestartTest(),)),
    ]
        p = pack(; kwargs..., particles_count = 128, steps_max = 3_000_000)
        @test p.converged
        @test p.packing_fraction > 0.5
    end
    diameters = [isodd(i) ? 1.0 : 1.4 for i in 1:64]
    p = pack(particles_diameters = diameters, particles_count = 999)
    @test p.diameters == diameters
    q = pack(dimension = 3, particles_count = 128, contact = Hertzian(),
             friction = Mindlin(poisson_ratio = 0.0))
    @test q.packing_fraction > 0.5
    # DampedDynamics runs (it is much slower to converge than FIRE, design §8)
    d = pack(friction = CundallStrack(friction_coefficient = 0.3),
             algorithm = DampedDynamics(drag = StokesDrag(velocity = 1.0,
                                                          during = :compression)),
             convergence = RelativeForce(tolerance = 1e-4), particles_count = 32,
             steps_max = 20_000)
    @test d isa Packing
end

@testset "write_packing and restart (§6, §11)" begin
    mktempdir() do directory
        path = joinpath(directory, "packing.h5")
        p = pack(particles_count = 64, steps_max = 2_000_000)
        write_packing(path, p)
        @test isfile(path)
        h5open(path, "r") do f
            @test read(attributes(f)["format"]) == "softpack-1"
            @test length(read(f["particles/diameter"])) == 64 - sum(p.rattlers)
            @test length(read(f["state/particles/diameter"])) == 64
            @test 0 < length(read(f["contacts/first"])) <= length(p.contacts)
        end
        @test_throws ArgumentError write_packing(path, p)
        write_packing(path, p; overwrite = true, rattlers_file = true, compression = :gzip)
        second = joinpath(directory, "packing_rattlers.h5")
        @test isfile(second)
        h5open(second, "r") do f
            @test length(read(f["particles/diameter"])) == 64
            @test length(read(f["particles/rattler"])) == 64
        end
        p2 = pack(particles_count = 64, steps_max = 5000)
        @test !p2.converged
        write_packing(path, p2; overwrite = true)
        p3 = pack(restart_packing = path, steps_max = 2_000_000)
        @test p3.converged
        @test p3.packing_fraction ≈ p.packing_fraction
        @test p3.positions ≈ p.positions rtol = 1e-9
        csv = joinpath(directory, "packing.csv")
        write_packing(csv, p; format = :csv)
        @test isfile(joinpath(directory, "packing_particles.csv"))
        @test isfile(joinpath(directory, "packing_contacts.csv"))
        # a periodic restart file written during the run, and a continuation from it
        for boundary in (Periodic(), Walls())
            path = joinpath(directory, "midrun-$(nameof(typeof(boundary))).h5")
            first_run = pack(particles_count = 32, boundary = boundary, steps_max = 20_000,
                             restart_file = RestartFile(path; every = 2000))
            @test isfile(path)
            continued = pack(restart_packing = path)
            @test continued.converged || continued.stop_reason === :steps_max
            @test continued.positions isa Matrix{Float64}
        end
        # the rattlers file and gzip compression
        marked = joinpath(directory, "marked.h5")
        write_packing(marked, p; rattlers_file = true, compression = (:gzip, 4))
        @test isfile(SoftPack.second_path(marked))
        snap = joinpath(directory, "snapshots.h5")
        p4 = pack(particles_count = 32, snapshots = Snapshots(every = 2000),
                  steps_max = 200_000)
        write_packing(snap, p4)
        h5open(snap, "r") do f
            @test haskey(f, "snapshots/positions")
            @test size(read(f["snapshots/positions"]), 2) == 32
        end
        if Sys.which("ffmpeg") !== nothing
            movie = joinpath(directory, "movie.mp4")
            pack(particles_count = 32, movie = Movie(movie; every = 2000, size = 200),
                 steps_max = 200_000)
            @test isfile(movie) && filesize(movie) > 1000
        end
    end
end

@testset "rotation markers" begin
    p = pack(particles_count = 32)
    mktempdir() do directory
        plain = joinpath(directory, "plain.ppm")
        SoftPack.render_packing(plain, p; size = 120)
        auto = joinpath(directory, "auto.ppm")
        SoftPack.render_packing(auto, p; size = 120)
        @test read(plain) == read(auto)       # frictionless: the default draws no markers
        marked = joinpath(directory, "marked.ppm")
        SoftPack.render_packing(marked, p; size = 120, markers = true)
        @test read(marked) != read(plain)
        f = pack(particles_count = 32,
                 friction = CundallStrack(friction_coefficient = 0.3))
        on = joinpath(directory, "friction.ppm")
        SoftPack.render_packing(on, f; size = 120)
        off = joinpath(directory, "friction_off.ppm")
        SoftPack.render_packing(off, f; size = 120, markers = false)
        @test read(on) != read(off)           # friction: the default draws them
    end
    p.system.rotations[1] = SVector(0.0)
    @test SoftPack.marker_direction(p.system, 1) == (1.0, 0.0, 1.0)
    p.system.rotations[1] = SVector(pi / 2)
    d = SoftPack.marker_direction(p.system, 1)
    @test abs(d[1]) < 1e-12 && d[2] ≈ 1.0 && d[3] == 1.0
    q = pack(dimension = 3, particles_count = 64)
    q.system.rotations[1] = SVector(0.0, 0.0, pi / 2)   # turn about the view axis
    d = SoftPack.marker_direction(q.system, 1)
    @test abs(d[1]) < 1e-12 && d[2] ≈ 1.0 && d[3] ≈ 1.0
    q.system.rotations[1] = SVector(0.0, pi / 2, 0.0)   # x diameter points at the camera
    @test SoftPack.marker_direction(q.system, 1)[3] < 0.1
    # a margin widens the frame (for a rotated view) and turns the wrap off
    mktempdir() do directory
        tight = joinpath(directory, "tight.ppm")
        wide = joinpath(directory, "wide.ppm")
        SoftPack.render_packing(tight, p; size = 80)
        SoftPack.render_packing(wide, p; size = 80, margin = 0.5)
        @test read(tight) != read(wide)
        walled = pack(particles_count = 32, boundary = Walls())
        SoftPack.render_packing(joinpath(directory, "walled.ppm"), walled; size = 80,
                                margin = 0.3)   # the border follows the box, not the frame
        @test isfile(joinpath(directory, "walled.ppm"))
    end
end

@testset "failure handling (§6)" begin
    p = @test_logs (:warn, r"did not converge") pack(steps_max = 500)
    @test !p.converged && p.stop_reason === :steps_max && p.steps == 500
    @test_throws ErrorException pack(steps_max = 500, failure_action = :error)
end

@testset "refused settings are named" begin
    @test_throws ArgumentError pack(friction = 0.5)
    @test_throws ArgumentError pack(contact = Hookean(), friction = Mindlin())
    @test_throws ArgumentError pack(algorithm = DampedDynamics(integrator = :rk4))
    @test_throws ArgumentError pack(algorithm = DampedDynamics(
        damping = ContactDamping(coulomb_limit = :total)))
    @test_throws ArgumentError pack(convergence = :not_a_test)
    @test_throws ArgumentError pack(dimension = 4)
    @test_throws ArgumentError pack(particles_count = 1)
    @test_throws ArgumentError pack(failure_action = :ignore)
    @test_throws ArgumentError pack(restart_packing = joinpath(tempdir(), "missing.h5"))
end

@testset "Float64 floor warning (T-2brz option 1)" begin
    d = SoftPack.draw_diameters(Bidisperse(), 256, nothing)
    @test_logs (:warn, r"force tolerance is probably out of reach") SoftPack.float64_floor_warning(
        PackParams(target = Pressure(1e-7)), d, 1.0)
    @test_logs (:warn, r"force floor is probably out of reach") SoftPack.float64_floor_warning(
        PackParams(target = Pressure(1e-6)), d, 1.0)
    @test_logs SoftPack.float64_floor_warning(PackParams(), d, 1.0)
    @test_logs SoftPack.float64_floor_warning(PackParams(target = Pressure(1e-5)), d, 1.0)
end

end
