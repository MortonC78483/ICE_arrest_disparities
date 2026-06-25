"""
Build_pew_disparity.py

Parallel disparity analysis using Pew Research Center 2023 national denominators
as a sensitivity / robustness check vs. MPI state-summed denominators.

Pew's national 2023 estimates (from country-trends.xlsx) provide complete coverage
for each region — including countries that MPI's state-summed approach undercounts
(Cuba, Venezuela, Colombia, India, China, etc.).

Key methodological points:
  - Both Pew and MPI use the same broad definition of "unauthorized" (DACA, TPS,
    parole, asylum-pending all included). The differences are measurement, not
    definitional.
  - Pew's 2023 totals are 14M (Pew) vs 13.74M (MPI) — very similar.
  - Country-level differences arise because MPI's state×country file only captures
    top 2-5 countries per state; Pew has true national totals.

Outputs:
  - pew_vs_mpi_disparity_comparison.csv
  - pew_national_region_disparity_with_CI.csv
  - pew_disparity_trajectory_60day.csv
  Figures (in Figures/ddp/):
  - disparity_MPI_vs_Pew_comparison.png
  - disparity_forest_by_criminality_PEW.png
  - disparity_pre_post_slopegraph_PEW.png
  - disparity_trajectory_60day_PEW.png
  - disparity_trajectory_deviation_60day_PEW.png

Run:  python Build_pew_disparity.py
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.lines import Line2D
from math import sqrt, exp, erf

from disparity_helpers import (
    load_ddp, load_mpi_state_region, REGIONS_ORDER, REGION_SHORT,
    FIG_PATH, DATA_PATH, OUTPUT_DATA, T2_ANCHOR,
)

# === Pew 2023 national denominators ===
# Aggregated to match our MPI region categories.
# Source: RE_2025.08.21_Unauthorized-immigrants_detailed-tables_country-trends.xlsx
# Pew categories combined as follows:
#   Pew Mexico (4.25M) + Pew Central America (2.85M) → "Mexico and Central America"
#   Pew Asia (1.75M) + Pew Middle East (250K) → "Asia"
#                                                (Pew's Middle East includes North Africa;
#                                                 small under-count of true Asia)
#   Pew Africa (sub-Saharan, 475K) → "Africa"
#                                    (small under-count for North Africa, which is in Middle East)
#   Pew Europe & Canada (1.05M) → "Europe/Canada/Oceania"
#                                  (small under-count for Oceania, which is in Pew "Other")
PEW_REGION_2023 = {
    'Mexico and Central America':  7_100_000,
    'South America':               2_100_000,
    'Caribbean':                   1_150_000,
    'Asia':                        2_000_000,
    'Africa':                        475_000,
    'Europe/Canada/Oceania':       1_050_000,
}
PEW_TOTAL = sum(PEW_REGION_2023.values())  # ~13,875,000 (vs Pew published total 14,000,000)

# Pew's separate Mexico vs Central America (enables clean Mex vs CA split)
PEW_MEXICO = 4_250_000
PEW_CENTRAL_AMERICA = 2_850_000

REGION_COLORS = {
    'Mexico and Central America': '#993C1D',
    'Caribbean':                  '#E07B30',
    'South America':              '#534AB7',
    'Asia':                       '#7BA968',
    'Africa':                     '#A0628F',
    'Europe/Canada/Oceania':      '#3B7E9C',
}

# === HELPERS ===
def safe_disp(arr, total_arr, pop, total_pop):
    if total_arr == 0 or total_pop == 0 or pop == 0:
        return np.nan
    return (arr/total_arr) / (pop/total_pop)

def ci_for_disparity(observed, region_pop, total_arrests, total_pop):
    """Poisson SIR 95% CI."""
    if observed == 0 or region_pop == 0:
        return (np.nan, np.nan, np.nan)
    expected = region_pop * (total_arrests / total_pop)
    disparity = observed / expected
    se_log = 1.0 / sqrt(observed)
    return (disparity, disparity * exp(-1.96 * se_log), disparity * exp(+1.96 * se_log))

def assign_window(d):
    """Assign a date offset to a 60-day non-overlapping window index."""
    return -((-d - 1) // 60 + 1) if d < 0 else d // 60

# === MAIN ===
def main():
    print("Loading DDP and computing Pew-based disparities...")
    df_full = load_ddp(restrict_to_t2_window=False)
    df_full = df_full[df_full.region != ''].copy()
    df_full['country_upper'] = df_full.citizenship_country.str.strip().str.upper()
    mpi = load_mpi_state_region()
    df_full = df_full[df_full.state_clean.isin(mpi.state_upper.unique())].copy()
    df_full = df_full[(df_full.date >= T2_ANCHOR - pd.Timedelta(days=420))
                      & (df_full.date <= T2_ANCHOR + pd.Timedelta(days=420))].copy()
    df_full['days_from_inaug'] = (df_full.date - T2_ANCHOR).dt.days

    # Standard ±414 split for static analyses
    df_414 = df_full[(df_full.date >= T2_ANCHOR - pd.Timedelta(days=414))
                     & (df_full.date <= T2_ANCHOR + pd.Timedelta(days=414))].copy()
    pre = df_414[df_414.post == 0]
    post = df_414[df_414.post == 1]

    # MPI denominators for comparison
    mpi_pop = mpi.groupby('region').unauth_pop.sum().to_dict()
    MPI_TOTAL = sum(mpi_pop.values())

    # ============================================================
    # COMPARISON TABLE: MPI vs Pew (post period)
    # ============================================================
    arr_post = post.groupby('region').agg(
        arrests=('post','count'),
        convicted=('convicted','sum'),
        noncriminal=('noncriminal','sum'),
    ).reset_index()
    T_arr = arr_post.arrests.sum()
    T_conv = arr_post.convicted.sum()
    T_non = arr_post.noncriminal.sum()

    # Mexico vs Central America split (Pew enables this)
    df_mca = post[post.region == 'Mexico and Central America'].copy()
    df_mca['is_mexico'] = (df_mca.country_upper == 'MEXICO').astype(int)
    mex_arr = df_mca.is_mexico.sum()
    mex_conv = df_mca[df_mca.is_mexico==1].convicted.sum()
    mex_non = df_mca[df_mca.is_mexico==1].noncriminal.sum()
    ca_arr = (1 - df_mca.is_mexico).sum()
    ca_conv = df_mca[df_mca.is_mexico==0].convicted.sum()
    ca_non = df_mca[df_mca.is_mexico==0].noncriminal.sum()

    rows = []
    rows.append({'group': 'Mexico (alone)',
                 'arrests': mex_arr, 'convicted': mex_conv, 'noncriminal': mex_non,
                 'mpi_pop': np.nan, 'pew_pop': PEW_MEXICO,
                 'mpi_disp_total': np.nan, 'mpi_disp_conv': np.nan, 'mpi_disp_non': np.nan,
                 'pew_disp_total': safe_disp(mex_arr, T_arr, PEW_MEXICO, PEW_TOTAL),
                 'pew_disp_conv':  safe_disp(mex_conv, T_conv, PEW_MEXICO, PEW_TOTAL),
                 'pew_disp_non':   safe_disp(mex_non, T_non, PEW_MEXICO, PEW_TOTAL)})
    rows.append({'group': 'Central America',
                 'arrests': ca_arr, 'convicted': ca_conv, 'noncriminal': ca_non,
                 'mpi_pop': np.nan, 'pew_pop': PEW_CENTRAL_AMERICA,
                 'mpi_disp_total': np.nan, 'mpi_disp_conv': np.nan, 'mpi_disp_non': np.nan,
                 'pew_disp_total': safe_disp(ca_arr, T_arr, PEW_CENTRAL_AMERICA, PEW_TOTAL),
                 'pew_disp_conv':  safe_disp(ca_conv, T_conv, PEW_CENTRAL_AMERICA, PEW_TOTAL),
                 'pew_disp_non':   safe_disp(ca_non, T_non, PEW_CENTRAL_AMERICA, PEW_TOTAL)})

    for r in REGIONS_ORDER:
        rrow = arr_post[arr_post.region == r].iloc[0]
        arr = int(rrow.arrests); conv = int(rrow.convicted); non = int(rrow.noncriminal)
        rows.append({'group': r,
                     'arrests': arr, 'convicted': conv, 'noncriminal': non,
                     'mpi_pop': mpi_pop[r], 'pew_pop': PEW_REGION_2023[r],
                     'mpi_disp_total': safe_disp(arr, T_arr, mpi_pop[r], MPI_TOTAL),
                     'mpi_disp_conv':  safe_disp(conv, T_conv, mpi_pop[r], MPI_TOTAL),
                     'mpi_disp_non':   safe_disp(non, T_non, mpi_pop[r], MPI_TOTAL),
                     'pew_disp_total': safe_disp(arr, T_arr, PEW_REGION_2023[r], PEW_TOTAL),
                     'pew_disp_conv':  safe_disp(conv, T_conv, PEW_REGION_2023[r], PEW_TOTAL),
                     'pew_disp_non':   safe_disp(non, T_non, PEW_REGION_2023[r], PEW_TOTAL)})

    cmp = pd.DataFrame(rows)
    cmp.to_csv(OUTPUT_DATA / 'pew_vs_mpi_disparity_comparison.csv', index=False)

    # ============================================================
    # FIGURE: MPI vs Pew side-by-side bar chart
    # ============================================================
    plot_groups = [
        ('Mexico (alone)', 'Mexico (alone)\n(Pew only)'),
        ('Central America', 'Central America\n(Pew only)'),
        ('Mexico and Central America', 'Mexico/CA'),
        ('South America', 'S. America'),
        ('Caribbean', 'Caribbean'),
        ('Asia', 'Asia'),
        ('Africa', 'Africa'),
        ('Europe/Canada/Oceania', 'Eur/Can/Oce'),
    ]
    fig, axes = plt.subplots(1, 3, figsize=(17, 7), sharey=True)
    for ax, (key, title) in zip(axes, [('total','All arrests'),('conv','w/ criminal conviction'),('non','w/ no criminal conviction')]):
        labels, mpi_vals, pew_vals = [], [], []
        for grp, lbl in plot_groups:
            row = cmp[cmp.group == grp].iloc[0]
            labels.append(lbl)
            mpi_vals.append(row[f'mpi_disp_{key}'])
            pew_vals.append(row[f'pew_disp_{key}'])
        y = np.arange(len(labels))
        h = 0.38
        bars_m = ax.barh(y - h/2, [v if not pd.isna(v) else 0 for v in mpi_vals], h, label='MPI denominator', color='#993C1D', alpha=0.9)
        bars_p = ax.barh(y + h/2, pew_vals, h, label='Pew denominator', color='#534AB7', alpha=0.9)
        for b, v in zip(bars_m, mpi_vals):
            if pd.isna(v): b.set_alpha(0)
        for i, (m, p) in enumerate(zip(mpi_vals, pew_vals)):
            if not pd.isna(m): ax.text(m + 0.04, i - h/2, f'{m:.2f}', va='center', fontsize=9, color='#993C1D')
            ax.text(p + 0.04, i + h/2, f'{p:.2f}', va='center', fontsize=9, color='#534AB7')
        ax.axvline(1.0, color='gray', linestyle='--', linewidth=1, alpha=0.7)
        ax.set_yticks(y); ax.set_yticklabels(labels, fontsize=10); ax.invert_yaxis()
        ax.set_xlim(0, max(2.0, max(pew_vals) * 1.15))
        ax.set_title(title, fontsize=11); ax.set_xlabel('Disparity ratio')
        ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False); ax.grid(axis='x', alpha=0.3)
        if ax is axes[0]: ax.legend(loc='lower right', fontsize=9, framealpha=0.95)
    fig.suptitle('Disparity ratio: MPI state-summed vs. Pew national denominators (post period)\nMex/Central America split available with Pew only', fontsize=12, y=1.0)
    plt.tight_layout()
    plt.savefig(FIG_PATH / 'disparity_MPI_vs_Pew_comparison.png', dpi=180, bbox_inches='tight'); plt.close()

    # ============================================================
    # FOREST PLOT (Pew, post period)
    # ============================================================
    rows_ci = []
    for r in REGIONS_ORDER:
        sub = post[post.region == r]
        arr = len(sub); conv = sub.convicted.sum(); non = sub.noncriminal.sum()
        pop = PEW_REGION_2023[r]
        d_t, lo_t, hi_t = ci_for_disparity(arr,  pop, T_arr,  PEW_TOTAL)
        d_c, lo_c, hi_c = ci_for_disparity(conv, pop, T_conv, PEW_TOTAL)
        d_n, lo_n, hi_n = ci_for_disparity(non,  pop, T_non,  PEW_TOTAL)
        rows_ci.append({'region': r,
            'disp_tot': d_t, 'lo_tot': lo_t, 'hi_tot': hi_t,
            'disp_con': d_c, 'lo_con': lo_c, 'hi_con': hi_c,
            'disp_non': d_n, 'lo_non': lo_n, 'hi_non': hi_n})
    res = pd.DataFrame(rows_ci)
    res.to_csv(OUTPUT_DATA / 'pew_national_region_disparity_with_CI.csv', index=False)

    fig, ax = plt.subplots(figsize=(11, 8.5))
    y_positions, labels = [], []
    gap = 1.5; n_regions = len(res)
    for i, (_, r) in enumerate(res.iterrows()):
        base = (n_regions - 1 - i) * (gap + 3)
        y_positions.append((base + 2, base + 1, base))
        labels.append(REGION_SHORT[r.region])
    colors = {'tot':'#534AB7','con':'#993C1D','non':'#7BA968'}
    type_labels = {'tot':'All arrests','con':'w/ criminal conviction','non':'w/ no criminal conviction'}
    for i, (_, r) in enumerate(res.iterrows()):
        yp_tot, yp_con, yp_non = y_positions[i]
        for typ, yp in [('tot', yp_tot),('con', yp_con),('non', yp_non)]:
            d, lo, hi = r[f'disp_{typ}'], r[f'lo_{typ}'], r[f'hi_{typ}']
            ax.plot([lo, hi], [yp, yp], color=colors[typ], lw=2.5)
            ax.plot([d], [yp], marker='o', color=colors[typ], markersize=8)
            ax.text(hi + 0.06, yp, f'{d:.2f} [{lo:.2f}, {hi:.2f}]', va='center', fontsize=8.5, color=colors[typ])
    ax.axvline(1.0, color='gray', linestyle='--', linewidth=1)
    group_centers = [(yp[0] + yp[2]) / 2 for yp in y_positions]
    ax.set_yticks(group_centers); ax.set_yticklabels(labels, fontsize=11, fontweight='bold')
    for i, (yp_tot, yp_con, yp_non) in enumerate(y_positions):
        for typ, yp in [('tot', yp_tot),('con', yp_con),('non', yp_non)]:
            ax.text(-0.13, yp, type_labels[typ], ha='right', va='center', fontsize=8, color=colors[typ])
    ax.set_xlim(-0.05, 1.95)
    ax.set_xlabel('Disparity ratio (arrest share / unauthorized population share)\n95% CIs from Poisson SIR formula. Denominators: Pew 2023 national estimates.')
    ax.set_title('Term 2 regional disparity with Pew denominators — point estimates + 95% CIs', fontsize=11)
    ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    legend_elements = [Line2D([0],[0], marker='o', color=c, lw=2.5, label=l) for c,l in zip(colors.values(), type_labels.values())]
    ax.legend(handles=legend_elements, loc='lower right', fontsize=9, framealpha=0.95)
    plt.tight_layout()
    plt.savefig(FIG_PATH / 'disparity_forest_by_criminality_PEW.png', dpi=180, bbox_inches='tight'); plt.close()

    # ============================================================
    # SLOPEGRAPH (Pew, pre vs post)
    # ============================================================
    def disp(period_df, region, pop, total_pop, conv_filter=None):
        sub = period_df[period_df.region == region]
        if conv_filter is not None:
            sub = sub[sub.convicted == conv_filter]
        arr = len(sub)
        period_total = len(period_df) if conv_filter is None else len(period_df[period_df.convicted == conv_filter])
        return safe_disp(arr, period_total, pop, total_pop)

    slope_data = {}
    for period, sub_df in [('pre', pre), ('post', post)]:
        slope_data[period] = {'tot': {}, 'con': {}, 'non': {}}
        for r in REGIONS_ORDER:
            slope_data[period]['tot'][r] = disp(sub_df, r, PEW_REGION_2023[r], PEW_TOTAL, None)
            slope_data[period]['con'][r] = disp(sub_df, r, PEW_REGION_2023[r], PEW_TOTAL, 1)
            slope_data[period]['non'][r] = disp(sub_df, r, PEW_REGION_2023[r], PEW_TOTAL, 0)

    fig, axes = plt.subplots(1, 3, figsize=(15, 7), sharey=True)
    for ax, (key, title) in zip(axes, [('tot','All arrests'),('con','w/ criminal conviction'),('non','w/ no criminal conviction')]):
        for r in REGIONS_ORDER:
            y_pre  = slope_data['pre'][key][r]; y_post = slope_data['post'][key][r]
            color = REGION_COLORS[r]
            ax.plot([0, 1], [y_pre, y_post], '-', color=color, linewidth=2.5, alpha=0.85)
            ax.scatter([0, 1], [y_pre, y_post], color=color, s=70, zorder=3, edgecolor='white', linewidth=1.5)
            ax.text(-0.07, y_pre, f'{REGION_SHORT[r]}: {y_pre:.2f}', ha='right', va='center', color=color, fontsize=9.5, fontweight='bold')
            ax.text(1.07, y_post, f'{y_post:.2f}', ha='left', va='center', color=color, fontsize=9.5, fontweight='bold')
        ax.axhline(1.0, color='gray', linestyle='--', linewidth=1, alpha=0.6)
        ax.set_xlim(-0.6, 1.6)
        all_vals = list(slope_data['pre'][key].values()) + list(slope_data['post'][key].values())
        ax.set_ylim(0, max(2.0, max(v for v in all_vals if not pd.isna(v)) * 1.1))
        ax.set_xticks([0, 1])
        ax.set_xticklabels(['Pre\n(Biden, last 414 days)', 'Post\n(Trump 2, first 414 days)'], fontsize=10)
        ax.set_title(title, fontsize=11)
        ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
        if ax is axes[0]: ax.set_ylabel('Disparity ratio (>1 = over-targeted)', fontsize=11)
    fig.suptitle('Pre vs post Trump 2: regional disparity slopegraph (Pew 2023 denominators)', fontsize=12, y=1.0)
    plt.tight_layout()
    plt.savefig(FIG_PATH / 'disparity_pre_post_slopegraph_PEW.png', dpi=180, bbox_inches='tight'); plt.close()

    # ============================================================
    # TRAJECTORY (Pew, 60-day windows)
    # ============================================================
    df_full['win_idx'] = df_full.days_from_inaug.apply(assign_window).astype(int)
    rows = []
    for win_idx, sub in df_full.groupby('win_idx'):
        center_days = (win_idx*60 + (win_idx+1)*60) / 2
        center_date = T2_ANCHOR + pd.Timedelta(days=center_days)
        by_region = sub.groupby('region').agg(arrests=('post','count'), convicted=('convicted','sum'), noncriminal=('noncriminal','sum')).reset_index()
        T_arr_w = by_region.arrests.sum(); T_conv_w = by_region.convicted.sum(); T_non_w = by_region.noncriminal.sum()
        for r in REGIONS_ORDER:
            rrow = by_region[by_region.region == r]
            arr  = int(rrow.arrests.iloc[0]) if len(rrow) else 0
            conv = int(rrow.convicted.iloc[0]) if len(rrow) else 0
            non  = int(rrow.noncriminal.iloc[0]) if len(rrow) else 0
            pop = PEW_REGION_2023[r]
            rows.append({'win_idx': win_idx, 'center_days': center_days, 'center_date': center_date, 'region': r,
                'arrests': arr, 'convicted': conv, 'noncriminal': non,
                'disp_total': safe_disp(arr, T_arr_w, pop, PEW_TOTAL),
                'disp_conv':  safe_disp(conv, T_conv_w, pop, PEW_TOTAL),
                'disp_non':   safe_disp(non, T_non_w, pop, PEW_TOTAL)})
    ts = pd.DataFrame(rows)
    ts.to_csv(OUTPUT_DATA / 'pew_disparity_trajectory_60day.csv', index=False)

    # Compute deviation from pre-baseline
    pre_baselines = ts[ts.win_idx < 0].groupby('region')[['disp_total','disp_conv','disp_non']].mean()
    ts['dev_total'] = ts.apply(lambda r: r.disp_total - pre_baselines.loc[r.region, 'disp_total'], axis=1)
    ts['dev_conv']  = ts.apply(lambda r: r.disp_conv  - pre_baselines.loc[r.region, 'disp_conv'],  axis=1)
    ts['dev_non']   = ts.apply(lambda r: r.disp_non   - pre_baselines.loc[r.region, 'disp_non'],   axis=1)

    # Plot trajectory
    fig, axes = plt.subplots(3, 1, figsize=(12, 11), sharex=True)
    for ax, (col, title) in zip(axes, [('disp_total','All arrests'), ('disp_conv','Arrests w/ criminal conviction'), ('disp_non','Arrests w/ no criminal conviction')]):
        for r in REGIONS_ORDER:
            sub = ts[ts.region == r].sort_values('center_days')
            ax.plot(sub.center_date, sub[col], marker='o', label=REGION_SHORT[r], color=REGION_COLORS[r], linewidth=2, markersize=5)
        ax.axvline(T2_ANCHOR, color='black', linestyle='--', linewidth=1.2, alpha=0.7)
        ax.axhline(1.0, color='gray', linestyle=':', linewidth=1)
        ax.set_ylabel('Disparity ratio'); ax.set_title(title, fontsize=11)
        ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False); ax.grid(axis='y', alpha=0.3)
    axes[0].legend(loc='upper left', fontsize=9, ncol=3, framealpha=0.95)
    axes[-1].xaxis.set_major_locator(mdates.MonthLocator(bymonth=[1,4,7,10]))
    axes[-1].xaxis.set_major_formatter(mdates.DateFormatter('%b %Y'))
    plt.setp(axes[-1].xaxis.get_majorticklabels(), rotation=30, ha='right')
    fig.suptitle('Regional disparity trajectory with Pew 2023 denominators (60-day windows)', fontsize=12, y=1.0)
    plt.tight_layout()
    plt.savefig(FIG_PATH / 'disparity_trajectory_60day_PEW.png', dpi=180, bbox_inches='tight'); plt.close()

    # Plot deviation
    fig, axes = plt.subplots(3, 1, figsize=(13, 11), sharex=True)
    for ax, (col, title) in zip(axes, [('dev_total','All arrests'), ('dev_conv','Arrests w/ criminal conviction'), ('dev_non','Arrests w/ no criminal conviction')]):
        for r in REGIONS_ORDER:
            sub = ts[ts.region == r].sort_values('center_days')
            ax.plot(sub.center_date, sub[col], marker='o', label=REGION_SHORT[r], color=REGION_COLORS[r], linewidth=2.5, markersize=6)
        ax.axvline(T2_ANCHOR, color='black', linestyle='--', linewidth=1.5, alpha=0.7)
        ax.axhline(0, color='gray', linestyle='-', linewidth=1)
        ax.set_ylabel('Δ disparity\n(window − pre-period mean)', fontsize=10); ax.set_title(title, fontsize=11)
        ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False); ax.grid(axis='y', alpha=0.3)
    axes[0].legend(loc='upper left', fontsize=9, ncol=3, framealpha=0.95)
    axes[-1].xaxis.set_major_locator(mdates.MonthLocator(bymonth=[1,4,7,10]))
    axes[-1].xaxis.set_major_formatter(mdates.DateFormatter('%b %Y'))
    plt.setp(axes[-1].xaxis.get_majorticklabels(), rotation=30, ha='right')
    fig.suptitle('Departure from pre-period baseline (Pew 2023 denominators) — 60-day windows', fontsize=11, y=1.0)
    plt.tight_layout()
    plt.savefig(FIG_PATH / 'disparity_trajectory_deviation_60day_PEW.png', dpi=180, bbox_inches='tight'); plt.close()

    print(f"\nDone. Pew-based figures and CSVs saved.")

if __name__ == '__main__':
    main()
