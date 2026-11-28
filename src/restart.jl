# ---------------------------------------------------------------------------
#  The restart file (design §6): one HDF5 file that holds every particle, the
#  full dynamic state, the contact history, the compression state, every setting
#  and the provenance, so `restart_packing` can continue a run exactly.
# ---------------------------------------------------------------------------

"""
    RunResults

The scalar results written next to the state: the pressure and packing fraction, the
contact number and force residual, whether the run converged and why it stopped, the
scales and the time step.
"""
struct RunResults
    pressure::Float64
    packing_fraction::Float64
    contact_number::Float64
    force_residual::Float64
    converged::Bool
    stop_reason::Symbol
    diameter_reference::Float64
    diameter_mean::Float64
    mass_reference::Float64
    time_step::Float64
end

# --- Settings serialization --------------------------------------------------

setting_dict(x::Union{Number,String,Bool}) = x
setting_dict(x::Symbol) = string(x)
setting_dict(::Nothing) = "nothing"
setting_dict(x::AbstractVector) = collect(x)
setting_dict(x::Dates.Period) = Dict("seconds" => Dates.Millisecond(x).value / 1000)
function setting_dict(x)
    d = Dict{String,Any}()
    for name in fieldnames(typeof(x))
        d[string(name)] = setting_dict(getfield(x, name))
    end
    return d
end

symbol_or_number(x) = x isa Number ? x : Symbol(x)

function contact_from_dict(d)
    law = d["law"]
    return law == "Hookean" ? Hookean(stiffness = d["stiffness"]) :
           Hertzian(stiffness = d["stiffness"])
end

function friction_from_dict(d)
    (d === nothing || d == "nothing") && return nothing
    if haskey(d, "stiffness_ratio")
        return CundallStrack(friction_coefficient = d["friction_coefficient"],
                             stiffness_ratio = symbol_or_number(d["stiffness_ratio"]))
    end
    return Mindlin(friction_coefficient = d["friction_coefficient"],
                   poisson_ratio = d["poisson_ratio"])
end

function mass_from_dict(d)
    haskey(d, "density") && return Density(density = d["density"])
    return EqualMass(d["mass"])
end

function distribution_from_dict(d)
    haskey(d, "diameter_small") &&
        return Bidisperse(diameter_small = d["diameter_small"],
                          diameter_ratio = d["diameter_ratio"],
                          fraction_small = d["fraction_small"])
    haskey(d, "diameter_mean") &&
        return UniformPolydisperse(diameter_mean = d["diameter_mean"], spread = d["spread"])
    return Monodisperse(diameter = d["diameter"])
end

function boundary_from_dict(d)
    haskey(d, "friction") && return Walls(friction = d["friction"])
    return Periodic()
end

function convergence_from_dict(d)
    d == "nothing" &&
        throw(ArgumentError("a user convergence function cannot be restarted"))
    haskey(d, "accelerations") && return LeidenAcceleration(tolerance = d["tolerance"])
    haskey(d, "energy") && return KineticEnergy(tolerance = d["tolerance"])
    haskey(d, "restart") && return RestartTest()
    return RelativeForce(tolerance = d["tolerance"])
end

function rattlers_from_dict(d)
    d == "custom" &&
        throw(ArgumentError("a user rattler rule cannot be restarted; pass rattlers explicitly"))
    (d === nothing || d == "nothing") && return nothing
    haskey(d, "two") && return TwoContact()
    if haskey(d, "floor")
        floor = d["floor"]
        return floor == "tolerance" ? Unresolved(floor = :tolerance,
                                                 cone_test = d["cone_test"]) :
               Unresolved(floor = Float64(floor), cone_test = d["cone_test"])
    end
    return ContactCount(cone_test = d["cone_test"])
end

