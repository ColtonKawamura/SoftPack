# ---------------------------------------------------------------------------
#  pack(): the entry point (design §1, §2, §6).
# ---------------------------------------------------------------------------

"""
    pack(; kwargs...) -> Packing
    pack(params::PackParams) -> Packing

Make a jammed packing. With no arguments: 256 frictionless Hookean disks (2D), a 50:50
bidisperse mixture of diameter ratio 1.4, compressed isotropically with FIRE in a
periodic box from packing fraction 0.25 until the elastic contact pressure is 1e-4
within a relative 1e-4, every net force below 1e-8 of the mean contact force, rattlers
removed, seed 1. Every keyword is a field of `PackParams`; the design doc
(`docs/design-references.md`, §0) gives each default and its reason.

`pack(restart_packing = path, ...)` continues a run from a file written by `write_packing`
or a `RestartFile`: every setting is taken from the file and only the run-control ones
(`steps_max`, `failure_action`, `convergence`, `restart_file`, `snapshots`, `movie`) may
change (design §6).

A run that does not converge warns and returns the packing with `converged = false`
(`failure_action = :error` throws instead).

```julia
packing = pack()
packing = pack(particles_count = 1024, target = Pressure(1e-5), seed = 7)
packing = pack(friction = CundallStrack(friction_coefficient = 0.3),
               algorithm = DampedDynamics())
packing = pack(dimension = 3, particles_count = 512, contact = Hertzian(),
               friction = Mindlin())
packing = pack(boundary = Walls())
```
"""
function pack(; kwargs...)
    restart = get(kwargs, :restart_packing, nothing)
    restart === nothing && return pack(PackParams(; kwargs...))
    return restart_pack(kwargs)
end

"""
    restart_pack(kwargs) -> Packing

Continue a run from a restart file (design §6). Only run-control settings may differ from
the stored ones.
"""
function restart_pack(kwargs)
    started = time()
    path = kwargs[:restart_packing]
    isfile(path) || throw(ArgumentError("restart_packing = $(repr(path)) does not exist"))
    stored, system, previous_control, previous, provenance = read_state(path)
    params = merge_restart_settings(stored, kwargs)
    validate(params)
    control = RunControl(copy(system.positions), system.side, params;
                         step = previous_control.step)
    control.compression = previous_control.compression
    timestep = previous.time_step
    evaluate_forces!(system)
    pressure = contact_pressure(system.table, system.side, params.dimension)
    band = params.pressure_tolerance * params.target.value
    ctx = convergence_context(params, system, timestep)
    state = run_state(system, pressure, control.step, params)
    outcome = if abs(pressure - params.target.value) <= band &&
                 is_converged(params.convergence, state, ctx)
        CompressionOutcome(:converged, 0, control.compression.accepted,
                           control.compression.rejected, control.compression.strain)
    else
        compress!(system, params, control, timestep, ctx)
    end
    return finish_packing(system, params, control, outcome, timestep, started)
end

const RESTART_MUTABLE = (:steps_max, :failure_action, :convergence, :restart_file,
                         :snapshots, :movie)

"""
    merge_restart_settings(stored, kwargs) -> PackParams

Start from the stored settings and apply the keywords the design lets a restart change;
any other keyword that differs from the file raises an error (design §6).
"""
function merge_restart_settings(stored::PackParams, kwargs)
    fields = Dict{Symbol,Any}(name => getfield(stored, name) for name in fieldnames(PackParams))
    for (key, value) in pairs(kwargs)
        key === :restart_packing && continue
        key in fieldnames(PackParams) ||
            throw(ArgumentError("unknown setting $(repr(key))"))
        if key in RESTART_MUTABLE
            fields[key] = value
        elseif !isequal(getfield(stored, key), value)
            throw(ArgumentError("a restart may change only $(join(RESTART_MUTABLE, ", ")), " *
                                "not $(repr(key)) (design §6)"))
        end
    end
    return PackParams(; fields...)
end

function pack(p::PackParams)
    validate(p)
    p.restart_packing === nothing ||
        return restart_pack((; restart_packing = p.restart_packing))
    started = time()
    rng = StableRNG(p.seed)
    dimension = p.dimension
    diameters = p.particles_diameters === nothing ?
        draw_diameters(p.particles_size_distribution, p.particles_count, rng) :
        copy(p.particles_diameters)
    count = length(diameters)
    diameter_ref = diameter_reference(p, diameters)
    masses = particle_masses(p.mass, diameters, dimension)
    mass_ref = mass_reference(p.mass, masses)
    float64_floor_warning(p, diameters, diameter_ref)
    positions, side, _, _ = place_dilute(Val(dimension), diameters,
                                         p.initial_state.packing_fraction, rng,
                                         p.boundary)
    timestep = timestep_start(p.timestep, masses, p.contact.stiffness, mass_ref;
                              friction = p.friction, dimension = dimension,
                              law = p.contact, target = p.target.value,
                              diameter_ref = diameter_ref,
                              packing_fraction = dimension == 2 ? 0.84 : 0.64)
    system = System(positions, diameters, masses, side, p.contact, p.friction, p.boundary)
    control = RunControl(positions, side, p; step = 0)
    ctx = convergence_context(p, system, timestep)
    outcome = compress!(system, p, control, timestep, ctx)
    return finish_packing(system, p, control, outcome, timestep, started;
                          diameter_ref = diameter_ref, mass_ref = mass_ref)
end

