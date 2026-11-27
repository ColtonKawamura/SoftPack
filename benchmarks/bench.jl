# SoftPack benchmark sweep. Run with
#     julia --project=. benchmarks/bench.jl
# from the repository root; it appends one CSV line per run to bench.csv and prints the
# same line. The table in results.md was built from such a file.
using SoftPack, Printf

const OUT = joinpath(@__DIR__, "bench.csv")
open(OUT, "w") do io
    println(io, "group,dimension,count,pressure,friction,contact,algorithm,tolerance,seed,",
                "converged,status,seconds,steps,accepted,rejected,packing_fraction,",
                "contact_number,rattlers,pressure_measured")
end

function record(group; dimension = 2, count = 256, pressure = 1e-4,
                label_friction = "none", label_contact = "Hookean",
                label_algorithm = "FIRE", tolerance = 1e-8, seed = 1, options...)
    print(group, " ", count, " ", label_friction, " ", label_algorithm, " ... ")
    t = time()
    p = try
        pack(; dimension = dimension, particles_count = count, target = Pressure(pressure),
             seed = seed, options...)
    catch e
        println("FAILED: ", sprint(showerror, e)[1:min(end, 200)])
        return
    end
    seconds = time() - t
    line = join(Any[group, dimension, count, pressure, label_friction, label_contact,
                    label_algorithm, tolerance, seed, p.converged, p.stop_reason,
                    @sprintf("%.3f", seconds), p.steps, p.compression_steps_accepted,
                    p.compression_steps_rejected,
                    @sprintf("%.5f", p.packing_fraction),
                    @sprintf("%.4f", p.contact_number), sum(p.rattlers),
                    @sprintf("%.4e", p.pressure)], ",")
    open(io -> println(io, line), OUT, "a")
    println(line)
    flush(stdout)
    return p
end

pack(particles_count = 32)   # compile

for count in (256, 1024, 4096)
    record("scaling"; count = count)
end
for count in (512, 4096)
    record("scaling3d"; dimension = 3, count = count)
end
for pressure in (1e-2, 1e-3, 1e-4, 1e-5), seed in 1:3
    record("pressure"; pressure = pressure, seed = seed)
end
for μ in (0.1, 0.3, 0.5)
    record("friction"; label_friction = "CundallStrack($μ)",
           friction = CundallStrack(friction_coefficient = μ))
end
record("hertzian"; label_contact = "Hertzian", contact = Hertzian())
record("hertzian_mindlin"; count = 128, label_contact = "Hertzian",
       label_friction = "Mindlin", contact = Hertzian(),
       friction = Mindlin(poisson_ratio = 0.0))
record("walls"; boundary = Walls())
record("walls_frictionless"; boundary = Walls(friction = false),
       friction = CundallStrack(friction_coefficient = 0.3))
record("density"; mass = Density(1.0))
for tolerance in (1e-4, 1e-6), seed in 1:2
    record("tolerance"; tolerance = tolerance, seed = seed,
           convergence = RelativeForce(tolerance = tolerance))
end
# damped dynamics, the slow path (see results.md)
record("damped_dynamics"; count = 32, label_algorithm = "DampedDynamics",
       tolerance = 1e-4,
       algorithm = DampedDynamics(drag = StokesDrag(velocity = 1.0, during = :compression)),
       convergence = RelativeForce(tolerance = 1e-4), steps_max = 500_000)
record("damped_dynamics_friction"; count = 32, label_friction = "CundallStrack(0.3)",
       label_algorithm = "DampedDynamics", tolerance = 1e-3,
       friction = CundallStrack(friction_coefficient = 0.3),
       algorithm = DampedDynamics(drag = StokesDrag(velocity = 1.0, during = :compression)),
       convergence = RelativeForce(tolerance = 1e-3), steps_max = 500_000)
