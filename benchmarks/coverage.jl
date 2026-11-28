# Exercise every exported entry point and every legal combination of the pack() options.
# One CSV row per attempt: section, name, status, detail, seconds.
using SoftPack, Printf

const DIR = @__DIR__
const OUT = joinpath(DIR, "coverage.csv")
open(OUT, "w") do io
    println(io, "section,name,status,detail,seconds")
end

const ROWS = Ref(0)
const FAILURES = String[]

function write_row(section, name, status, detail, seconds)
    line = join((section, name, status, replace(detail, "," => ";"),
                 @sprintf("%.2f", seconds)), ",")
    open(io -> println(io, line), OUT, "a")
    ROWS[] += 1
end

function attempt(section, name, options; expect_error::Bool = false)
    t = time()
    status, detail = "ok", ""
    try
        p = pack(; options...)
        detail = @sprintf("phi=%.4f z=%.4f conv=%s steps=%d",
                          p.packing_fraction, p.contact_number, p.converged, p.steps)
        expect_error && (status = "UNEXPECTED-OK")
    catch e
        message = replace(sprint(showerror, e), "\n" => " ")[1:min(end, 220)]
        if expect_error
            status, detail = "refused", message
        else
            status, detail = "error", message
            push!(FAILURES, "$section | $name | $message")
        end
    end
    write_row(section, name, status, detail, time() - t)
    status == "error" && println("  FAIL ", section, " / ", name, ": ", detail)
    return nothing
end

const BASE = (dimension = 2, particles_count = 32, target = Pressure(1e-3),
              convergence = RelativeForce(tolerance = 1e-3), pressure_tolerance = 0.05,
              steps_max = 80_000, failure_action = :warn)

opts(; extra...) = (; BASE..., extra...)

println("section 1: every exported name")
p = pack()
p32 = pack(particles_count = 32)
write_row("api", "contact_pressure", "ok", string(contact_pressure(p32)), 0.0)
write_row("api", "mean_normal_force", "ok", string(mean_normal_force(p32)), 0.0)
write_row("api", "is_converged", "ok", string(is_converged(p32)), 0.0)
write_row("api", "run_state", "ok", "RunState of $(length(run_state(p32).positions)) particles", 0.0)
state = run_state(p32)
@assert state isa RunState && length(state.positions) == 32
for rule in (ContactCount(), ContactCount(cone_test = false), TwoContact(),
             ForceFloor(floor = 1e-3), Unresolved(floor = 1e-6),
             pk -> falses(length(pk.diameters)))
    r = find_rattlers(p32, rule)
    @assert r isa BitVector && length(r) == 32
    write_row("api", "find_rattlers $(rule isa Function ? "custom" : nameof(typeof(rule)))",
              "ok", "rattlers=$(sum(r))", 0.0)
end
@assert p32.settings isa PackParams

mktempdir() do directory
    write_packing(joinpath(directory, "p.h5"), p32)
    write_packing(joinpath(directory, "p.csv"), p32; format = :csv)
end
write_row("api", "write_packing hdf5 and csv", "ok", "", 0.0)

println("section 2: one factor at a time")
attempt("one_factor", "distribution Bidisperse", opts(particles_size_distribution = Bidisperse()))
attempt("one_factor", "distribution Monodisperse", opts(particles_size_distribution = Monodisperse()))
attempt("one_factor", "distribution UniformPolydisperse",
        opts(particles_size_distribution = UniformPolydisperse()))
