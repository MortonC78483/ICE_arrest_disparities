"""
trajectory_helpers.py

Shared helpers for the trajectory analysis: denominator loaders for MPI, Pew,
and ACS, regional aggregation, and plotting routines for level (per-100k +
disparity) and deviation-from-baseline figures.

Supports two region groupings:
  - 6-region (default): Mexico and Central America combined
  - 7-group:            Mexico separated from Central America

Used by Build_all_trajectories.py.
"""

from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

from disparity_helpers import (
    DATA_PATH, OUTPUT_DATA, FIG_PATH, T2_ANCHOR,
    MCA, CARIBBEAN, SA, ASIA, AFRICA, EUCA,
    region_of as _region_of_6,
    load_ddp, load_mpi_state_region,
)

# === CONSTANTS ===
WINDOW_DAYS = 60
TOTAL_DAYS_EACH_SIDE = 420   # +/-420 days = 14 windows total

REGIONS_6 = ['Mexico and Central America', 'Caribbean', 'South America',
             'Asia', 'Africa', 'Europe/Canada/Oceania']

REGIONS_7 = ['Mexico', 'Central America', 'Caribbean', 'South America',
             'Asia', 'Africa', 'Europe/Canada/Oceania']

REGION_SHORT_6 = {
    'Mexico and Central America':  'Mex/CA',
    'Caribbean':                   'Caribbean',
    'South America':               'S.America',
    'Asia':                        'Asia',
    'Africa':                      'Africa',
    'Europe/Canada/Oceania':       'Eur/Can/Oce',
}
REGION_SHORT_7 = {
    'Mexico':              'Mexico',
    'Central America':     'C. America',
    'Caribbean':           'Caribbean',
    'South America':       'S. America',
    'Asia':                'Asia',
    'Africa':              'Africa',
    'Europe/Canada/Oceania': 'Eur/Can/Oce',
}

REGION_COLORS_6 = {
    'Mexico and Central America': '#993C1D',
    'Caribbean':                  '#E07B30',
    'South America':              '#534AB7',
    'Asia':                       '#7BA968',
    'Africa':                     '#A0628F',
    'Europe/Canada/Oceania':      '#3B7E9C',
}
REGION_COLORS_7 = {
    'Mexico':              '#7A2D14',
    'Central America':     '#D86F2A',
    'Caribbean':           '#E8A547',
    'South America':       '#534AB7',
    'Asia':                '#7BA968',
    'Africa':              '#A0628F',
    'Europe/Canada/Oceania': '#3B7E9C',
}

# === Pew 2023 national denominators (matches Build_pew_disparity.py) ===
PEW_REGION_2023 = {
    'Mexico and Central America':  7_100_000,
    'South America':               2_100_000,
    'Caribbean':                   1_150_000,
    'Asia':                        2_000_000,
    'Africa':                        475_000,
    'Europe/Canada/Oceania':       1_050_000,
}
PEW_MEXICO          = 4_250_000
PEW_CENTRAL_AMERICA = 2_850_000

# === ACS B05006 column codes (matches Build_AOR_denominator_ACS.py) ===
# Region totals
ACS_COL_MCA       = 'B05006_154E'  # Central America (incl Mexico)
ACS_COL_CARIBBEAN = 'B05006_140E'
ACS_COL_SA        = 'B05006_164E'
ACS_COL_ASIA      = 'B05006_047E'
ACS_COL_AFRICA    = 'B05006_095E'
ACS_COL_EUR       = 'B05006_002E'
ACS_COL_OCE       = 'B05006_130E'
ACS_COL_CANADA    = 'B05006_176E'
# Mexico-specific
ACS_COL_MEXICO    = 'B05006_160E'  # subset of MCA above

ACS_CSV_PATH = DATA_PATH / 'ACS' / 'county_birth_region_2023_raw.csv'


def _is_mexico_country(country):
    return (country or '').strip().upper() == 'MEXICO'


