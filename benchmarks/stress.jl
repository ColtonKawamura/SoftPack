# Stress test for pack(): wide parameter combinations and large packings.
#
# Usage: julia --project=. benchmarks/stress.jl <section> [more sections...]
#
# Sections:
#   corners   - extreme values of every single setting at N = 32 (fast, finds crashes)
#   physics   - cross products of law, friction, mass, boundary, distribution at N = 64/128
#   targets   - pressure and tolerance sweeps at N = 256
#   large2d   - 2D scaling to N = 65536
#   large3d   - 3D scaling to N = 16384
#   record    - output, snapshots, movie and restart round trips
#   all       - every section above except large2d/large3d
#
# One CSV row per attempt, appended as soon as the attempt ends, so a killed
# process keeps every finished row: section,name,status,detail,seconds,phi,z,pressure,residual,steps
#
# status is one of: ok, nonconverged, invalid, error, unexpected-ok, refused.
# "invalid" means pack() returned but the result fails a physical sanity check
# (non-finite numbers, packing fraction out of range, pressure outside the band
# while converged = true).

using SoftPack, Printf, Dates

const DIR = @__DIR__
const OUT = get(ENV, "STRESS_CSV", joinpath(DIR, "stress.csv"))
if !isfile(OUT)
    open(io -> println(io, "section,name,status,detail,seconds,phi,z,pressure,residual,steps"),
         OUT, "w")
end
const FAILURES = String[]

function write_row(section, name, status, detail, seconds; p = nothing)
    if p === nothing
        extra = ",,,,"
    else
        extra = @sprintf("%.6g,%.6g,%.6g,%.3g,%d", p.packing_fraction, p.contact_number,
                         p.pressure, p.force_residual, p.steps)
    end
    line = join((section, name, status, replace(detail, "," => ";"), @sprintf("%.2f", seconds),
                 extra), ",")
    open(io -> println(io, line), OUT, "a")
    return nothing
end

"""
    sanity(p, options) -> Vector{String}

Checks a returned packing for non-finite numbers, an impossible packing fraction
and a converged flag that contradicts the pressure band. Empty means clean.
"""
function sanity(p, options)
    issues = String[]
    all(isfinite, p.positions) || push!(issues, "non-finite positions")
    all(isfinite, p.forces) || push!(issues, "non-finite forces")
    isfinite(p.pressure) || push!(issues, "non-finite pressure")
    isfinite(p.packing_fraction) || push!(issues, "non-finite packing fraction")
    isfinite(p.contact_number) || push!(issues, "non-finite contact number")
    # Inf is the honest residual when there is no contact to divide by; it is only a
    # problem when contacts exist.
    (isfinite(p.force_residual) || isempty(p.contacts.first)) ||
        push!(issues, "non-finite force residual")
    if isfinite(p.packing_fraction) && !(0 < p.packing_fraction < 1.5)
        push!(issues, "packing fraction $(p.packing_fraction)")
    end
    target = p.settings.target.value
    band = p.settings.pressure_tolerance * target
    if p.converged && abs(p.pressure - target) > band * (1 + 1e-9)
        push!(issues, "converged but P = $(p.pressure) outside the band")
    end
    if isfinite(p.pressure) && p.pressure < 0
        push!(issues, "negative pressure")
    end
    if any(isnan, p.diameters) || any(isnan, p.masses)
        push!(issues, "non-finite diameters or masses")
    end
    return issues
end

function attempt(section, name, options; expect = :ok)
    println("START ", section, " / ", name)
    flush(stdout)
    t = time()
    status, detail, packing = "ok", "", nothing
    try
        packing = pack(; options...)
        issues = sanity(packing, options)
        if !isempty(issues)
            status, detail = "invalid", join(issues, "; ")
        elseif !packing.converged
            status = "nonconverged"
            detail = @sprintf("stop=%s P=%.3g steps=%d", packing.stop_reason,
                              packing.pressure, packing.steps)
        end
        if expect === :error
            status, detail = "unexpected-ok", @sprintf("phi=%.4f z=%.4f", packing.packing_fraction,
                                                        packing.contact_number)
        end
    catch e
        message = replace(sprint(showerror, e), "\n" => " ")
        message = message[1:min(end, 260)]
        if expect === :error
            if e isa SoftPack.PackingError
                status, detail = "refused", message
            else
                status, detail = "error", message
                push!(FAILURES, "$section | $name | $message")
            end
        else
            status, detail = "error", message
            push!(FAILURES, "$section | $name | $message")
        end
    end
    seconds = time() - t
    write_row(section, name, status, detail, seconds; p = packing)
    if status in ("error", "invalid", "unexpected-ok")
        println("  FAIL ", section, " / ", name, ": ", status, " ", detail)
    elseif status == "nonconverged"
        println("  NONCONV ", section, " / ", name, ": ", detail)
    end
    return nothing
