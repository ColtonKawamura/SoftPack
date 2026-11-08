# A runnable SoftPack example:  julia --project=. examples/example.jl
#
# In M0 the settings, the softpack-1 output format and round-trip reading all work,
# but no packing algorithm is implemented yet, so pack() raises a clear "not
# implemented yet" error. This example therefore does two things:
#   1. shows the intended user workflow (build a PackParams, call pack), and
#   2. exercises the working softpack-1 IO with a small hand-built packing.

using SoftPack
using Printf

# --- 1. Intended workflow -----------------------------------------------------
p = PackParams()
p.algorithm = :fire_compress
p.dim = 2
p.N = 64
p.force_threshold = 1e-12
@printf("Settings: algorithm = %s, dim = %d, N = %d\n", p.algorithm, p.dim, p.N)

# pack(p) currently raises the "not implemented yet" error; a later milestone
# returns a Packing instead.
try
    pack(p)
catch e
    @printf("pack(p): %s\n", e)
end

# --- 2. softpack-1 output format (works now) ----------------------------------
positions = [0.0 1.0 2.0; 0.0 0.0 1.0]        # 2 x 3
radii = [0.3, 0.25, 0.2]
box = [3.0, 3.0]
is_rattler = Bool[false, true, false]         # the middle particle is a rattler
contacts = [Contact(1, 2, 0.15, 0.5, nothing, (1.0, 0.0))]
pk = Packing{2, Float64}(positions, radii, box, is_rattler, contacts, Dict{String,Any}(
    "algorithm" => "fire_compress", "pressure" => 1e-4, "seed" => 1))

dir = joinpath(mktempdir(), "example-packing")
write_packing(pk, dir)
@printf("wrote softpack-1 packing to %s\n", dir)
for f in ("particles.csv", "contacts.csv", "metadata.toml")
    @printf("  %-16s %d bytes\n", f, filesize(joinpath(dir, f)))
end

pk2 = read_packing(dir)
@printf("read back: N = %d, rattlers = %s\n", length(pk2.radii), pk2.is_rattler)
@assert pk2.positions == pk.positions
@assert pk2.radii == pk.radii
@assert pk2.is_rattler == pk.is_rattler
println("softpack-1 round-trip OK")
