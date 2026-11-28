# ---------------------------------------------------------------------------
#  Settings types (design §0 and §1). Every setting with sub-settings is a small
#  type, so algorithms, laws and rules are swapped by dispatch. Defaults are the
#  design's defaults; the section that gives the reason is named on each type.
# ---------------------------------------------------------------------------

using Dates: Period

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

"""
    Hertzian(; stiffness = 1.0)

Hertzian repulsion: with overlap `delta > 0` the energy is `(2/5) stiffness * delta^(5/2)`
and the normal force `stiffness * delta^(3/2)` (design §2: O'Hern's alpha = 5/2 with one
stiffness for every pair).
"""
Base.@kwdef struct Hertzian <: ContactLaw
    stiffness::Float64 = 1.0
end

# --- Friction (§13) ---------------------------------------------------------

abstract type FrictionModel end

"""
    CundallStrack(; friction_coefficient = 0.5, stiffness_ratio = :matched)

A linear tangential spring with Coulomb slip (design §13). `stiffness_ratio` is the
tangential over the normal stiffness: `:matched` gives 1/3 in 2D and 2/7 in 3D, which makes
the tangential contact vibration as fast as the normal one; give a number instead for a
fixed ratio. With `Hertzian` contacts the ratio multiplies the current normal stiffness.
"""
Base.@kwdef struct CundallStrack <: FrictionModel
    friction_coefficient::Float64 = 0.5
    stiffness_ratio::Union{Symbol,Float64} = :matched
end

"""
    Mindlin(; friction_coefficient = 0.5, poisson_ratio = 0.0)

The Hertz-Mindlin tangential force, whose stiffness grows with the overlap (design §13):
`k_t = eta * k_n` with `eta = 2 (1 - nu) / (2 - nu)` and `nu` the `poisson_ratio`. Needs
`Hertzian` contacts.
"""
Base.@kwdef struct Mindlin <: FrictionModel
    friction_coefficient::Float64 = 0.5
    poisson_ratio::Float64 = 0.0
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
EqualMass(; mass::Float64 = 1.0) = EqualMass(mass)

"""
    Density(density = 1.0)

Mass from a material density times the particle's area (a disk, 2D) or volume (a sphere,
3D) (design §4).
"""
struct Density <: MassRule
    density::Float64
end
Density(; density::Float64 = 1.0) = Density(density)

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

"""
    Walls(; friction = true)

A flat, rigid wall on every side of the box (design §2), using the particle `contact` law
and stiffness. With `friction = true` and a `friction` model set, a wall contact carries
the same model and its own tangential spring; `friction = false` keeps wall contacts
normal-only. Without a friction model the walls are frictionless either way.
"""
Base.@kwdef struct Walls <: Boundary
    friction::Bool = true
end

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
accept below the pressure band, halve the step and retry above it (design §2). With
`Walls` the walls move with the box.
"""
Base.@kwdef struct IsotropicCompression <: Protocol
    strain_step::Float64 = 1e-2
end

# --- Convergence (§5) -------------------------------------------------------

abstract type ConvergenceTest end

"""
    RelativeForce(; tolerance = 1e-8)

A minimization has converged when every particle's net elastic force is below
`tolerance` times the mean normal contact force, and with friction every net torque below
`tolerance` times the mean force times the mean diameter (design §5). The default 1e-8 is
provisional until it has been timed on frictional packings (card T-2brz).
"""
Base.@kwdef struct RelativeForce <: ConvergenceTest
    tolerance::Float64 = 1e-8   # PROVISIONAL T-2brz: kept, frictional timing is a release gate
end

"""
    LeidenAcceleration(; tolerance = 1e-10)

The Leiden rule: every particle's acceleration below `tolerance`, in reduced units
(design §5). It replaces the `RelativeForce` test; the pressure band still applies.
"""
Base.@kwdef struct LeidenAcceleration <: ConvergenceTest
    tolerance::Float64 = 1e-10
end

"""
    KineticEnergy(; tolerance = 1e-8)

