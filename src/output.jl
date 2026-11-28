# ---------------------------------------------------------------------------
#  write_packing (design §11): HDF5 by default, CSV as an option. One 1-D dataset
#  per column, gzip compression on request, safe writes (a temporary file renamed
#  over the path), and a second file with every particle and its rattler flag.
# ---------------------------------------------------------------------------

"""
    second_path(path)

`packing.h5` -> `packing_rattlers.h5`; a path without an extension gets `_rattlers` at
the end (design §11).
"""
function second_path(path::AbstractString)
    base, extension = splitext(path)
    return isempty(extension) ? path * "_rattlers" : base * "_rattlers" * extension
end

"""
    write_packing(path, packing; rattlers_file = false, compression = nothing,
                  overwrite = false, format = :hdf5)

Write a `Packing` to `path` (design §11).

- The main `particles` group holds the remaining particles with their original `id`
  (0-based); `contacts` holds the contacts between them. The `state` group holds every
  particle and the full dynamic state, so `restart_packing = path` continues the run.
- `rattlers_file = true` also writes `second_path(path)` with every particle and a
  `rattler` flag.
- `compression = :gzip` uses gzip level 4, or give `(:gzip, level)`.
- `overwrite = false` refuses to replace an existing file.
- The format follows the extension: `.h5` or `.hdf5` is HDF5, `.csv` is CSV, anything
  else is an error unless `format` says otherwise. `format = :csv` writes
  `<path>_particles.csv` and `<path>_contacts.csv` with the same columns (card T-zk8c).
  A CSV export cannot restart a run; use HDF5 for that.

Files are written to a temporary file in the same directory and renamed into place, so a
job killed during a write leaves any existing file intact.
"""
function write_packing(path::AbstractString, p::Packing;
                       rattlers_file::Bool = false,
                       compression = nothing,
                       overwrite::Bool = false,
                       format::Union{Nothing,Symbol} = nothing)
    if format === nothing
        extension = lowercase(splitext(path)[2])
        format = extension in (".h5", ".hdf5") ? :hdf5 :
                 extension == ".csv" ? :csv :
                 throw(ArgumentError("cannot tell the format from $(repr(path)): use a .h5 " *
                                     "or .csv extension, or pass format = :hdf5 or :csv"))
    end
    format in (:hdf5, :csv) ||
        throw(ArgumentError("format must be :hdf5 or :csv, got $(repr(format))"))
    targets = [path]
    rattlers_file && push!(targets, second_path(path))
    if format === :csv
        targets = [csv_particles_path(path), csv_contacts_path(path)]
        rattlers_file && append!(targets, [csv_particles_path(second_path(path)),
                                           csv_contacts_path(second_path(path))])
    end
    if !overwrite
        for target in targets
            isfile(target) && throw(ArgumentError(
                "$target already exists; pass overwrite = true to replace it (design §11)"))
        end
    end
    if format === :csv
        write_csv(path, p; all = false, rattlers = false)
        rattlers_file && write_csv(second_path(path), p; all = true, rattlers = true)
        return nothing
    end
    if compression isa Tuple
        compression[1] === :gzip ||
            throw(ArgumentError("compression must be :gzip or (:gzip, level)"))
        level = Int(compression[2])
    elseif compression === nothing
        level = nothing
    elseif compression === :gzip
        level = 4
    else
        throw(ArgumentError("compression must be :gzip or (:gzip, level)"))
    end
    write_state(path, p.system, p.control, results(p); compression = level)
    edit_hdf5(path, p; all = false, rattlers = false, level = level)
    if rattlers_file
        write_state(second_path(path), p.system, p.control, results(p);
                    compression = level)
        edit_hdf5(second_path(path), p; all = true, rattlers = true, level = level)
    end
    return nothing
end

