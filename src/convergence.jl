# ---------------------------------------------------------------------------
#  Convergence (design §5). The option decides rest at the current box; the
#  pressure band is checked by the compression protocol after every minimization.
# ---------------------------------------------------------------------------

"""
    force_scale(table, force_floor)

The force scale of `RelativeForce`: the mean normal contact force, but never below
`force_floor = P_target * d_ref^(D-1) / 10`, so that a minimization with no or few
contacts can end (design §2, "Force floor").
"""
force_scale(table::ContactTable, force_floor::Float64) =
    max(mean_normal_force(table), force_floor)

"""
    force_floor_for(pressure_target, diameter_ref, dimension)

`P_target d_ref^(D-1) / 10`, the floor of the force scale during the compression (design §2).
"""
force_floor_for(pressure_target::Float64, diameter_ref::Float64, dimension::Int) =
    pressure_target * (dimension == 2 ? diameter_ref : diameter_ref * diameter_ref) / 10

"""
    largest_force(forces)

`max_i |F_i|` over all particles.
"""
largest_force(forces::Vector{<:SVector}) = sqrt(maximum(f -> dot_in_order(f, f), forces))

"""
    is_converged(test, system, force_floor) -> Bool

`RelativeForce`: `max_i |F_i| < tolerance * max(<f_n>, f_floor)`.
"""
is_converged(test::RelativeForce, s::System, force_floor::Float64) =
    largest_force(s.forces) < test.tolerance * force_scale(s.table, force_floor)

"""
    float64_floor_warning(params, diameters, diameter_ref)

Warn at run start when `Float64` positions cannot reach the force test (card T-2brz,
option 1). Near a coordinate `x` positions move in steps of `eps(x)`, so the residual
force cannot fall much below `2 k eps(L)`, with `L` the box side (wiki, Convergence
criterion, "Floating-point floor"). Two thresholds are checked:

- at the target, `tolerance * <f_n>`, with the side and the mean force estimated from
  `phi = 0.84` (2D) or `0.64` (3D) and `z = 2D` contacts per particle;
- during the compression, `tolerance * f_floor` with `f_floor = P_target d_ref^(D-1) / 10`
  (design §2). A compression step can leave contacts whose overlaps are pure round-off, at
  any packing fraction; only this floor then sets the test, and when it is out of reach
  the minimization stalls until `steps_max` (seen at `P_target = 1e-6`, `N = 256`: 5 of 5
  seeds, some at packing fraction 0.67).
"""
function float64_floor_warning(p::PackParams, diameters::Vector{Float64},
                               diameter_ref::Float64)
    p.convergence isa RelativeForce || return nothing
    dimension = p.dimension
    count = length(diameters)
    tolerance = p.convergence.tolerance
    packing_fraction_jamming = dimension == 2 ? 0.84 : 0.64
    volume = total_volume(diameters, dimension) / packing_fraction_jamming
    side = box_side_for(volume, 1.0, dimension)
    diameter_mean = sum_in_order(diameters) / count
    contacts_per_particle = 2 * dimension
    # P = sum_c f l / (D V) with N z / 2 contacts of length <d>  =>  <f> = 2 D V P / (N z <d>)
    force_mean = 2 * dimension * volume * p.target.value /
                 (count * contacts_per_particle * diameter_mean)
    force_floor = force_floor_for(p.target.value, diameter_ref, dimension)
    floor_estimate = 2 * p.contact.stiffness * eps(side)
    if tolerance * force_mean < floor_estimate
        @warn "The force tolerance is probably out of reach of Float64 positions: at the " *
              "target it asks for net forces below " *
              (@sprintf "%.1e" tolerance * force_mean) *
              ", and positions near the box side $(round(side; sigdigits = 3)) can only " *
              "reach about " * (@sprintf "%.1e" floor_estimate) * ". Expect the run to stop " *
              "at steps_max with converged = false; a looser tolerance or a higher " *
              "target pressure avoids it."
    elseif tolerance * force_floor < floor_estimate
        @warn "The compression's force floor is probably out of reach of Float64 positions: " *
              "a compression step that leaves contacts with round-off overlaps must bring " *
              "every net force below " *
              (@sprintf "%.1e" tolerance * force_floor) * " (tolerance times " *
              "P_target d_ref^(D-1)/10), and positions near the box side " *
              "$(round(side; sigdigits = 3)) can only reach about " *
              (@sprintf "%.1e" floor_estimate) * ". Such a step stalls until steps_max " *
              "and the run returns converged = false; a looser tolerance or a higher " *
              "target pressure avoids it."
    end
    return nothing
end
