
# Probe (not SoftPack code): initial state of pack() from StableRNG(seed): RSA of non-touching particles.
using StableRNGs, Printf
function initial_state(seed, diam, phi0, D, periodic; cap = 10^4)
    rng = StableRNG(seed)
    n = length(diam); R = diam ./ 2
    vol = D == 2 ? sum(pi .* R .^ 2) : sum(4 / 3 * pi .* R .^ 3)
    L = (vol / phi0)^(1 / D)
    order = sortperm(diam; rev = true, alg = MergeSort)        # decreasing diameter, equal diameters in index order (stable)
    x = zeros(n, D); placed = Int[]; draws = 0; maxtry = 0
    for i in order
        tries = 0
        while true
            tries += 1; draws += 1
            p = zeros(D)
            for a in 1:D
                u = rand(rng)
                p[a] = periodic ? u * L : R[i] + u * (L - 2R[i])
            end
            ok = true
            for j in placed
                dx = x[j, :] .- p
                periodic && (dx .-= L .* round.(dx ./ L))
                if sqrt(sum(abs2, dx)) - (R[j] + R[i]) <= 0
                    ok = false; break
                end
            end
            if ok
                x[i, :] = p; push!(placed, i); break
            end
            tries >= cap && error("packing_fraction too high: $tries failed draws for particle $i")
        end
        maxtry = max(maxtry, tries)
    end
    mingap = Inf
    for i in 1:n, j in i+1:n
        dx = x[i, :] .- x[j, :]
        periodic && (dx .-= L .* round.(dx ./ L))
        mingap = min(mingap, sqrt(sum(abs2, dx)) - (R[i] + R[j]))
    end
    return x, L, draws, maxtry, mingap, vol
end
diam = vcat(fill(1.0, 128), fill(1.4, 128))
for periodic in (true, false)
    x, L, draws, maxtry, mingap, vol = initial_state(1, diam, 0.25, 2, periodic)
    tag = periodic ? "periodic" : "walls"
    @printf("%s  area=%.4f  L0=%.4f  draws=%d  max_tries=%d  min_gap=%.3e\n", tag, vol, L, draws, maxtry, mingap)
    open(joinpath(@__DIR__, "init_$(tag).txt"), "w") do io
        println(io, L)
        for i in 1:size(x, 1); println(io, x[i, 1], " ", x[i, 2]); end
    end
end
