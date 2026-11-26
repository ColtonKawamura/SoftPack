"""
    SoftPack

Jammed packings of soft particles. `pack()` with no arguments makes the default packing
of the design (`docs/design-references.md`, §2): 256 frictionless Hookean disks in a
50:50 bidisperse mixture of diameter ratio 1.4, compressed isotropically with FIRE in a
periodic box until the contact pressure is 1e-4, with rattlers removed.

This build implements the frictionless path only. Choices that are still open on the
design board are marked `PROVISIONAL <card>` in the source, so
`grep -rn PROVISIONAL src` lists every one of them.
"""
module SoftPack

using Printf: @sprintf
using StableRNGs: StableRNG
using StaticArrays: SVector

export pack, PackParams, Packing, ContactTable, find_rattlers,
       Bidisperse, UniformPolydisperse, Monodisperse,
       Hookean, EqualMass, Pressure, Periodic, Dilute, IsotropicCompression,
       RelativeForce, FIRE, CollisionTime, ContactCount

include("settings.jl")
include("particles.jl")
include("box.jl")
include("neighbors.jl")
include("contacts.jl")
include("initial_state.jl")
include("timestep.jl")
include("convergence.jl")
include("fire.jl")
include("compression.jl")
include("packing.jl")
include("rattlers.jl")
include("pack.jl")

end # module
