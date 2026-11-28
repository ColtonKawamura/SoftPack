"""
    SoftPack

Jammed packings of soft particles. `pack()` with no arguments makes the default packing
of the design (`docs/design-references.md`, §2): 256 frictionless Hookean disks in a
50:50 bidisperse mixture of diameter ratio 1.4, compressed isotropically with FIRE in a
periodic box until the contact pressure is 1e-4, with rattlers removed.

Every setting of the design is a keyword of `pack()`: Hookean and Hertzian contacts,
Cundall-Strack and Mindlin friction with rotation, equal or density masses, periodic boxes
or walls, FIRE or damped dynamics with its three integrators and its damping and drag
options, the four convergence tests plus user functions, the four rattler rules, restarts,
snapshots, a movie and `write_packing`. Choices still open on the design board are marked
`PROVISIONAL <card>` in the source, so `grep -rn PROVISIONAL src` lists every one.
"""
module SoftPack

using Printf: @sprintf
using Dates
using TOML
using Random
using SparseArrays
using LinearAlgebra: Diagonal, Symmetric, cholesky, iszero
using StableRNGs
using StaticArrays: SVector
using HDF5

export pack, PackParams, Packing, PackingError, ContactTable, RunState, find_rattlers, write_packing,
       is_converged, run_state, contact_pressure, mean_normal_force,
       Bidisperse, UniformPolydisperse, Monodisperse,
       Hookean, Hertzian, CundallStrack, Mindlin,
       EqualMass, Density, Pressure, Periodic, Walls, Dilute, IsotropicCompression,
       RelativeForce, LeidenAcceleration, KineticEnergy, RestartTest,
       FIRE, DampedDynamics, ContactDamping, ViscousRate, RelativeVelocityDamping,
       StokesDrag, CollisionTime, ContactCount, TwoContact, ForceFloor, Unresolved,
       Snapshots, Movie, RestartFile

include("settings.jl")
include("particles.jl")
include("box.jl")
include("neighbors.jl")
include("contacts.jl")
include("initial_state.jl")
include("timestep.jl")
include("convergence.jl")
include("control.jl")
include("damping.jl")
include("fire.jl")
include("damped.jl")
include("compression.jl")
include("packing.jl")
include("rattlers.jl")
include("restart.jl")
include("output.jl")
include("movie.jl")
include("pack.jl")

end # module