function damping_from_dict(d)
    (d === nothing || d == "nothing") && return nothing
    d isa String && (d == "nothing" ? (return nothing) :
                     throw(ArgumentError("unreadable damping settings")))
    haskey(d, "rate") && return RelativeVelocityDamping(rate = d["rate"],
                                                        attractive = d["attractive"],
                                                        coulomb_limit = Symbol(d["coulomb_limit"]))
    if haskey(d, "tangential_mass")
        return ContactDamping(normal = d["normal"], tangential = d["tangential"],
                              tangential_mass = Symbol(d["tangential_mass"]),
                              attractive = d["attractive"],
                              coulomb_limit = Symbol(d["coulomb_limit"]))
    end
    return ViscousRate(normal = d["normal"], tangential = d["tangential"],
                       attractive = d["attractive"],
                       coulomb_limit = Symbol(d["coulomb_limit"]))
end

function drag_from_dict(d)
    (d === nothing || d == "nothing") && return nothing
    return StokesDrag(velocity = d["velocity"], spin = d["spin"],
                      during = Symbol(d["during"]))
end

function algorithm_from_dict(d)
    if haskey(d, "timestep_max")
        return FIRE(timestep_max = d["timestep_max"], timestep_min = d["timestep_min"],
                    delay = Int(d["delay"]), timestep_grow = d["timestep_grow"],
                    timestep_shrink = d["timestep_shrink"],
                    mixing_coefficient = d["mixing_coefficient"],
                    mixing_shrink = d["mixing_shrink"], uphill_max = Int(d["uphill_max"]),
                    inertia_correction = d["inertia_correction"],
                    delay_initial = d["delay_initial"],
                    integrator = Symbol(d["integrator"]),
                    damping = damping_from_dict(d["damping"]),
                    drag = drag_from_dict(d["drag"]))
    end
    return DampedDynamics(integrator = Symbol(d["integrator"]),
                          damping = damping_from_dict(d["damping"]),
                          drag = drag_from_dict(d["drag"]))
end

timestep_from_dict(d) = d isa Number ? d : CollisionTime(fraction = d["fraction"])

restart_file_from_dict(d) =
    (d isa String) ? nothing :
    RestartFile(path = d["path"], every = interval_from_value(d["every"]))

snapshots_from_dict(d) =
    (d isa String) ? nothing : Snapshots(every = interval_from_value(d["every"]))

movie_from_dict(d) =
    (d isa String) ? nothing :
    Movie(path = d["path"], every = interval_from_value(d["every"]),
          size = Int(d["size"]), fps = Int(d["fps"]))

interval_from_value(v) = v isa Dict ? Dates.Millisecond(round(Int, 1000 * v["seconds"])) : Int(v)

function params_from_dict(d)
    diameters = d["particles_diameters"] isa Vector ? Float64.(d["particles_diameters"]) :
        nothing
    return PackParams(
        dimension = Int(d["dimension"]),
        particles_count = Int(d["particles_count"]),
        particles_size_distribution = distribution_from_dict(d["particles_size_distribution"]),
        particles_diameters = diameters,
        contact = contact_from_dict(d["contact"]),
        friction = friction_from_dict(d["friction"]),
        mass = mass_from_dict(d["mass"]),
        target = Pressure(d["target"]["value"]),
        boundary = boundary_from_dict(d["boundary"]),
        initial_state = Dilute(packing_fraction = d["initial_state"]["packing_fraction"]),
        protocol = IsotropicCompression(strain_step = d["protocol"]["strain_step"]),
        convergence = convergence_from_dict(d["convergence"]),
        pressure_tolerance = d["pressure_tolerance"],
        steps_max = Int(d["steps_max"]),
        failure_action = Symbol(d["failure_action"]),
        restart_packing = d["restart_packing"] isa String &&
                          d["restart_packing"] != "nothing" ? d["restart_packing"] : nothing,
        restart_file = restart_file_from_dict(d["restart_file"]),
        algorithm = algorithm_from_dict(d["algorithm"]),
        timestep = timestep_from_dict(d["timestep"]),
        rattlers = rattlers_from_dict(d["rattlers"]),
        seed = Int(d["seed"]),
        snapshots = snapshots_from_dict(d["snapshots"]),
        movie = movie_from_dict(d["movie"]))
end

