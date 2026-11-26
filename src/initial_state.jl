# ---------------------------------------------------------------------------
#  The initial state (design §2): random sequential addition of non-touching
#  particles at rest in a periodic box.
# ---------------------------------------------------------------------------

"""
    place_dilute(Val(D), diameters, packing_fraction, rng; trials_max = 10^4)
        -> (positions, side, trials, trials_most)

Place the particles one by one, largest first (equal diameters in index order). A trial
draws one `rand(rng)` per axis, `x` then `y` then `z`, puts the center at `u * side`, and is
kept only if the gap to every placed particle is positive. The box side gives the
packing fraction `packing_fraction`. After `trials_max` failed trials for one particle an
`ArgumentError` asks for a lower packing fraction. Returns the positions (in index
order), the side, the total number of trials and the most trials one particle needed.
"""
function place_dilute(::Val{D}, diameters::Vector{Float64}, packing_fraction::Float64, rng;
                      trials_max::Int = 10^4) where {D}
    count = length(diameters)
    radii = diameters ./ 2
    volume = total_volume(diameters, D)
    side = box_side_for(volume, packing_fraction, D)
    order = sortperm(diameters; rev = true, alg = Base.Sort.MergeSort)  # stable
    positions = fill(zero(SVector{D,Float64}), count)
    grid = CellGrid(SVector{D,Float64}[], side, maximum(diameters), count)
    use_grid = grid.cells_per_side >= 3
    placed = Int[]
    trials = 0
    trials_most = 0
    for i in order
        tries = 0
        while true
            tries += 1
            trials += 1
            trial = SVector{D,Float64}(ntuple(_ -> rand(rng) * side, Val(D)))
            if gap_is_positive(trial, radii[i], positions, radii, placed, grid, use_grid, side)
                positions[i] = trial
                push!(placed, i)
                use_grid && insert!(grid, i, trial, side)
                break
            end
            tries >= trials_max && throw(ArgumentError(
                "could not place particle $i after $tries trials at packing_fraction = " *
                "$packing_fraction; use a lower packing_fraction"))
        end
        trials_most = max(trials_most, tries)
    end
    return positions, side, trials, trials_most
end

function gap_is_positive(trial::SVector{D,Float64}, radius::Float64, positions, radii,
                         placed, grid::CellGrid{D}, use_grid::Bool, side::Float64) where {D}
    clear = true
    check = j -> begin
        dx = minimum_image(trial - positions[j], side)
        if sqrt(dot_in_order(dx, dx)) - (radii[j] + radius) <= 0
            clear = false
        end
    end
    if use_grid
        foreach_nearby(check, grid, cell_index(grid, trial, side))
    else
        foreach(check, placed)
    end
    return clear
end
