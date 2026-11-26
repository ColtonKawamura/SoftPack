# ---------------------------------------------------------------------------
#  Rattler rules (design §9).
# ---------------------------------------------------------------------------

"""
    find_rattlers(packing, rule) -> BitVector

Apply a rattler rule to a finished packing; `true` marks a rattler. `rule` is
`ContactCount(...)`, `nothing` (no rattlers) or any function that takes the `Packing` and
returns one `Bool` per particle (PROVISIONAL T-hg7w / T-1x2y: the design says "a function
of the contact network" and has not fixed its argument).
"""
find_rattlers(p::Packing{D}, rule) where {D} =
    find_rattlers(rule, p.contacts, length(p.diameters), D, p.settings.friction !== nothing)

find_rattlers(p::Packing, rule::Function) = BitVector(rule(p))

find_rattlers(::Nothing, table::ContactTable, count::Int, dimension::Int, frictional::Bool) =
    falses(count)

"""
    find_rattlers(rule::ContactCount, table, count, dimension, frictional) -> BitVector

Remove particles with fewer than `D + 1` contacts (frictionless) or 2 (frictional), then
repeat on the remaining network until no particle changes (card T-hg7w, option 1). Each
removal lowers its neighbors' counts, so the removals cascade.
"""
function find_rattlers(rule::ContactCount, table::ContactTable, count::Int,
                       dimension::Int, frictional::Bool)
    frictional && not_implemented("ContactCount with friction (cone test)", rule)
    minimum_contacts = dimension + 1
    neighbors = [Int[] for _ in 1:count]
    for c in eachindex(table.first)
        push!(neighbors[table.first[c]], table.second[c])
        push!(neighbors[table.second[c]], table.first[c])
    end
    contacts = length.(neighbors)
    rattler = falses(count)
    queue = [i for i in 1:count if contacts[i] < minimum_contacts]
    rattler[queue] .= true
    while !isempty(queue)
        i = pop!(queue)
        for j in neighbors[i]
            rattler[j] && continue
            contacts[j] -= 1
            if contacts[j] < minimum_contacts
                rattler[j] = true
                push!(queue, j)
            end
        end
    end
    return rattler
end

"""
    contact_number(table, rattlers) -> Float64

Mean number of contacts per remaining particle, counting only contacts between two
remaining particles.
"""
function contact_number(table::ContactTable, rattlers::BitVector)
    remaining = count(!, rattlers)
    remaining == 0 && return 0.0
    kept = count(c -> !rattlers[table.first[c]] && !rattlers[table.second[c]],
                 eachindex(table.first))
    return 2 * kept / remaining
end
