# Paper benchmark runs for SoftPack: O'Hern 2003 scaling and Silbert 2010 friction.
# Resumable: each finished run is appended to the CSV and skipped on a rerun.
#
#   julia --project=. benchmarks/paper_figures.jl [output.csv]
#
# The default output is benchmarks/paper_figures/paper_benchmarks.csv. The full set is
# 118 runs (about 15 minutes on one core); analyze.py makes the figures and the tables.

using SoftPack

const OUT = length(ARGS) >= 1 ? ARGS[1] :
            joinpath(@__DIR__, "paper_figures", "paper_benchmarks.csv")
const HEADER = "benchmark,dimension,contact,mu,N,seed,P,phi,z,rattlers,steps,converged,seconds"

function load_done(path)
    done = Set{String}()
    isfile(path) || return done
    for (i, line) in enumerate(eachline(path))
        i == 1 && continue
        isempty(strip(line)) && continue
        push!(done, join(split(line, ',')[1:7], ','))
    end
    return done
end

function emit!(path, done, row)
    key = join(row[1:7], ',')
    key in done && return
    open(path, "a") do io
        println(io, join(row, ','))
        flush(io)
    end
    push!(done, key)
end

isdir(dirname(OUT)) || mkpath(dirname(OUT))
if !isfile(OUT)
    open(OUT, "w") do io
        println(io, HEADER)
    end
end
done = load_done(OUT)

contact_name(c) = c isa Hookean ? "Hookean" : c isa Hertzian ? "Hertzian" : string(typeof(c))

function run_one(; benchmark::String, dimension::Int, contact, mu, N::Int, seed::Int, P::Float64)
    key = join([benchmark, string(dimension), contact_name(contact),
                mu === nothing ? "none" : string(mu), string(N), string(seed), string(P)], ",")
    key in done && return
    kw = Dict{Symbol,Any}(
        :dimension => dimension,
        :particles_count => N,
        :contact => contact,
        :target => Pressure(P),
        :seed => seed,
    )
    if dimension == 3 && benchmark == "silbert"
        kw[:particles_size_distribution] = Monodisperse()
    end
    if mu !== nothing
        kw[:friction] = CundallStrack(friction_coefficient = mu)
    end
    t = time()
    p = pack(; kw...)
    elapsed = time() - t
    row = [benchmark, string(dimension), contact_name(contact),
           mu === nothing ? "none" : string(mu), string(N), string(seed), string(P),
           string(p.packing_fraction), string(p.contact_number), string(count(p.rattlers)),
           string(p.steps), string(p.converged), string(round(elapsed, digits = 2))]
    emit!(OUT, done, row)
    println(join(row, ','), "  (", round(elapsed, digits = 1), " s)")
    flush(stdout)
end

# --- O'Hern 2003: pressure sweeps, 2D/3D, Hookean/Hertzian -----------------
const PRESSURES = [1e-2, 1e-3, 3e-4, 1e-4, 3e-5, 1e-5]

for dimension in (2, 3), contact in (Hookean(), Hertzian())
    N = dimension == 2 ? 1024 : 512
    for seed in (1, 2), P in PRESSURES
        run_one(; benchmark = "ohern", dimension, contact, mu = nothing, N, seed, P)
    end
end

# --- extra 3D seeds: the 512-sphere packing fraction scatters by ~0.005 between
# seeds, so the scaling fit needs more than two members per pressure.
for contact in (Hookean(), Hertzian()), seed in 3:8, P in (1e-2, 1e-3, 3e-4, 1e-4)
    run_one(; benchmark = "ohern", dimension = 3, contact, mu = nothing,
              N = 512, seed, P)
end

# --- Silbert 2010: friction sweep at P = 1e-4 ----------------------------
for mu in (0.01, 0.1, 0.2, 0.5, 1.0), seed in (1, 2)
    run_one(; benchmark = "silbert", dimension = 2, contact = Hookean(),
              mu, N = 1024, seed, P = 1e-4)
end
for mu in (0.01, 0.1, 0.2, 0.5, 1.0), seed in (1, 2)
    run_one(; benchmark = "silbert", dimension = 3, contact = Hookean(),
              mu, N = 512, seed, P = 1e-4)
end
# frictionless anchor for the 3D monodisperse Silbert row (2D uses the O'Hern run)
for seed in (1, 2)
    run_one(; benchmark = "silbert", dimension = 3, contact = Hookean(),
              mu = nothing, N = 512, seed, P = 1e-4)
end

println("done: ", OUT)
