# ---------------------------------------------------------------------------
#  pack: entry point for a packing run.
#
#  pack(p::PackParams) validates, then dispatches on Val(p.algorithm). Every
#  algorithm is unimplemented in M0, so the fallback throws a clear error listing
#  what is available. Later cards add one file + one method per algorithm to this
#  dispatch.
# ---------------------------------------------------------------------------

"""
    pack(p::PackParams) -> Packing

Validate `p` and run the requested algorithm. In M0 no algorithm is implemented,
so this always throws an `ErrorException` saying the algorithm is "not implemented
yet" and listing the available ones.
"""
function pack(p::PackParams)
    validate(p)
    # Brace form turns the algorithm Symbol into a static type parameter so the
    # Val dispatch below matches pack(::Val{alg}, p). (Parens would make a
    # Val{Symbol}, which does not match and raises a MethodError.)
    return pack(Val{p.algorithm}(), p)
end

# Fallback for a known-but-unimplemented algorithm. A later card adds a more
# specific `pack(::Val{:fire_compress}, p)` which this one is less specific than.
function pack(::Val{alg}, p::PackParams) where {alg}
    error("algorithm $(alg) is not implemented yet; available: ", join(ALGORITHMS, ", "))
end

"""
    pack(; kwargs...) -> Packing

Convenience form: build a `PackParams` from the keyword arguments and pack it.
Example: `pack(N = 64, pressure = 1e-3)`. As with `pack(p)`, in v0.1 this
always throws the "not implemented yet" error.
"""
pack(; kwargs...) = pack(PackParams(; kwargs...))
