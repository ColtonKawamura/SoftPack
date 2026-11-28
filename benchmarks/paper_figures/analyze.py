"""Analyze the SoftPack paper-benchmark CSV against O'Hern 2003 and Silbert 2010.

Method
------
phi_c is the zero-pressure intercept of phi(P) with the published exponent held fixed
(c = 1 for Hookean, 3/2 for Hertzian), fitted on the low-pressure points P <= 1e-3.
The exponent c is then fitted freely on the asymptotic window 0.002 <= phi - phi_c <= 0.03,
where the overlaps are small and the seed scatter is negligible.  The z exponent is
fitted on the same window with z_c = 2D (frictionless).

Run:
    python3 benchmarks/paper_figures/analyze.py [csv] [outdir]

Needs numpy and matplotlib.
"""
import csv
import os
import sys
from collections import defaultdict

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "paper_benchmarks.csv")
OUTDIR = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.abspath(CSV))

# O'Hern 2003, Phys. Rev. E 68, 011306, Table I
OHERN = {
    (2, "Hookean"):  dict(p0=0.34, c=1.01, Z0=3.6, zexp=0.49, Zc=3.98),
    (2, "Hertzian"): dict(p0=0.27, c=1.50, Z0=3.3, zexp=0.48, Zc=3.98),
    (3, "Hookean"):  dict(p0=0.28, c=1.03, Z0=8.4, zexp=0.47, Zc=5.98),
    (3, "Hertzian"): dict(p0=0.18, c=1.51, Z0=7.4, zexp=0.49, Zc=5.98),
}
OHERN_PHIC = {(2, "Hookean"): 0.842, (2, "Hertzian"): 0.842,
              (3, "Hookean"): 0.648, (3, "Hertzian"): 0.648}

# Silbert 2010, Soft Matter 6, 2918, Table I
SILBERT = {
    2: dict(mu=[0, 0.001, 0.01, 0.1, 0.2, 0.5, 1, 10],
            phi=[0.843, 0.843, 0.842, 0.836, 0.827, 0.801, 0.779, 0.767],
            z=[3.96, 3.86, 3.85, 3.73, 3.59, 3.15, 2.91, 2.97]),
    3: dict(mu=[0, 0.001, 0.01, 0.1, 0.2, 0.5, 1, 10],
            phi=[0.639, 0.638, 0.634, 0.614, 0.595, 0.574, 0.556, 0.544],
            z=[5.96, 5.93, 5.76, 5.17, 4.60, 4.22, 3.98, 3.88]),
}


def load(path):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            if not r.get("P"):
                continue
            r["P"] = float(r["P"]); r["phi"] = float(r["phi"]); r["z"] = float(r["z"])
            r["N"] = int(r["N"]); r["seed"] = int(r["seed"])
            r["dimension"] = int(r["dimension"])
            rows.append(r)
    return rows


def group_ohern(rows):
    groups = defaultdict(lambda: defaultdict(list))
    for r in rows:
        if r["benchmark"] == "ohern":
            groups[(r["dimension"], r["contact"])][r["P"]].append(r)
    out = {}
    for key, byP in groups.items():
        Ps = np.array(sorted(byP))
        out[key] = dict(
            P=Ps,
            phi=np.array([np.mean([q["phi"] for q in byP[p]]) for p in Ps]),
            phi_sd=np.array([np.std([q["phi"] for q in byP[p]]) for p in Ps]),
            z=np.array([np.mean([q["z"] for q in byP[p]]) for p in Ps]),
            z_sd=np.array([np.std([q["z"] for q in byP[p]]) for p in Ps]),
            n=np.array([len(byP[p]) for p in Ps]),
            N=byP[Ps[0]][0]["N"],
        )
    return out


def phic_from_low_pressure(P, phi, exponent):
    """Zero-pressure intercept with the published exponent; fitted on P <= 1e-3."""
    m = P <= 1e-3
    x = P[m] ** (1.0 / exponent)
    A = np.vstack([x, np.ones_like(x)]).T
    coef, *_ = np.linalg.lstsq(A, phi[m], rcond=None)
    return float(coef[1])


