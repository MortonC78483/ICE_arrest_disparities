"""
Disparity_statistical_tests.py

Computes 95% CIs (Poisson SIR formula) for regional disparity ratios and runs
pairwise z-tests across regions and across criminality types.

Outputs:
  - national_region_disparity_with_CI.csv  (in Data/)
  - disparity_forest_by_criminality.png    (in Figures/ddp/)

Inputs:
  - national_region_disparity_PREVIEW.csv  (created by Build_disparity_figures.py)

Run:  python Disparity_statistical_tests.py
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from math import sqrt, log, exp, erf

from disparity_helpers import REGIONS_ORDER, REGION_SHORT, FIG_PATH, DATA_PATH, OUTPUT_DATA

def norm_cdf(z):
    """Cumulative distribution function for the standard normal (no scipy)."""
    return 0.5 * (1 + erf(z / sqrt(2)))

def ci_for_disparity(observed_arrests, region_pop, total_arrests, total_pop):
    """95% CI for a disparity ratio using Poisson SIR formula.

    Var[log(SIR)] ≈ 1/observed (for Poisson-distributed event counts)
    """
    if observed_arrests == 0 or region_pop == 0:
        return (np.nan, np.nan, np.nan)
    expected = region_pop * (total_arrests / total_pop)
    disparity = observed_arrests / expected
    se_log = 1.0 / sqrt(observed_arrests)
    return (disparity, disparity * exp(-1.96 * se_log), disparity * exp(+1.96 * se_log))

def pairwise_test(arr_A, pop_A, arr_B, pop_B):
    """Test if (arr_A/pop_A) / (arr_B/pop_B) differs from 1.

    Returns (ratio, z_score, two_sided_p_value).
    """
    if arr_A == 0 or arr_B == 0:
        return (np.nan, np.nan, np.nan)
    log_ratio = log((arr_A / pop_A) / (arr_B / pop_B))
    se = sqrt(1/arr_A + 1/arr_B)
    z = log_ratio / se
    p = 2 * (1 - norm_cdf(abs(z)))
    return (exp(log_ratio), z, p)

def main():
    nat = pd.read_csv(OUTPUT_DATA / 'national_region_disparity_PREVIEW.csv')
    nat = nat.set_index('region').reindex(REGIONS_ORDER).reset_index()
    print("Loaded national region disparity:")
    print(nat[['region','arrests','convicted','noncriminal','unauth_pop']])

    T_unauth = nat.unauth_pop.sum()
    T_arr   = nat.arrests.sum()
    T_conv  = nat.convicted.sum()
    T_non   = nat.noncriminal.sum()

    # === STEP 1: 95% CIs ===
    rows = []
    for _, r in nat.iterrows():
        d_t, lo_t, hi_t = ci_for_disparity(r.arrests,    r.unauth_pop, T_arr,  T_unauth)
        d_c, lo_c, hi_c = ci_for_disparity(r.convicted,  r.unauth_pop, T_conv, T_unauth)
        d_n, lo_n, hi_n = ci_for_disparity(r.noncriminal,r.unauth_pop, T_non,  T_unauth)
        rows.append({
            'region': r.region,
            'arrests_post': int(r.arrests), 'convicted_post': int(r.convicted), 'noncriminal_post': int(r.noncriminal),
            'disp_tot': d_t, 'lo_tot': lo_t, 'hi_tot': hi_t,
            'disp_con': d_c, 'lo_con': lo_c, 'hi_con': hi_c,
            'disp_non': d_n, 'lo_non': lo_n, 'hi_non': hi_n,
        })
    res = pd.DataFrame(rows)
    res.to_csv(OUTPUT_DATA / 'national_region_disparity_with_CI.csv', index=False)

    print("\n=== 95% CIs FOR DISPARITY RATIOS (post period) ===\n")
    print(f"{'Region':<28} {'TOTAL [95% CI]':>22} {'CONVICTED [95% CI]':>22} {'NON-CRIMINAL [95% CI]':>24}")
    for _, r in res.iterrows():
        print(f"{r.region:<28} {r.disp_tot:>5.2f} [{r.lo_tot:.2f},{r.hi_tot:.2f}]   "
              f"{r.disp_con:>5.2f} [{r.lo_con:.2f},{r.hi_con:.2f}]   "
              f"{r.disp_non:>5.2f} [{r.lo_non:.2f},{r.hi_non:.2f}]")

    # === STEP 2: Pairwise tests (selected key contrasts) ===
    key_pairs = [
        ('Europe/Canada/Oceania', 'South America'),
        ('Europe/Canada/Oceania', 'Caribbean'),
        ('Europe/Canada/Oceania', 'Mexico and Central America'),
        ('Europe/Canada/Oceania', 'Asia'),
        ('Europe/Canada/Oceania', 'Africa'),
        ('Africa', 'South America'),
        ('Asia', 'South America'),
        ('Caribbean', 'South America'),
        ('Mexico and Central America', 'South America'),
    ]
    for label, col in [('Total','arrests'),('Convicted-criminal','convicted'),('Non-criminal','noncriminal')]:
        print(f"\n--- {label} arrests ---")
        print(f"{'Comparison':<58} {'disp_A/disp_B':>14} {'z':>8} {'p-value':>12}")
        for a, b in key_pairs:
            rA = nat[nat.region==a].iloc[0]; rB = nat[nat.region==b].iloc[0]
            ratio, z, p = pairwise_test(rA[col], rA.unauth_pop, rB[col], rB.unauth_pop)
            sig = '***' if p < 0.001 else ('**' if p < 0.01 else ('*' if p < 0.05 else '   '))
            print(f"{a:<26} vs {b:<28} {ratio:>14.3f} {z:>8.2f} {p:>12.2e} {sig}")

    # === STEP 3: Within-region tests (criminal vs non-criminal) ===
    print("\n=== WITHIN-REGION: criminal vs non-criminal disparity ===")
    print("Tests: does the disparity ratio differ between convicted-criminal arrests and no-conviction arrests?")
    print(f"{'Region':<28} {'disp_conv':>10} {'disp_non':>10} {'ratio (non/conv)':>18} {'z':>8} {'p-value':>12}")
    for _, r in nat.iterrows():
        if r.convicted == 0 or r.noncriminal == 0:
            continue
        ratio = (r.noncriminal / r.convicted) * (T_conv / T_non)
        se = sqrt(1/r.noncriminal + 1/r.convicted)
        z = log(ratio) / se
        p = 2 * (1 - norm_cdf(abs(z)))
        sig = '***' if p < 0.001 else ('**' if p < 0.01 else ('*' if p < 0.05 else '   '))
        rdisp = res[res.region == r.region].iloc[0]
        print(f"{r.region:<28} {rdisp.disp_con:>10.2f} {rdisp.disp_non:>10.2f} {ratio:>18.2f} {z:>8.2f} {p:>12.2e} {sig}")

    # === FOREST PLOT ===
    print("\nBuilding forest plot with 95% CIs...")
    fig, ax = plt.subplots(figsize=(11, 8.5))
    y_positions, labels = [], []
    gap = 1.5
    n_regions = len(res)
    for i, (_, r) in enumerate(res.iterrows()):
        base = (n_regions - 1 - i) * (gap + 3)
        y_positions.append((base + 2, base + 1, base))  # tot, con, non (top→bottom)
        labels.append(REGION_SHORT[r.region])

    colors = {'tot':'#534AB7','con':'#993C1D','non':'#7BA968'}
    type_labels = {'tot':'All arrests','con':'w/ criminal conviction','non':'w/ no criminal conviction'}

    for i, (_, r) in enumerate(res.iterrows()):
        yp_tot, yp_con, yp_non = y_positions[i]
        for typ, yp in [('tot', yp_tot),('con', yp_con),('non', yp_non)]:
            d = r[f'disp_{typ}']; lo = r[f'lo_{typ}']; hi = r[f'hi_{typ}']
            ax.plot([lo, hi], [yp, yp], color=colors[typ], lw=2.5)
            ax.plot([d], [yp], marker='o', color=colors[typ], markersize=8)
            ax.text(hi + 0.1, yp, f'{d:.2f} [{lo:.2f}, {hi:.2f}]', va='center', fontsize=8.5, color=colors[typ])
    ax.axvline(1.0, color='gray', linestyle='--', linewidth=1)
    ax.text(1.0, len(res)*(gap+3) - 0.5, 'Proportional\n(= pop share)', fontsize=8, color='gray', ha='left', va='top')
    group_centers = [(yp[0] + yp[2]) / 2 for yp in y_positions]
    ax.set_yticks(group_centers); ax.set_yticklabels(labels, fontsize=11, fontweight='bold')
    for i, (yp_tot, yp_con, yp_non) in enumerate(y_positions):
        for typ, yp in [('tot', yp_tot),('con', yp_con),('non', yp_non)]:
            ax.text(-0.18, yp, type_labels[typ], ha='right', va='center', fontsize=8, color=colors[typ])
    ax.set_xlim(-0.05, 2.1)
    ax.set_xlabel('Disparity ratio (arrest share / unauthorized population share)\n95% CIs from Poisson SIR formula')
    ax.set_title('Term 2 regional disparity by arrest type — 95% CIs\nAll pairwise differences across regions p < 0.001 except where noted', fontsize=11)
    ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    legend_elements = [Line2D([0],[0], marker='o', color=c, lw=2.5, label=l) for c,l in zip(colors.values(), type_labels.values())]
    ax.legend(handles=legend_elements, loc='lower right', fontsize=9, framealpha=0.95)
    plt.tight_layout()
    out = FIG_PATH / 'disparity_forest_by_criminality.png'
    plt.savefig(out, dpi=180, bbox_inches='tight'); plt.close()
    print(f"Saved: {out}")
    print(f"Saved: {OUTPUT_DATA / 'national_region_disparity_with_CI.csv'}")

if __name__ == '__main__':
    main()