def region_of(country, grouping=6):
    """Map a citizenship-country string to a region label.

    grouping=6: collapse Mexico into 'Mexico and Central America'
    grouping=7: separate 'Mexico' from 'Central America'
    """
    if grouping == 6:
        return _region_of_6(country)
    # grouping == 7
    c = (country or '').strip().upper()
    if c == 'MEXICO':                return 'Mexico'
    if c in (MCA - {'MEXICO'}):      return 'Central America'
    if c in CARIBBEAN:               return 'Caribbean'
    if c in SA:                      return 'South America'
    if c in ASIA:                    return 'Asia'
    if c in AFRICA:                  return 'Africa'
    if c in EUCA:                    return 'Europe/Canada/Oceania'
    return ''


# === DENOMINATOR LOADERS ===
def load_mpi_denominators(grouping=6):
    """MPI national region totals (state-summed). Returns dict region -> pop."""
    mpi = load_mpi_state_region()
    region_totals = mpi.groupby('region').unauth_pop.sum().to_dict()
    if grouping == 6:
        return {r: float(region_totals[r]) for r in REGIONS_6}
    # 7-group: split Mexico out using state-country data
    sc = pd.read_csv(DATA_PATH / 'MPI' / 'mpi_state_country.csv')
    mexico_pop = float(sc[sc.country == 'Mexico'].unauth_pop.sum())
    mca_total = float(region_totals['Mexico and Central America'])
    out = {
        'Mexico':           mexico_pop,
        'Central America':  mca_total - mexico_pop,
    }
    for r in REGIONS_7[2:]:
        out[r] = float(region_totals[r])
    return out


def load_pew_denominators(grouping=6):
    if grouping == 6:
        return {r: float(v) for r, v in PEW_REGION_2023.items()}
    out = {
        'Mexico':           float(PEW_MEXICO),
        'Central America':  float(PEW_CENTRAL_AMERICA),
    }
    for r in REGIONS_7[2:]:
        out[r] = float(PEW_REGION_2023[r])
    return out


def load_acs_denominators(grouping=6):
    acs = pd.read_csv(ACS_CSV_PATH, dtype={'STATEFP': str, 'COUNTYFP': str, 'GEOID': str})
    mca_total = float(acs[ACS_COL_MCA].sum())
    region_totals = {
        'Mexico and Central America':  mca_total,
        'Caribbean':                   float(acs[ACS_COL_CARIBBEAN].sum()),
        'South America':               float(acs[ACS_COL_SA].sum()),
        'Asia':                        float(acs[ACS_COL_ASIA].sum()),
        'Africa':                      float(acs[ACS_COL_AFRICA].sum()),
        'Europe/Canada/Oceania':       float(
            acs[ACS_COL_EUR].sum() + acs[ACS_COL_OCE].sum() + acs[ACS_COL_CANADA].sum()
        ),
    }
    if grouping == 6:
        return region_totals
    mexico_pop = float(acs[ACS_COL_MEXICO].sum())
    out = {
        'Mexico':           mexico_pop,
        'Central America':  region_totals['Mexico and Central America'] - mexico_pop,
    }
    for r in REGIONS_7[2:]:
        out[r] = region_totals[r]
    return out


DENOMINATOR_LOADERS = {
    'MPI': load_mpi_denominators,
    'Pew': load_pew_denominators,
    'ACS': load_acs_denominators,
}