attempt("one_factor", "contact Hertzian", opts(contact = Hertzian()))
attempt("one_factor", "friction CundallStrack", opts(friction = CundallStrack(friction_coefficient = 0.3)))
attempt("one_factor", "friction Mindlin", opts(contact = Hertzian(), friction = Mindlin(friction_coefficient = 0.3)))
attempt("one_factor", "mass Density", opts(mass = Density(density = 1.0)))
attempt("one_factor", "boundary Walls", opts(boundary = Walls()))
attempt("one_factor", "boundary Walls no friction", opts(boundary = Walls(friction = false)))
attempt("one_factor", "initial Dilute", opts(initial_state = Dilute(packing_fraction = 0.2)))
attempt("one_factor", "protocol IsotropicCompression", opts(protocol = IsotropicCompression(strain_step = 5e-3)))
attempt("one_factor", "convergence LeidenAcceleration", opts(convergence = LeidenAcceleration(tolerance = 1e-10)))
attempt("one_factor", "convergence KineticEnergy", opts(convergence = KineticEnergy(tolerance = 1e-6)))
attempt("one_factor", "convergence RestartTest", opts(convergence = RestartTest()))
attempt("one_factor", "convergence custom", opts(convergence = state -> state.step >= 10_000))
attempt("one_factor", "timestep CollisionTime", opts(timestep = CollisionTime(fraction = 0.1)))
attempt("one_factor", "timestep number", opts(timestep = 0.02))
attempt("one_factor", "rattlers ContactCount cone off", opts(rattlers = ContactCount(cone_test = false)))
attempt("one_factor", "rattlers TwoContact", opts(rattlers = TwoContact()))
attempt("one_factor", "rattlers ForceFloor", opts(rattlers = ForceFloor(floor = 1e-3)))
attempt("one_factor", "rattlers Unresolved", opts(rattlers = Unresolved(floor = 1e-6)))
attempt("one_factor", "rattlers custom", opts(rattlers = pk -> falses(length(pk.diameters))))
attempt("one_factor", "algorithm FIRE explicit", opts(algorithm = FIRE()))
attempt("one_factor", "algorithm DD", opts(algorithm = DampedDynamics()))
attempt("one_factor", "seed 7", opts(seed = 7))

println("section 3: physics cross product")
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
    attempt("physics", "D$dimension $cname $fname $(nameof(typeof(mass))) $(nameof(typeof(boundary)))",
            opts(dimension = dimension, particles_count = dimension == 2 ? 32 : 64,
                 contact = contact, friction = friction, mass = mass, boundary = boundary))
end

println("section 4: algorithm cross product")
algorithms = [("FIRE", FIRE()),
              ("DD-centered", DampedDynamics(integrator = :centered_velocity_verlet)),
              ("DD-lagged", DampedDynamics(integrator = :lagged_velocity_verlet)),
              ("DD-euler", DampedDynamics(integrator = :semi_implicit_euler))]
dampings = [("none", nothing), ("ContactDamping", ContactDamping()),
            ("ViscousRate", ViscousRate()), ("RelativeVelocityDamping", RelativeVelocityDamping())]
drags = [("none", nothing), ("always", StokesDrag(velocity = 1.0, during = :always)),
         ("compression", StokesDrag(velocity = 1.0, during = :compression))]
for (aname, algorithm) in algorithms, (dname, damping) in dampings, (gname, drag) in drags,
    friction in (nothing, CundallStrack(friction_coefficient = 0.3))
    algo = algorithm isa FIRE ? FIRE(damping = damping, drag = drag) :
        DampedDynamics(integrator = algorithm.integrator, damping = damping, drag = drag)
    attempt("algorithm", "$aname damping=$dname drag=$gname friction=$(friction === nothing ? "off" : "on")",
            opts(algorithm = algo, friction = friction, steps_max = 60_000))
end

println("section 5: convergence cross product")
tests = [("RelativeForce", RelativeForce(tolerance = 1e-3)),
         ("LeidenAcceleration", LeidenAcceleration(tolerance = 1e-10)),
         ("KineticEnergy", KineticEnergy(tolerance = 1e-6)),
         ("RestartTest", RestartTest()),
         ("custom", state -> state.step >= 10_000)]
for (tname, test) in tests, (aname, algorithm) in algorithms
    attempt("convergence", "$tname $aname", opts(convergence = test, algorithm = algorithm))
end

println("section 6: rattlers cross product")
for rule in (ContactCount(), ContactCount(cone_test = false), TwoContact(),
             ForceFloor(floor = 1e-3), Unresolved(floor = 1e-6)),
    (fname, friction) in (("off", nothing), ("on", CundallStrack(friction_coefficient = 0.3)))
    attempt("rattlers", "$(nameof(typeof(rule))) friction=$fname",
            opts(rattlers = rule, friction = friction))
end

