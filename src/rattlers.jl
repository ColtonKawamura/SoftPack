# ---------------------------------------------------------------------------
#  Rattler rules (design §9).
# ---------------------------------------------------------------------------

"""
    find_rattlers(packing, rule) -> BitVector

Apply a rattler rule to a finished packing; `true` marks a rattler. `rule` is
`ContactCount(...)`, `TwoContact(...)`, `ForceFloor(...)`, `Unresolved(...)`, `nothing`
(no rattlers) or any function that takes the `Packing` and returns one `Bool` per particle
(PROVISIONAL T-hg7w / T-1x2y: the design says "a function of the contact network" and has
not fixed its argument).
"""
find_rattlers(p::Packing, rule) =
    find_rattlers(rule, p.contacts, length(p.diameters), p.settings)

find_rattlers(p::Packing, rule::Function) = BitVector(rule(p))

find_rattlers(::Nothing, table::ContactTable, count::Int, settings) = falses(count)

"""
    friction_coefficient(settings) -> Union{Nothing,Float64}

The friction coefficient of a run, or `nothing` when frictionless.
"""
friction_coefficient(settings) =
    settings.friction === nothing ? nothing : settings.friction.friction_coefficient

"""
    rule_minimum(rule, dimension, frictional)

The fewest contacts a particle needs under the rule: `D + 1` frictionless or 2 with
friction for `ContactCount`, 3 for `TwoContact` (removes two or fewer), 2 for
`ForceFloor` and `Unresolved`.
"""
rule_minimum(::ContactCount, dimension::Int, frictional::Bool) =
    frictional ? 2 : dimension + 1
rule_minimum(::TwoContact, dimension::Int, frictional::Bool) = 3
rule_minimum(::ForceFloor, dimension::Int, frictional::Bool) = 2
rule_minimum(::Unresolved, dimension::Int, frictional::Bool) = 2

"""
    effective_floor(rule, mean_force, settings)

The force below which a contact counts as broken: none for the count rules, `floor *
<f>` for `ForceFloor`, and the packing's own tolerance times `<f>` for `Unresolved`
(design §9).
"""
effective_floor(::ContactCount, mean_force::Float64, settings) = -Inf
effective_floor(::TwoContact, mean_force::Float64, settings) = -Inf
effective_floor(rule::ForceFloor, mean_force::Float64, settings) = rule.floor * mean_force
function effective_floor(rule::Unresolved, mean_force::Float64, settings)
    floor = rule.floor === :tolerance ?
        convergence_tolerance(settings) * mean_force : Float64(rule.floor)
    return floor
end

"""
    find_rattlers(rule, table, count, settings) -> BitVector

Every rule builds the effective contact network (contacts below its force floor count as
broken), removes particles with too few contacts, repeats until nothing changes (card
T-hg7w, option 1), and then runs the cone test on two-contact particles when
`cone_test = true` (design §9).
"""
function find_rattlers(rule::RattlerRule, table::ContactTable, count::Int, settings)
    mean_force = mean_normal_force(table)
    threshold = effective_floor(rule, mean_force, settings)
    minimum = rule_minimum(rule, settings.dimension, settings.friction !== nothing)
    μ = friction_coefficient(settings)
    cone = rule isa ContactCount && rule.cone_test && μ !== nothing
    rattler = falses(count)
    while true
        neighbors = [Int[] for _ in 1:count]
        directions = [similar(table.normals, 0) for _ in 1:count]
        for c in eachindex(table.first)
            table.normal_forces[c] > threshold || continue
            i = table.first[c]
            j = table.second[c]
            rattler[i] && continue
            (j != 0 && rattler[j]) && continue
            push!(neighbors[i], j)
            push!(directions[i], -table.normals[c])   # center of i to the contact point
            if j != 0
                push!(neighbors[j], i)
                push!(directions[j], table.normals[c])  # center of j to the contact point
            end
        end
        changed = false
        for i in 1:count
            if !rattler[i] && length(neighbors[i]) < minimum
                rattler[i] = true
                changed = true
            end
        end
        if cone
            limit = pi - 2 * atan(μ)
            for i in 1:count
                rattler[i] && continue
                length(neighbors[i]) == 2 || continue
                cosine = clamp(dot_in_order(directions[i][1], directions[i][2]), -1.0, 1.0)
                if acos(cosine) < limit
                    rattler[i] = true
                    changed = true
                end
            end
        end
        changed || break
    end
    return rattler
end

convergence_tolerance(settings) =
    hasproperty(settings.convergence, :tolerance) ? settings.convergence.tolerance : 1e-8

"""
    contact_number(table, rattlers) -> Float64

Mean number of contacts per remaining particle, counting only contacts between two
remaining particles. A wall contact counts like a pair contact (PROVISIONAL: design §2
leaves this open for `Walls`).
"""
function contact_number(table::ContactTable, rattlers::BitVector)
    remaining = count(!, rattlers)
    remaining == 0 && return 0.0
    kept = count(c -> !rattlers[table.first[c]] &&
                       (table.second[c] == 0 || !rattlers[table.second[c]]),
                 eachindex(table.first))
    return 2 * kept / remaining
end
