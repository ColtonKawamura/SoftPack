# ---------------------------------------------------------------------------
#  read_packing: read a softpack-1 packing written by write_packing.
# ---------------------------------------------------------------------------

"""
    read_packing(dir) -> Packing

Read the `particles.csv`, `contacts.csv` and `metadata.toml` in `dir` and rebuild
a `Packing`. Floats are read back with full precision, so values match what
`write_packing` stored. Throws `ArgumentError` if any of the three files is
missing.
"""
function read_packing(dir::AbstractString)
    particles = joinpath(dir, "particles.csv")
    contacts = joinpath(dir, "contacts.csv")
    metadata_file = joinpath(dir, "metadata.toml")
    for f in (particles, contacts, metadata_file)
        isfile(f) || throw(ArgumentError("missing softpack-1 file: $f"))
    end

    positions, radii, is_rattler, _z, D = parse_particles_csv(particles)
    contacts_list, _Dc = parse_contacts_csv(contacts)
    meta = TOML.parsefile(metadata_file)

    pk_meta = Dict{String,Any}(string(k) => _unserialize_toml(v) for (k, v) in meta)
    # Reconstruct the floating-point type from the stored precision so a Float32
    # packing is read back as Float32 rather than silently widened to Float64.
    # Values were written with the type's exact round-trip precision, so casting
    # recovers them exactly.
    T = _eltype_from_precision(get(pk_meta, "precision", "Float64"))
    positions = T.(positions)
    radii = T.(radii)
    box = T.(pk_meta["box"])
    contacts = Contact{D,T}[_cast_contact(c, T) for c in contacts_list]
    return Packing{D,T}(positions, radii, box, is_rattler, contacts, pk_meta)
end

# Map the stored precision ("Float32"/"Float64") back to a Julia type; default to
# Float64 for anything unrecognized (e.g. a hand-written file).
function _eltype_from_precision(p::AbstractString)
    p == "Float32" && return Float32
    p == "Float16" && return Float16
    p == "Float64" && return Float64
    return Float64
end

# Rebuild a contact whose numbers are in type T. CSV is always read as Float64,
# so here we cast; a missing friction force stays nothing.
function _cast_contact(c::Contact{D,TA}, ::Type{T}) where {D,TA,T}
    return Contact(c.i, c.j,
                   T(c.overlap),
                   T(c.force_normal),
                   c.friction_force === nothing ? nothing : T(c.friction_force),
                   ntuple(k -> T(c.normal[k]), D))
end