println("section 7: output matrix")
mktempdir() do directory
    base_packing = pack(; opts()...)
    counter = 0
    for format in (:hdf5, :csv),
        compression in (nothing, :gzip, (:gzip, 1), (:gzip, 9)),
        rattlers_file in (false, true),
        overwrite in (false, true)
        format === :csv && compression !== nothing && continue
        counter += 1
        path = joinpath(directory, "out$(counter).$(format === :csv ? "csv" : "h5")")
        name = "format=$format compression=$compression rattlers_file=$rattlers_file overwrite=$overwrite"
        t = time()
        status, detail = "ok", ""
        try
            overwrite && write_packing(path, base_packing; format = format,
                                       rattlers_file = rattlers_file)
            write_packing(path, base_packing; format = format, compression = compression,
                          rattlers_file = rattlers_file, overwrite = overwrite)
            if rattlers_file
                second = SoftPack.second_path(path)
                format === :hdf5 && !isfile(second) &&
                    error("the rattlers file was not written")
            end
        catch e
            status = "error"
            detail = replace(sprint(showerror, e), "\n" => " ")[1:min(end, 220)]
            push!(FAILURES, "output | $name | $detail")
            println("  FAIL output / ", name, ": ", detail)
        end
        write_row("output", name, status, detail, time() - t)
    end
end

println("section 8: recording matrix")
mktempdir() do directory
    restart_path = joinpath(directory, "restart.h5")
    movie_path = joinpath(directory, "movie.mp4")
    attempt("recording", "restart_file", opts(restart_file = RestartFile(restart_path; every = 2000)))
    attempt("recording", "snapshots", opts(snapshots = Snapshots(every = 2000)))
    attempt("recording", "movie", opts(movie = Movie(movie_path; every = 4000, size = 160)))
    attempt("recording", "all three",
            opts(restart_file = RestartFile(restart_path; every = 2000),
                 snapshots = Snapshots(every = 2000),
                 movie = Movie(movie_path; every = 4000, size = 160)))
    if isfile(restart_path)
        attempt("recording", "restart_packing continuation",
                (restart_packing = restart_path, steps_max = 200_000))
        attempt("recording", "restart rejects a physics change",
                (restart_packing = restart_path,
                 friction = CundallStrack(friction_coefficient = 0.3));
                expect_error = true)
    else
        push!(FAILURES, "recording | restart file was not written")
    end
end

println("section 9: restart round trips")
mktempdir() do directory
    for friction in (nothing, CundallStrack(friction_coefficient = 0.3)),
        boundary in (Periodic(), Walls()),
        algorithm in (FIRE(), DampedDynamics())
        path = joinpath(directory, "rt.h5")
        first_run = try
            pack(; opts(restart_file = RestartFile(path; every = 10), steps_max = 300,
                        friction = friction, boundary = boundary, algorithm = algorithm)...)
        catch e
            push!(FAILURES, "restart | first run $(nameof(typeof(algorithm))) $(nameof(typeof(boundary))) | " *
                            replace(sprint(showerror, e), "\n" => " "))
            nothing
        end
        first_run === nothing && continue
        attempt("restart", "continue $(nameof(typeof(algorithm))) $(nameof(typeof(boundary))) friction=$(friction === nothing ? "off" : "on")",
                (restart_packing = path, steps_max = 200_000))
    end
end

println("section 10: refusals")
attempt("refusal", "dimension 4", opts(dimension = 4); expect_error = true)
attempt("refusal", "one particle", opts(particles_count = 1); expect_error = true)
attempt("refusal", "Mindlin with Hookean", opts(friction = Mindlin()); expect_error = true)
attempt("refusal", "unknown integrator", opts(algorithm = DampedDynamics(integrator = :nope)); expect_error = true)
attempt("refusal", "negative stiffness", opts(contact = Hookean(stiffness = -1.0)); expect_error = true)
attempt("refusal", "steps_max 0", opts(steps_max = 0); expect_error = true)
attempt("refusal", "failure_action bad", opts(failure_action = :boom); expect_error = true)
attempt("refusal", "negative tolerance", opts(convergence = RelativeForce(tolerance = -1.0)); expect_error = true)
attempt("refusal", "bad drag during", opts(algorithm = DampedDynamics(drag = StokesDrag(velocity = 1.0, during = :nope))); expect_error = true)
attempt("refusal", "coulomb_limit total", opts(algorithm = DampedDynamics(damping = ContactDamping(coulomb_limit = :total))); expect_error = true)
attempt("refusal", "negative rattler floor", opts(rattlers = ForceFloor(floor = -1.0)); expect_error = true)

println()
println("attempts: ", ROWS[])
println("failures: ", length(FAILURES))
for f in FAILURES
    println("  ", f)
end