end

const BASE = (dimension = 2, particles_count = 32, target = Pressure(1e-3),
              convergence = RelativeForce(tolerance = 1e-3), pressure_tolerance = 0.05,
              steps_max = 80_000, failure_action = :warn)

opts(; extra...) = (; BASE..., extra...)

function section_corners()
    println("== corners: extreme single-setting values, N = 32 ==")
    d = Dict{String,Any}()
    # Size distributions and custom diameters
    for (name, extra) in [
        ("dist Bidisperse ratio 1.0", (particles_size_distribution = Bidisperse(diameter_ratio = 1.0),)),
        ("dist Bidisperse ratio 2.0", (particles_size_distribution = Bidisperse(diameter_ratio = 2.0),)),
        ("dist Bidisperse fraction_small 0", (particles_size_distribution = Bidisperse(fraction_small = 0.0),)),
        ("dist Bidisperse fraction_small 1", (particles_size_distribution = Bidisperse(fraction_small = 1.0),)),
        ("dist Bidisperse diameter_small 0.1", (particles_size_distribution = Bidisperse(diameter_small = 0.1),)),
        ("dist Monodisperse", (particles_size_distribution = Monodisperse(),)),
        ("dist UniformPolydisperse spread 0", (particles_size_distribution = UniformPolydisperse(spread = 0.0),)),
        ("dist UniformPolydisperse spread 0.5", (particles_size_distribution = UniformPolydisperse(spread = 0.5),)),
        ("dist UniformPolydisperse spread 0.9", (particles_size_distribution = UniformPolydisperse(spread = 0.9),)),
        ("dist UniformPolydisperse mean 2", (particles_size_distribution = UniformPolydisperse(diameter_mean = 2.0),)),
        ("diameters two custom", (particles_diameters = [1.0, 2.0],)),
        ("diameters lognormal 32", (particles_diameters = exp.(0.3 .* randn(32)) .+ 0.5,)),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # Contact laws and stiffnesses
    for (name, extra) in [
        ("contact Hertzian", (contact = Hertzian(),)),
        ("contact Hertzian stiff 1e3", (contact = Hertzian(stiffness = 1e3),)),
        ("contact Hooke stiff 1e-4", (contact = Hookean(stiffness = 1e-4),)),
        ("contact Hooke stiff 1e4", (contact = Hookean(stiffness = 1e4),)),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # Friction corners
    for (name, extra) in [
        ("friction CundallStrack mu 0", (friction = CundallStrack(friction_coefficient = 0.0),)),
        ("friction CundallStrack mu 1e-6", (friction = CundallStrack(friction_coefficient = 1e-6),)),
        ("friction CundallStrack mu 1.0", (friction = CundallStrack(friction_coefficient = 1.0),)),
        ("friction CundallStrack ratio 0.01", (friction = CundallStrack(stiffness_ratio = 0.01),)),
        ("friction CundallStrack ratio 1.0", (friction = CundallStrack(stiffness_ratio = 1.0),)),
        ("friction CundallStrack ratio 100", (friction = CundallStrack(stiffness_ratio = 100.0),)),
        ("friction Mindlin nu 0.49", (contact = Hertzian(), friction = Mindlin(poisson_ratio = 0.49))),
        ("friction Mindlin nu -0.99", (contact = Hertzian(), friction = Mindlin(poisson_ratio = -0.99))),
        ("friction Hertz CundallStrack", (contact = Hertzian(), friction = CundallStrack(friction_coefficient = 0.3))),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # Mass corners
    for (name, extra) in [
        ("mass Density 1e-6", (mass = Density(density = 1e-6),)),
        ("mass Density 1e6", (mass = Density(density = 1e6),)),
        ("mass EqualMass 1e-6", (mass = EqualMass(mass = 1e-6),)),
        ("mass EqualMass 1e6", (mass = EqualMass(mass = 1e6),)),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # Target pressures
    for (name, extra) in [
        ("target P 1e-6", (target = Pressure(1e-6),)),
        ("target P 1e-2", (target = Pressure(1e-2),)),
        ("target P 1", (target = Pressure(1.0),)),
        ("target P 100", (target = Pressure(100.0),)),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # Start and protocol
    for (name, extra) in [
        ("start Dilute 0.05", (initial_state = Dilute(packing_fraction = 0.05),)),
        ("start Dilute 0.35", (initial_state = Dilute(packing_fraction = 0.35),)),
        ("start Dilute 0.40", (initial_state = Dilute(packing_fraction = 0.40),)),
        ("protocol strain 1e-3", (protocol = IsotropicCompression(strain_step = 1e-3),)),
        ("protocol strain 0.1", (protocol = IsotropicCompression(strain_step = 0.1),)),
        ("protocol strain 0.5", (protocol = IsotropicCompression(strain_step = 0.5),)),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # Convergence tests
    for (name, extra) in [
        ("conv RelativeForce 1e-4", (convergence = RelativeForce(tolerance = 1e-4),)),
        ("conv RelativeForce 1e-10", (convergence = RelativeForce(tolerance = 1e-10),)),
        ("conv Leiden 1e-10", (convergence = LeidenAcceleration(tolerance = 1e-10),)),
        ("conv KineticEnergy 1e-6", (convergence = KineticEnergy(tolerance = 1e-6),)),
        ("conv RestartTest", (convergence = RestartTest(),)),
        ("conv custom step 10000", (convergence = state -> state.step >= 10_000,)),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # Timesteps
    for (name, extra) in [
        ("timestep CollisionTime 1/10", (timestep = CollisionTime(fraction = 1 / 10),)),
        ("timestep CollisionTime 1/200", (timestep = CollisionTime(fraction = 1 / 200),)),
        ("timestep 1e-3", (timestep = 1e-3,)),
        ("timestep 0.1", (timestep = 0.1,)),
        ("timestep 10", (timestep = 10.0,)),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # FIRE knobs
    for (name, extra) in [
        ("FIRE timestep_max 1", (algorithm = FIRE(timestep_max = 1.0),)),
        ("FIRE timestep_min 1e-4", (algorithm = FIRE(timestep_min = 1e-4),)),
        ("FIRE delay 0", (algorithm = FIRE(delay = 0),)),
        ("FIRE uphill_max 1", (algorithm = FIRE(uphill_max = 1),)),
        ("FIRE displacement_max 1e-6", (algorithm = FIRE(displacement_max = 1e-6),)),
        ("FIRE displacement_max 10", (algorithm = FIRE(displacement_max = 10.0),)),
        ("FIRE inertia_correction false", (algorithm = FIRE(inertia_correction = false),)),
        ("FIRE delay_initial false", (algorithm = FIRE(delay_initial = false),)),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # Damped dynamics damping and drag corners
    for (name, extra) in [
        ("DD no damping", (algorithm = DampedDynamics(damping = nothing),)),
        ("DD zero ContactDamping", (algorithm = DampedDynamics(damping = ContactDamping(normal = 0.0, tangential = 0.0)),)),
        ("DD ContactDamping 1.5", (algorithm = DampedDynamics(damping = ContactDamping(normal = 1.5, tangential = 1.5)),)),
        ("DD zero ViscousRate", (algorithm = DampedDynamics(damping = ViscousRate(normal = 0.0, tangential = 0.0)),)),
        ("DD zero RelativeVelocity", (algorithm = DampedDynamics(damping = RelativeVelocityDamping(rate = 0.0)),)),
        ("DD attractive", (algorithm = DampedDynamics(damping = ContactDamping(attractive = true)),)),
        ("DD tangential_pair", (algorithm = DampedDynamics(damping = ContactDamping(tangential_mass = :pair)),)),
        ("DD drag spin 0", (algorithm = DampedDynamics(drag = StokesDrag(velocity = 1.0, spin = 0.0)),)),
        ("DD drag zero", (algorithm = DampedDynamics(drag = StokesDrag(velocity = 0.0)),)),
        ("DD friction no damping", (friction = CundallStrack(friction_coefficient = 0.3),
                                    algorithm = DampedDynamics(damping = nothing))),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # Boundaries and rattlers
    for (name, extra) in [
        ("walls 2D", (boundary = Walls(),)),
        ("walls no friction with friction on", (boundary = Walls(friction = false),
                                                friction = CundallStrack(friction_coefficient = 0.3))),
        ("walls 3D", (dimension = 3, particles_count = 64, boundary = Walls())),
        ("rattlers cone off", (rattlers = ContactCount(cone_test = false),)),
        ("rattlers TwoContact", (rattlers = TwoContact(),)),
        ("rattlers ForceFloor 0", (rattlers = ForceFloor(floor = 0.0),)),
        ("rattlers Unresolved 1e-12", (rattlers = Unresolved(floor = 1e-12),)),
        ("rattlers keep all", (rattlers = pk -> falses(length(pk.diameters)),)),
        ("rattlers remove all", (rattlers = pk -> trues(length(pk.diameters)),)),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # Small and tiny systems
    for (name, extra) in [
        ("N 2 2D", (particles_count = 2,)),
        ("N 3 2D", (particles_count = 3,)),
        ("N 4 2D", (particles_count = 4,)),
        ("N 2 3D", (dimension = 3, particles_count = 2)),
        ("N 64 3D default", (dimension = 3, particles_count = 64)),
        ("N 64 3D monodisperse", (dimension = 3, particles_count = 64,
                                  particles_size_distribution = Monodisperse())),
    ]
        attempt("corners", name, opts(; extra...))
    end
    # Pressure tolerance and step cap
    for (name, extra) in [
        ("pressure_tolerance 0.5", (pressure_tolerance = 0.5,)),
        ("pressure_tolerance 1e-6", (pressure_tolerance = 1e-6,)),
        ("steps_max 1", (steps_max = 1,)),
        ("failure_action error steps 1", (steps_max = 1, failure_action = :error)),
    ]
        expect = startswith(name, "failure_action") ? :error : :ok
        attempt("corners", name, opts(; extra...); expect = expect)
    end
    return nothing
end

function section_corners2()
    println("== corners2: size extremes, low pressures, reporting edge cases ==")
    for (name, extra) in [
        ("dist Bidisperse ratio 5", (particles_size_distribution = Bidisperse(diameter_ratio = 5.0),)),
        ("dist Bidisperse ratio 10", (particles_size_distribution = Bidisperse(diameter_ratio = 10.0),)),
        ("dist Bidisperse ratio 10 N 256", (particles_count = 256,
                                            particles_size_distribution = Bidisperse(diameter_ratio = 10.0))),
        ("dist UniformPolydisperse spread 0.95", (particles_size_distribution = UniformPolydisperse(spread = 0.95),)),
        ("diameters lognormal broad", (particles_diameters = exp.(0.8 .* randn(64)) .+ 0.2,)),
        ("diameters one huge", (particles_diameters = [100.0; fill(1.0, 31)],)),
        ("N 1024 monodisperse 2D", (particles_count = 1024,
                                    particles_size_distribution = Monodisperse())),
        ("N 256 monodisperse 3D", (dimension = 3, particles_count = 256,
                                   particles_size_distribution = Monodisperse())),
    ]
        attempt("corners2", name, opts(; extra...))
    end
    for (name, extra) in [
        ("target P 1e-6 N 64", (particles_count = 64, target = Pressure(1e-6), steps_max = 300_000)),
        ("target P 1e-7 N 64", (particles_count = 64, target = Pressure(1e-7), steps_max = 300_000)),
        ("target P 1e-8 N 64", (particles_count = 64, target = Pressure(1e-8), steps_max = 300_000)),
        ("tol 1e-12 N 64", (particles_count = 64, convergence = RelativeForce(tolerance = 1e-12),
                            steps_max = 300_000)),
        ("FIRE timestep_max 1e-3", (algorithm = FIRE(timestep_max = 1e-3),)),
        ("FIRE timestep_min 10", (algorithm = FIRE(timestep_min = 10.0),)),
        ("timestep 1e-6", (timestep = 1e-6, steps_max = 50_000)),
        ("timestep 1e3", (timestep = 1e3, steps_max = 50_000)),
    ]
        attempt("corners2", name, opts(; extra...))
    end
    # recording edge cases: no frame is due, and wall-clock intervals
    mktempdir() do directory
        attempt("corners2", "movie no frame due",
                opts(particles_count = 32, steps_max = 2000,
                     movie = Movie(joinpath(directory, "none.mp4"); every = 10^9, size = 80)))
        attempt("corners2", "snapshots wall clock",
                opts(particles_count = 32, steps_max = 200_000,
                     snapshots = Snapshots(every = Millisecond(100))))
        attempt("corners2", "restart_file wall clock",
                opts(particles_count = 32, steps_max = 200_000,
                     restart_file = RestartFile(joinpath(directory, "clock.h5");
                                                every = Millisecond(100))))
    end
    return nothing
end

function section_physics()
    println("== physics: cross products of law, friction, boundary, dimension ==")
    contacts = [("Hookean", Hookean(), [("none", nothing),
                                        ("CundallStrack", CundallStrack(friction_coefficient = 0.3))]),
                ("Hertzian", Hertzian(), [("none", nothing),
                                          ("CundallStrack", CundallStrack(friction_coefficient = 0.3)),
                                          ("Mindlin", Mindlin(friction_coefficient = 0.3))])]
    for (cname, contact, frictions) in contacts,
        (fname, friction) in frictions,
        mass in (EqualMass(), Density(density = 1.0)),
        boundary in (Periodic(), Walls(), Walls(friction = false)),
        dimension in (2, 3)
        count = dimension == 2 ? 64 : 128
        attempt("physics", "D$dimension $cname $fname $(nameof(typeof(mass))) $(nameof(typeof(boundary)))",
                opts(dimension = dimension, particles_count = count, contact = contact,
                     friction = friction, mass = mass, boundary = boundary))
    end
    return nothing
end

function section_small3d()
    println("== small3d: convergence, rattlers and algorithms in 3D ==")
    for (name, extra) in [
        ("D3 Leiden 1e-10", (dimension = 3, particles_count = 64,
                             convergence = LeidenAcceleration(tolerance = 1e-10))),
        ("D3 KineticEnergy 1e-6", (dimension = 3, particles_count = 64,
                                   convergence = KineticEnergy(tolerance = 1e-6))),
        ("D3 RestartTest", (dimension = 3, particles_count = 64,
                            convergence = RestartTest())),
        ("D3 rattlers TwoContact", (dimension = 3, particles_count = 64,
                                    rattlers = TwoContact())),
        ("D3 rattlers ForceFloor", (dimension = 3, particles_count = 64,
                                    rattlers = ForceFloor(floor = 1e-3))),
        ("D3 rattlers Unresolved", (dimension = 3, particles_count = 64,
                                    rattlers = Unresolved(floor = 1e-6))),
        ("D3 friction Mindlin Density Walls", (dimension = 3, particles_count = 64,
                                               contact = Hertzian(),
                                               friction = Mindlin(friction_coefficient = 0.3),
                                               mass = Density(density = 1.0),
                                               boundary = Walls())),
        ("D3 custom diameters", (dimension = 3,
                                 particles_diameters = [isodd(i) ? 1.0 : 1.4 for i in 1:64])),
        ("D3 target 1e-2", (dimension = 3, particles_count = 128, target = Pressure(1e-2))),
        ("D3 target 1e-5", (dimension = 3, particles_count = 128, target = Pressure(1e-5),
                            steps_max = 500_000)),
        ("D2 FIRE ViscousRate", (algorithm = FIRE(damping = ViscousRate()),)),
        ("D2 FIRE RelativeVelocityDamping", (algorithm = FIRE(damping = RelativeVelocityDamping()),)),
        ("D3 DD lagged loose", (dimension = 3, particles_count = 64,
                                algorithm = DampedDynamics(integrator = :lagged_velocity_verlet),
                                convergence = RelativeForce(tolerance = 1e-3),
                                steps_max = 100_000)),
        ("D3 DD euler loose", (dimension = 3, particles_count = 64,
                               algorithm = DampedDynamics(integrator = :semi_implicit_euler),
                               convergence = RelativeForce(tolerance = 1e-3),
                               steps_max = 100_000)),
    ]
        attempt("small3d", name, opts(; extra...))
    end
    return nothing
end

function section_medium()
    println("== medium: common production combinations at N = 256-1024 ==")
    cases = [
        ("D2 N512 default", (particles_count = 512,)),
        ("D2 N1024 default", (particles_count = 1024,)),
        ("D3 N256 default", (dimension = 3, particles_count = 256)),
        ("D2 N512 friction 0.3", (particles_count = 512,
                                  friction = CundallStrack(friction_coefficient = 0.3))),
        ("D3 N256 friction 0.3", (dimension = 3, particles_count = 256,
                                  friction = CundallStrack(friction_coefficient = 0.3))),
        ("D2 N512 Hertzian", (particles_count = 512, contact = Hertzian())),
        ("D2 N512 Hertzian Mindlin", (particles_count = 512, contact = Hertzian(),
                                      friction = Mindlin(friction_coefficient = 0.3))),
        ("D3 N256 Hertzian Mindlin", (dimension = 3, particles_count = 256,
                                      contact = Hertzian(),
                                      friction = Mindlin(friction_coefficient = 0.3))),
        ("D2 N512 walls", (particles_count = 512, boundary = Walls())),
        ("D3 N256 walls", (dimension = 3, particles_count = 256, boundary = Walls())),
        ("D2 N512 polydisperse", (particles_count = 512,
                                  particles_size_distribution = UniformPolydisperse(spread = 0.3))),
        ("D2 N512 density", (particles_count = 512, mass = Density(density = 1.0))),
        ("D2 N512 target 1e-5", (particles_count = 512, target = Pressure(1e-5))),
        ("DD D2 N256 compression drag", (particles_count = 256,
                                          algorithm = DampedDynamics(drag = StokesDrag(velocity = 1.0,
                                                                                       during = :compression)),
                                          convergence = RelativeForce(tolerance = 1e-4),
                                          steps_max = 300_000)),
        ("DD D3 N128 compression drag", (dimension = 3, particles_count = 128,
                                          algorithm = DampedDynamics(drag = StokesDrag(velocity = 1.0,
                                                                                       during = :compression)),
                                          convergence = RelativeForce(tolerance = 1e-4),
                                          steps_max = 300_000)),
        ("FIRE friction drag compression", (particles_count = 512,
                                             friction = CundallStrack(friction_coefficient = 0.3),
                                             algorithm = FIRE(drag = StokesDrag(velocity = 1.0,
                                                                                during = :compression)))),
    ]
    for (name, extra) in cases
        attempt("medium", name, opts(; extra...))
    end
    return nothing
end

function section_targets()
    println("== targets: pressure sweep at N = 256, tolerance cost ==")
    for dimension in (2, 3),
        target in (1e-2, 1e-3, 1e-4, 1e-5),
        tolerance in (1e-4, 1e-6, 1e-8)
        count = dimension == 2 ? 256 : 512
        attempt("targets", "D$dimension P$target tol$tolerance",
                opts(dimension = dimension, particles_count = count,
                     target = Pressure(target), convergence = RelativeForce(tolerance = tolerance),
                     steps_max = 2_000_000))
    end
    return nothing
end

function section_large2d()
    println("== large2d: scaling ==")
    for count in (1024, 4096, 16384, 65536)
        attempt("large2d", "N $count default", opts(particles_count = count,
                                                    steps_max = 5_000_000))
    end
    for count in (2048, 8192, 32768)
        attempt("large2d", "N $count frictional", opts(particles_count = count,
                                                       friction = CundallStrack(friction_coefficient = 0.3),
                                                       steps_max = 5_000_000))
    end
    attempt("large2d", "N 16384 P 1e-5", opts(particles_count = 16384, target = Pressure(1e-5),
                                              steps_max = 5_000_000))
    attempt("large2d", "N 16384 monodisperse", opts(particles_count = 16384,
                                                    particles_size_distribution = Monodisperse(),
                                                    steps_max = 5_000_000))
    return nothing
end

function section_large3d()
    println("== large3d: scaling ==")
    for count in (512, 4096, 8192, 16384)
        attempt("large3d", "N $count default", opts(dimension = 3, particles_count = count,
                                                    steps_max = 5_000_000))
    end
    for count in (2048, 8192)
        attempt("large3d", "N $count frictional", opts(dimension = 3, particles_count = count,
                                                       friction = CundallStrack(friction_coefficient = 0.3),
                                                       steps_max = 5_000_000))
    end
    attempt("large3d", "N 4096 walls", opts(dimension = 3, particles_count = 4096,
                                            boundary = Walls(), steps_max = 5_000_000))
    attempt("large3d", "N 4096 Hertzian Mindlin", opts(dimension = 3, particles_count = 4096,
                                                       contact = Hertzian(),
                                                       friction = Mindlin(friction_coefficient = 0.3),
                                                       steps_max = 5_000_000))
    return nothing
end

function section_record()
    println("== record: output, snapshots, movies, restarts ==")
    mktempdir() do directory
        base = pack(; opts(particles_count = 256)...)
        for format in (:hdf5, :csv), compression in (nothing, :gzip)
            format === :csv && compression !== nothing && continue
            path = joinpath(directory, "out.$format")
            t = time()
            status, detail = "ok", ""
            try
                write_packing(path, base; format = format, compression = compression,
                              rattlers_file = true, overwrite = true)
                second = SoftPack.second_path(path)
                if format === :hdf5 && !isfile(second)
                    error("the rattlers file was not written")
                end
            catch e
                status = "error"
                detail = replace(sprint(showerror, e), "\n" => " ")[1:min(end, 260)]
                push!(FAILURES, "record | output $format $compression | $detail")
            end
            write_row("record", "output $format compression=$compression", status, detail,
                      time() - t)
        end
        restart_path = joinpath(directory, "restart.h5")
        attempt("record", "snapshots 256",
                opts(particles_count = 256, snapshots = Snapshots(every = 5000)))
        attempt("record", "movie 256",
                opts(particles_count = 256,
                     movie = Movie(joinpath(directory, "movie.mp4"); every = 10_000, size = 320)))
        attempt("record", "restart_file 256",
                opts(particles_count = 256,
                     restart_file = RestartFile(restart_path; every = 5000)))
        if isfile(restart_path)
            attempt("record", "restart continuation", (restart_packing = restart_path,
                                                       steps_max = 2_000_000))
        else
            push!(FAILURES, "record | restart file missing")
        end
        big_path = joinpath(directory, "restart_big.h5")
        attempt("record", "restart_file N 4096",
                opts(particles_count = 4096,
                     restart_file = RestartFile(big_path; every = 20_000)))
        if isfile(big_path)
            attempt("record", "restart continuation N 4096",
                    (restart_packing = big_path, steps_max = 2_000_000))
        end
    end
    return nothing
end

const SECTIONS = Dict("corners" => section_corners, "corners2" => section_corners2,
                      "physics" => section_physics, "small3d" => section_small3d,
                      "medium" => section_medium, "targets" => section_targets,
                      "large2d" => section_large2d,
                      "large3d" => section_large3d, "record" => section_record)

function main(args)
    requested = isempty(args) ? ["corners"] : args
    if "all" in requested
        requested = ["corners", "physics", "targets", "record"]
    end
    for name in requested
        haskey(SECTIONS, name) || error("unknown section $name; choose from $(join(keys(SECTIONS), ", ")), all")
        SECTIONS[name]()
    end
    println()
    println("failures: ", length(FAILURES))
    for f in FAILURES
        println("  ", f)
    end
    return isempty(FAILURES) ? 0 : 1
end

exit(main(ARGS))
