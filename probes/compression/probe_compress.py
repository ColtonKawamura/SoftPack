"""Probe (not SoftPack code): isotropic compression of a 2D bidisperse packing, periodic box or walls.

Checks the design choices for T-zvs1:
  1. random sequential addition (RSA) of non-touching particles at a dilute packing fraction,
  2. isotropic compression in stages with FIRE 2.0 minimization and bisection on the box length,
  3. pressure from the virial (pair + wall contacts) equals pressure from the wall force.
Units: small diameter 1, k = 1, m = 1, Hookean contacts, frictionless.
"""
import sys, time
import numpy as np

D = 2
FORCE_TOL = float(sys.argv[3]) if len(sys.argv) > 3 else 1e-8     # epsilon_F, relative to <f_n>
P_TARGET, P_TOL = 1e-4, 1e-4                                   # target pressure, relative tolerance
STRAIN_STEP = 1e-2
F_FLOOR = P_TARGET * 1.0 ** (D - 1) / 10      # force-scale floor: P_target d^(D-1) / 10, d = small diameter


def make_diameters(n=256, ratio=1.4, frac_small=0.5):
    ns = int(round(frac_small * n))
    return np.array([1.0] * ns + [ratio] * (n - ns))


def rsa(diam, phi0, periodic, rng):
    """Largest first, uniform draws, accept only if every gap is strictly positive."""
    n = len(diam)
    R = diam / 2
    L = np.sqrt(np.sum(np.pi * R**2) / phi0)
    order = np.argsort(-diam, kind="stable")
    x = np.zeros((n, D))
    placed = []
    draws = 0
    for i in order:
        while True:
            draws += 1
            if periodic:
                p = rng.random(D) * L
            else:
                p = R[i] + rng.random(D) * (L - 2 * R[i])
            ok = True
            if placed:
                dx = x[placed] - p
                if periodic:
                    dx -= L * np.round(dx / L)
                r = np.sqrt((dx**2).sum(1))
                ok = np.all(r - (R[placed] + R[i]) > 0)
            if ok:
                x[i] = p
                placed.append(i)
                break
    return x, L, draws


class NL:
    """Verlet list: pairs closer than R_i + R_j + skin; rebuilt when a particle moves more than skin/2."""
    def __init__(self, x, R, L, periodic, skin=0.4):
        self.skin, self.R, self.periodic = skin, R, periodic
        self.build(x, L)
    def build(self, x, L):
        n = len(self.R)
        dx = x[:, None, :] - x[None, :, :]
        if self.periodic:
            dx -= L * np.round(dx / L)
        r = np.sqrt((dx ** 2).sum(2))
        cand = np.triu((r < self.R[:, None] + self.R[None, :] + self.skin), 1)
        self.ii, self.jj = np.nonzero(cand)
        self.x0 = x.copy()
        self.L0 = L
    def check(self, x, L):
        d = x - self.x0
        if self.periodic:
            d -= L * np.round(d / L)
        if np.sqrt((d ** 2).sum(1)).max() > 0.5 * self.skin * 0.5:
            self.build(x, L)


def forces(x, R, L, periodic, nl=None):
    """Return force array, pair contact count, wall contact count, mean f_n, energy, virial, wall virial, wall forces."""
    n = len(R)
    if nl is None:
        nl = NL(x, R, L, periodic)
    else:
        nl.check(x, L)
    ii, jj = nl.ii, nl.jj
    dx = x[ii] - x[jj]
    if periodic:
        dx -= L * np.round(dx / L)
    r = np.sqrt((dx ** 2).sum(1))
    delta = (R[ii] + R[jj]) - r
    m = delta > 0
    ii, jj, dx, r, delta = ii[m], jj[m], dx[m], r[m], delta[m]
    F = np.zeros_like(x)
    nij = dx / r[:, None]
    for a in range(D):
        F[:, a] += np.bincount(ii, weights=nij[:, a] * delta, minlength=n) - np.bincount(jj, weights=nij[:, a] * delta, minlength=n)
    virial = float(np.sum(delta * r))
    E = 0.5 * float(np.sum(delta ** 2))
    wall_f = np.zeros(2 * D)
    wall_virial = 0.0
    nw = 0
    if not periodic:
        for a in range(D):
            dlo = R - x[:, a]
            dhi = R - (L - x[:, a])
            for side, d_, sign in ((0, dlo, +1), (1, dhi, -1)):
                mm = d_ > 0
                if mm.any():
                    F[mm, a] += sign * d_[mm]
                    wall_f[2 * a + side] += d_[mm].sum()
                    dist = R[mm] - d_[mm]
                    wall_virial += float(np.sum(d_[mm] * dist))
                    E += 0.5 * float(np.sum(d_[mm] ** 2))
                    nw += int(mm.sum())
    nc = len(delta) + nw
    fsum = delta.sum() + wall_f.sum()
    fmean = fsum / nc if nc else 0.0
    return F, len(delta), nw, fmean, E, virial, wall_virial, wall_f