The `RelativeForce` test at its default tolerance and a mean kinetic energy per particle
below `tolerance * P_target * d_ref^D` (design §5).
"""
Base.@kwdef struct KineticEnergy <: ConvergenceTest
    tolerance::Float64 = 1e-8
end

"""
    RestartTest()

The `RelativeForce` test at its default tolerance, then once on the final packing zero the
velocities and check that the kinetic energy and the unbalanced forces do not grow back
(design §5). It is the check for saddles.
"""
struct RestartTest <: ConvergenceTest end

# --- Algorithms (§7, §8, §14) -----------------------------------------------

abstract type Algorithm end

"""
    FIRE(; timestep_max = 10, timestep_min = 0.02, delay = 20, timestep_grow = 1.1,
           timestep_shrink = 0.5, mixing_coefficient = 0.25, mixing_shrink = 0.99,
           uphill_max = 2000, inertia_correction = true, delay_initial = true,
           integrator = :semi_implicit_euler, damping = nothing, drag = nothing)

FIRE 2.0 with the LAMMPS `min_style fire` defaults (design §14). `timestep_max` and
`timestep_min` are multiples of the starting step. The step rules follow Algorithm 2 of
the wiki's FIRE settings page, which matches LAMMPS `min_fire.cpp` (card T-vcne,
option 1). With friction FIRE also integrates the spins; the design allows the
combination and records it as non-standard (§7). `damping` and `drag` are accepted but off
by default, since FIRE's own velocity rules remove energy.
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

"""
    DampedDynamics(; integrator = :centered_velocity_verlet,
                     damping = ContactDamping(), drag = nothing)

Damped molecular dynamics (design §8). The `integrator` is `:centered_velocity_verlet`
(default), `:lagged_velocity_verlet` or `:semi_implicit_euler`; they differ in which
velocity the dashpot uses. `damping` is `ContactDamping`, `ViscousRate`,
`RelativeVelocityDamping` or `nothing`; `drag` is `StokesDrag(...)` or `nothing`.
"""
Base.@kwdef struct DampedDynamics <: Algorithm
    integrator::Symbol = :centered_velocity_verlet
    damping::Any = ContactDamping()
    drag::Any = nothing
end

# --- Damping (§8) -----------------------------------------------------------

abstract type DampingModel end

"""
    ContactDamping(; normal = 0.98, tangential = 0.98, tangential_mass = :with_rotation,
                     attractive = false, coulomb_limit = :elastic)

Contact dashpots, each a `normal` or `tangential` fraction of its own critical value
(design §8). `tangential_mass = :with_rotation` measures the tangential critical value on
the true sliding mass (the particle rotation included), `:pair` on the pair's reduced
mass. `attractive = false` never lets the normal dashpot pull. `coulomb_limit = :elastic`
caps the friction at the elastic normal force.
"""
Base.@kwdef struct ContactDamping <: DampingModel
    normal::Float64 = 0.98
    tangential::Float64 = 0.98
    tangential_mass::Symbol = :with_rotation
    attractive::Bool = false
    coulomb_limit::Symbol = :elastic
end

"""
    ViscousRate(; normal = 0.5, tangential = 0.5, attractive = false,
                  coulomb_limit = :elastic)

Raw contact damping rates: dashpot force `-gamma * v` with `gamma = m_eff * rate`, in units
of `1/tau` with `tau = sqrt(m_ref / k)` (design §8). `m_eff` is the pair's reduced mass in
both directions, the LAMMPS convention.
"""
Base.@kwdef struct ViscousRate <: DampingModel
    normal::Float64 = 0.5
    tangential::Float64 = 0.5
    attractive::Bool = false
    coulomb_limit::Symbol = :elastic
end

"""
    RelativeVelocityDamping(; rate = 0.5, attractive = false, coulomb_limit = :elastic)

One dashpot on the full relative velocity of the two centers,
`F = -gamma (v_i - v_j)` with `gamma = m_eff * rate` (design §8). It applies no torque.
"""
Base.@kwdef struct RelativeVelocityDamping <: DampingModel
    rate::Float64 = 0.5
    attractive::Bool = false
    coulomb_limit::Symbol = :elastic
