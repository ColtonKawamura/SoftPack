# ---------------------------------------------------------------------------
#  What pack() returns (design §11). It carries the analysis data, the results
#  and the full run state (system and control) that write_packing and a restart
#  need.
# ---------------------------------------------------------------------------

"""
    Packing{D}

The result of `pack()`.

Per particle (index = particle id): `positions` (`D` x `N`, inside `[0, box_side)`),
`diameters`, `masses`, `forces` and `torques` (net elastic), `rattlers`.

Contacts: `contacts`, the contact table of the final state (see `ContactTable`).

Results: `box_side`, `pressure` (elastic virial pressure), `packing_fraction` (all
particles), `contact_number` (mean contacts per particle after rattler removal, counting
only contacts between remaining particles), `force_residual` (`max_i |F_i| / <f_n>`).

Run: `converged`, `stop_reason` (`:converged`, `:steps_max`, `:uphill_max` or
`:strain_step_min`), `steps`, `compression_steps_accepted`, `compression_steps_rejected`,
`strain_step_final`, `timestep_start`, `runtime_seconds`.

Scales and provenance: `diameter_reference`, `diameter_mean`, `mass_reference`,
`settings` (the `PackParams` of the run), `seed`, `random_number_generator`,
`softpack_version`, `softpack_commit`, `julia_version`.

The full dynamic state (velocities, spins, accelerations, the contact history and the
compression state) lives in `system` and `control`; `write_packing` and a restart read
them.
"""
struct Packing{D,NR,S,C}
    positions::Matrix{Float64}
    diameters::Vector{Float64}
    masses::Vector{Float64}
    forces::Matrix{Float64}
    torques::Matrix{Float64}
    rattlers::BitVector
    contacts::ContactTable{D}
    box_side::Float64
    pressure::Float64
    packing_fraction::Float64
    contact_number::Float64
    force_residual::Float64
    converged::Bool
    stop_reason::Symbol
    steps::Int
    compression_steps_accepted::Int
    compression_steps_rejected::Int
    strain_step_final::Float64
    timestep_start::Float64
    runtime_seconds::Float64
    diameter_reference::Float64
    diameter_mean::Float64
    mass_reference::Float64
    settings::PackParams
    seed::Int
    random_number_generator::String
    softpack_version::String
    softpack_commit::String
    julia_version::String
    system::S
    control::C
end

Base.ndims(::Packing{D}) where {D} = D
rotation_ndims(::Packing{D,NR}) where {D,NR} = NR

"""
    results(packing) -> RunResults

The scalar results of a packing, in the form the writers use.
"""
results(p::Packing) = RunResults(p.pressure, p.packing_fraction, p.contact_number,
    p.force_residual, p.converged, p.stop_reason, p.diameter_reference, p.diameter_mean,
    p.mass_reference, p.timestep_start)

"""
    contact_pressure(packing) -> Float64

The pressure measured at the end of the run: the virial of the final contact table.
"""
contact_pressure(p::Packing{D}) where {D} = contact_pressure(p.contacts, p.box_side, D)

"""
    mean_normal_force(packing) -> Float64

The mean normal force over the contacts of the final state.
"""
mean_normal_force(p::Packing) = mean_normal_force(p.contacts)

"""
    is_converged(packing) -> Bool

Whether the run met its convergence test; the same value as `packing.converged`.
"""
is_converged(p::Packing) = p.converged

"""
    run_state(packing) -> RunState

A `RunState` of the final state, the view a user convergence or rattler function gets.
"""
run_state(p::Packing) = run_state(p.system, p.pressure, p.steps, p.settings)

function Base.show(io::IO, p::Packing{D}) where {D}
    print(io, "Packing{$D}(", length(p.diameters), " particles, P = ",
          @sprintf("%.4g", p.pressure), ", converged = ", p.converged, ")")
end

function Base.show(io::IO, ::MIME"text/plain", p::Packing{D}) where {D}
    count = length(p.diameters)
    remaining = count - sum(p.rattlers)
    println(io, "Packing{$D}: ", count, " particles (", count - remaining,
            " rattlers removed)")
    println(io, "  converged        ", p.converged, p.converged ? "" : " ($(p.stop_reason))")
    println(io, "  pressure         ", @sprintf("%.6g", p.pressure),
            " (target ", p.settings.target.value, ")")
    println(io, "  packing fraction ", @sprintf("%.4f", p.packing_fraction))
    println(io, "  contact number   ", @sprintf("%.4f", p.contact_number),
            " (", length(p.contacts), " contacts)")
    println(io, "  force residual   ", @sprintf("%.2e", p.force_residual),
            " (max |F_i| / <f_n>)")
    println(io, "  box side         ", @sprintf("%.6g", p.box_side))
    print(io, "  steps            ", p.steps, " steps, ",
          p.compression_steps_accepted, " accepted + ", p.compression_steps_rejected,
          " rejected compression steps, ", @sprintf("%.2f", p.runtime_seconds), " s")
end
