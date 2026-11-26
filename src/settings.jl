# ---------------------------------------------------------------------------
#  Settings types (design §0 and §1). Every setting with sub-settings is a small
#  type, so algorithms, laws and rules are swapped by dispatch. Defaults are the
#  design's defaults; the section that gives the reason is named on each type.
# ---------------------------------------------------------------------------

# --- Particle sizes (§3) ----------------------------------------------------

abstract type SizeDistribution end

"""
    Bidisperse(; diameter_small = 1.0, diameter_ratio = 1.4, fraction_small = 0.5)

Two diameters, `diameter_small` and `diameter_ratio * diameter_small`, with
`fraction_small` the number fraction of small particles (design §3). The small diameter
is the reference diameter (the length unit).
"""
Base.@kwdef struct Bidisperse <: SizeDistribution
    diameter_small::Float64 = 1.0
    diameter_ratio::Float64 = 1.4
    fraction_small::Float64 = 0.5
end

"""
    UniformPolydisperse(; diameter_mean = 1.0, spread = 0.2)

Diameters uniform between `diameter_mean * (1 - spread)` and
`diameter_mean * (1 + spread)` (design §3). The mean diameter is the reference diameter.
"""
Base.@kwdef struct UniformPolydisperse <: SizeDistribution
    diameter_mean::Float64 = 1.0
    spread::Float64 = 0.2
end

"""
    Monodisperse(; diameter = 1.0)

One diameter for every particle (design §3).
"""
Base.@kwdef struct Monodisperse <: SizeDistribution
    diameter::Float64 = 1.0
end

# --- Contacts (§2) ----------------------------------------------------------

abstract type ContactLaw end

"""
    Hookean(; stiffness = 1.0)

Harmonic repulsion: with overlap `delta > 0` the energy is `stiffness * delta^2 / 2` and
the normal force `stiffness * delta` (design §2). One stiffness for every pair.
"""
Base.@kwdef struct Hookean <: ContactLaw
    stiffness::Float64 = 1.0
end

# --- Mass (§4) --------------------------------------------------------------

abstract type MassRule end

"""
    EqualMass(mass = 1.0)

Every particle has the same mass (design §4).
"""
struct EqualMass <: MassRule
    mass::Float64
end
EqualMass() = EqualMass(1.0)

# --- Target, box, start and protocol (§2) -----------------------------------

abstract type Target end

"""
    Pressure(value = 1e-4)

Compress until the elastic contact (virial) pressure is `value` (design §2), in units of
the stiffness (2D) or stiffness per length (3D).
"""
struct Pressure <: Target
    value::Float64
end
Pressure() = Pressure(1e-4)

abstract type Boundary end

"""
    Periodic()

A periodic square (2D) or cube (3D) box (design §2).
"""
struct Periodic <: Boundary end

abstract type InitialState end

"""
    Dilute(; packing_fraction = 0.25)

Random sequential addition of non-touching particles at rest, largest first, at
`packing_fraction` (design §2).
"""
Base.@kwdef struct Dilute <: InitialState
    packing_fraction::Float64 = 0.25
end

abstract type Protocol end

"""
    IsotropicCompression(; strain_step = 1e-2)

Shrink every side of the box by the factor `1 - strain_step`, minimize, read the pressure;
accept below the pressure band, halve the step and retry above it (design §2).
"""
Base.@kwdef struct IsotropicCompression <: Protocol
    strain_step::Float64 = 1e-2
end

# --- Convergence (§5) -------------------------------------------------------

abstract type ConvergenceTest end

"""
    RelativeForce(; tolerance = 1e-8)

A minimization has converged when every particle's net elastic force is below
`tolerance` times the mean normal contact force (design §5). The default 1e-8 is
provisional until it has been timed on frictional packings (card T-2brz, option 1).
"""
Base.@kwdef struct RelativeForce <: ConvergenceTest
    tolerance::Float64 = 1e-8   # PROVISIONAL T-2brz: kept, frictional timing is a release gate
end

# --- Algorithm (§7, §14) ----------------------------------------------------

abstract type Algorithm end

