"""
Build_country_disparity.py

Country-of-origin level disparity analyses:
  - country_per100k_by_method.png         (national, top 10 countries)
  - california_country_disparity_heatmap.png   (CA by country/region)
  - la_aor_country_disparity_heatmap.png       (LA AOR, prorated denominators)
  - la_aor_country_disparity_heatmap_county_based.png  (LA AOR, county-summed)

Inputs:
  - DDP arrests-latest.dta
  - mpi_state_country.csv (from Parse_MPI_profiles.py)
  - mpi_county_country.csv, mpi_county_region.csv (from Parse_MPI_county_profiles.py)
  - MPI Excel for state and county totals

Run:  python Build_country_disparity.py
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm
from pathlib import Path

from disparity_helpers import (
    load_ddp, load_mpi_state_country, load_mpi_state_region,
    load_mpi_county_country, load_mpi_county_region,
    DATA_PATH, OUTPUT_DATA, FIG_PATH, REGIONS_ORDER,
    MCA, CARIBBEAN, SA, ASIA, AFRICA, EUCA,
)

# Country buckets used for state-level country disparity (CA + LA AOR)
def bucket_country(c):
    """Map a citizenship_country (uppercase) to a country/region bucket."""
    c = (c or '').strip().upper()
    if c == 'MEXICO': return 'Mexico'
    if c == 'GUATEMALA': return 'Guatemala'
    if c == 'EL SALVADOR': return 'El Salvador'
    if c == 'HONDURAS': return 'Honduras'
    if c in MCA: return 'Other Mex/CA'
    if c == 'PHILIPPINES': return 'Philippines'
    if c in ASIA: return 'Other Asia'
    if c in CARIBBEAN: return 'Caribbean'
    if c in SA: return 'South America'
    if c in AFRICA: return 'Africa'
    if c in EUCA: return 'Eur/Can/Oce'
    return 'Unmapped'

BUCKET_ORDER = ['Mexico','Guatemala','El Salvador','Honduras','Other Mex/CA',
                'South America','Caribbean','Philippines','Other Asia','Africa','Eur/Can/Oce']

def heatmap_4cells(agg, denom_label, fig_title, out_path):
    """4-column heatmap of country/region buckets × {LEA-c, LEA-n, CA-c, CA-n}."""
    fig, ax = plt.subplots(figsize=(10, 7))
    heat_cols = ['disp_lea_conv','disp_lea_non','disp_ca_conv','disp_ca_non']
    heat_labels = ['LEA + conviction','LEA + no conviction','Community + conviction','Community + no conviction']
    mat = agg[heat_cols].values
    norm = TwoSlopeNorm(vmin=0, vcenter=1, vmax=4)
    im = ax.imshow(mat, cmap='RdBu_r', norm=norm, aspect='auto')
    ax.set_xticks(range(len(heat_cols)))
    ax.set_xticklabels(heat_labels, rotation=20, ha='right', fontsize=10)
    ax.set_yticks(range(len(agg)))
    ax.set_yticklabels([f"{r.bucket} ({r.unauth_pop//1000:,}K, {r.pop_share*100:.1f}%)"
                        for _, r in agg.iterrows()], fontsize=9)
    for i in range(mat.shape[0]):
        for j in range(mat.shape[1]):
            v = mat[i, j]
            if pd.notna(v) and not np.isinf(v):
                color = 'white' if v < 0.4 or v > 2.5 else 'black'
                ax.text(j, i, f'{v:.2f}', ha='center', va='center', color=color, fontsize=9)
    ax.set_title(fig_title, fontsize=10)
    plt.colorbar(im, ax=ax, label=f'Disparity ratio (>1 = over-targeted within {denom_label})',
                 fraction=0.04, pad=0.02)
    plt.tight_layout()
    plt.savefig(out_path, dpi=180, bbox_inches='tight'); plt.close()
    print(f"Saved: {out_path}")

def compute_bucket_disparities(df_filtered, pop_dict):
    """From a filtered DDP dataframe and a {bucket: unauth_pop} dict, compute disparity table.

    Returns a DataFrame with one row per bucket and disparity columns.
    """
    df_filtered = df_filtered[df_filtered.bucket != 'Unmapped'].copy()
    agg = df_filtered.groupby('bucket').agg(
        arrests=('convicted','count'),
        convicted=('convicted','sum'),
        noncriminal=('noncriminal','sum'),
    ).reset_index()
    df_lea = df_filtered[df_filtered.method_class=='LEA']
    df_ca  = df_filtered[df_filtered.method_class=='CA']
    agg['lea_conv'] = agg.bucket.map(df_lea.groupby('bucket').convicted.sum()).fillna(0).astype(int)
    agg['lea_non']  = agg.bucket.map(df_lea.groupby('bucket').noncriminal.sum()).fillna(0).astype(int)
    agg['ca_conv']  = agg.bucket.map(df_ca.groupby('bucket').convicted.sum()).fillna(0).astype(int)
    agg['ca_non']   = agg.bucket.map(df_ca.groupby('bucket').noncriminal.sum()).fillna(0).astype(int)
    agg['unauth_pop'] = agg.bucket.map(pop_dict)
    agg = agg.dropna(subset=['unauth_pop'])
    agg['unauth_pop'] = agg['unauth_pop'].astype(int)

    for col in ['arrests','convicted','noncriminal','lea_conv','lea_non','ca_conv','ca_non']:
        agg[f'per100k_{col}'] = agg[col] / agg.unauth_pop * 100000

    T_unauth = agg.unauth_pop.sum()
    agg['pop_share'] = agg.unauth_pop / T_unauth
    for c, total_col in [('total','arrests'),('lea_conv','lea_conv'),
                         ('lea_non','lea_non'),('ca_conv','ca_conv'),('ca_non','ca_non')]:
        T = agg[total_col].sum()
        agg[f'disp_{c}'] = (agg[total_col] / T) / agg.pop_share

    return agg.set_index('bucket').reindex(BUCKET_ORDER).reset_index()

# === ANALYSIS 1: National per-capita by country ===
def analysis_national_country(df_post):
    print("\n=== ANALYSIS: National per-capita by country (post period) ===")
    mpi_c = load_mpi_state_country()
    nat_country_pop = mpi_c.groupby('country').unauth_pop.sum()

    # Map MPI country name to DDP citizenship_country (uppercased)
    mpi_to_ddp = {
        'Mexico':'MEXICO','Guatemala':'GUATEMALA','Honduras':'HONDURAS','El Salvador':'EL SALVADOR',
        'Venezuela':'VENEZUELA','Philippines':'PHILIPPINES','Ecuador':'ECUADOR','Colombia':'COLOMBIA',
        'Dominican Republic':'DOMINICAN REPUBLIC','Brazil':'BRAZIL',
    }
    countries = []
    for mc, dn in mpi_to_ddp.items():
        countries.append({
            'mpi_name': mc, 'ddp_name': dn,
            'unauth_pop_mpi': int(nat_country_pop.get(mc, 0)),
        })
    cdf = pd.DataFrame(countries)

    # Arrest counts per country
    nat_arr = df_post.groupby('citizenship_country').agg(
        arrests=('post','count'), convicted=('convicted','sum'), noncriminal=('noncriminal','sum'),
    )
    df_lea = df_post[df_post.method_class == 'LEA']
    df_ca  = df_post[df_post.method_class == 'CA']
    cdf['ddp_arrests'] = cdf.ddp_name.map(nat_arr.arrests).fillna(0).astype(int)
    cdf['lea_conv'] = cdf.ddp_name.map(df_lea.groupby('citizenship_country').convicted.sum()).fillna(0).astype(int)
    cdf['lea_non']  = cdf.ddp_name.map(df_lea.groupby('citizenship_country').noncriminal.sum()).fillna(0).astype(int)
    cdf['ca_conv']  = cdf.ddp_name.map(df_ca.groupby('citizenship_country').convicted.sum()).fillna(0).astype(int)
    cdf['ca_non']   = cdf.ddp_name.map(df_ca.groupby('citizenship_country').noncriminal.sum()).fillna(0).astype(int)

    cdf['per100k_total']    = cdf.ddp_arrests / cdf.unauth_pop_mpi * 100000
    cdf['per100k_lea_conv'] = cdf.lea_conv / cdf.unauth_pop_mpi * 100000
    cdf['per100k_lea_non']  = cdf.lea_non / cdf.unauth_pop_mpi * 100000
    cdf['per100k_ca_conv']  = cdf.ca_conv / cdf.unauth_pop_mpi * 100000
    cdf['per100k_ca_non']   = cdf.ca_non / cdf.unauth_pop_mpi * 100000

    cdf = cdf.sort_values('per100k_total', ascending=False).reset_index(drop=True)
    cdf.to_csv(OUTPUT_DATA / 'national_country_disparity.csv', index=False)
    print(cdf[['mpi_name','unauth_pop_mpi','ddp_arrests','per100k_total']].to_string(index=False))

    # Bar chart: per-100k by country, LEA vs Community
    fig, ax = plt.subplots(figsize=(11, 6))
    order = cdf.sort_values('per100k_total', ascending=True)
    y = np.arange(len(order))
    ax.barh(y - 0.2, order.per100k_lea_conv + order.per100k_lea_non, height=0.4,
            label='LEA arrests (jail-driven)', color='#993C1D', alpha=0.85)
    ax.barh(y + 0.2, order.per100k_ca_conv + order.per100k_ca_non, height=0.4,
            label='Community Arrests (proactive)', color='#534AB7', alpha=0.85)
    for i, r in enumerate(order.itertuples()):
        lea = r.per100k_lea_conv + r.per100k_lea_non
        ca  = r.per100k_ca_conv + r.per100k_ca_non
        ax.text(lea + 200, i - 0.2, f'{lea:,.0f}', va='center', fontsize=8, color='#993C1D')
        ax.text(ca + 200, i + 0.2,  f'{ca:,.0f}',  va='center', fontsize=8, color='#534AB7')
    ax.set_yticks(y); ax.set_yticklabels(order.mpi_name, fontsize=10)
    ax.set_xlabel('Arrests per 100,000 unauthorized residents')
    ax.set_title('Term 2 per-capita arrest rates by country of origin\nBy method (LEA jail-driven vs. Community proactive)', fontsize=11)
    ax.legend(loc='lower right', fontsize=9); ax.grid(axis='x', alpha=0.3)
    ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    plt.tight_layout()
    out = FIG_PATH / 'country_per100k_by_method.png'
    plt.savefig(out, dpi=180, bbox_inches='tight'); plt.close()
    print(f"Saved: {out}")

# === ANALYSIS 2: California by country/region ===
def analysis_california(df_post):
    print("\n=== ANALYSIS: California by country/region ===")
    df_ca = df_post[df_post.state_clean == 'CALIFORNIA'].copy()
    df_ca['bucket'] = df_ca.citizenship_country.apply(bucket_country)

    # CA denominators (from MPI state regions + CA state country file)
    ca_pop = {
        'Mexico':           1_720_000, 'Guatemala': 326_000,
        'El Salvador':        265_000, 'Honduras':   91_000,
        'Other Mex/CA':       2_436_000 - 1_720_000 - 326_000 - 265_000 - 91_000,  # 34K
        'South America':       98_000, 'Caribbean':   5_000,
        'Philippines':        104_000, 'Other Asia':  127_000,  # 231 - 104
        'Africa':              23_000, 'Eur/Can/Oce':117_000,
    }
    agg = compute_bucket_disparities(df_ca, ca_pop)
    agg.to_csv(OUTPUT_DATA / 'california_country_disparity.csv', index=False)
    print(agg[['bucket','unauth_pop','arrests','per100k_arrests','disp_total']].to_string(index=False))

    heatmap_4cells(agg, 'CA',
        'California: arrest disparity by country of origin × method × criminal-conviction status\n("Other Mex/CA" = Nicaragua/CR/Panama/Belize; "Other Asia" = non-Philippine Asia)',
        FIG_PATH / 'california_country_disparity_heatmap.png')

# === ANALYSIS 3: LA AOR — both prorated and county-based denominators ===
def analysis_la_aor(df_post):
    print("\n=== ANALYSIS: LA AOR by country/region ===")
    df_la = df_post[df_post.apprehension_aor == 'Los Angeles Area of Responsibility'].copy()
    df_la['bucket'] = df_la.citizenship_country.apply(bucket_country)

    # Method 1: Prorated from CA state totals
    la_aor_county_pops = {  # MPI county totals
        'Los Angeles County, California': 1_101_000, 'Orange County, California': 229_000,
        'Riverside County, California': 152_000, 'San Bernardino County, California': 149_000,
        'Ventura County, California': 58_000, 'Santa Barbara County, California': 45_000,
        'San Luis Obispo County, California': 8_000,
    }
    la_aor_total = sum(la_aor_county_pops.values())
    la_share = la_aor_total / 2_910_000  # CA state total
    print(f"LA AOR total: {la_aor_total:,} ({la_share*100:.1f}% of CA)")

    ca_state_pop = {  # Same dict as analysis_california
        'Mexico':1_720_000,'Guatemala':326_000,'El Salvador':265_000,'Honduras':91_000,
        'Other Mex/CA':34_000,'Caribbean':5_000,'South America':98_000,
        'Philippines':104_000,'Other Asia':127_000,'Africa':23_000,'Eur/Can/Oce':117_000,
    }
    la_pop_prorated = {k: int(round(v * la_share, -2)) for k, v in ca_state_pop.items()}
    agg_prorated = compute_bucket_disparities(df_la, la_pop_prorated)
    agg_prorated.to_csv(OUTPUT_DATA / 'la_aor_country_disparity.csv', index=False)
    heatmap_4cells(agg_prorated, 'LA AOR',
        'Los Angeles AOR (LA+OC+RIV+SBD+VEN+SBA+SLO): arrest disparity by country × method × conviction\nDenominators prorated from MPI state totals',
        FIG_PATH / 'la_aor_country_disparity_heatmap.png')

    # Method 2: County-based (sum the parsed county profiles)
    try:
        cc = load_mpi_county_country()
        cr = load_mpi_county_region()
        la_aor_short = ['Los Angeles County','Orange County','Riverside County',
                        'San Bernardino County','Ventura County','Santa Barbara County']
        la_country = cc[cc.county.isin(la_aor_short)].groupby('country').unauth_pop.sum()
        la_region  = cr[cr.county.isin(la_aor_short)].groupby('region').unauth_pop.sum()

        la_pop = {
            'Mexico':      int(la_country.get('Mexico', 0)),
            'Guatemala':   int(la_country.get('Guatemala', 0)),
            'El Salvador': int(la_country.get('El Salvador', 0)),
            'Honduras':    int(la_country.get('Honduras', 0)),
            'Philippines': int(la_country.get('Philippines', 0)),
        }
        mex_ca_named = sum(la_pop[k] for k in ['Mexico','Guatemala','El Salvador','Honduras'])
        la_pop['Other Mex/CA']  = max(0, int(la_region.get('Mexico and Central America', 0)) - mex_ca_named)
        la_pop['South America'] = int(la_region.get('South America', 0))
        la_pop['Caribbean']     = int(la_region.get('Caribbean', 0))
        la_pop['Other Asia']    = max(0, int(la_region.get('Asia', 0)) - la_pop['Philippines'])
        la_pop['Africa']        = int(la_region.get('Africa', 0))
        la_pop['Eur/Can/Oce']   = int(la_region.get('Europe/Canada/Oceania', 0))

        # Add SLO via small-state proration (8K)
        slo_total = la_aor_county_pops['San Luis Obispo County, California']
        ca_total = sum(ca_state_pop.values())
        for k in la_pop:
            la_pop[k] += int(round(ca_state_pop[k] * slo_total / ca_total, -2))

        agg_county = compute_bucket_disparities(df_la, la_pop)
        agg_county.to_csv(OUTPUT_DATA / 'la_aor_country_disparity_county_based.csv', index=False)
        heatmap_4cells(agg_county, 'LA AOR',
            'Los Angeles AOR (LA+OC+RIV+SBD+VEN+SBA+SLO): arrest disparity by country × method × conviction\nDenominators from MPI county-level data (6 of 7 counties; SLO prorated)',
            FIG_PATH / 'la_aor_country_disparity_heatmap_county_based.png')
    except FileNotFoundError as e:
        print(f"Skipping county-based LA AOR analysis (missing parsed county data): {e}")

def main():
    df = load_ddp()
    df_post = df[df.post == 1].copy()
    analysis_national_country(df_post)
    analysis_california(df_post)
    analysis_la_aor(df_post)
    print("\nDone. All country-level figures saved to:", FIG_PATH)

if __name__ == '__main__':
    main()
