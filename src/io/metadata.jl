# ---------------------------------------------------------------------------
#  softpack-1 metadata.toml serialization.
#
#  NOTE: Julia 1.12's stdlib TOML exports `print`, not `write` (TOML.write no
#  longer exists), so we serialize with TOML.print. Reading uses TOML.parse,
#  which returns a Dict{String,Any}.
# ---------------------------------------------------------------------------

# A metadata value may be a Symbol, a Type, or `nothing` (e.g. friction =
# nothing), none of which TOML has a representation for. Render those as strings.
_toml_value(v::Symbol) = string(v)
_toml_value(v::Type) = string(v)
_toml_value(v::Nothing) = "nothing"
_toml_value(v) = v

# The inverse of _toml_value: TOML has no null, so `nothing` was written as the
# literal string "nothing". Convert that string back to Julia `nothing` so a
# write→read round-trip recovers the original value. Nested vectors/dicts are
# handled too, in case a future metadata value is structured.
function _unserialize_toml(v)
    v === "nothing" && return nothing
    v isa AbstractVector && return _unserialize_toml.(v)
    v isa AbstractDict && return Dict{String,Any}(string(k) => _unserialize_toml(x)
                                                 for (k, x) in v)
    return v
end

"""
    write_metadata(io, metadata, format, version, git_commit, box)

Write `metadata.toml`: the fixed softpack-1 keys (format, softpack_version,
git_commit, box) plus everything in `metadata` (final pressure, packing fractions,
coordination numbers, residual force, steps, wall time, seed, precision, backend
and the PackParams fields). Keys are written in sorted order for a stable file.
"""
function write_metadata(io, metadata::Dict{String,Any}, format::AbstractString,
                        version::AbstractString, git_commit::Union{String,Nothing},
                        box::AbstractVector)
    toml = Dict{String,Any}()
    toml["format"] = format
    toml["softpack_version"] = version
    isnothing(git_commit) || (toml["git_commit"] = git_commit)
    toml["box"] = box
    for (k, v) in sort(collect(metadata), by = first)
        toml[string(k)] = _toml_value(v)
    end
    TOML.print(io, toml)
    return nothing
end
