"""
Build_acs_disparity.py

Parallel disparity analysis using ACS 2023 foreign-born by region of birth
(Census table B05006, summed to national region totals) as a broader-coverage
sensitivity check vs. MPI and Pew denominators.

Important caveat: the ACS denominator captures ALL foreign-born residents, not
the unauthorized subset. Absolute disparity levels under ACS are therefore not
directly comparable to MPI or Pew. The comparable quantities are trajectory
shape, cross-region ordering, and pre-vs-post directional change.

Region categories follow the standard 6-region grouping (Mexico and Central
America combined, matching the MPI side-by-side comparisons in
Build_disparity_figures.py). The 7-group split (Mexico vs. Central America)
is handled by the trajectory pipeline in Build_all_trajectories.py.

Outputs (in OUTPUT_DATA):
  - acs_national_region_disparity_with_CI.csv
  - mpi_vs_acs_disparity_comparison.csv
Figures (in FIG_PATH):
  - disparity_forest_by_criminality_ACS.png
  - disparity_pre_post_slopegraph_ACS.png
  - disparity_MPI_vs_ACS_comparison.png

Run:  python Build_acs_disparity.py
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from math import sqrt, exp

from disparity_helpers import (
    load_ddp, REGIONS_ORDER, REGION_SHORT,
    FIG_PATH, OUTPUT_DATA, T2_ANCHOR,
)
from trajectory_helpers import load_acs_denominators


REGION_COLORS = {
    'Mexico and Central America': '#993C1D',
    'Caribbean':                  '#E07B30',
    'South America':              '#534AB7',
    'Asia':                       '#7BA968',
    'Africa':                     '#A0628F',
    'Europe/Canada/Oceania':      '#3B7E9C',
}


# === Region of birth assignment (6-region) ===
def _region_of_country(country):
    """Map a country string to a 6-region bucket. Mirrors disparity_helpers logic."""
    from disparity_helpers import region_of
    return region_of(country)


def compute_disparity_rows(df, denominators, label):
    """Compute disparity ratios with 95% CIs for each region in df.

    df must have a 'region' column already assigned. Returns a DataFrame:
        region | measure | observed | expected | disparity | ci_lo | ci_hi
    where measure is one of {total, conv, no_conv}."""
    out = []
    total_pop = sum(denominators.values())
    for measure_label, sub in [
        ('total', df),
        ('conv',  df[df.is_conv == 1]),
        ('no_conv', df[df.is_conv == 0]),
    ]:
        total_arr = len(sub)
        for region in REGIONS_ORDER:
            pop = denominators.get(region, np.nan)
            observed = (sub.region == region).sum()
            expected = pop * (total_arr / total_pop) if total_pop else np.nan
            if observed == 0 or pop == 0 or not np.isfinite(expected):
                disparity, ci_lo, ci_hi = (np.nan, np.nan, np.nan)
            else:
                disparity = observed / expected
                se_log = 1.0 / sqrt(observed)
                ci_lo = disparity * exp(-1.96 * se_log)
                ci_hi = disparity * exp(+1.96 * se_log)
            out.append(dict(
                source=label, region=region, measure=measure_label,
                observed=observed, expected=expected,
                disparity=disparity, ci_lo=ci_lo, ci_hi=ci_hi,
            ))
    return pd.DataFrame(out)


# === Forest plot ===
def make_forest(df_post, out_path, denom_label='ACS'):
    """3-panel forest plot (total / conv / no_conv) with 95% CIs."""
    fig, axes = plt.subplots(1, 3, figsize=(13, 5.5), sharey=True)
    measures = [('total', 'Total arrests'),
                ('conv',  'With criminal conviction'),
                ('no_conv', 'No criminal conviction')]
    for ax, (m_key, m_title) in zip(axes, measures):
        sub = df_post[df_post.measure == m_key].set_index('region').reindex(REGIONS_ORDER)
        ypos = np.arange(len(sub))
        for i, region in enumerate(sub.index):
            row = sub.loc[region]
            color = REGION_COLORS[region]
            ax.plot([row.ci_lo, row.ci_hi], [i, i], color=color, lw=2.0)
            ax.scatter(row.disparity, i, color=color, s=42, zorder=3)
            label = f"{row.disparity:.2f}" if np.isfinite(row.disparity) else "n/a"
            ax.text(row.ci_hi * 1.05, i, label, va='center', fontsize=8)
        ax.axvline(1.0, color='gray', ls='--', lw=0.8)
        ax.set_yticks(ypos)
        ax.set_yticklabels([REGION_SHORT[r] for r in sub.index])
        ax.set_title(m_title, fontsize=10)
        ax.set_xlabel('Disparity ratio (95% CI)', fontsize=9)
        ax.set_xscale('log')
        ax.invert_yaxis()
    fig.suptitle(
        f'Regional disparity, post-period ({denom_label} 2023 denominators)\n'
        f'95% Poisson SIR confidence intervals. PRELIMINARY.',
        fontsize=11, y=1.02,
    )
    plt.tight_layout()
    plt.savefig(out_path, dpi=180, bbox_inches='tight'); plt.close()
    print(f"  -> {out_path.name}")


# === Pre/post slopegraph ===
def make_slopegraph(df_pre, df_post, out_path, denom_label='ACS'):
    fig, axes = plt.subplots(1, 3, figsize=(13, 5.5), sharey=True)
    measures = [('total', 'Total arrests'),
                ('conv',  'With criminal conviction'),
                ('no_conv', 'No criminal conviction')]
    for ax, (m_key, m_title) in zip(axes, measures):
        for region in REGIONS_ORDER:
            r_pre  = df_pre [(df_pre .region == region) & (df_pre .measure == m_key)]
            r_post = df_post[(df_post.region == region) & (df_post.measure == m_key)]
            if r_pre.empty or r_post.empty:
                continue
            y_pre  = r_pre.disparity.values[0]
            y_post = r_post.disparity.values[0]
            color = REGION_COLORS[region]
            ax.plot([0, 1], [y_pre, y_post], color=color, lw=2.0, marker='o')
            ax.text(-0.05, y_pre, f"{REGION_SHORT[region]} {y_pre:.2f}",
                    ha='right', va='center', fontsize=8, color=color)
            ax.text( 1.05, y_post, f"{y_post:.2f}",
                    ha='left',  va='center', fontsize=8, color=color)
        ax.axhline(1.0, color='gray', ls='--', lw=0.8)
        ax.set_xlim(-0.6, 1.6)
        ax.set_xticks([0, 1])
        ax.set_xticklabels(['Pre', 'Post'])
        ax.set_title(m_title, fontsize=10)
        if ax is axes[0]:
            ax.set_ylabel('Disparity ratio', fontsize=9)
        ax.set_yscale('log')
    fig.suptitle(
        f'Pre vs. post Trump 2: regional disparity ({denom_label} 2023 denominators)\n'
        f'PRELIMINARY.',
        fontsize=11, y=1.02,
    )
    plt.tight_layout()
    plt.savefig(out_path, dpi=180, bbox_inches='tight'); plt.close()
    print(f"  -> {out_path.name}")


# === MPI vs ACS comparison ===
def make_comparison_figure(df_mpi, df_acs, out_path):
    fig, axes = plt.subplots(1, 3, figsize=(13, 5.5), sharey=True)
    measures = [('total', 'Total arrests'),
                ('conv',  'With criminal conviction'),
                ('no_conv', 'No criminal conviction')]
    width = 0.35
    for ax, (m_key, m_title) in zip(axes, measures):
        sub_mpi = df_mpi[df_mpi.measure == m_key].set_index('region').reindex(REGIONS_ORDER)
        sub_acs = df_acs[df_acs.measure == m_key].set_index('region').reindex(REGIONS_ORDER)
        ypos = np.arange(len(REGIONS_ORDER))
        ax.barh(ypos - width/2, sub_mpi.disparity.values, height=width,
                color='#3B7E9C', edgecolor='black', lw=0.5, label='MPI')
        ax.barh(ypos + width/2, sub_acs.disparity.values, height=width,
                color='#A0628F', edgecolor='black', lw=0.5, label='ACS')
        ax.axvline(1.0, color='gray', ls='--', lw=0.8)
        ax.set_yticks(ypos)
        ax.set_yticklabels([REGION_SHORT[r] for r in REGIONS_ORDER])
        ax.set_title(m_title, fontsize=10)
        ax.set_xlabel('Disparity ratio', fontsize=9)
        ax.invert_yaxis()
        if ax is axes[0]:
            ax.legend(fontsize=8, loc='lower right')
    fig.suptitle(
        'MPI vs. ACS disparity ratios, post-period\n'
        '(ACS denominator is foreign-born, not unauthorized; '
        'absolute levels not directly comparable.) PRELIMINARY.',
        fontsize=10, y=1.04,
    )
    plt.tight_layout()
    plt.savefig(out_path, dpi=180, bbox_inches='tight'); plt.close()
    print(f"  -> {out_path.name}")


def main():
    print("Loading DDP arrests and assigning regions...")
    df = load_ddp()

    # is_conv flag
    df['is_conv'] = (df['apprehension_criminality'] == '1 Convicted Criminal').astype(int)

    # Region of birth (6-region)
    df['region'] = df['citizenship_country'].map(_region_of_country)
    df = df.dropna(subset=['region'])

    # Pre / post split around inauguration
    df['days_from_inaug'] = (df['apprehension_date'] - T2_ANCHOR).dt.days
    pre  = df[(df.days_from_inaug >= -414) & (df.days_from_inaug < 0)]
    post = df[(df.days_from_inaug >= 0)    & (df.days_from_inaug <= 414)]
    print(f"  Pre:  {len(pre):>8,}")
    print(f"  Post: {len(post):>8,}")

    # ACS denominators
    print("\nLoading ACS regional denominators (B05006)...")
    acs_denoms = load_acs_denominators(grouping=6)
    for r, p in acs_denoms.items():
        print(f"  {r:<32s}  {p:>14,.0f}")

    # Compute disparities
    print("\nComputing post-period disparities under ACS denominators...")
    df_acs_post = compute_disparity_rows(post, acs_denoms, label='ACS_post')
    print("Computing pre-period disparities under ACS denominators...")
    df_acs_pre  = compute_disparity_rows(pre,  acs_denoms, label='ACS_pre')

    df_acs_all = pd.concat([df_acs_pre, df_acs_post], ignore_index=True)
    csv_out = OUTPUT_DATA / 'acs_national_region_disparity_with_CI.csv'
    df_acs_all.to_csv(csv_out, index=False)
    print(f"  -> {csv_out}")

    # Forest + slopegraph
    print("\nBuilding figures...")
    make_forest(df_acs_post, FIG_PATH / 'disparity_forest_by_criminality_ACS.png')
    make_slopegraph(df_acs_pre, df_acs_post, FIG_PATH / 'disparity_pre_post_slopegraph_ACS.png')

    # MPI vs ACS comparison (need MPI side, computed below from same loader)
    print("\nComputing MPI side for the side-by-side comparison...")
    from disparity_helpers import load_mpi_state_region
    mpi_state_region = load_mpi_state_region()
    mpi_denoms = mpi_state_region.groupby('region')['unauthorized'].sum().to_dict()
    df_mpi_post = compute_disparity_rows(post, mpi_denoms, label='MPI_post')
    cmp_csv = OUTPUT_DATA / 'mpi_vs_acs_disparity_comparison.csv'
    pd.concat([df_mpi_post.assign(source='MPI'),
               df_acs_post.assign(source='ACS')], ignore_index=True).to_csv(cmp_csv, index=False)
    print(f"  -> {cmp_csv}")

    make_comparison_figure(df_mpi_post, df_acs_post,
                           FIG_PATH / 'disparity_MPI_vs_ACS_comparison.png')

    print("\nDone.")


if __name__ == '__main__':
    main()
