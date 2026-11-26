# ---------------------------------------------------------------------------
#  pack(): the entry point (design §1, §2).
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

A run that does not converge warns and returns the packing with `converged = false`
(`failure_action = :error` throws instead).

```julia
packing = pack()
packing = pack(particles_count = 1024, target = Pressure(1e-5), seed = 7)
packing = pack(dimension = 3, particles_count = 512)
```
"""
pack(; kwargs...) = pack(PackParams(; kwargs...))

function pack(p::PackParams)
    validate(p)
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
    stiffness = p.contact.stiffness
    float64_floor_warning(p, diameters, diameter_ref)

    positions, side, _, _ = place_dilute(Val(dimension), diameters,
                                         p.initial_state.packing_fraction, rng)
    timestep = timestep_start(p.timestep, masses, stiffness, mass_ref)
    force_floor = force_floor_for(p.target.value, diameter_ref, dimension)
    system = System(positions, diameters, masses, side, p.contact)
    outcome = compress!(system, p, timestep, force_floor)

    converged = outcome.status === :converged
    table = copy(system.table)
    residual = largest_force(system.forces) / mean_normal_force(table)
    volume = total_volume(diameters, dimension)
    final_positions = [wrap(x, system.side) for x in system.positions]
    packing = Packing{dimension}(
        reduce(hcat, final_positions), diameters, masses, reduce(hcat, system.forces),
        falses(count), table, system.side,
        contact_pressure(table, system.side, dimension), volume / system.side^dimension,
        contact_number(table, falses(count)), residual, converged, outcome.status,
        outcome.steps, outcome.accepted, outcome.rejected, outcome.strain_step, timestep,
        0.0, diameter_ref, sum_in_order(diameters) / count, mass_ref, p, p.seed,
        "StableRNGs.LehmerRNG", softpack_version(), softpack_commit(), string(VERSION))
    rattlers = find_rattlers(packing, p.rattlers)
    packing = Packing{dimension}(packing.positions, diameters, masses, packing.forces,
        rattlers, table, packing.box_side, packing.pressure, packing.packing_fraction,
        contact_number(table, rattlers), residual, converged, outcome.status,
        outcome.steps, outcome.accepted, outcome.rejected, outcome.strain_step, timestep,
        time() - started, diameter_ref, packing.diameter_mean, mass_ref, p, p.seed,
        packing.random_number_generator, packing.softpack_version, packing.softpack_commit, packing.julia_version)

    if !converged
        message = "pack() did not converge ($(outcome.status)) after $(outcome.steps) " *
                  "steps: P = $(@sprintf "%.4g" packing.pressure), force residual " *
                  "$(@sprintf "%.2e" residual). The packing is returned with converged = false."
        p.failure_action === :error && error(message)
        @warn message
    end
    return packing
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