function settings_toml(p::PackParams)
    d = setting_dict(p)
    d["contact"]["law"] = p.contact isa Hookean ? "Hookean" : "Hertzian"
    d["convergence"] = convergence_dict(p.convergence)
    d["rattlers"] = rattlers_dict(p.rattlers)
    io = IOBuffer()
    TOML.print(io, d)
    return String(take!(io))
end

function convergence_dict(test)
    test isa RelativeForce && return Dict("tolerance" => test.tolerance)
    test isa LeidenAcceleration && return Dict("tolerance" => test.tolerance,
                                               "accelerations" => true)
    test isa KineticEnergy && return Dict("tolerance" => test.tolerance, "energy" => true)
    test isa RestartTest && return Dict("restart" => true)
    return "nothing"
end

function rattlers_dict(rule)
    rule === nothing && return "nothing"
    rule isa ContactCount && return Dict("cone_test" => rule.cone_test)
    rule isa TwoContact && return Dict("two" => true)
    rule isa ForceFloor && return Dict("cone_test" => rule.cone_test, "floor" => rule.floor)
    rule isa Unresolved && return Dict("cone_test" => rule.cone_test,
                                       "floor" => rule.floor === :tolerance ?
                                                 "tolerance" : rule.floor)
    # A user function cannot be serialized; say so on restart instead of silently
    # dropping it and returning a packing with a different rattler treatment.
    return "custom"
end

# --- Writing -----------------------------------------------------------------

"""
    _put!(file, name, data, level)

Write one dataset, gzip-compressed at `level` when it is not `nothing` (design §11:
compression only with gzip/deflate, the filter every HDF5 installation has).
"""
function _put!(f, name::AbstractString, data, level)
    if level === nothing
        f[name] = data
    else
        parts = split(name, '/')
        group = f
        for part in parts[1:end-1]
            group = haskey(group, part) ? group[part] : create_group(group, part)
        end
        if isempty(data)
            group[parts[end]] = data
        else
            HDF5.write_dataset(group, parts[end], data; deflate = level,
                               chunk = size(data))
        end
    end
    return nothing
end

