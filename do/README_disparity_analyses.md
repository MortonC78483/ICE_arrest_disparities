# Disparity analyses — code inventory

All code for the East/Patler/Cox 2026 disparity work lives here. Pipeline summary:

## Stata pipeline (primary)

| Script | Purpose | Inputs | Outputs |
|---|---|---|---|
| `Clean_state_field.do` | DDP single-state AOR imputation | `AdminArrests_MidMar.dta` | `ddp_arrests_state_cleaned.dta` |
| `State_disparities.do` | State-level enforcement intensity + region disparity | `ddp_arrests_state_cleaned.dta`, `mpi_state_unauth.csv`, `MPI/mpi_state_region.csv` | `state_enforcement_intensity.csv`, `state_region_disparity.csv`, scatter PNG |
| `Country_disparities_term2.do` | Term 2 country-level disparities (older draft) | DDP, optional country denominators | various CSVs |

Note: the Reimers/Oaxaca decomposition scripts (`Oaxaca_patler_term1.do`, `Oaxaca_patler_term2.do`, `Oaxaca_comparison.do`, `Volume_conviction.do`) belong to the companion decomposition paper, not the disparity paper. They are not part of the disparity replication pipeline; the LEA/Community-Arrests classification reuses their convention but does not re-run them.

## MPI parsers (Python — exploratory data prep)

| Script | Purpose | Outputs |
|---|---|---|
| `Parse_MPI_profiles.py` | Parse pasted state-level MPI profiles | `MPI/mpi_state_country.csv`, `MPI/mpi_state_region.csv` |
| `Parse_MPI_county_profiles.py` | Parse pasted county-level MPI profiles | `MPI/mpi_county_country.csv`, `MPI/mpi_county_region.csv` |

Workflow: paste each MPI profile into the appropriate `*_pasted.txt` (in `Data/MPI/profiles/`), then run the parser.

## Disparity figure code (Python — all heatmaps, forest plots, trajectories)

Two shared helper modules:

- `disparity_helpers.py` — country→region crosswalk, AOR/method classifications, DDP loader, MPI/Pew/CMS denominator loaders. Used by the static-figure scripts. Includes a sandbox path-detection fallback so loaders resolve in any working environment; the canonical Dropbox path still wins when present.
- `trajectory_helpers.py` — denominator loaders (MPI, Pew, ACS), 60-day window aggregation, and plotting functions for the per-capita / disparity-level / deviation views. Used by the trajectory pipeline.

| Script | Purpose | Figures generated |
|---|---|---|
| `Build_disparity_figures.py` | All state×region heatmaps (post-only and pre/post) + national 3-bar chart | `state_region_disparity_*.png`, `disparity_by_criminality_preview.png` |
| `Disparity_statistical_tests.py` | 95% Poisson SIR CIs + pairwise z-tests across regions | `disparity_forest_by_criminality.png`, `national_region_disparity_with_CI.csv` |
| `Build_country_disparity.py` | National per-country bar chart, California country heatmap, LA AOR country heatmaps (prorated and county-based) | `country_per100k_by_method.png`, `california_country_disparity_heatmap.png`, `la_aor_country_disparity_heatmap*.png` |
| `Build_pew_disparity.py` | Pew sensitivity analysis: forest plot, slopegraph, MPI-vs-Pew comparison. (The trajectory portions of this script are superseded by `Build_all_trajectories.py`.) | `disparity_forest_PEW_7groups.png`, `disparity_pre_post_slopegraph_PEW*.png`, `disparity_MPI_vs_Pew_comparison.png` |
| `Build_all_trajectories.py` | **Master driver for the trajectory analyses.** Produces 9 PNGs (3 denominators × 3 view types) plus 3 long-format CSVs in a single run. The 7-group region split (Mexico separated from Central America) is fixed. | `per100k_trajectory_60day{,_PEW,_ACS}_7groups.png`, `disparity_trajectory_60day{,_PEW,_ACS}_7groups.png`, `disparity_trajectory_60day{,_Pew,_ACS}_7groups_deviation.png` |

**Superseded scripts** (kept on disk for back-reference; not in the current run order):

- `Build_disparity_trajectory.py` — original MPI 6-region trajectory; replaced by `Build_all_trajectories.py`.
- `Build_acs_disparity_trajectory.py` — intermediate ACS-only trajectory; rolled into `Build_all_trajectories.py`.

To regenerate all figures from scratch:

```bash
cd /Users/patler/Dropbox/Immigrant_Apprehensions/Do/Arrest_disparities/do
# 1. Run the Stata pipeline first (Clean_state_field → State_disparities)
# 2. Then the Python figure scripts (any order):
python Build_disparity_figures.py
python Disparity_statistical_tests.py
python Build_country_disparity.py
python Build_pew_disparity.py
python Build_all_trajectories.py
```

## DDP arrest data

The `arrests-latest.dta` file (DDP release) is shared directly via Dropbox by Caitlin Patler. Do not re-download from the public DDP release; the analyses in this folder were run on Caitlin's on-file version. The file lives at `Data/Arrest_disparities/arrests-latest.dta` alongside all the other data sources for this paper. The loader in `disparity_helpers.load_ddp()` looks there first, with fallbacks to a previous path under `Immigrant_Apprehensions_Patler/` for back-compat.

## Project layout

This paper has a self-contained folder structure inside the umbrella Dropbox. All data and code for the paper sit under two top-level folders (`Do/Arrest_disparities/` for code, `Data/Arrest_disparities/` for data), which simplifies sharing — invite a collaborator to just those two folders and they have everything they need.