def loglog_fit(x, y):
    A = np.vstack([np.log(x), np.ones_like(x)]).T
    coef, *_ = np.linalg.lstsq(A, np.log(y), rcond=None)
    return float(coef[0]), float(np.exp(coef[1]))


def analyze_ohern(data):
    fits = {}
    for key, d in data.items():
        D, contact = key
        exponent = 1.0 if contact == "Hookean" else 1.5
        phic = phic_from_low_pressure(d["P"], d["phi"], exponent)
        delta = d["phi"] - phic
        zc = 4.0 if D == 2 else 6.0
        win = (delta >= 0.002) & (delta <= 0.03) & (d["P"] >= 1e-4)
        if win.sum() < 2:
            win = (delta >= 0.002) & (d["P"] >= 1e-4)
        c, p0 = loglog_fit(delta[win], d["P"][win])
        zw = win & (d["z"] - zc > 0.01)
        if zw.sum() >= 2:
            zexp, Z0 = loglog_fit(delta[zw], d["z"][zw] - zc)
        else:
            zexp, Z0 = np.nan, np.nan
        fits[key] = dict(phic=phic, c=c, p0=p0, zexp=zexp, Z0=Z0,
                         n_pressure=int(win.sum()), n_z=int(zw.sum()))
    return fits


def style():
    plt.rcParams.update({
        "font.size": 9, "axes.labelsize": 9.5, "axes.titlesize": 10,
        "legend.fontsize": 7.2, "xtick.labelsize": 8, "ytick.labelsize": 8,
        "axes.spines.top": False, "axes.spines.right": False,
        "figure.dpi": 160, "savefig.dpi": 300, "savefig.bbox": "tight",
    })