"""
    write_state(path, system, control, results)

Write the full run state to `path` in the restart format, atomically: a temporary file in
the same directory is renamed over `path` (design §6, "Safe writes"). With
`snapshots = false` the collected snapshot frames are not written; mid-run restart files
use that, since snapshots are output (§11) rather than run state.
"""
function write_state(path::AbstractString, s::System{D,NR}, control::RunControl{D},
                     results::RunResults; compression = nothing,
                     snapshots::Bool = true) where {D,NR}
    level = compression === nothing ? nothing :
        (compression isa Tuple ? Int(compression[2]) : 4)
    directory = dirname(abspath(path))
    isdir(directory) || mkpath(directory)
    temporary, io = mktemp(directory; cleanup = false)
    close(io)
    try
        h5open(temporary, "w") do f
            attributes(f)["format"] = "softpack-1"
            attributes(f)["softpack_version"] = softpack_version()
            attributes(f)["softpack_commit"] = softpack_commit()
            attributes(f)["julia_version"] = string(VERSION)
            attributes(f)["seed"] = control.params.seed
            attributes(f)["rng"] = "StableRNGs.LehmerRNG"
            attributes(f)["rng_version"] = rng_version()
            attributes(f)["dimension"] = D
            attributes(f)["settings"] = settings_toml(control.params)
            attributes(f)["converged"] = results.converged
            attributes(f)["stop_reason"] = string(results.stop_reason)
            attributes(f)["step"] = control.step
            attributes(f)["box_side"] = s.side
            attributes(f)["pressure"] = results.pressure
            attributes(f)["packing_fraction"] = results.packing_fraction
            attributes(f)["contact_number"] = results.contact_number
            attributes(f)["force_residual"] = results.force_residual
            attributes(f)["diameter_reference"] = results.diameter_reference
            attributes(f)["diameter_mean"] = results.diameter_mean
            attributes(f)["mass_reference"] = results.mass_reference
            attributes(f)["time_step"] = results.time_step
            _put!(f, "state/particles/diameter", s.diameters, level)
            _put!(f, "state/particles/mass", s.masses, level)
            _put!(f, "state/particles/moment", s.moments, level)
            _put!(f, "state/positions", positions_matrix(s.positions), level)
            _put!(f, "state/velocities", positions_matrix(s.velocities), level)
            _put!(f, "state/rotations", positions_matrix(s.rotations), level)
            _put!(f, "state/spins", positions_matrix(s.spins), level)
            _put!(f, "state/accelerations", positions_matrix(s.accelerations), level)
            _put!(f, "state/angular_accelerations", positions_matrix(s.angular_accelerations), level)
            table = s.table
            _put!(f, "state/contacts/first", collect(Int64.(table.first)), level)
            _put!(f, "state/contacts/second", collect(Int64.(table.second)), level)
            _put!(f, "state/contacts/wall_id", collect(Int64.(table.wall_id)), level)
            _put!(f, "state/contacts/sliding", collect(UInt8.(table.sliding)), level)
            _put!(f, "state/contacts/tangential",
                  isempty(table.tangential_forces) ? zeros(D, 0) :
                  positions_matrix(table.tangential_forces), level)
            if size(s.wall_tangential, 1) > 0
                walls, count = size(s.wall_tangential)
                tangential = Array{Float64}(undef, D, walls, count)
                for w in 1:walls, i in 1:count, a in 1:D
                    tangential[a, w, i] = s.wall_tangential[w, i][a]
                end
                _put!(f, "state/walls/tangential", tangential, level)
                _put!(f, "state/walls/sliding", collect(UInt8.(s.wall_sliding)), level)
            end
            compression = control.compression
            attributes(f)["compression_accepted_side"] = compression.accepted_side
            attributes(f)["compression_strain"] = compression.strain
            attributes(f)["compression_accepted"] = compression.accepted
            attributes(f)["compression_rejected"] = compression.rejected
            attributes(f)["compression_drag_on"] = compression.drag_on
            attributes(f)["compression_mid_trial"] = compression.mid_trial
            fire_state = compression.fire_state
            attributes(f)["fire_present"] = fire_state !== nothing
            attributes(f)["fire_timestep"] = fire_state === nothing ? 0.0 :
                                             fire_state.timestep
            attributes(f)["fire_mixing"] = fire_state === nothing ? 0.0 : fire_state.mixing
            attributes(f)["fire_downhill"] = fire_state === nothing ? 0 :
                                             fire_state.downhill_count
            attributes(f)["fire_uphill"] = fire_state === nothing ? 0 :
                                           fire_state.uphill_count
            f["state/compression/accepted_positions"] =
                positions_matrix(compression.accepted_positions)
            if snapshots && !isempty(control.snapshot_frames)
                frames = Array{Float64}(undef, D, size(control.snapshot_frames[1], 2),
                                        length(control.snapshot_frames))
                for (k, frame) in enumerate(control.snapshot_frames)
                    frames[:, :, k] = frame
                end
                _put!(f, "snapshots/positions", frames, level)
                attributes(f["snapshots/positions"])["array_order"] = "column-major"
            end
        end
        mv(temporary, path; force = true)
    catch
        rm(temporary; force = true)
        rethrow()
    end
    return nothing
end

# --- Reading -----------------------------------------------------------------

