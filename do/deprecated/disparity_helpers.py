"""
Shared helpers for disparity analysis scripts.
Contains: country -> MPI region mapping, AOR classifications, data loaders.

Usage: from disparity_helpers import load_ddp, region_of, classify_method, REGIONS_ORDER
"""

import pandas as pd
import numpy as np
from pathlib import Path

# === PATHS ===
# All disparity-paper data lives under Data/Arrest_disparities/ (consolidated for
# easier sharing -- one folder, one Dropbox invite). Layout:
#
#   Data/Arrest_disparities/
#     ├── MPI/    Pew/    ACS/    CMSNY/      <- raw denominator sources
#     ├── crosswalks/                          <- AOR/country/state/FIPS crosswalks
#     ├── project_outputs/                     <- intermediate CSVs from the pipeline
#     ├── mpi_state_unauth.csv                 <- MPI state-total denominator
#     ├── ddp_arrests_state_cleaned.dta        <- output of Clean_state_field.do
#     └── arrests-latest.dta                   <- DDP raw arrest records (Caitlin's copy)
#
# The Python and Stata scripts live in Do/Arrest_disparities/do/ (this file's
# directory). Output figures land in Do/Arrest_disparities/figures/.
PROJECT_ROOT = Path('/Users/patler/Dropbox/Immigrant_Apprehensions/Do/Arrest_disparities')
DATA_PATH    = Path('/Users/patler/Dropbox/Immigrant_Apprehensions/Data/Arrest_disparities')
OUTPUT_DATA  = DATA_PATH / 'project_outputs'
FIG_PATH     = PROJECT_ROOT / 'figures'
DDP_RAW      = DATA_PATH / 'arrests-latest.dta'   # raw DDP file (Caitlin's shared copy)

# Detect VM mount in case running on Cowork sandbox (any session name)
import os, glob as _glob
if not DATA_PATH.exists():
    _candidates = _glob.glob('/sessions/*/mnt/Immigrant_Apprehensions')
    if _candidates:
        _root = Path(_candidates[0])
        DATA_PATH    = _root / 'Data' / 'Arrest_disparities'
        OUTPUT_DATA  = DATA_PATH / 'project_outputs'
        FIG_PATH     = _root / 'Do' / 'Arrest_disparities' / 'figures'
        PROJECT_ROOT = _root / 'Do' / 'Arrest_disparities'
        DDP_RAW      = DATA_PATH / 'arrests-latest.dta'

# === CONSTANTS ===
REGIONS_ORDER = ['Mexico and Central America','Caribbean','South America','Asia','Africa','Europe/Canada/Oceania']
REGION_SHORT = {'Mexico and Central America':'Mex/CA','Caribbean':'Caribbean','South America':'S.America',
                'Asia':'Asia','Africa':'Africa','Europe/Canada/Oceania':'Eur/Can/Oce'}

# Term 2 inauguration anchor and ±414-day windows
T2_ANCHOR = pd.Timestamp(2025, 1, 20)
WINDOW_DAYS = 414

# Single-state AOR imputation map (Clean_state_field.do logic)
STATE_IMPUTATION = {
    'Phoenix Area of Responsibility': 'ARIZONA',
    'Dallas Area of Responsibility': 'TEXAS',
    'Buffalo Area of Responsibility': 'NEW YORK',
    'New York City Area of Responsibility': 'NEW YORK',
    'San Diego Area of Responsibility': 'CALIFORNIA',
    'Houston Area of Responsibility': 'TEXAS',
    'Harlingen Area of Responsibility': 'TEXAS',
    'San Antonio Area of Responsibility': 'TEXAS',
    'Miami Area of Responsibility': 'FLORIDA',
    'Los Angeles Area of Responsibility': 'CALIFORNIA',
    'San Francisco Area of Responsibility': 'CALIFORNIA',
}

# Apprehension method classification (matches Oaxaca_patler_term2.do)
LEA_METHODS = {
    '287(g) Program','Anti-Smuggling','CAP Federal Incarceration','CAP Local Incarceration',
    'CAP State Incarceration','Criminal Alien Program','ERO Reprocessed Arrest',
    'Law Enforcement Agency Response Unit','Organized Crime Drug Enforcement Task Force',
    'Other Agency (turned over to INS)','Other Task Force','Probation and Parole',
    'Custodial Arrest','Patrol Border','Patrol Interior',
}
CA_METHODS = {'Located','Non-Custodial Arrest','Worksite Enforcement'}
# Anything else → 'OTHER'

