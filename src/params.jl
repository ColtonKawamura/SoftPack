# ---------------------------------------------------------------------------
#  PackParams: the user-facing settings for a packing run.
#
#  `Base.@kwdef` gives a keyword constructor with defaults AND a no-arg
#  constructor, and the struct is `mutable` so a single field can be tweaked
#  after construction:  p.force_threshold = 1e-14.
# ---------------------------------------------------------------------------

"""
    PackParams

Mutable keyword struct holding every setting for a packing run. All fields have
sensible defaults (shown below); see `validate` for the rules that are enforced.

# Fields
- `algorithm = :fire_compress`        -- packing algorithm (a symbol, see `ALGORITHMS`)
- `dim = 2`                           -- spatial dimension (2 or 3)
- `N = 256`                           -- number of particles
- `sizes = Bidisperse(ratio = 1.4, fraction = 0.5)` -- size distribution
- `contact = Hookean(k = 1.0)`        -- contact law
- `pressure = 1e-4`                   -- target mechanical pressure
- `pressure_tol = 1e-2`               -- pressure convergence tolerance (relative)
- `force_threshold = 1e-12`           -- residual force convergence criterion
- `max_steps = 10^7`                  -- maximum number of iterations
- `rattlers = :remove`                -- `:remove`, `:flag` or `:keep`
- `backend = :cpu`                    -- `:cpu`, `:cuda` or `:metal`
- `precision = Float64`               -- `Float64` or `Float32`
- `seed = 1`                          -- RNG seed
- `friction = nothing`                -- friction setting (unsupported in 3D in v1)
- `verbose = false`                   -- print progress
"""
Base.@kwdef mutable struct PackParams
    algorithm       :: Symbol          = :fire_compress
    dim             :: Int             = 2
    N               :: Int             = 256
    sizes           :: SizeDistribution = Bidisperse(ratio = 1.4, fraction = 0.5)
    contact         :: ContactLaw       = Hookean(k = 1.0)
    pressure        :: Float64          = 1e-4
    pressure_tol    :: Float64          = 1e-2
    force_threshold :: Float64          = 1e-12
    max_steps       :: Int              = 10^7
    rattlers        :: Symbol           = :remove
    backend         :: Symbol           = :cpu
    precision       :: Type             = Float64
    seed            :: Int              = 1
    friction        :: Any              = nothing
    verbose         :: Bool             = false
end

# The set of algorithm symbols `pack()` knows about. Later cards add one symbol
# here (plus one `pack(::Val{alg}, p)` method) to support a new algorithm.
const ALGORITHMS = (:fire_compress,)

# Valid values for the enumerated settings, used to build the error messages in
# `validate`.
const _BACKENDS = (:cpu, :cuda, :metal)
const _RATTLERS = (:remove, :flag, :keep)

"""
    validate(p::PackParams) -> Bool

Check `p` and throw a clear `ArgumentError` on the first rule it breaks. Returns
`true` when `p` is well-formed. Called at the start of `pack` so bad settings
fail early with an actionable message.
"""
function validate(p::PackParams)
    p.dim in (2, 3) ||
        throw(ArgumentError("dim must be 2 or 3, got $(p.dim)"))
    p.N > 0 ||
        throw(ArgumentError("N must be a positive integer, got $(p.N)"))
    p.pressure > 0 ||
        throw(ArgumentError("pressure must be positive, got $(p.pressure)"))

    p.algorithm in ALGORITHMS ||
        throw(ArgumentError("unknown algorithm :$(p.algorithm); valid algorithms: " *
                            join(ALGORITHMS, ", ")))

    p.backend in _BACKENDS ||
        throw(ArgumentError("unknown backend :$(p.backend); valid backends: " *
                            join(_BACKENDS, ", ")))

    p.rattlers in _RATTLERS ||
        throw(ArgumentError("unknown rattlers :$(p.rattlers); valid values: " *
                            join(_RATTLERS, ", ")))

    if p.backend == :metal && p.precision == Float64
        throw(ArgumentError("the :metal backend does not support Float64 (Metal has " *
                            "no Float64); use precision = Float32"))
    end

    if p.friction !== nothing && p.dim == 3
        throw(ArgumentError("friction is not supported in 3D for v1; run in dim = 2 or " *
                            "set friction = nothing"))
    end

    return true
end