"""
    read_state(path) -> (params, system, control, results, provenance)

Read a restart file written by `write_state` or `write_packing`.
"""
function read_state(path::AbstractString)
    h5open(path, "r") do f
        attrs = Dict(name => read(attributes(f)[name])
                     for name in keys(attributes(f)))
        params = params_from_dict(TOML.parse(attrs["settings"]))
        D = Int(attrs["dimension"])
        NR = rotation_count(D)
        diameters = read(f["state/particles/diameter"])
        masses = read(f["state/particles/mass"])
        moments = read(f["state/particles/moment"])
        positions_matrix_read = read(f["state/positions"])
        velocity_matrix_read = read(f["state/velocities"])
        rotation_matrix_read = read(f["state/rotations"])
        spin_matrix_read = read(f["state/spins"])
        acceleration_matrix_read = read(f["state/accelerations"])
        angular_matrix_read = read(f["state/angular_accelerations"])
        count = size(positions_matrix_read, 2)
        columns(matrix) = [SVector{size(matrix, 1),Float64}(matrix[:, i]) for i in 1:count]
        positions = columns(positions_matrix_read)
        side = attrs["box_side"]
        system = System(positions, diameters, masses, side, params.contact, params.friction,
                        params.boundary; moments = moments)
        copyto!(system.velocities, columns(velocity_matrix_read))
        copyto!(system.rotations, columns(rotation_matrix_read))
        copyto!(system.spins, columns(spin_matrix_read))
        copyto!(system.accelerations, columns(acceleration_matrix_read))
        copyto!(system.angular_accelerations, columns(angular_matrix_read))
        first = read(f["state/contacts/first"])
        second = read(f["state/contacts/second"])
        sliding = Bool.(read(f["state/contacts/sliding"]))
        tangential = read(f["state/contacts/tangential"])
        build!(system.neighbors, system.positions, system.diameters, side,
               params.boundary isa Periodic)
        lookup = Dict((system.neighbors.first[p], system.neighbors.second[p]) => p
                      for p in eachindex(system.neighbors.first))
        for k in eachindex(first)
            pair = (Int(first[k]), Int(second[k]))
            p = get(lookup, pair, 0)
            p == 0 && continue
            system.neighbors.tangential[p] =
                SVector{D,Float64}(ntuple(a -> tangential[a, k], Val(D)))
            system.neighbors.sliding[p] = sliding[k]
        end
        if size(system.wall_tangential, 1) > 0
            wall = read(f["state/walls/tangential"])
            for w in axes(system.wall_tangential, 1), i in axes(system.wall_tangential, 2)
                system.wall_tangential[w, i] =
                    SVector{D,Float64}(ntuple(a -> wall[a, w, i], Val(D)))
            end
            system.wall_sliding .= Bool.(read(f["state/walls/sliding"]))
        end
        copyto!(system.last_positions, system.positions)
        copyto!(system.last_rotations, system.rotations)
        control = RunControl(positions, side, params; step = Int(attrs["step"]),
                             timestep = attrs["time_step"])
        control.compression.accepted_side = attrs["compression_accepted_side"]
        control.compression.strain = attrs["compression_strain"]
        control.compression.accepted = Int(attrs["compression_accepted"])
        control.compression.rejected = Int(attrs["compression_rejected"])
        control.compression.drag_on = attrs["compression_drag_on"]
        control.compression.mid_trial = attrs["compression_mid_trial"]
        accepted = read(f["state/compression/accepted_positions"])
        control.compression.accepted_positions =
            [SVector{D,Float64}(accepted[:, i]) for i in 1:size(accepted, 2)]
        if attrs["fire_present"]
            start = attrs["time_step"]
            fire = params.algorithm isa FIRE ? params.algorithm : FIRE()
            control.compression.fire_state = FireState(attrs["fire_timestep"],
                fire.timestep_max * start, fire.timestep_min * start,
                attrs["fire_mixing"], Int(attrs["fire_downhill"]),
                Int(attrs["fire_uphill"]))
        end
        results = RunResults(attrs["pressure"], attrs["packing_fraction"],
                             attrs["contact_number"], attrs["force_residual"],
                             attrs["converged"], Symbol(attrs["stop_reason"]),
                             attrs["diameter_reference"], attrs["diameter_mean"],
                             attrs["mass_reference"], attrs["time_step"])
        provenance = (softpack_version = attrs["softpack_version"],
                      softpack_commit = attrs["softpack_commit"],
                      julia_version = attrs["julia_version"], seed = Int(attrs["seed"]))
        return params, system, control, results, provenance
    end
end


"""
    rng_version()

The version of StableRNGs that drew the run; recorded so a packing file says which
generator produced it (card T-jc2b).
"""
rng_version() = string(Base.pkgversion(StableRNGs))
# function_rng_version_marker