# === COUNTRY → MPI REGION CROSSWALK (uppercased to match DDP) ===
MCA = {'MEXICO','GUATEMALA','EL SALVADOR','HONDURAS','NICARAGUA','COSTA RICA','PANAMA','BELIZE'}
CARIBBEAN = {
    'CUBA','DOMINICAN REPUBLIC','HAITI','JAMAICA','TRINIDAD AND TOBAGO','BAHAMAS','BARBADOS',
    'ANTIGUA AND BARBUDA','SAINT LUCIA','GRENADA','DOMINICA','SAINT VINCENT AND THE GRENADINES',
    'SAINT KITTS AND NEVIS','ST. LUCIA','ST. KITTS-NEVIS','ST. VINCENT-GRENADINES','ANTIGUA-BARBUDA',
    'BRITISH VIRGIN ISLANDS','TURKS AND CAICOS ISLANDS','BERMUDA','NETHERLANDS ANTILLES','GUADELOUPE',
    'CURACAO','ARUBA','ANGUILLA','MONTSERRAT','CAYMAN ISLANDS','SINT MAARTEN(DUTCH)','SINT EUSTATIUS',
}
SA = {'BRAZIL','COLOMBIA','VENEZUELA','ECUADOR','PERU','ARGENTINA','BOLIVIA','CHILE','PARAGUAY',
      'URUGUAY','GUYANA','SURINAME','FRENCH GUIANA'}
ASIA = {
    'CHINA','INDIA','PHILIPPINES','VIETNAM','SOUTH KOREA','JAPAN','BANGLADESH','PAKISTAN',
    'INDONESIA','MALAYSIA','THAILAND','SRI LANKA','NEPAL','BURMA','MYANMAR','CAMBODIA','LAOS',
    'SINGAPORE','MONGOLIA','TAIWAN','AFGHANISTAN','UZBEKISTAN','KAZAKHSTAN','KYRGYZSTAN','TAJIKISTAN',
    'TURKMENISTAN','NORTH KOREA','BHUTAN','MALDIVES','BRUNEI','IRAN','IRAQ','SYRIA','LEBANON','JORDAN',
    'ISRAEL','YEMEN','SAUDI ARABIA','TURKEY','ARMENIA','AZERBAIJAN','GEORGIA','KUWAIT','QATAR',
    'BAHRAIN','UNITED ARAB EMIRATES','OMAN','PALESTINE',
    # DDP-specific spellings:
    'CHINA, PEOPLES REPUBLIC OF','TURKIYE','KOREA','HONG KONG','MACAU','EAST TIMOR',
    'PALESTINE BORN BEFORE 1948',
}
AFRICA = {
    'NIGERIA','ETHIOPIA','EGYPT','KENYA','GHANA','SOMALIA','SUDAN','SOUTH SUDAN','SOUTH AFRICA',
    'SENEGAL','CAMEROON','LIBERIA','SIERRA LEONE','ERITREA','IVORY COAST',"COTE D'IVOIRE",'MALI',
    'MOROCCO','TUNISIA','ALGERIA','UGANDA','TANZANIA','ZIMBABWE','RWANDA','BURKINA FASO','CHAD',
    'NIGER','GAMBIA','GUINEA','TOGO','BENIN','MAURITANIA','ANGOLA','MOZAMBIQUE','ZAMBIA','MALAWI',
    'MADAGASCAR','BOTSWANA','NAMIBIA','LESOTHO','CONGO','DEMOCRATIC REPUBLIC OF THE CONGO',
    'CENTRAL AFRICAN REPUBLIC','EQUATORIAL GUINEA','GABON','COMOROS','CAPE VERDE','DJIBOUTI',
    'BURUNDI','LIBYA',
    # DDP-specific spellings:
    'DEM REP OF THE CONGO','GUINEA-BISSAU','MAURITIUS','SAO TOME AND PRINCIPE','ESWATINI',
}
EUCA = {
    'CANADA','UNITED KINGDOM','IRELAND','GERMANY','FRANCE','ITALY','SPAIN','PORTUGAL','GREECE',
    'RUSSIA','UKRAINE','POLAND','ROMANIA','HUNGARY','CZECH REPUBLIC','SLOVAKIA','BULGARIA','SERBIA',
    'CROATIA','SLOVENIA','MACEDONIA','NORTH MACEDONIA','ALBANIA','BOSNIA AND HERZEGOVINA','BELGIUM',
    'NETHERLANDS','SWEDEN','NORWAY','DENMARK','FINLAND','ICELAND','SWITZERLAND','AUSTRIA',
    'LUXEMBOURG','CYPRUS','MALTA','ESTONIA','LATVIA','LITHUANIA','BELARUS','MOLDOVA','MONTENEGRO',
    'KOSOVO','AUSTRALIA','NEW ZEALAND','FIJI','SAMOA','TONGA','PAPUA NEW GUINEA',
    # DDP-specific spellings:
    'BOSNIA-HERZEGOVINA','USSR','YUGOSLAVIA','SERBIA AND MONTENEGRO','CZECHOSLOVAKIA','ANDORRA',
    'MONACO','MICRONESIA, FEDERATED STATES OF','MARSHALL ISLANDS','PALAU','FRENCH POLYNESIA',
}

def region_of(country):
    """Return MPI region for a country. Pass uppercased trimmed string."""
    c = (country or '').strip().upper()
    if c in MCA: return 'Mexico and Central America'
    if c in CARIBBEAN: return 'Caribbean'
    if c in SA: return 'South America'
    if c in ASIA: return 'Asia'
    if c in AFRICA: return 'Africa'
    if c in EUCA: return 'Europe/Canada/Oceania'
    return ''  # unmapped