end

# --- Drag (§8) --------------------------------------------------------------

abstract type DragModel end

"""
    StokesDrag(; velocity, spin = velocity, during = :always)

Stokes drag on each particle: force `-velocity * m * v` and torque `-spin * I * omega`,
with the rates in units of `1/tau` (design §8). `velocity` has no default. `during` is
`:always` or `:compression` (on until the pressure first lies in the band).
"""
struct StokesDrag <: DragModel
    velocity::Float64
    spin::Float64
    during::Symbol
end
StokesDrag(; velocity, spin = velocity, during = :always) =
    StokesDrag(velocity, spin, during)

# --- Time step (§12) --------------------------------------------------------

abstract type TimestepRule end

"""
    CollisionTime(; fraction = 1/50)

The starting step is `fraction` of the shortest binary collision time
`pi * sqrt(m_eff / k)`, with `m_eff` the reduced mass of the lightest pair and `k` the
stiffest contact, tangential with rotation included when friction is on (design §12;
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
T-hg7w, option 1). With `cone_test`, a two-contact particle is also removed when no
forces inside its friction cones can hold it.
"""
Base.@kwdef struct ContactCount <: RattlerRule
    cone_test::Bool = true
end

"""
    TwoContact()

Repeatedly remove particles with two or fewer contacts (design §9). It has no
`cone_test`: a particle with two contacts is removed whether or not its cones could
hold it, so the test would never be reached.
"""
struct TwoContact <: RattlerRule end

"""
    ForceFloor(; floor = 1e-3, cone_test = true)

Contacts with force below `floor` times the mean contact force count as broken, then
particles with fewer than two contacts are removed (design §9).
"""
Base.@kwdef struct ForceFloor <: RattlerRule
    floor::Float64 = 1e-3
    cone_test::Bool = true
end

"""
    Unresolved(; floor = :tolerance, cone_test = true)

Remove particles whose contacts all carry less than the packing's force tolerance
(design §9). `floor = :tolerance` ties the floor to the packing's own stopping rule; give a
number for a fixed force.
"""
Base.@kwdef struct Unresolved <: RattlerRule
    floor::Union{Symbol,Float64} = :tolerance
    cone_test::Bool = true
end

# --- Recording (§6, §11) ----------------------------------------------------

"""
    Interval

A recording interval: a number of steps, or a `Dates.Period` of wall-clock time.
"""
const Interval = Union{Integer,Period}

"""
    Snapshots(; every)

Record the particle positions every `every` steps (or wall-clock `every`) during the run
(design §11). `write_packing` stores them.
"""
Base.@kwdef struct Snapshots
    every::Interval
end

"""
    Movie(path; every, size = 640, fps = 25)

Render a frame every `every` steps (or wall-clock `every`) during the run and encode them
into `path` with ffmpeg at the end (design §11). The image is `size` pixels wide; `.gif`
and `.mp4` are understood.
"""
Base.@kwdef struct Movie
    path::String
    every::Interval
    size::Int = 640
    fps::Int = 25
end
Movie(path::AbstractString; every, size::Int = 640, fps::Int = 25) =
    Movie(path, every, size, fps)

"""
    RestartFile(path; every)

Save the run's full state to `path` every `every` steps (or wall-clock `every`), and again
when the run stops (design §6). `restart_packing = path` continues from such a file.
"""
Base.@kwdef struct RestartFile
    path::String
    every::Interval
end
RestartFile(path::AbstractString; every) = RestartFile(path, every)

# --- All settings ------------------------------------------------------------