"""
    FIRE(; timestep_max = 10, timestep_min = 0.02, delay = 20, timestep_grow = 1.1,
           timestep_shrink = 0.5, mixing_coefficient = 0.25, mixing_shrink = 0.99,
           uphill_max = 2000, inertia_correction = true, delay_initial = true,
           integrator = :semi_implicit_euler, damping = nothing, drag = nothing)

FIRE 2.0 with the LAMMPS `min_style fire` defaults (design §14). `timestep_max` and
`timestep_min` are multiples of the starting step. The step rules follow Algorithm 2 of
the wiki's FIRE settings page, which matches LAMMPS `min_fire.cpp` (card T-vcne,
option 1).
"""
Base.@kwdef struct FIRE <: Algorithm
    timestep_max::Float64 = 10.0
    timestep_min::Float64 = 0.02
    delay::Int = 20
    timestep_grow::Float64 = 1.1
    timestep_shrink::Float64 = 0.5
    mixing_coefficient::Float64 = 0.25
    mixing_shrink::Float64 = 0.99
    uphill_max::Int = 2000
    inertia_correction::Bool = true
    delay_initial::Bool = true
    integrator::Symbol = :semi_implicit_euler
    damping::Any = nothing
    drag::Any = nothing
end

# --- Time step (§12) --------------------------------------------------------

abstract type TimestepRule end

"""
    CollisionTime(; fraction = 1/50)

The starting step is `fraction` of the shortest binary collision time
`pi * sqrt(m_eff / k)`, with `m_eff` the reduced mass of the lightest pair (design §12;
card T-d66w, option 1).
"""
Base.@kwdef struct CollisionTime <: TimestepRule
    fraction::Float64 = 1 / 50
end

# --- Rattlers (§9) ----------------------------------------------------------

abstract type RattlerRule end

"""
    ContactCount(; cone_test = true)

Repeatedly remove particles with fewer than `D + 1` contacts when frictionless (`D` the
dimension) or fewer than 2 when frictional, until no particle changes (design §9; card
T-hg7w, option 1). The cone test only acts on frictional two-contact particles, so it
changes nothing in a frictionless packing.
"""
Base.@kwdef struct ContactCount <: RattlerRule
    cone_test::Bool = true
end

# --- All settings ------------------------------------------------------------

"""
    PackParams(; kwargs...)

Every setting of `pack()`, with the design's defaults (design §0). `pack(params)` runs it;
`pack(; kwargs...)` builds one from keywords. Keywords that the design lists but this
build does not implement yet are accepted here and rejected by `pack()` with an error
that names them.
"""
Base.@kwdef struct PackParams
    dimension::Int = 2
    particles_count::Int = 256
    particles_size_distribution::SizeDistribution = Bidisperse()
    particles_diameters::Union{Nothing,Vector{Float64}} = nothing
    contact::Any = Hookean()
    friction::Any = nothing
    mass::Any = EqualMass(1.0)
    target::Any = Pressure(1e-4)
    boundary::Any = Periodic()
    initial_state::Any = Dilute()
    protocol::Any = IsotropicCompression()
    convergence::Any = RelativeForce()
    pressure_tolerance::Float64 = 1e-4
    steps_max::Int = 10^7
    failure_action::Symbol = :warn
    restart_packing::Any = nothing
    restart_file::Any = nothing
    algorithm::Any = FIRE()
    timestep::Any = CollisionTime()
    rattlers::Any = ContactCount()
    seed::Int = 1
    snapshots::Any = nothing
    movie::Any = nothing
end

function not_implemented(setting::AbstractString, value)
    throw(ArgumentError(
        "$setting = $(repr(value)) is designed but not implemented yet. This build " *
        "implements the frictionless default path: Hookean contacts, EqualMass, " *
        "Pressure target, Periodic box, Dilute start, IsotropicCompression, " *
        "RelativeForce, FIRE with the semi-implicit Euler integrator and no damping or " *
        "drag, ContactCount or `nothing` or a function for the rattlers."))
end

