# Increases in national origin disparities in ICE Arrests, 2025-26

## System Requirements
The code for this paper uses R version 4.5.2. A snapshot of the R environment used to run the code is located in renv.lock. The code for this paper was tested on a MacBook Pro (15.4.1) laptop computer. No non-standard hardware is required to run the code.

## Installation Guide
### Dependencies: 
Install all packages, matching the versions to the renv.lock file included in this repository, using renv::init(), then the renv::restore() function. This took 10 minutes on a MacBook Pro (15.4.1) laptop computer.

### Raw data sources:
Our data folder is not included in the GitHub, but all datasets are available online. Processes to obtain datasets are described below, along with the filepaths they should be set to within the data folder in order to proceed with running the rest of the codebase.

* data/raw/arrests-latest.parquet
    - Navigate to https://github.com/deportationdata/ice/blob/71fb6ae39e0aeff8a5c7ad2b071153a235c59797/data/arrests-latest.parquet, download the "arrests-latest.parquet" dataset. At the time of writing this paper, this was the most recent dataset available. Save the dataset to “data/raw/arrests-latest.parquet”.
* data/raw/county_birth_region_2023_raw.csv
    - Navigate to https://data.census.gov/table/ACSDT5Y2023.B05006?g=010XX00US$0500000, then click “Download Table” -> “Download .zip”. Save the .csv file in the downloaded dataset as “data/raw/county_birth_region_2023_raw.csv”, which requires changing the name.
* data/raw/ice-aor-county-shp.parquet
    - Navigate to https://github.com/deportationdata/ice-offices/tree/refs/heads/main/data and download the April 16, 2026 “ice-aor-county-shp.parquet” file. Save the file to “data/raw/ice-aor-county-shp.parquet”.
* data/raw/mpi_state_region.csv
    - Navigate to https://www.migrationpolicy.org/data-tool/unauthorized-immigrants, use the state profile navigation to create a dataset with columns “state” (containing title case state name), “region” containing region options “Mexico and Central America,” “Caribbean,” “South America,” “Europe/Canada/Oceania,” “Asia,” and “Africa,” and “unauth_pop” containing the MPI unauthorized population. Entries without an MPI estimate are omitted (e.g. Alaska only has entries for Mexico and Central America, Europe/Canada/Oceania, and Asia). Save the dataset to “data/raw/mpi_state_region.csv”.

Downloading the raw data sources should not take longer than 5 minutes per data source on a normal laptop computer (tested on MacBook Pro (15.4.1)).
The MPI data source will take longer to copy from the MPI website. Each state takes less than 30 seconds to load on the website.

## Demo and Instructions for use
The datasets for this paper are relatively small, so we offer readers the opportunity to run our full codebase as our demo for reproducibility. The order, expected runtime, and expected outputs of the various files are below.

Set your working directory to the main project directory (not the "do" directory) before running .R files. 
Knit all .Rmd files to run -- they will use the "do" directory as their working directory automatically.

### Running the code files
* 00_clean_arrests_threat_gender_age.R cleans the raw arrests data. For details on the cleaning process and more information on how many individuals are cut from the dataset at each cleaning step, see 0.1_paper_numbers.Rmd, which outputs more information about this cleaning process. Expected output: data/processed/ddp_arrests_state_threat_gender_age_cleaned.dta. Time to run: 30 seconds.
* 01_make_glm_traj.R creates the panel data trajectories with threat level, arrest type, and conviction status by state and AOR using raw denominator data and the cleaned arrest data. Users should run this file twice, once with filter_LA = F and AOR = F (expected output: data/processed/glm_trajectory_type_threatlevel_convicted_ACS_MPI.csv), and once with filter_LA = F and AOR = T (expected output: data/processed/glm_trajectory_type_threatlevel_convicted_ACS_MPI_AOR.csv). Time to run: 30 seconds per input combination.
* 02_make_table.Rmd makes tables 1 and accompanying supplement table, which summarize changes in arrest rates pre- and post-inauguration using MPI and ACS denominators respectively. Expected output: prints two tables, one for the main text (MPI denominators) and one for the supplement (ACS denominators). Time to run: 30 seconds.
* 03_fig_rates.Rmd makes figure 1 and accompanying supplement figures with raw arrest rates by group and window, as well as the diff-in-diff values by group and window. Expected output: figures/main_text/mpi_denoms_fig1.pdf, figures/supplement/acs_denoms_fig1.pdf, figures/supplement/multiplicative_fig1.pdf. Time to run: 1 minute.
* 04_fig_boxplot.Rmd makes figure 2 and accompanying supplement figures with the change in arrest rates (pre- to post-inauguration) by group and AOR. Expected output: figures/main_text/mpi_denoms_fig3.pdf, figures/supplement/acs_denoms_fig3.pdf, figures/supplement/multiplicative_fig3.pdf. Time to run: 30 seconds.
* 05_fig_conviction.Rmd makes figure 3 and accompanying supplement figures with raw arrest rates by group, conviction status, and window, as well as the diff-in-diff values by group, conviction status, and window. Expected output: figures/main_text/mpi_denoms_fig2.pdf, figures/supplement/acs_denoms_fig2.pdf, figures/supplement/multiplicative_fig2.pdf. Time to run: 5 minutes.
* 06_triple_diff.Rmd  performs the triple difference analysis to determine whether region disparities are higher among people with or without convictions, by arrest type. Expected output: printed confidence intervals for two triple difference analyses. Time to run: 30 seconds.
* 07_indiv_region_increases.Rmd calculates the differences in arrest rates by state and AOR to determine whether the trends observed nationally in figure 1b and figure 2 appear hold in smaller geographies. This result is briefly discussed in the paper but not presented quantitatively. Time to run: 30 seconds.
* 08_indiv_region_conv_method_increases.Rmd calculates the differences in arrest rates by state and AOR restricted to certain combinations of conviction status and arrest method (e.g. LEA arrests of non-convicted people). This shows that the differences observed nationally in figure 3 hold in smaller geographies. This result is briefly discussed in the paper but not presented quantitatively. Time to run: 30 seconds.

### Instructions for use
Once raw data have been formatted as described above, running the code files in order will reproduce all figures, tables, and numbers reported in the paper.