def pressure(x, R, L, periodic):
    F, npair, nw, fmean, E, vir, wvir, wall_f = forces(x, R, L, periodic)
    omega = L**D
    p_virial = (vir + wvir) / (D * omega)               # pair virial plus wall contacts
    p_pair_only = vir / (D * omega)
    p_wall = wall_f.sum() / (2 * D * L ** (D - 1)) if not periodic else float("nan")
    return F, npair, nw, fmean, p_virial, p_pair_only, p_wall


def fire(x, R, L, periodic, m=1.0, max_steps=2_000_000):
    """FIRE 2.0 with the LAMMPS defaults, semi-implicit Euler, from rest."""
    dt0 = np.pi * np.sqrt(0.5) / 50                  # t_col / 50, M_n = m/2, k = 1
    dt, dtmax, dtmin = dt0, 10 * dt0, 0.02 * dt0
    alpha0, delay, grow, shrink, ashrink, uphill_max = 0.25, 20, 1.1, 0.5, 0.99, 2000
    v = np.zeros_like(x)
    alpha, n_down, n_up = alpha0, 0, 0
    step = 0
    nl = NL(x, R, L, periodic)
    while step < max_steps:
        F, npair, nw, fmean, *_ = forces(x, R, L, periodic, nl)
        nc = npair + nw
        if nc == 0:
            return x, step, True, 0
        fmax = np.sqrt((F**2).sum(1)).max()
        if fmax < FORCE_TOL * max(fmean, F_FLOOR):
            return x, step, True, nc
        P = float((F * v).sum())
        if P > 0:
            n_down += 1
            n_up = 0
            vn = np.sqrt((v**2).sum())
            fn_ = np.sqrt((F**2).sum())
            v = (1 - alpha) * v + alpha * vn * F / fn_
            if n_down > delay:
                dt = min(dt * grow, dtmax)
                alpha *= ashrink
        else:
            n_up += 1
            n_down = 0
            if n_up > uphill_max:
                return x, step, False, nc
            if step >= delay:
                if dt * shrink >= dtmin:
                    dt *= shrink
                alpha = alpha0
            x = x - 0.5 * dt * v
            v[:] = 0
            F, *_ = forces(x, R, L, periodic, nl)
        v = v + dt * F / m
        x = x + dt * v
        if periodic:
            x = x % L
        step += 1
    return x, step, False, nc


def compress(diam, phi0, periodic, seed):
    rng = np.random.default_rng(seed)
    R = diam / 2
    x, L, draws = rsa(diam, phi0, periodic, rng)
    # sanity: no contact at the start
    _, npair, nw, *_ = forces(x, R, L, periodic)
    assert npair == 0 and nw == 0
    omega_particles = float(np.sum(np.pi * R**2))
    log = [("start", phi0, 0.0, 0, 0)]
    x_base, L_base = x.copy(), L            # last accepted state (P below the band); every trial starts from it
    eps = STRAIN_STEP
    total_fire = 0
    stages = 0
    rejected = 0
    t0 = time.time()
    while True:
        stages += 1
        Lnew = L_base * (1 - eps)                       # compress the accepted state by one strain step
        x_try = x_base * (Lnew / L_base)
        x_try, nsteps, ok, nc = fire(x_try, R, Lnew, periodic)
        total_fire += nsteps
        F, npair, nw, fmean, p_v, p_pair, p_wall = pressure(x_try, R, Lnew, periodic)
        P = p_v
        phi = omega_particles / Lnew**D
        log.append((stages, phi, P, nc, nsteps, eps))
        print(f'  stage {stages:3d} eps={eps:.2e} phi={phi:.6f} P={P:.3e} contacts={nc} fire_steps={nsteps} t={time.time()-t0:.0f}s', file=sys.stderr, flush=True)
        if abs(P - P_TARGET) <= P_TOL * P_TARGET:
            return dict(x=x_try, L=Lnew, phi=phi, P=P, p_pair_only=p_pair, p_wall=p_wall, npair=npair, nw=nw,
                        stages=stages, rejected=rejected, fire_steps=total_fire, draws=draws, phi0=phi0, log=log,
                        seconds=time.time() - t0, L0=L, R=R, periodic=periodic, ok=ok)
        if P > P_TARGET:                                # overshoot: reject, retry from the same base with half the step
            eps *= 0.5
            rejected += 1
            if eps < 1e-14:
                return dict(P=P, phi=phi, log=log, failed=True, rejected=rejected)
        else:                                           # below the band: accept
            x_base, L_base = x_try, Lnew


if __name__ == "__main__":
    mode = sys.argv[1]            # periodic | walls
    phi0 = float(sys.argv[2])
    diam = make_diameters()
    res = compress(diam, phi0, mode == "periodic", seed=1)
    r = {k: v for k, v in res.items() if k not in ("x", "log", "R")}
    print(mode, r)
    lg = res["log"]
    print("stages:", len(lg) - 1)