"""
    edit_hdf5(path, packing; all, rattlers, level)

Add the analysis groups to a file already holding the state: `particles` (remaining
particles, or every one with `all`) and `contacts` (between the remaining ones).
"""
function edit_hdf5(path::AbstractString, p::Packing{D}; all::Bool, rattlers::Bool,
                   level) where {D}
    h5open(path, "r+") do f
        keep = all ? collect(1:length(p.diameters)) : findall(!, p.rattlers)
        _put!(f, "particles/id", collect(Int64.(keep .- 1)), level)
        _put!(f, "particles/diameter", p.diameters[keep], level)
        _put!(f, "particles/mass", p.masses[keep], level)
        for axis in 1:D
            _put!(f, "particles/position_$(("x", "y", "z")[axis])",
                  p.positions[axis, keep], level)
            _put!(f, "particles/force_$(("x", "y", "z")[axis])",
                  p.forces[axis, keep], level)
        end
        if rattlers
            _put!(f, "particles/rattler", collect(UInt8.(p.rattlers)), level)
        end
        keep_set = falses(length(p.diameters))
        keep_set[keep] .= true
        table = p.contacts
        selected = [c for c in eachindex(table.first)
                    if keep_set[table.first[c]] &&
                       (table.second[c] == 0 || keep_set[table.second[c]])]
        _put!(f, "contacts/first", collect(Int64.(table.first[selected] .- 1)), level)
        _put!(f, "contacts/second", collect(Int64.(table.second[selected] .- 1)), level)
        _put!(f, "contacts/wall_id", collect(Int64.(table.wall_id[selected])), level)
        _put!(f, "contacts/overlap", table.overlaps[selected], level)
        _put!(f, "contacts/normal_force", table.normal_forces[selected], level)
        tangential = [sqrt(dot_in_order(table.tangential_forces[c],
                                        table.tangential_forces[c]))
                      for c in selected]
        _put!(f, "contacts/tangential_force", tangential, level)
        _put!(f, "contacts/sliding", collect(UInt8.(table.sliding[selected])), level)
        attributes(f)["particle_id_base"] = 0
    end
    return nothing
end

# --- CSV ---------------------------------------------------------------------

csv_particles_path(path::AbstractString) = begin
    base, extension = splitext(path)
    (isempty(extension) ? path : base) * "_particles.csv"
end
csv_contacts_path(path::AbstractString) = begin
    base, extension = splitext(path)
    (isempty(extension) ? path : base) * "_contacts.csv"
end

"""
    write_csv(path, packing; all, rattlers)

The CSV option (PROVISIONAL T-zk8c): one table per file, a `#` line of settings, then the
columns. `all = false` writes the remaining particles only.
"""
function write_csv(path::AbstractString, p::Packing{D}; all::Bool, rattlers::Bool) where {D}
    keep = all ? collect(1:length(p.diameters)) : findall(!, p.rattlers)
    particles_path = csv_particles_path(path)
    contacts_path = csv_contacts_path(path)
    open(particles_path, "w") do io
        println(io, "# SoftPack ", p.softpack_version, " ", p.softpack_commit,
                " seed ", p.seed, " dimension ", D, " box_side ", p.box_side,
                " pressure ", p.pressure, " packing_fraction ", p.packing_fraction,
                " converged ", p.converged)
        columns = ["id", "diameter", "mass"]
        append!(columns, [("position_" * axis) for axis in ("x", "y", "z")[1:D]])
        rattlers && push!(columns, "rattler")
        println(io, join(columns, ","))
        for i in keep
            values = Any[i - 1, p.diameters[i], p.masses[i]]
            append!(values, [p.positions[axis, i] for axis in 1:D])
            rattlers && push!(values, Int(p.rattlers[i]))
            println(io, join(values, ","))
        end
    end
    keep_set = falses(length(p.diameters))
    keep_set[keep] .= true
    open(contacts_path, "w") do io
        println(io, "# first and second are 0-based particle ids; second = -1 marks a wall")
        println(io, "first,second,wall_id,overlap,normal_force,tangential_force,sliding")
        table = p.contacts
        for c in eachindex(table.first)
            keep_set[table.first[c]] || continue
            table.second[c] == 0 || keep_set[table.second[c]] || continue
            tangential = sqrt(dot_in_order(table.tangential_forces[c],
                                           table.tangential_forces[c]))
            println(io, join(Any[table.first[c] - 1,
                                 table.second[c] == 0 ? -1 : table.second[c] - 1,
                                 table.wall_id[c], table.overlaps[c],
                                 table.normal_forces[c], tangential,
                                 Int(table.sliding[c])], ","))
        end
    end
    return nothing
end