"""
    convergence_context(params, system, timestep) -> ConvergenceContext

The scales the convergence tests use, from the system's diameters and masses.
"""
function convergence_context(p::PackParams, s::System{D}, timestep::Float64) where {D}
    diameter_ref = diameter_reference(p, s.diameters)
    diameter_mean = sum_in_order(s.diameters) / length(s.diameters)
    force_floor = force_floor_for(p.target.value, diameter_ref, D)
    stiffness = p.contact.stiffness
    if p.contact isa Hertzian
        overlap = expected_overlap(p.contact, stiffness, p.target.value, diameter_ref, D,
                                   D == 2 ? 0.84 : 0.64)
        stiffness = contact_stiffness(p.contact, overlap)
    end
    return ConvergenceContext(force_floor, diameter_mean, p.target.value, diameter_ref,
                              stiffness, mass_mean(s.masses), D)
end

mass_mean(masses) = sum_in_order(masses) / length(masses)

"""
    finish_packing(system, params, control, outcome, timestep, started; scales...)

Assemble the `Packing`: copy the analysis arrays and the contact table, apply the rattler
rule, write the final restart file, finish the movie and warn when the run did not
converge.
"""
function finish_packing(s::System{D,NR}, params::PackParams, control::RunControl{D},
                        outcome::CompressionOutcome, timestep::Float64,
                        started::Float64;
                        diameter_ref::Union{Nothing,Float64} = nothing,
                        mass_ref::Union{Nothing,Float64} = nothing) where {D,NR}
    table = copy(s.table)
    count = length(s.diameters)
    diameter_ref = diameter_ref === nothing ? diameter_reference(params, s.diameters) :
        diameter_ref
    mass_ref = mass_ref === nothing ? mass_mean(s.masses) : mass_ref
    volume = total_volume(s.diameters, D)
    force_mean = mean_normal_force(table)
    residual = force_mean > 0 ? largest_force(s.forces) / force_mean : Inf
    converged = outcome.status === :converged
    packing = Packing{D,NR,typeof(s),typeof(control)}(
        positions_matrix(s.positions), copy(s.diameters), copy(s.masses),
        positions_matrix(s.forces), positions_matrix(s.torques), falses(count), table,
        s.side, contact_pressure(table, s.side, D), volume / s.side^D,
        contact_number(table, falses(count)), residual, converged, outcome.status,
        control.step, outcome.accepted, outcome.rejected, outcome.strain_step, timestep,
        time() - started, diameter_ref, sum_in_order(s.diameters) / count, mass_ref,
        params, params.seed, "StableRNGs.LehmerRNG", softpack_version(),
        softpack_commit(), string(VERSION), s, control)
    rattlers = find_rattlers(packing, params.rattlers)
    packing = Packing{D,NR,typeof(s),typeof(control)}(
        packing.positions, packing.diameters, packing.masses, packing.forces,
        packing.torques, rattlers, table, packing.box_side, packing.pressure,
        packing.packing_fraction, contact_number(table, rattlers), residual, converged,
        outcome.status, packing.steps, outcome.accepted, outcome.rejected,
        packing.strain_step_final, timestep, packing.runtime_seconds,
        packing.diameter_reference, packing.diameter_mean, mass_ref, params, params.seed,
        packing.random_number_generator, packing.softpack_version,
        packing.softpack_commit, packing.julia_version, s, control)
    if params.restart_file !== nothing
        write_state(params.restart_file.path, s, control, results(packing))
    end
    check_timestep_warning(s, timestep, params)
    finish_movie!(control)
    for message in control.warnings
        @warn message
    end
    if !converged
        message = "pack() did not converge ($(outcome.status)) after $(packing.steps) " *
                  "steps: P = $(@sprintf "%.4g" packing.pressure), force residual " *
                  "$(@sprintf "%.2e" residual). The packing is returned with " *
                  "converged = false."
        params.failure_action === :error && error(message)
        @warn message
    end
    return packing
end

"""
    check_timestep_warning(system, timestep, params)

Warn when a contact became stiffer than the chosen step resolves (design §12): compare
the highest contact frequency with the stable step of the algorithm's integrator.
"""
function check_timestep_warning(s::System, timestep::Float64, params::PackParams)
    omega, stable = check_timestep(s, timestep, params.algorithm)
    if timestep > stable
        @warn "the time step $(round(timestep; sigdigits = 3)) exceeds the stable step " *
              "$(round(stable; sigdigits = 3)) of the algorithm at the highest contact " *
              "frequency $(round(omega; sigdigits = 3)); a smaller timestep is safer " *
              "(design §12)"
    end
    return nothing
end

softpack_version() = string(pkgversion(@__MODULE__))

const SOFTPACK_COMMIT = Ref{String}("")

"""
    softpack_commit()

The git commit of the SoftPack source tree (with `-dirty` when it has uncommitted
changes), or `"unknown"` when it is not a git checkout.
"""
function softpack_commit()
    isempty(SOFTPACK_COMMIT[]) || return SOFTPACK_COMMIT[]
    root = dirname(@__DIR__)
    commit = try
        hash = readchomp(pipeline(`git -C $root rev-parse HEAD`; stderr = devnull))
        dirty = !isempty(readchomp(pipeline(`git -C $root status --porcelain --untracked-files=no`;
                                            stderr = devnull)))
        dirty ? hash * "-dirty" : hash
    catch
        "unknown"
    end
    SOFTPACK_COMMIT[] = commit
    return commit
end
