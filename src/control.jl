# ---------------------------------------------------------------------------
#  Run control: the compression state a restart needs (design §2, §6), the
#  absolute step counter, and the recording schedules for restart files,
#  snapshots and the movie (design §6, §11).
# ---------------------------------------------------------------------------

"""
    CompressionState{D}

What the compression protocol must remember between trials (design §2): the accepted
positions and side, the strain step, the counts of accepted and rejected steps, whether
drag is on, and FIRE's state when a restart lands in the middle of a trial.
"""
mutable struct CompressionState{D}
    accepted_positions::Vector{SVector{D,Float64}}
    accepted_side::Float64
    strain::Float64
    accepted::Int
    rejected::Int
    drag_on::Bool
    fire_state::Union{Nothing,Any}
    mid_trial::Bool
end

CompressionState(positions::Vector{SVector{D,Float64}}, side::Float64,
                 strain::Float64) where {D} =
    CompressionState{D}(copy(positions), side, strain, 0, 0, false, nothing, false)

"""
    Schedule

One recording schedule: an interval of steps or wall-clock time, and the step and clock
time of the next recording.
"""
mutable struct Schedule
    every::Interval
    next_step::Int
    next_time::Float64
    started::Float64
end

Schedule(every::Integer, started::Float64, step::Int = 0) =
    Schedule(every, step + Int(every), Inf, started)
Schedule(every::Period, started::Float64, step::Int = 0) =
    Schedule(every, typemax(Int), started + Dates.Millisecond(every).value / 1000, started)

"""
    due!(schedule, step) -> Bool

True when a recording is due at this step (or, for a wall-clock interval, now).
"""
function due!(schedule::Schedule, step::Int)
    if schedule.every isa Integer
        return step >= schedule.next_step
    end
    return time() >= schedule.next_time
end

"""
    advance!(schedule, step)

Move the schedule to its next recording.
"""
function advance!(schedule::Schedule, step::Int)
    if schedule.every isa Integer
        schedule.next_step = step + Int(schedule.every)
    else
        schedule.next_time = time() + Dates.Millisecond(schedule.every).value / 1000
    end
    return schedule
end

"""
    RunControl{D}

Everything a step needs besides the `System`: the settings, the compression state, the
absolute step count against `steps_max`, and the recording schedules with their collected
frames.
"""
mutable struct RunControl{D}
    params::PackParams
    compression::CompressionState{D}
    step::Int
    step_at_start::Int
    steps_max::Int
    time_step::Float64
    restart_schedule::Union{Nothing,Schedule}
    snapshot_schedule::Union{Nothing,Schedule}
    movie_schedule::Union{Nothing,Schedule}
    snapshot_frames::Vector{Matrix{Float64}}
    movie_directory::Union{Nothing,String}
    movie_frame::Int
    movie_size::Int
    movie_fps::Int
    movie_path::String
    movie_command_ok::Bool
    warnings::Vector{String}
end

function RunControl(positions::Vector{SVector{D,Float64}}, side::Float64,
                    params::PackParams; step::Int = 0,
                    timestep::Float64 = 0.0) where {D}
    started = time()
    strain = params.protocol isa IsotropicCompression ? params.protocol.strain_step : 0.0
    restart_schedule = params.restart_file isa RestartFile ?
        Schedule(params.restart_file.every, started, step) : nothing
    snapshot_schedule = params.snapshots isa Snapshots ?
        Schedule(params.snapshots.every, started, step) : nothing
    movie_schedule = params.movie isa Movie ? Schedule(params.movie.every, started, step) : nothing
    movie_directory = params.movie isa Movie ? mktempdir(; prefix = "softpack-movie-") : nothing
    movie_path = params.movie isa Movie ? params.movie.path : ""
    movie_size = params.movie isa Movie ? params.movie.size : 640
    movie_fps = params.movie isa Movie ? params.movie.fps : 25
    return RunControl{D}(params, CompressionState(positions, side, strain), step, step,
        params.steps_max, timestep, restart_schedule, snapshot_schedule, movie_schedule,
        Matrix{Float64}[], movie_directory, 0, movie_size, movie_fps, movie_path, true,
        String[])
end

"""
    record_step!(control, system)

Called after every step: write a restart file, take a snapshot or render a movie frame
when its schedule is due (design §6, §11). Recording never changes the trajectory.
"""
function record_step!(control::RunControl{D}, s::System{D}) where {D}
    if control.restart_schedule !== nothing && due!(control.restart_schedule, control.step)
        pressure = contact_pressure(s.table, s.side, D)
        fraction = total_volume(s.diameters, D) / s.side^D
        results = RunResults(pressure, fraction, NaN, NaN, false, :running,
                             diameter_reference(control.params.particles_size_distribution),
                             sum_in_order(d -> d, s.diameters) / length(s.diameters),
                             mass_reference(control.params.mass, s.masses),
                             control.time_step)
        # Snapshot frames are output (§11), not run state: rewriting every frame collected
        # so far into every mid-run restart file makes the I/O quadratic in the frame
        # count. The final write_state and write_packing still store them.
        write_state(control.params.restart_file.path, s, control, results; snapshots = false)
        advance!(control.restart_schedule, control.step)
    end
    if control.snapshot_schedule !== nothing && due!(control.snapshot_schedule, control.step)
        push!(control.snapshot_frames, positions_matrix(s.positions))
        advance!(control.snapshot_schedule, control.step)
    end
    if control.movie_schedule !== nothing && due!(control.movie_schedule, control.step) &&
       control.movie_directory !== nothing
        control.movie_frame += 1
        render_frame!(joinpath(control.movie_directory,
                               @sprintf("frame%06d.ppm", control.movie_frame)),
                      s, control.movie_size)
        advance!(control.movie_schedule, control.step)
    end
    return nothing
end

"""
    positions_matrix(positions) -> Matrix{Float64}

The `D x N` matrix of positions.
"""
positions_matrix(positions::Vector{SVector{D,Float64}}) where {D} = reduce(hcat, positions)

"""
    finish_movie!(control)

Encode the frames collected during the run into `control.movie_path` with ffmpeg. Without
frames or without ffmpeg it warns and leaves the frames in `control.movie_directory`.
"""
function finish_movie!(control::RunControl)
    control.movie_schedule === nothing && return nothing
    if control.movie_frame == 0
        push!(control.warnings, "movie: no frame was recorded (every = " *
              "$(control.params.movie.every) steps)")
        return nothing
    end
    path = control.movie_path
    pattern = joinpath(control.movie_directory, "frame%06d.ppm")
    codec = endswith(lowercase(path), ".gif") ?
        ["-filter_complex", "[0:v]split[a][b];[a]palettegen[p];[b][p]paletteuse"] :
        ["-pix_fmt", "yuv420p", "-vcodec", "libx264"]
    command = `ffmpeg -y -framerate $(control.movie_fps) -i $pattern $codec $path`
    result = try
        run(pipeline(command; stdout = devnull, stderr = devnull); wait = true)
        true
    catch
        false
    end
    if result
        rm(control.movie_directory; force = true, recursive = true)
    else
        push!(control.warnings, "movie: ffmpeg failed; the frames are in " *
              "$(control.movie_directory)")
    end
    return nothing
end