def classify_method(m):
    if m in LEA_METHODS: return 'LEA'
    if m in CA_METHODS:  return 'CA'
    return 'OTHER'

# === DATA LOADERS ===

def load_ddp(columns=None, restrict_to_t2_window=True, drop_hq=True, drop_missing_state=True):
    """Load DDP arrests-latest.dta with standard preprocessing.

    Args:
        columns: list of columns to load (default = full set used in disparity work)
        restrict_to_t2_window: if True, filter to ±414 days around 1/20/2025
        drop_hq: if True, drop HQ AOR records
        drop_missing_state: if True, apply state imputation and drop empty state_clean

    Returns DataFrame with columns: date, post (0/1), state_clean (uppercased + imputed),
                                    convicted (0/1), noncriminal, region, method_class
    """
    if columns is None:
        columns = ['apprehension_date','apprehension_aor','apprehension_state',
                   'citizenship_country','apprehension_criminality','apprehension_method']

    # Try common DDP source paths. The canonical location is now
    # DATA_PATH / 'arrests-latest.dta' (inside Data/Arrest_disparities/).
    # Older locations are kept as fallbacks so prior workspaces still work.
    import glob
    candidates = [
        DDP_RAW,
        Path('/Users/patler/Dropbox/Immigrant_Apprehensions_Patler/Data/ddp arrests/arrests-latest.dta'),
        Path('/sessions/affectionate-quirky-fermi/mnt/Data/ddp arrests/arrests-latest.dta'),
    ]
    # Also probe any current Cowork sandbox mount (handles arbitrary session names).
    candidates += [Path(p) for p in glob.glob('/sessions/*/mnt/*/Arrest_disparities/arrests-latest.dta')]
    candidates += [Path(p) for p in glob.glob('/sessions/*/mnt/ddp arrests/arrests-latest.dta')]
    candidates += [Path(p) for p in glob.glob('/sessions/*/mnt/*/ddp arrests/arrests-latest.dta')]
    def _safe_exists(p):
        try:
            return p.exists()
        except (PermissionError, OSError):
            return False
    src = next((p for p in candidates if _safe_exists(p)), None)
    if src is None:
        raise FileNotFoundError(f"DDP arrests-latest.dta not found in: {candidates}")

    df = pd.read_stata(str(src), columns=columns, convert_categoricals=False)
    df['date'] = pd.to_datetime(df.apprehension_date, errors='coerce')

    # State imputation
    df['state_clean'] = df.apprehension_state.str.strip().str.upper()
    mask = df['state_clean'] == ''
    df.loc[mask, 'state_clean'] = df.loc[mask, 'apprehension_aor'].map(STATE_IMPUTATION).fillna('')

    # Term 2 window filter
    if restrict_to_t2_window:
        df = df[(df.date >= T2_ANCHOR - pd.Timedelta(days=WINDOW_DAYS))
                & (df.date <= T2_ANCHOR + pd.Timedelta(days=WINDOW_DAYS))].copy()
    df['post'] = (df.date >= T2_ANCHOR).astype(int)

    if drop_missing_state:
        df = df[df.state_clean != '']

    if drop_hq:
        df = df[~df.apprehension_aor.isin(['HQ Area of Responsibility', ''])]

    # Conviction & method
    df['convicted'] = (df.apprehension_criminality == '1 Convicted Criminal').astype(int)
    df['noncriminal'] = 1 - df.convicted
    df['method_class'] = df.apprehension_method.apply(classify_method)

    # Region from country
    df['region'] = df.citizenship_country.apply(region_of)

    return df

def load_mpi_state_region():
    """Return MPI state×region unauth_pop dataframe with state_upper key."""
    f = DATA_PATH / 'MPI' / 'mpi_state_region.csv'
    df = pd.read_csv(f)
    df['state_upper'] = df.state.str.upper().str.strip()
    return df.groupby(['state_upper','region']).unauth_pop.sum().reset_index()

def load_mpi_state_country():
    """Return MPI state×country unauth_pop dataframe."""
    f = DATA_PATH / 'MPI' / 'mpi_state_country.csv'
    df = pd.read_csv(f)
    df['state_upper'] = df.state.str.upper().str.strip()
    return df

def load_mpi_county_region():
    """Return MPI county×region unauth_pop (only counties we've parsed)."""
    f = DATA_PATH / 'MPI' / 'mpi_county_region.csv'
    return pd.read_csv(f)

def load_mpi_county_country():
    """Return MPI county×country unauth_pop (only counties we've parsed)."""
    f = DATA_PATH / 'MPI' / 'mpi_county_country.csv'
    return pd.read_csv(f)

def load_mpi_state_totals():
    """Return state-level unauthorized population totals."""
    f = DATA_PATH / 'mpi_state_unauth.csv'
    return pd.read_csv(f)