"""
    PackParams(; kwargs...)

Every setting of `pack()`, with the design's defaults (design §0). `pack(params)` runs it;
`pack(; kwargs...)` builds one from keywords.
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
    throw(ArgumentError("$setting = $(repr(value)) is designed but not implemented yet; " *
                        "see docs/design-references.md for the list of settings."))
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
    (p.contact isa Hookean || p.contact isa Hertzian) || not_implemented("contact", p.contact)
    p.contact.stiffness > 0 || throw(ArgumentError("stiffness must be positive"))
    validate_friction(p.friction, p.contact)
    (p.mass isa EqualMass || p.mass isa Density) || not_implemented("mass", p.mass)
    p.mass isa EqualMass && p.mass.mass <= 0 &&
        throw(ArgumentError("EqualMass needs a positive mass"))
    p.mass isa Density && p.mass.density <= 0 &&
        throw(ArgumentError("Density needs a positive density"))
    p.target isa Pressure || not_implemented("target", p.target)
    p.target.value > 0 || throw(ArgumentError("the target pressure must be positive"))
    (p.boundary isa Periodic || p.boundary isa Walls) ||
        not_implemented("boundary", p.boundary)
    p.initial_state isa Dilute || not_implemented("initial_state", p.initial_state)
    0 < p.initial_state.packing_fraction < 1 ||
        throw(ArgumentError("Dilute packing_fraction must lie between 0 and 1"))
    p.protocol isa IsotropicCompression || not_implemented("protocol", p.protocol)
    0 < p.protocol.strain_step < 1 ||
        throw(ArgumentError("strain_step must lie between 0 and 1"))
    validate_convergence(p.convergence)
    p.pressure_tolerance > 0 || throw(ArgumentError("pressure_tolerance must be positive"))
    p.steps_max >= 1 || throw(ArgumentError("steps_max must be at least 1"))
    p.failure_action in (:warn, :error) ||
        throw(ArgumentError("failure_action must be :warn or :error"))
    (p.restart_packing === nothing || p.restart_packing isa AbstractString) ||
        not_implemented("restart_packing", p.restart_packing)
    (p.restart_file === nothing || p.restart_file isa RestartFile) ||
        not_implemented("restart_file", p.restart_file)
    validate_algorithm(p.algorithm)
    p.timestep isa CollisionTime || p.timestep isa Real ||
        throw(ArgumentError("timestep must be CollisionTime(...) or a number"))
    (p.timestep isa CollisionTime ? p.timestep.fraction : p.timestep) > 0 ||
        throw(ArgumentError("the time step must be positive"))
    validate_rattlers(p.rattlers)
    (p.snapshots === nothing || p.snapshots isa Snapshots) ||
        not_implemented("snapshots", p.snapshots)
    (p.movie === nothing || p.movie isa Movie) || not_implemented("movie", p.movie)
    0 <= p.seed <= typemax(Int) ||
        throw(ArgumentError("seed must lie between 0 and $(typemax(Int)), got $(p.seed)"))
    if p.rattlers isa Unresolved && p.rattlers.floor === :tolerance &&
       !hasproperty(p.convergence, :tolerance)
        throw(ArgumentError("Unresolved(floor = :tolerance) needs a convergence test with " *
                            "a force tolerance; pass an explicit floor"))
    end
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

function validate_friction(friction, contact)
    friction === nothing && return friction
    (friction isa CundallStrack || friction isa Mindlin) ||
        not_implemented("friction", friction)
    friction.friction_coefficient >= 0 ||
        throw(ArgumentError("friction_coefficient must be non-negative"))
    if friction isa CundallStrack && friction.stiffness_ratio isa Real
        friction.stiffness_ratio > 0 ||
            throw(ArgumentError("stiffness_ratio must be positive"))
    end
    friction isa Mindlin && !(contact isa Hertzian) &&
        throw(ArgumentError("Mindlin friction needs Hertzian contacts (design §13)"))
    friction isa Mindlin && !(-1 < friction.poisson_ratio < 0.5) &&
        throw(ArgumentError("poisson_ratio must lie between -1 and 0.5"))
    return friction
end

function validate_convergence(test)
    (test isa RelativeForce || test isa LeidenAcceleration || test isa KineticEnergy ||
     test isa RestartTest || test isa Function) || not_implemented("convergence", test)
    hasproperty(test, :tolerance) && test.tolerance <= 0 &&
        throw(ArgumentError("tolerance must be positive"))
    return test
end

function validate_algorithm(algorithm)
    if algorithm isa FIRE
        algorithm.integrator === :semi_implicit_euler ||
            not_implemented("FIRE integrator", algorithm.integrator)
        algorithm.timestep_max > 0 && algorithm.timestep_min > 0 ||
            throw(ArgumentError("FIRE timestep_max and timestep_min must be positive"))
        algorithm.timestep_min <= algorithm.timestep_max ||
            throw(ArgumentError("FIRE needs timestep_min <= timestep_max"))
        algorithm.timestep_grow >= 1 ||
            throw(ArgumentError("FIRE timestep_grow must be at least 1"))
        (0 < algorithm.timestep_shrink <= 1) ||
            throw(ArgumentError("FIRE timestep_shrink must lie in (0, 1]"))
        algorithm.delay >= 0 ||
            throw(ArgumentError("FIRE delay must be non-negative"))
        algorithm.uphill_max >= 1 ||
            throw(ArgumentError("FIRE uphill_max must be at least 1"))
        validate_damping(algorithm.damping)
        validate_drag(algorithm.drag)
        return algorithm
    end
    algorithm isa DampedDynamics || not_implemented("algorithm", algorithm)
    algorithm.integrator in (:centered_velocity_verlet, :lagged_velocity_verlet,
                             :semi_implicit_euler) ||
        throw(ArgumentError("integrator must be :centered_velocity_verlet, " *
                            ":lagged_velocity_verlet or :semi_implicit_euler, got " *
                            "$(algorithm.integrator)"))
    validate_damping(algorithm.damping)
    validate_drag(algorithm.drag)
    return algorithm
end

function validate_damping(damping)
    damping === nothing && return damping
    (damping isa ContactDamping || damping isa ViscousRate ||
     damping isa RelativeVelocityDamping) || not_implemented("damping", damping)
    if damping isa ContactDamping
        (damping.normal >= 0 && damping.tangential >= 0) ||
            throw(ArgumentError("damping ratios must be non-negative"))
        damping.tangential_mass in (:with_rotation, :pair) ||
            throw(ArgumentError("tangential_mass must be :with_rotation or :pair"))
    elseif damping isa ViscousRate
        (damping.normal >= 0 && damping.tangential >= 0) ||
            throw(ArgumentError("damping rates must be non-negative"))
    else
        damping.rate >= 0 || throw(ArgumentError("the damping rate must be non-negative"))
    end
    if getproperty(damping, :coulomb_limit) === :total
        throw(ArgumentError("coulomb_limit = :total is designed but not implemented yet: " *
                            "it needs the normal dashpot back from the algorithm (§7). " *
                            "Use the default :elastic."))
    end
    getproperty(damping, :coulomb_limit) === :elastic ||
        throw(ArgumentError("coulomb_limit must be :elastic (the only value implemented)"))
    return damping
end

function validate_drag(drag)
    drag === nothing && return drag
    drag isa StokesDrag || not_implemented("drag", drag)
    (drag.velocity >= 0 && drag.spin >= 0) ||
        throw(ArgumentError("drag rates must be non-negative"))
    drag.during in (:always, :compression) ||
        throw(ArgumentError("during must be :always or :compression"))
    return drag
end

function validate_rattlers(rattlers)
    rattlers === nothing && return rattlers
    (rattlers isa ContactCount || rattlers isa TwoContact || rattlers isa ForceFloor ||
     rattlers isa Unresolved || rattlers isa Function) ||
        not_implemented("rattlers", rattlers)
    if rattlers isa ForceFloor
        rattlers.floor >= 0 || throw(ArgumentError("ForceFloor floor must be non-negative"))
    elseif rattlers isa Unresolved
        rattlers.floor isa Symbol && rattlers.floor !== :tolerance &&
            throw(ArgumentError("Unresolved floor must be :tolerance or a force"))
    end
    return rattlers
end