# === TRAJECTORY BUILDER ===
def assign_window(days_from_inaug):
    """Map a day-offset to a 60-day non-overlapping window index."""
    if days_from_inaug < 0:
        return -((-days_from_inaug - 1) // WINDOW_DAYS + 1)
    return days_from_inaug // WINDOW_DAYS


def load_filtered_ddp(grouping=6):
    """Load DDP arrests, filter to MPI-states, compute window indices,
    reassign region for the requested grouping.

    Returns dataframe with columns: date, post, state_clean, convicted,
    noncriminal, region, days_from_inaug, win_idx.
    """
    df = load_ddp(restrict_to_t2_window=False)
    if grouping == 7:
        # Re-classify region with Mexico separated
        df['region'] = df.citizenship_country.apply(lambda c: region_of(c, grouping=7))
    df = df[df.region != ''].copy()

    # Apples-to-apples sample: same MPI-state filter as the original MPI script
    mpi = load_mpi_state_region()
    df = df[df.state_clean.isin(mpi.state_upper.unique())].copy()

    df = df[(df.date >= T2_ANCHOR - pd.Timedelta(days=TOTAL_DAYS_EACH_SIDE))
            & (df.date <= T2_ANCHOR + pd.Timedelta(days=TOTAL_DAYS_EACH_SIDE))].copy()
    df['days_from_inaug'] = (df.date - T2_ANCHOR).dt.days
    df['win_idx'] = df.days_from_inaug.apply(assign_window).astype(int)
    return df


def build_trajectory(df, denominators, grouping=6):
    """Build long-format trajectory: region x window x measures.

    denominators: dict region -> population
    """
    regions = REGIONS_6 if grouping == 6 else REGIONS_7
    T_pop = sum(denominators.values())
    rows = []
    for win_idx, sub in df.groupby('win_idx'):
        center_days = (win_idx * WINDOW_DAYS + (win_idx + 1) * WINDOW_DAYS) / 2
        center_date = T2_ANCHOR + pd.Timedelta(days=center_days)
        by_region = sub.groupby('region').agg(
            arrests=('post', 'count'),
            convicted=('convicted', 'sum'),
            noncriminal=('noncriminal', 'sum'),
        ).reset_index()
        T_arr  = by_region.arrests.sum()
        T_conv = by_region.convicted.sum()
        T_non  = by_region.noncriminal.sum()
        for r in regions:
            row = by_region[by_region.region == r]
            arr  = int(row.arrests.iloc[0])    if len(row) else 0
            conv = int(row.convicted.iloc[0])  if len(row) else 0
            non  = int(row.noncriminal.iloc[0]) if len(row) else 0
            pop = denominators[r]
            pop_share = pop / T_pop
            rows.append({
                'win_idx': win_idx,
                'center_days': center_days,
                'center_date': center_date,
                'region': r,
                'arrests': arr, 'convicted': conv, 'noncriminal': non,
                'pop': pop, 'pop_share': pop_share,
                'disp_total': (arr / T_arr) / pop_share if T_arr > 0 else np.nan,
                'disp_conv':  (conv / T_conv) / pop_share if T_conv > 0 else np.nan,
                'disp_non':   (non / T_non) / pop_share if T_non > 0 else np.nan,
                'per100k_total': arr / pop * 100000,
                'per100k_conv':  conv / pop * 100000,
                'per100k_non':   non / pop * 100000,
            })
    ts = pd.DataFrame(rows)
    # Append deviation-from-pre-period-mean columns
    pre = ts[ts.win_idx < 0].groupby('region')[['disp_total', 'disp_conv', 'disp_non']].mean()
    ts['dev_total'] = ts.apply(lambda r: r.disp_total - pre.loc[r.region, 'disp_total'], axis=1)
    ts['dev_conv']  = ts.apply(lambda r: r.disp_conv  - pre.loc[r.region, 'disp_conv'],  axis=1)
    ts['dev_non']   = ts.apply(lambda r: r.disp_non   - pre.loc[r.region, 'disp_non'],   axis=1)
    return ts


# === PLOTTING ===
def _region_meta(grouping):
    if grouping == 6:
        return REGIONS_6, REGION_SHORT_6, REGION_COLORS_6
    return REGIONS_7, REGION_SHORT_7, REGION_COLORS_7


def _plot_3panel(ts, value_cols, ylabel_unit, suptitle, out_path, grouping,
                 zero_line=None, hline=None, ylim_lower=None):
    """3-panel sharex line plot, one panel per arrest-type slice.

    value_cols : list of (column_name, panel_title) triplet
    ylabel_unit: y-axis label
    zero_line  : if set, draw horizontal line at this y-value
    hline      : if set, draw horizontal line at y=hline (e.g. 1.0 for disparity ref)
    ylim_lower : optional fixed lower y-bound
    """
    regions, short, colors = _region_meta(grouping)
    n_regions = len(regions)
    n_legend_cols = 4 if n_regions == 7 else 3

    fig, axes = plt.subplots(3, 1, figsize=(12, 11), sharex=True)
    for ax, (col, title) in zip(axes, value_cols):
        for r in regions:
            sub = ts[ts.region == r].sort_values('center_days')
            ax.plot(sub.center_date, sub[col], marker='o', label=short[r],
                    color=colors[r], linewidth=2, markersize=5)
        ax.axvline(T2_ANCHOR, color='black', linestyle='--', linewidth=1.2, alpha=0.7)
        if hline is not None:
            ax.axhline(hline, color='gray', linestyle=':', linewidth=1)
        if zero_line is not None:
            ax.axhline(zero_line, color='gray', linestyle='-', linewidth=1, alpha=0.5)
        if ylim_lower is not None:
            ax.set_ylim(bottom=ylim_lower)
        ax.set_ylabel(ylabel_unit)
        ax.set_title(title, fontsize=11)
        ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
        ax.grid(axis='y', alpha=0.3)
    axes[0].legend(loc='upper left', fontsize=9, ncol=n_legend_cols, framealpha=0.95)
    axes[-1].xaxis.set_major_locator(mdates.MonthLocator(bymonth=[1, 4, 7, 10]))
    axes[-1].xaxis.set_major_formatter(mdates.DateFormatter('%b %Y'))
    plt.setp(axes[-1].xaxis.get_majorticklabels(), rotation=30, ha='right')
    fig.suptitle(suptitle, fontsize=12, y=1.0)
    plt.tight_layout()
    plt.savefig(out_path, dpi=180, bbox_inches='tight'); plt.close()


PANEL_TITLES = [
    ('All arrests',                          'total'),
    ('Arrests w/ criminal conviction',       'conv'),
    ('Arrests w/ no criminal conviction',    'non'),
]


def plot_per100k(ts, denom_label, grouping, out_path):
    cols = [(f'per100k_{key}', title) for title, key in PANEL_TITLES]
    grp_str = '6 regions' if grouping == 6 else '7 groups (Mex split)'
    _plot_3panel(
        ts, cols,
        ylabel_unit='Arrests per 100k\n(60-day window)',
        suptitle=f'Per-capita arrest rate trajectory ({denom_label} denominators) -- '
                 f'60-day windows around Trump 2 inauguration\n[{grp_str}]',
        out_path=out_path,
        grouping=grouping,
        ylim_lower=0,
    )


def plot_disparity(ts, denom_label, grouping, out_path):
    cols = [(f'disp_{key}', title) for title, key in PANEL_TITLES]
    grp_str = '6 regions' if grouping == 6 else '7 groups (Mex split)'
    _plot_3panel(
        ts, cols,
        ylabel_unit='Disparity ratio',
        suptitle=f'Regional disparity trajectory ({denom_label} denominators) -- '
                 f'60-day windows around Trump 2 inauguration\n[{grp_str}]',
        out_path=out_path,
        grouping=grouping,
        hline=1.0,
        ylim_lower=0,
    )


def plot_deviation(ts, denom_label, grouping, out_path):
    cols = [(f'dev_{key}', title) for title, key in PANEL_TITLES]
    grp_str = '6 regions' if grouping == 6 else '7 groups (Mex split)'
    _plot_3panel(
        ts, cols,
        ylabel_unit='Δ disparity\n(window - pre-period mean)',
        suptitle=f'Departure from pre-period baseline ({denom_label} denominators) -- '
                 f'60-day windows\n[{grp_str}]',
        out_path=out_path,
        grouping=grouping,
        zero_line=0.0,
    )


def figure_paths(denom_label, grouping):
    """Return (per100k_path, disparity_path, deviation_path, csv_path).

    Filename suffixes:
      MPI -> no suffix (default)        e.g. per100k_trajectory_60day.png
      Pew -> _PEW (uppercase, matches existing convention)
      ACS -> _ACS (uppercase)
    """
    suffix_map = {'MPI': '', 'Pew': '_PEW', 'ACS': '_ACS'}
    suffix_denom = suffix_map[denom_label]
    suffix_grp   = '' if grouping == 6 else '_7groups'
    base = f'trajectory_60day{suffix_denom}{suffix_grp}'
    return (
        FIG_PATH / f'per100k_{base}.png',
        FIG_PATH / f'disparity_{base}.png',
        FIG_PATH / f'disparity_{base}_deviation.png',
        OUTPUT_DATA / f'{base}_long.csv',
    )
