# ---------------------------------------------------------------------------
#  write_packing: write a Packing to disk in the softpack-1 format.
# ---------------------------------------------------------------------------

# Version of the on-disk format, kept in sync with Project.toml.
const SOFTPACK_VERSION = "0.1.0-DEV"

# Detect the short git commit of the working tree, if we are inside a git repo.
# Returns the hash string, or nothing when git is unavailable or not a repo.
function _git_commit()::Union{String,Nothing}
    try
        raw = strip(read(chomp, `git rev-parse --short HEAD`))
        return isempty(raw) ? nothing : raw
    catch
        return nothing
    end
end

# Coordination number of every particle (how many contacts touch it) and whether
# the contact list carries any friction force.
function _coordination_and_friction(contacts::Vector{Contact{D,T}}, N) where {D,T}
    z = zeros(Int, N)
    has_ft = false
    for c in contacts
        z[c.i] += 1
        z[c.j] += 1
        c.friction_force !== nothing && (has_ft = true)
    end
    return z, has_ft
end

"""
    write_packing(pk, dir; git_commit = <detected>)

Write `pk` into a new directory `dir` as three files: `particles.csv`,
`contacts.csv` and `metadata.toml` (the softpack-1 format, see docs/src/format.md).
All particles are written; rattlers are flagged, never dropped. Floats use full
round-trip precision. Returns `dir`.
"""
function write_packing(pk::Packing, dir::AbstractString;
                       git_commit::Union{String,Nothing} = _git_commit())
    isdir(dir) || mkdir(dir)
    D = size(pk.positions, 1)
    N = length(pk.radii)

    z, has_ft = _coordination_and_friction(pk.contacts, N)

    open(joinpath(dir, "particles.csv"), "w") do io
        write_particles_csv(io, Val{D}(), pk.positions, pk.radii, pk.is_rattler, z)
    end
    open(joinpath(dir, "contacts.csv"), "w") do io
        write_contacts_csv(io, Val{D}(), pk.contacts, has_ft)
    end
    open(joinpath(dir, "metadata.toml"), "w") do io
        write_metadata(io, pk.metadata, "softpack-1", SOFTPACK_VERSION, git_commit, pk.box)
    end
    return dir
end