def main():
    style()
    rows = load(CSV)
    data = group_ohern(rows)
    fits = analyze_ohern(data)

    colors = {"Hookean": "#1f77b4", "Hertzian": "#d62728"}
    markers = {"Hookean": "o", "Hertzian": "s"}

    fig1, axes1 = plt.subplots(1, 2, figsize=(7.0, 3.35))
    handles1 = []
    for ax, D in zip(axes1, (2, 3)):
        for contact in ("Hookean", "Hertzian"):
            key = (D, contact)
            if key not in data:
                continue
            d, f = data[key], fits[key]
            delta = d["phi"] - f["phic"]
            m = delta > 0
            h = ax.loglog(delta[m], d["P"][m], markers[contact], color=colors[contact],
                          ms=4.5, mfc="white" if contact == "Hertzian" else colors[contact],
                          mew=1.0, ls="none", label=f"{contact} data")[0]
            xs = np.array([0.002, 0.03])
            hf = ax.loglog(xs, f["p0"] * xs ** f["c"], "-", color=colors[contact],
                           lw=1.0, alpha=0.9, label=f"{contact} fit")[0]
        for contact, slope in (("Hookean", 1.0), ("Hertzian", 1.5)):
            xs = np.array([0.002, 0.03])
            hg = ax.loglog(xs, 0.3 * xs ** slope, ":", color=colors[contact],
                           lw=0.8, alpha=0.6, label=f"slope {slope:.1f}")[0]
        ax.set_xlabel(r"$\varphi-\varphi_c$")
        ax.set_ylabel(r"$P\,d^{2-D}/k$")
        ax.set_title(f"{D}D bidisperse, N={data[(D, 'Hookean')]['N']}")
        ax.set_xlim(1e-4, 0.12)
        ax.text(0.98, 0.04, f"$c$ = {fits[(D, 'Hookean')]['c']:.2f} (Hook),\n"
                            f"{fits[(D, 'Hertzian')]['c']:.2f} (Hertz)",
                transform=ax.transAxes, ha="right", va="bottom", fontsize=7)
    handles1, labels1 = axes1[0].get_legend_handles_labels()
    fig1.legend(handles1, labels1, loc="lower center", ncol=4, frameon=False,
                bbox_to_anchor=(0.5, -0.02), columnspacing=1.2, handletextpad=0.4)
    fig1.subplots_adjust(bottom=0.30)
    fig1.savefig(f"{OUTDIR}/fig1_ohern_pressure_scaling.png")
    fig1.savefig(f"{OUTDIR}/fig1_ohern_pressure_scaling.svg")

    fig2, axes2 = plt.subplots(1, 2, figsize=(7.0, 3.35))
    for ax, D in zip(axes2, (2, 3)):
        zc = 4.0 if D == 2 else 6.0
        for contact in ("Hookean", "Hertzian"):
            key = (D, contact)
            if key not in data:
                continue
            d, f = data[key], fits[key]
            delta = d["phi"] - f["phic"]
            m = (delta > 0) & (d["z"] - zc > 0)
            ax.loglog(delta[m], d["z"][m] - zc, markers[contact], color=colors[contact],
                      ms=4.5, mfc="white" if contact == "Hertzian" else colors[contact],
                      mew=1.0, ls="none", label=f"{contact} data")
            xs = np.array([0.002, 0.03])
            ax.loglog(xs, f["Z0"] * xs ** f["zexp"], "-", color=colors[contact], lw=1.0,
                      label=f"{contact} fit")
        xs = np.array([0.002, 0.03])
        ax.loglog(xs, 3.5 * xs ** 0.5, "k:", lw=0.8, alpha=0.6, label="slope 0.5")
        ax.set_xlabel(r"$\varphi-\varphi_c$")
        ax.set_ylabel(r"$z-z_c$")
        ax.set_title(f"{D}D, $z_c={zc:.0f}$")
        ax.set_xlim(1e-4, 0.12)
        ax.text(0.98, 0.04, f"$z$ = {fits[(D, 'Hookean')]['zexp']:.2f} (Hook),\n"
                            f"{fits[(D, 'Hertzian')]['zexp']:.2f} (Hertz)",
                transform=ax.transAxes, ha="right", va="bottom", fontsize=7)
    handles2, labels2 = axes2[0].get_legend_handles_labels()
    fig2.legend(handles2, labels2, loc="lower center", ncol=5, frameon=False,
                bbox_to_anchor=(0.5, -0.02), columnspacing=1.0, handletextpad=0.4)
    fig2.subplots_adjust(bottom=0.30)
    fig2.savefig(f"{OUTDIR}/fig2_ohern_coordination_scaling.png")
    fig2.savefig(f"{OUTDIR}/fig2_ohern_coordination_scaling.svg")

    # --- Silbert friction comparison -------------------------------------
    sil = defaultdict(lambda: defaultdict(list))
    for r in rows:
        if r["benchmark"] == "silbert":
            mu = 0.0 if r["mu"] == "none" else float(r["mu"])
            sil[(r["dimension"], mu)][r["P"]].append(r)
    anchor2 = [r for r in rows if r["benchmark"] == "ohern" and r["dimension"] == 2
               and r["contact"] == "Hookean" and abs(r["P"] - 1e-4) < 1e-12]
    if anchor2:
        sil[(2, 0.0)][1e-4] = anchor2

    fig3, axes3 = plt.subplots(2, 2, figsize=(7.0, 5.3), sharex=True)
    sil_rows = []
    for col, D in enumerate((2, 3)):
        mu_s, phi_s, z_s, phi_e, z_e = [], [], [], [], []
        for mu in sorted(m for (d, m) in sil if d == D and m is not None):
            runs = [q for P in sil[(D, mu)] for q in sil[(D, mu)][P]]
            mu_s.append(mu)
            phi_s.append(np.mean([q["phi"] for q in runs]))
            z_s.append(np.mean([q["z"] for q in runs]))
            phi_e.append(np.std([q["phi"] for q in runs]))
            z_e.append(np.std([q["z"] for q in runs]))
        ax = axes3[0, col]
        ax.errorbar(SILBERT[D]["mu"], SILBERT[D]["phi"], yerr=None, fmt="s--",
                    color="0.35", ms=4, lw=0.9, label="Silbert 2010 (Table I)")
        ax.errorbar(mu_s, phi_s, yerr=phi_e, fmt="o-", color="#1f77b4", ms=4,
                    lw=1.1, capsize=2, label="SoftPack, P = $10^{-4}$")
        if D == 2:
            ax.axhline(0.835, color="0.6", lw=0.7, ls=":", label="Xiong 2019 limits")
            ax.axhline(0.765, color="0.6", lw=0.7, ls=":")
        ax.set_xscale("log"); ax.set_ylabel(r"$\varphi$")
        ax.set_title(f"{D}D, P = $10^{{-4}}$")
        ax.legend(loc="lower left", frameon=False)

        ax = axes3[1, col]
        ax.errorbar(SILBERT[D]["mu"], SILBERT[D]["z"], fmt="s--", color="0.35",
                    ms=4, lw=0.9, label="Silbert 2010 (Table I)")
        ax.errorbar(mu_s, z_s, yerr=z_e, fmt="o-", color="#1f77b4", ms=4,
                    lw=1.1, capsize=2, label="SoftPack, P = $10^{-4}$")
        if D == 2:
            ax.axhline(4.0, color="0.6", lw=0.7, ls=":")
            ax.axhline(3.0, color="0.6", lw=0.7, ls=":")
        ax.set_xscale("log"); ax.set_xlabel(r"$\mu$"); ax.set_ylabel(r"$z$")
        ax.legend(loc="lower left", frameon=False)
        sil_rows.append((D, mu_s, phi_s, z_s))

    fig3.savefig(f"{OUTDIR}/fig3_friction_silbert.png")
    fig3.savefig(f"{OUTDIR}/fig3_friction_silbert.svg")

    # --- tables -----------------------------------------------------------
    lines = ["# SoftPack paper-benchmark fits", "",
             "`phi_c` is the zero-pressure intercept with the published exponent held fixed,",
             "fitted on P <= 1e-3; `c` is then fitted on 0.002 <= dphi <= 0.03.", "",
             "| D | contact | N | phi_c (fit) | phi* (paper) | c (fit) | c (paper) | p0 (fit) | p0 (paper) | z exp (fit) | z exp (paper) | Z0 (fit) |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for key in sorted(fits, key=lambda k: (k[0], k[1])):
        f = fits[key]; ref = OHERN[key]; D, contact = key
        lines.append(f"| {D} | {contact} | {data[key]['N']} | {f['phic']:.4f} | "
                     f"{OHERN_PHIC[key]:.3f} | {f['c']:.3f} | {ref['c']:.2f} | "
                     f"{f['p0']:.3f} | {ref['p0']:.2f} | {f['zexp']:.3f} | "
                     f"{ref['zexp']:.2f} | {f['Z0']:.2f} |")
    open(f"{OUTDIR}/fit_table.md", "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))

    # Silbert deviations at the measured points
    lines2 = ["", "## Silbert 2010 comparison", "",
              "| D | mu | phi SoftPack | phi Silbert | delta phi | z SoftPack | z Silbert | delta z |",
              "|---|---|---|---|---|---|---|---|"]
    for D, mu_s, phi_s, z_s in sil_rows:
        for mu, ph, zz in zip(mu_s, phi_s, z_s):
            ref = SILBERT[D]
            if mu in ref["mu"]:
                j = ref["mu"].index(mu)
                lines2.append(f"| {D} | {mu:g} | {ph:.4f} | {ref['phi'][j]:.3f} | "
                              f"{ph - ref['phi'][j]:+.4f} | {zz:.3f} | {ref['z'][j]:.2f} | "
                              f"{zz - ref['z'][j]:+.3f} |")
    open(f"{OUTDIR}/silbert_table.md", "w").write("\n".join(lines2) + "\n")
    print("\n".join(lines2))


if __name__ == "__main__":
    main()
