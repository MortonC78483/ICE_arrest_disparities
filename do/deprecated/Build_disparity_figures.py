"""
Build_disparity_figures.py

Generates the state×region disparity figures (POST-only and PRE/POST):
  - state_region_disparity_heatmap_preview.png       (initial preview, top 15)
  - disparity_by_criminality_preview.png             (national 3-bar chart)
  - state_region_disparity_by_criminality.png        (2-panel state×region)
  - state_region_disparity_LEA_vs_CA.png             (2x2, top 15 states)
  - state_region_disparity_LEA_vs_CA_ALL_STATES.png  (2x2, all 44 jurisdictions)
  - state_region_disparity_by_criminality_PRE_POST.png    (4-panel)
  - state_region_disparity_LEA_vs_CA_PRE_POST.png         (8-panel)

Inputs:
  - DDP arrests-latest.dta (full record-level data)
  - mpi_state_region.csv

Outputs go to FIG_PATH (Immigrant_Apprehensions/Figures/ddp/)

Run:  python Build_disparity_figures.py
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm

from disparity_helpers import (
    load_ddp, load_mpi_state_region, REGIONS_ORDER, REGION_SHORT, FIG_PATH, DATA_PATH, OUTPUT_DATA
)

def disparity_matrix(filtered_df, top_states, mpi_region):
    """Compute state×region disparity matrix from a filtered arrest dataframe."""
    if len(filtered_df) == 0:
        return pd.DataFrame(index=top_states, columns=REGIONS_ORDER, dtype=float)
    agg = filtered_df.groupby(['state_clean','region']).size().reset_index(name='arrests')
    agg = agg.rename(columns={'state_clean':'state_upper'})
    m = agg.merge(mpi_region, on=['state_upper','region'], how='inner')
    m['state_unauth_total'] = m.groupby('state_upper').unauth_pop.transform('sum')
    m['state_arr_total']    = m.groupby('state_upper').arrests.transform('sum')
    m['region_pop_share']   = m.unauth_pop / m.state_unauth_total
    m['region_arr_share']   = m.arrests / m.state_arr_total
    m['disp']               = m.region_arr_share / m.region_pop_share
    return m[m.state_upper.isin(top_states)].pivot_table(
        index='state_upper', columns='region', values='disp', aggfunc='first'
    ).reindex(top_states)[REGIONS_ORDER]

def annotate_heatmap(ax, mat, fontsize=8.5):
    for i in range(mat.shape[0]):
        for j in range(mat.shape[1]):
            v = mat.values[i, j]
            if pd.notna(v) and not np.isinf(v):
                color = 'white' if v < 0.4 or v > 2.5 else 'black'
                ax.text(j, i, f'{v:.2f}', ha='center', va='center', color=color, fontsize=fontsize)

def main():
    print("Loading DDP data...")
    df = load_ddp()
    df = df[df.region != ''].copy()
    mpi = load_mpi_state_region()

    # Restrict to states with MPI denominator coverage
    df = df[df.state_clean.isin(mpi.state_upper.unique())]

    # Top 15 states by post-period arrest volume
    post_volume = df[df.post == 1].state_clean.value_counts().head(15)
    top15 = post_volume.index.tolist()
    print(f"Top 15 destination states (post): {top15}")

    # ============================================================
    # FIGURE 1: state×region disparity by criminality (post-only, 2 panels)
    # ============================================================
    print("Building 2-panel post-only criminality heatmap...")
    dpost = df[df.post == 1]
    mat_conv = disparity_matrix(dpost[dpost.convicted == 1], top15, mpi)
    mat_non  = disparity_matrix(dpost[dpost.convicted == 0], top15, mpi)

    fig, (axL, axR) = plt.subplots(1, 2, figsize=(14, 7), sharey=True)
    norm = TwoSlopeNorm(vmin=0, vcenter=1, vmax=4)
    for ax, mat, title in [(axL, mat_conv, 'Arrests w/ criminal conviction'),
                            (axR, mat_non,  'Arrests w/ no criminal conviction')]:
        im = ax.imshow(mat.values, cmap='RdBu_r', norm=norm, aspect='auto')
        ax.set_xticks(range(len(REGIONS_ORDER)))
        ax.set_xticklabels([REGION_SHORT[r] for r in REGIONS_ORDER], rotation=30, ha='right', fontsize=9)
        ax.set_yticks(range(len(top15)))
        ax.set_yticklabels([s.title() for s in top15], fontsize=9)
        annotate_heatmap(ax, mat)
        ax.set_title(title, fontsize=11)
    fig.colorbar(im, ax=[axL, axR], label='Disparity ratio (>1 = over-targeted)', fraction=0.025, pad=0.02)
    fig.suptitle('Term 2 (post-1/20/2025) state×region disparity — by criminal-conviction status', fontsize=12, y=1.0)
    out = FIG_PATH / 'state_region_disparity_by_criminality.png'
    plt.savefig(out, dpi=180, bbox_inches='tight'); plt.close()
    print(f"  Saved: {out}")

    # ============================================================
    # FIGURE 2: 2x2 LEA/CA × conviction (top 15)
    # ============================================================
    print("Building 2x2 LEA/CA × conviction heatmap...")
    dpost_methods = dpost[dpost.method_class.isin(['LEA','CA'])]
    panels = [
        (dpost_methods[(dpost_methods.method_class=='LEA') & (dpost_methods.convicted==1)],
         'LEA — w/ criminal conviction'),
        (dpost_methods[(dpost_methods.method_class=='LEA') & (dpost_methods.convicted==0)],
         'LEA — w/ no criminal conviction'),
        (dpost_methods[(dpost_methods.method_class=='CA')  & (dpost_methods.convicted==1)],
         'Community Arrests — w/ criminal conviction'),
        (dpost_methods[(dpost_methods.method_class=='CA')  & (dpost_methods.convicted==0)],
         'Community Arrests — w/ no criminal conviction'),
    ]
    # Top 15 must be from LEA+CA only (slightly different list than overall)
    post_volume_methods = dpost_methods.state_clean.value_counts().head(15)
    top15_methods = post_volume_methods.index.tolist()

    fig, axes = plt.subplots(2, 2, figsize=(15, 11), sharex=True, sharey=True)
    for ax, (subdf, title) in zip(axes.ravel(), panels):
        mat = disparity_matrix(subdf, top15_methods, mpi)
        im = ax.imshow(mat.values, cmap='RdBu_r', norm=norm, aspect='auto')
        ax.set_xticks(range(len(REGIONS_ORDER)))
        ax.set_xticklabels([REGION_SHORT[r] for r in REGIONS_ORDER], rotation=30, ha='right', fontsize=9)
        ax.set_yticks(range(len(top15_methods)))
        ax.set_yticklabels([s.title() for s in top15_methods], fontsize=9)
        annotate_heatmap(ax, mat, fontsize=7.5)
        ax.set_title(title, fontsize=10.5)
    fig.colorbar(im, ax=axes.ravel().tolist(), label='Disparity ratio (>1 = over-targeted)', fraction=0.018, pad=0.02)
    fig.suptitle('Term 2 (post-1/20/2025) state×region disparity — by arrest method × criminal-conviction status', fontsize=12, y=0.995)
    out = FIG_PATH / 'state_region_disparity_LEA_vs_CA.png'
    plt.savefig(out, dpi=180, bbox_inches='tight'); plt.close()
    print(f"  Saved: {out}")

    # ============================================================
    # FIGURE 2-ALL: 2x2 LEA/CA × conviction, all 44 jurisdictions
    # ============================================================
    print("Building 2x2 LEA/CA × conviction heatmap (all states)...")
    arrest_volumes = dpost_methods.state_clean.value_counts()
    states_with_mpi = set(mpi.state_upper.unique())
    all_eligible = [s for s in arrest_volumes.index if s in states_with_mpi and arrest_volumes[s] >= 100]
    n_states = len(all_eligible)

    fig, axes = plt.subplots(2, 2, figsize=(14, max(10, 0.32 * n_states)), sharex=True, sharey=True)
    for ax, (subdf, title) in zip(axes.ravel(), panels):
        mat = disparity_matrix(subdf, all_eligible, mpi)
        im = ax.imshow(mat.values, cmap='RdBu_r', norm=norm, aspect='auto')
        ax.set_xticks(range(len(REGIONS_ORDER)))
        ax.set_xticklabels([REGION_SHORT[r] for r in REGIONS_ORDER], rotation=30, ha='right', fontsize=9)
        ax.set_yticks(range(n_states))
        ax.set_yticklabels([s.title() for s in all_eligible], fontsize=8)
        annotate_heatmap(ax, mat, fontsize=6.5)
        ax.set_title(title, fontsize=10.5)
    fig.colorbar(im, ax=axes.ravel().tolist(), label='Disparity ratio (>1 = over-targeted)', fraction=0.018, pad=0.02)
    fig.suptitle(f'Term 2 (post-1/20/2025) state×region disparity — all {n_states} jurisdictions with MPI denominators', fontsize=11, y=0.995)
    out = FIG_PATH / 'state_region_disparity_LEA_vs_CA_ALL_STATES.png'
    plt.savefig(out, dpi=160, bbox_inches='tight'); plt.close()
    print(f"  Saved: {out}")

    # ============================================================
    # FIGURE 3: PRE/POST 4-panel by criminality
    # ============================================================
    print("Building 4-panel pre/post criminality heatmap...")
    panels_pp = [
        (df[(df.post==0) & (df.convicted==1)], 'PRE (Biden, Term 2 −414d to inauguration)\nArrests w/ criminal conviction'),
        (df[(df.post==0) & (df.convicted==0)], 'PRE (Biden, Term 2 −414d to inauguration)\nArrests w/ no criminal conviction'),
        (df[(df.post==1) & (df.convicted==1)], 'POST (Trump 2.0, ~14 mo. since inauguration)\nArrests w/ criminal conviction'),
        (df[(df.post==1) & (df.convicted==0)], 'POST (Trump 2.0, ~14 mo. since inauguration)\nArrests w/ no criminal conviction'),
    ]
    fig, axes = plt.subplots(2, 2, figsize=(14, 11), sharex=True, sharey=True)
    for ax, (subdf, title) in zip(axes.ravel(), panels_pp):
        mat = disparity_matrix(subdf, top15, mpi)
        im = ax.imshow(mat.values, cmap='RdBu_r', norm=norm, aspect='auto')
        ax.set_xticks(range(len(REGIONS_ORDER)))
        ax.set_xticklabels([REGION_SHORT[r] for r in REGIONS_ORDER], rotation=30, ha='right', fontsize=9)
        ax.set_yticks(range(len(top15)))
        ax.set_yticklabels([s.title() for s in top15], fontsize=9)
        annotate_heatmap(ax, mat, fontsize=8)
        ax.set_title(title, fontsize=10)
    fig.colorbar(im, ax=axes.ravel().tolist(), label='Disparity ratio (>1 = over-targeted)', fraction=0.018, pad=0.02)
    fig.suptitle('State×region disparity, by criminal-conviction status: PRE vs POST Trump-2 inauguration\n(Top 15 destination states by post-period arrest volume)', fontsize=11.5, y=1.0)
    out = FIG_PATH / 'state_region_disparity_by_criminality_PRE_POST.png'
    plt.savefig(out, dpi=170, bbox_inches='tight'); plt.close()
    print(f"  Saved: {out}")

    # ============================================================
    # FIGURE 4: PRE/POST 8-panel LEA/CA × conviction
    # ============================================================
    print("Building 8-panel pre/post LEA/CA × conviction heatmap...")
    method_panels = []
    for period_label, post_val in [('PRE', 0), ('POST', 1)]:
        for method, conv_val, conv_label in [
            ('LEA', 1, 'criminal conviction'),
            ('LEA', 0, 'no criminal conviction'),
            ('CA',  1, 'criminal conviction'),
            ('CA',  0, 'no criminal conviction'),
        ]:
            sub = df[(df.post == post_val) & (df.method_class == method) & (df.convicted == conv_val)]
            method_label = 'LEA' if method == 'LEA' else 'Community'
            method_panels.append((f"{period_label}: {method_label} + {conv_label}", sub))

    fig, axes = plt.subplots(2, 4, figsize=(22, 11), sharey=True)
    for ax, (title, subdf) in zip(axes.ravel(), method_panels):
        mat = disparity_matrix(subdf, top15, mpi)
        im = ax.imshow(mat.values, cmap='RdBu_r', norm=norm, aspect='auto')
        ax.set_xticks(range(len(REGIONS_ORDER)))
        ax.set_xticklabels([REGION_SHORT[r] for r in REGIONS_ORDER], rotation=30, ha='right', fontsize=8)
        ax.set_yticks(range(len(top15)))
        ax.set_yticklabels([s.title() for s in top15], fontsize=7.5)
        annotate_heatmap(ax, mat, fontsize=6.5)
        ax.set_title(title, fontsize=10)
    fig.colorbar(im, ax=axes.ravel().tolist(), label='Disparity ratio (>1 = over-targeted)', fraction=0.012, pad=0.02)
    fig.suptitle('State×region disparity by arrest method × criminal-conviction status × period (PRE vs POST Trump 2)', fontsize=12, y=1.0)
    out = FIG_PATH / 'state_region_disparity_LEA_vs_CA_PRE_POST.png'
    plt.savefig(out, dpi=160, bbox_inches='tight'); plt.close()
    print(f"  Saved: {out}")

    # ============================================================
    # FIGURE 5: National 3-bar chart by criminality (post)
    # ============================================================
    print("Building national 3-bar chart...")
    nat = df[df.post == 1].groupby('region').agg(
        arrests=('post','count'),
        convicted=('convicted','sum'),
        noncriminal=('noncriminal','sum'),
    ).reset_index()
    pop = mpi.groupby('region').unauth_pop.sum().reset_index()
    nat = nat.merge(pop, on='region')
    T_unauth = nat.unauth_pop.sum()
    T_arr  = nat.arrests.sum()
    T_conv = nat.convicted.sum()
    T_non  = nat.noncriminal.sum()
    nat['unauth_share']    = nat.unauth_pop / T_unauth
    nat['disp_total']      = (nat.arrests / T_arr) / nat.unauth_share
    nat['disp_conv']       = (nat.convicted / T_conv) / nat.unauth_share
    nat['disp_noncriminal']= (nat.noncriminal / T_non) / nat.unauth_share
    bar_order = ['South America','Caribbean','Mexico and Central America','Asia','Africa','Europe/Canada/Oceania']
    nat = nat.set_index('region').reindex(bar_order).reset_index()

    fig, ax = plt.subplots(figsize=(11, 5.5))
    x = np.arange(len(nat))
    width = 0.27
    b1 = ax.bar(x - width, nat.disp_total,        width, label='All arrests',                          color='#534AB7', alpha=0.9)
    b2 = ax.bar(x,         nat.disp_conv,         width, label='Arrests w/ criminal conviction',       color='#993C1D', alpha=0.9)
    b3 = ax.bar(x + width, nat.disp_noncriminal,  width, label='Arrests w/ no criminal conviction',    color='#7BA968', alpha=0.9)
    for bars, vals in [(b1, nat.disp_total),(b2, nat.disp_conv),(b3, nat.disp_noncriminal)]:
        for b, v in zip(bars, vals):
            ax.text(b.get_x() + b.get_width()/2, v + 0.03, f'{v:.2f}', ha='center', fontsize=8.5)
    ax.axhline(1.0, color='gray', linestyle='--', linewidth=1, label='Proportional (= population share)')
    ax.set_xticks(x); ax.set_xticklabels([REGION_SHORT[r] for r in nat.region], fontsize=10)
    ax.set_ylabel('Disparity ratio (arrest share / unauthorized population share)')
    ax.set_title('Term 2 (post-1/20/2025) regional disparity — split by arrest type', fontsize=11)
    ax.set_ylim(0, 2.0); ax.grid(axis='y', alpha=0.3)
    ax.legend(loc='upper right', fontsize=9)
    ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    plt.tight_layout()
    out = FIG_PATH / 'disparity_by_criminality_preview.png'
    plt.savefig(out, dpi=180, bbox_inches='tight'); plt.close()
    print(f"  Saved: {out}")

    # Save the underlying data
    nat.to_csv(OUTPUT_DATA / 'national_region_disparity_PREVIEW.csv', index=False)

    print("\nDone. All disparity figures saved to:", FIG_PATH)

if __name__ == '__main__':
    main()