"""
    validate(params) -> params

Check that every setting is one this build implements and that the numbers make sense.
"""
function validate(p::PackParams)
    p.dimension in (2, 3) ||
        throw(ArgumentError("dimension must be 2 or 3, got $(p.dimension)"))
    if p.particles_diameters === nothing
        p.particles_count >= 2 ||
            throw(ArgumentError("particles_count must be at least 2, got $(p.particles_count)"))
    else
        length(p.particles_diameters) >= 2 ||
            throw(ArgumentError("particles_diameters needs at least 2 diameters"))
        all(>(0), p.particles_diameters) ||
            throw(ArgumentError("every diameter in particles_diameters must be positive"))
    end
    validate_distribution(p.particles_size_distribution)
    p.contact isa Hookean || not_implemented("contact", p.contact)
    p.contact.stiffness > 0 || throw(ArgumentError("stiffness must be positive"))
    p.friction === nothing || not_implemented("friction", p.friction)
    p.mass isa EqualMass || not_implemented("mass", p.mass)
    p.mass.mass > 0 || throw(ArgumentError("EqualMass needs a positive mass"))
    p.target isa Pressure || not_implemented("target", p.target)
    p.target.value > 0 || throw(ArgumentError("the target pressure must be positive"))
    p.boundary isa Periodic || not_implemented("boundary", p.boundary)
    p.initial_state isa Dilute || not_implemented("initial_state", p.initial_state)
    0 < p.initial_state.packing_fraction < 1 ||
        throw(ArgumentError("Dilute packing_fraction must lie between 0 and 1"))
    p.protocol isa IsotropicCompression || not_implemented("protocol", p.protocol)
    0 < p.protocol.strain_step < 1 ||
        throw(ArgumentError("strain_step must lie between 0 and 1"))
    p.convergence isa RelativeForce || not_implemented("convergence", p.convergence)
    p.convergence.tolerance > 0 || throw(ArgumentError("tolerance must be positive"))
    p.pressure_tolerance > 0 || throw(ArgumentError("pressure_tolerance must be positive"))
    p.steps_max >= 1 || throw(ArgumentError("steps_max must be at least 1"))
    p.failure_action in (:warn, :error) ||
        throw(ArgumentError("failure_action must be :warn or :error"))
    p.restart_packing === nothing || not_implemented("restart_packing", p.restart_packing)
    p.restart_file === nothing || not_implemented("restart_file", p.restart_file)
    p.algorithm isa FIRE || not_implemented("algorithm", p.algorithm)
    p.algorithm.integrator === :semi_implicit_euler ||
        not_implemented("FIRE integrator", p.algorithm.integrator)
    p.algorithm.damping === nothing || not_implemented("FIRE damping", p.algorithm.damping)
    p.algorithm.drag === nothing || not_implemented("FIRE drag", p.algorithm.drag)
    p.timestep isa CollisionTime || p.timestep isa Real ||
        throw(ArgumentError("timestep must be CollisionTime(...) or a number"))
    (p.timestep isa CollisionTime ? p.timestep.fraction : p.timestep) > 0 ||
        throw(ArgumentError("the time step must be positive"))
    p.rattlers === nothing || p.rattlers isa ContactCount || p.rattlers isa Function ||
        not_implemented("rattlers", p.rattlers)
    p.snapshots === nothing || not_implemented("snapshots", p.snapshots)
    p.movie === nothing || not_implemented("movie", p.movie)
    return p
end

function validate_distribution(d::Bidisperse)
    d.diameter_small > 0 || throw(ArgumentError("diameter_small must be positive"))
    d.diameter_ratio > 0 || throw(ArgumentError("diameter_ratio must be positive"))
    0 <= d.fraction_small <= 1 || throw(ArgumentError("fraction_small must lie in [0, 1]"))
    return d
end
function validate_distribution(d::UniformPolydisperse)
    d.diameter_mean > 0 || throw(ArgumentError("diameter_mean must be positive"))
    0 <= d.spread < 1 || throw(ArgumentError("spread must lie in [0, 1)"))
    return d
end
function validate_distribution(d::Monodisperse)
    d.diameter > 0 || throw(ArgumentError("diameter must be positive"))
    return d
end
