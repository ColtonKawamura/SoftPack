# ---------------------------------------------------------------------------
#  Compute forces, energy and the virial from a pair list.
#
#  The overlap is  delta = r_i + r_j - d_ij  (> 0 while the particles overlap,
#  i.e. are in contact). The contact normal `n` points from i to j, and the
#  repulsive force on j is  fn * n  (on i it is -fn * n), so Newton's third law
#  holds and the net force on the system is ~0.
#
#  Every separation vector below is the minimum-image one (folded into the
#  central cell), so the force direction and the virial are consistent even when
#  the two particles sit on opposite sides of the wrapped box.
# ---------------------------------------------------------------------------

"""
    compute_forces!(F, x, radii, box, pairs, contact) -> (energy, contacts)

Loop over the candidate pair indices `pairs = (i_indices, j_indices)` (as returned
by `pairlist` / `brute_force_pairlist`), compute the overlap and contact force for
each, accumulate:

  * `F` (a `D`-by-`N` matrix) with the total force on every particle, and
  * the total potential `energy`,

and return `(energy, contacts)`. `contacts` is the list of *actual* contacts
(`delta > 0`) as `Contact{D,T}` with fields `(i, j, overlap, force_normal, nothing,
normal)` where `normal` points from `i` to `j`. Only Hookean and Hertzian laws are
supported; the per-contact force/energy come from `force_magnitude` /
`contact_energy`.

The pair list may contain non-contacts (a Verlet skin layer); those are dropped
here by the `delta > 0` test, so `contacts` always holds only real contacts.
"""
function compute_forces!(F::Matrix{<:Any}, x::Matrix{<:Any}, radii::AbstractVector{<:Any},
                         box::PeriodicBox{D,T},
                         pairs::Tuple{<:AbstractVector{<:Integer},<:AbstractVector{<:Integer}},
                         contact) where {D,T}
    ii, jj = pairs
    N = length(radii)
    fill!(F, zero(T))
    energy = zero(T)
    contacts = Vector{Contact{D,T}}()

    # Scratch displacement reused for every pair (no per-pair allocation).
    dx = zeros(T, D)
    @inbounds for K in eachindex(ii)
        i = ii[K]
        j = jj[K]
        # Displacement from i to j, folded to the minimum image.
        @inbounds for d in 1:D
            dx[d] = x[d, j] - x[d, i]
        end
        minimum_image!(dx, box)
        dist2 = zero(T)
        @inbounds for d in 1:D
            dist2 += dx[d] * dx[d]
        end
        dist = sqrt(dist2)
        dist > 0 || continue                      # coincident particles: skip

        r_i = radii[i]
        r_j = radii[j]
        delta = r_i + r_j - dist
        delta > 0 || continue                     # not in contact (skin layer)

        k = T(contact.k)
        R_eff = effective_radius(T(r_i), T(r_j))
        fn = force_magnitude(contact, k, T(delta), R_eff)
        U = contact_energy(contact, k, T(delta), R_eff)
        energy += U

        # Unit normal from i to j; repulsive force on j is fn*n, on i is -fn*n.
        inv_dist = T(1) / dist
        n = ntuple(d -> T(dx[d]) * inv_dist, D)
        push!(contacts, Contact(i, j, T(delta), T(fn), nothing, n))

        fn_over_dist = fn * inv_dist
        @inbounds for d in 1:D
            F[d, i] -= fn_over_dist * dx[d]
            F[d, j] += fn_over_dist * dx[d]
        end
    end
    return energy, contacts
end

"""
    virial_stress(contacts, x, box) -> Matrix

Virial (mechanical) stress tensor
`sigma = (1/V) sum_contacts r_ij (outer) f_ij`, where `r_ij` is the minimum-image
separation (from i to j) and `f_ij = fn * n` the repulsive contact force. Because
`r_ij = dist * n`, each contact contributes `fn * dist * (n outer n)`, whose trace
is `fn * dist`.
"""
function virial_stress(contacts::Vector{Contact{D,T}}, x::Matrix{<:Any},
                       box::PeriodicBox{D,T}) where {D,T}
    V = volume(box)
    sigma = zeros(T, D, D)
    dx = zeros(T, D)
    @inbounds for c in contacts
        # Minimum-image separation from i to j; the stored normal is n = r_ij / dist.
        @inbounds for d in 1:D
            dx[d] = x[d, c.j] - x[d, c.i]
        end
        minimum_image!(dx, box)
        dist = sqrt(dot(dx, dx))
        fn = c.force_normal
        n = c.normal
        # contribution  fn * dist * (n outer n)
        @inbounds for a in 1:D
            na = fn * dist * n[a]
            for b in 1:D
                sigma[a, b] += na * n[b]
            end
        end
    end
    return sigma ./ V
end

"""
    virial_pressure(contacts, x, box) -> P

Mechanical (virial) pressure `P = trace(sigma) / D` of the contact network. This
is the true mechanical pressure. It differs from the pressure estimate in
`~/repos/GranE/src/pack.m`, which is an *energy-based* estimate (it inverts the
per-grain potential energy to a pressure); pack.m's is used to drive compression,
whereas this virial pressure is the mechanical quantity reported and converged on.

The trace is summed over the diagonal directly rather than via `LinearAlgebra.trace`,
so this file carries no extra dependency beyond Base.
"""
function virial_pressure(contacts::Vector{Contact{D,T}}, x::Matrix{<:Any},
                         box::PeriodicBox{D,T}) where {D,T}
    sigma = virial_stress(contacts, x, box)
    tr = zero(T)
    @inbounds for d in 1:D
        tr += sigma[d, d]
    end
    return tr / T(D)
end
