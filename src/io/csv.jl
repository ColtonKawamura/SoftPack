# ---------------------------------------------------------------------------
#  softpack-1 CSV serialization (particles.csv + contacts.csv).
#
# Plain CSV, one header row, full round-trip precision so read_packing recovers
# the exact stored numbers. DelimitedFiles is deliberately not used: reading this
# format inline gives exact control over round-trip precision (needed so read_packing
# recovers the exact stored numbers) and cleanly handles the optional friction column
# and the string header row. (DelimitedFiles' stdlib UUID is stable across Julia
# versions, so this is a format/precision choice, not a compatibility workaround.)
# ---------------------------------------------------------------------------

# Coordinate column names: 1 -> x, 2 -> y, 3 -> z.
const _COORD_NAMES = ("x", "y", "z")
# Contact-normal column names (softpack-1): nx, ny, nz.
const _NORMAL_NAMES = ("nx", "ny", "nz")

# Digits that round-trip a floating-point value exactly when parsed back:
# 17 for Float64, 9 for Float32.
_roundtrip_digits(::Type{Float64}) = 17
_roundtrip_digits(::Type{Float32}) = 9

# Format a real with the exact-round-trip precision for its type.
fmt_number(x::Float64) = @sprintf("%.17g", x)
fmt_number(x::Float32) = @sprintf("%.9g", x)

"""
    write_particles_csv(io, ::Val{D}, positions, radii, is_rattler, z_contacts)

Write `particles.csv`: `id, x, y[, z], radius, is_rattler, z_contacts` for every
particle. Rattlers are flagged (0/1) and never dropped. `z_contacts` is the
coordination number (how many contacts touch the particle).
"""
function write_particles_csv(io, ::Val{D}, positions, radii, is_rattler, z_contacts) where {D}
    @printf(io, "id")
    for d in 1:D
        @printf(io, ", %s", _COORD_NAMES[d])
    end
    @printf(io, ", radius, is_rattler, z_contacts\n")
    for i in 1:length(radii)
        @printf(io, "%d", i)
        for d in 1:D
            @printf(io, ", %s", fmt_number(positions[d, i]))
        end
        @printf(io, ", %s, %d, %d\n",
                fmt_number(radii[i]), is_rattler[i] ? 1 : 0, z_contacts[i])
    end
    return nothing
end

"""
    write_contacts_csv(io, ::Val{D}, contacts, has_friction)

Write `contacts.csv`: `i, j, overlap, fn[, ft], nx, ny[, nz]`. The optional `ft`
column appears only when at least one contact carries a friction force.
"""
function write_contacts_csv(io, ::Val{D}, contacts, has_friction) where {D}
    @printf(io, "i, j, overlap, fn")
    has_friction && @printf(io, ", ft")
    for d in 1:D
        @printf(io, ", %s", _NORMAL_NAMES[d])
    end
    @printf(io, "\n")
    for c in contacts
        @printf(io, "%d, %d, %s, %s", c.i, c.j,
                fmt_number(c.overlap), fmt_number(c.force_normal))
        has_friction && @printf(io, ", %s",
                fmt_number(c.friction_force === nothing ? zero(c.force_normal) : c.friction_force))
        for d in 1:D
            @printf(io, ", %s", fmt_number(c.normal[d]))
        end
        @printf(io, "\n")
    end
    return nothing
end

"""
    parse_particles_csv(path) -> (positions, radii, is_rattler, z_contacts, D)

Read a `particles.csv` written above. The dimension D is inferred from the number
of columns (all coordinate columns sit between `id` and `radius`)."""
function parse_particles_csv(path)
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("empty file: $path"))
    header = [strip(h) for h in split(lines[1], ',')]
    D = length(header) - 4  # minus id, radius, is_rattler, z_contacts
    nrows = length(lines) - 1
    positions = Matrix{Float64}(undef, D, nrows)
    radii = Vector{Float64}(undef, nrows)
    is_rattler = Vector{Bool}(undef, nrows)
    z_contacts = Vector{Int}(undef, nrows)
    for r in 1:nrows
        f = [strip(x) for x in split(lines[r + 1], ',')]
        for d in 1:D
            positions[d, r] = parse(Float64, f[d + 1])
        end
        radii[r] = parse(Float64, f[D + 2])
        is_rattler[r] = parse(Int, f[D + 3]) == 1
        z_contacts[r] = parse(Int, f[D + 4])
    end
    return positions, radii, is_rattler, z_contacts, D
end

"""
    parse_contacts_csv(path) -> (contacts, D)

Read a `contacts.csv` written above. The dimension and the presence of the
optional `ft` column are inferred from the header.
"""
function parse_contacts_csv(path)
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("empty file: $path"))
    header = [strip(h) for h in split(lines[1], ',')]
    has_ft = "ft" in header
    D = count(name -> name in _NORMAL_NAMES, header)
    nrows = length(lines) - 1
    contacts = Vector{Contact{D,Float64}}(undef, nrows)
    for r in 1:nrows
        f = [strip(x) for x in split(lines[r + 1], ',')]
        i = parse(Int, f[1])
        j = parse(Int, f[2])
        overlap = parse(Float64, f[3])
        fn = parse(Float64, f[4])
        idx = 5
        friction = nothing
        if has_ft
            friction = parse(Float64, f[idx])
            idx += 1
        end
        coords = parse.(Float64, f[idx:idx + D - 1])
        normal = ntuple(i -> coords[i], D)
        contacts[r] = Contact(i, j, overlap, fn, friction, normal)
    end
    return contacts, D
end