```
Immigrant_Apprehensions/
├── Do/Arrest_disparities/
│   ├── do/                     ← scripts (this folder)
│   ├── figures/                ← all paper PNGs land here
│   └── output_data/            ← reserved for project-local working files
├── Data/Arrest_disparities/    ← ALL data inputs and outputs for this paper
│   ├── MPI/  Pew/  ACS/  CMSNY/      ← raw denominator sources
│   ├── crosswalks/             ← AOR, country, state, FIPS crosswalks
│   ├── project_outputs/        ← intermediate CSVs written by the scripts
│   ├── mpi_state_unauth.csv    ← MPI state-total denominator
│   ├── ddp_arrests_state_cleaned.dta  ← output of Clean_state_field.do
│   └── arrests-latest.dta      ← DDP raw arrest records (Caitlin's shared copy)
└── Writing/Arrest_disparities/ ← handoff doc + drafts
```

Three path variables in `disparity_helpers.py` make the layout swappable:

- `DATA_PATH`   → `Immigrant_Apprehensions/Data/Arrest_disparities/` (all raw inputs)
- `OUTPUT_DATA` → `Immigrant_Apprehensions/Data/Arrest_disparities/project_outputs/` (intermediate CSVs)
- `FIG_PATH`    → `Immigrant_Apprehensions/Do/Arrest_disparities/figures/` (PNG output)

All scripts use these variables, so moving the project to a different host or VM only requires updating those three lines.

## Methodological notes

**Window**: Term 2 ±414 days around 1/20/2025 (matches appendix specification).

**State imputation**: 11 single-state AORs that are >93% concentrated in one state get empty-state records imputed; multi-state AORs (Atlanta, Boston, Chicago, etc.) are left as missing and dropped from per-capita analyses (~15% of records pre-imputation, ~5% post).

**Disparity measures** (three quantities computed in the analysis files):

- **Per-100k arrest rate**: arrests / population × 100,000, with the population denominator held fixed at the chosen source's 2023 estimate. Direct measure of enforcement intensity.
- **Disparity ratio**: (region's share of arrests in jurisdiction j) / (region's share of unauthorized population in jurisdiction j). Equivalently, (region's per-100k rate) / (overall per-100k rate within the same window). >1 = over-targeted, <1 = under-targeted. Stays approximately stable when enforcement scales up roughly uniformly across regions.
- **Deviation from pre-period baseline**: for each window, (disparity in this window) − (region's mean disparity across the 7 pre-inauguration windows). Centers each region at 0 in the pre-period so that post-period departures are directly visible.

**95% CIs**: Poisson SIR formula. Var[log(disparity)] ≈ 1/observed_arrests. CI = disparity × exp(±1.96/sqrt(observed)).

**Method classification (LEA vs CA)**:
- LEA = jail/correctional pickups (287(g), CAP, ERO Reprocessed Arrest, Custodial Arrest, Probation/Parole, Patrol)
- CA (Community Arrests) = proactive interior enforcement (Located, Non-Custodial Arrest, Worksite Enforcement)
- OTHER = inspection/transport-driven (small share, dropped from main analyses)

**MPI denominator caveats**:
- 7 small states (MT, ND, SD, WY, WV, VT, ME) have no sub-state regional MPI breakdown
- Some state×region cells (e.g., Caribbean and Africa in Alabama) are below MPI's small-cell threshold and render blank in heatmaps
- Country-level denominators from `mpi_state_country.csv` capture only top 2-5 sending countries per state; small-country national denominators are under-counted (Cuba, Venezuela, etc.)

**Country-of-origin caveats** for the national per-country chart: Mexico, Guatemala, Honduras, El Salvador have near-complete denominators (top countries in 25-40 states each). Venezuela, Philippines, Ecuador, Colombia, Dominican Republic, Brazil are likely under-counted by 30-60% because they're listed as top-country in only 3-9 states. True per-100k rates for those countries are probably 1.5-2× lower than reported.

**Denominator sources** (full list — see §2.1 of `ICE_Term2_disparity_handoff_2026-05-12.docx` for details):

- **MPI 2023** (primary, unauthorized) — `Data/mpi_state_unauth.csv` summed to national regions via `Data/MPI/mpi_state_region.csv`. ~13.7M.
- **Pew 2023** (sensitivity, unauthorized) — `Data/Pew/RE_2025.08.21_Unauthorized-immigrants_detailed-tables_*.xlsx` plus the methodology PDF. ~14.0M. Mexico and Central America reported separately; Caribbean and Asia denominators are larger than MPI's state-summed version.
- **ACS 2023** (broader-coverage sensitivity, foreign-born) — `Data/ACS/county_birth_region_2023_raw.csv` (Census table B05006). ~46M. Denominator is foreign-born (not unauthorized-only), so absolute disparity levels are not directly comparable to MPI/Pew; trajectory shape and cross-region ordering are the comparable quantities.
- **CMS 2024** (third-source national sanity check) — `Data/CMSNY/estimates_for_50_states.csv` and `estimates_for_50_states_liminal.csv`. ~14.6M, with liminal-status breakdown. **TO DO**: CMSNY state×country-of-origin data is not yet downloaded — the CMS Data Hub at `data.cmsny.org` suppresses country/region breakdowns in multi-state queries, so per-state queries (or a direct request to CMS) are needed.
