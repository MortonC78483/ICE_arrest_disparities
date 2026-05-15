*===============================================================
* Country-of-origin disparities in ICE arrests, Term 2
* Pre vs. post Trump 2.0 inauguration, by AOR and nationality
*
* Examines four kinds of disparities:
*   (1) Compositional change   — share of arrests by nationality, pre vs. post
*   (2) Differential growth    — which nationalities grew most
*   (3) Geographic concentration — which AORs target which nationalities
*   (4) Disparate impact       — arrests per 100k unauthorized residents
*                                  (requires MPI population data; optional)
*
* Inputs:
*   AdminArrests_MidMar.dta              (always required)
*   mpi_state_unauth.csv                 (optional, for AOR enforcement intensity)
*   mpi_country_unauth.csv               (optional, for country disparate impact)
*   aor_state_crosswalk.dta              (optional, for state→AOR aggregation)
*===============================================================

clear all
set more off

local DATAPATH "/Users/patler/Dropbox/Immigrant_Apprehensions/Data"
local FIGPATH  "/Users/patler/Dropbox/Immigrant_Apprehensions/Figures/ddp"

*===============================================================
* PART 1: Load DDP data, classify, and filter to Term 2 windows
*===============================================================

use "`DATAPATH'/AdminArrests_MidMar.dta", clear

replace ApprehensionAOR = "San Antonio Area of Responsibility" ///
    if inlist(ApprehensionAOR, "Harlingen Area of Responsibility", "Houston Area of Responsibility")

keep if inrange(date, mdy(1,20,2025) - 414, mdy(1,20,2025) + 414)
gen byte post = (date >= mdy(1,20,2025))
drop if ApprehensionAOR == "HQ Area of Responsibility" | ApprehensionAOR == ""

gen byte convicted = (ApprehensionCriminality == "1 Convicted Criminal")
gen ones = 1

* Standardize country variable name
rename citizenship_country country
replace country = trim(country)

*===============================================================
* PART 2: Identify top 20 countries by post-period arrest volume
*===============================================================

preserve
    keep if post == 1
    contract country, freq(n_post)
    gsort -n_post
    keep in 1/20
    keep country
    gen byte top20 = 1
    tempfile top20
    save `top20', replace
restore

merge m:1 country using `top20', keep(1 3) nogen
replace country = "Other (non-top-20)" if missing(top20)

*===============================================================
* PART 3: Save analytical dataset (AOR × country × period × counts)
*===============================================================

preserve
    collapse (sum) arrests=ones convicted=convicted, by(ApprehensionAOR country post)
    save "`DATAPATH'/country_disparities.dta", replace
    display _newline "Saved: `DATAPATH'/country_disparities.dta"
    display "  (`=_N' rows: AOR × country × pre/post)"
restore

*===============================================================
* PART 4: National-level summary table by nationality
*===============================================================

preserve
    collapse (sum) arrests convicted, by(country post)
    reshape wide arrests convicted, i(country) j(post)

    rename arrests0 n_pre
    rename arrests1 n_post
    rename convicted0 c_pre
    rename convicted1 c_post

    gen pct_change_arrests = (n_post/n_pre - 1) * 100
    gen pre_conv_share     = c_pre /n_pre  * 100
    gen post_conv_share    = c_post/n_post * 100
    gen pp_change_conv     = post_conv_share - pre_conv_share

    capture confirm file "`DATAPATH'/mpi_country_unauth.csv"
    if _rc == 0 {
        preserve
            import delimited using "`DATAPATH'/mpi_country_unauth.csv", clear varnames(1)
            tempfile mpi
            save `mpi'
        restore
        merge 1:1 country using `mpi', keep(1 3) nogen
        gen post_arrests_per_100k = n_post / unauth_pop * 100000
        gen pre_arrests_per_100k  = n_pre  / unauth_pop * 100000
        label variable post_arrests_per_100k "Term 2 post arrests per 100k unauthorized"
        label variable pre_arrests_per_100k  "Term 2 pre arrests per 100k unauthorized"
    }

    gsort -n_post
    format n_pre n_post c_pre c_post %10.0fc
    format pct_change_arrests pre_conv_share post_conv_share pp_change_conv %6.1f
    list, noobs
    export excel "`DATAPATH'/country_disparities_national.xlsx", replace firstrow(variables)
    display _newline "Saved: `DATAPATH'/country_disparities_national.xlsx"
restore

*===============================================================
* PART 5: AOR × top-10-nationality matrix (for heatmap)
*===============================================================

preserve
    * Re-identify top 10 (subset of top 20) for narrower matrix
    keep if post == 1 & country != "Other (non-top-20)"
    contract country, freq(n)
    gsort -n
    keep in 1/10
    keep country
    gen byte top10 = 1
    tempfile top10
    save `top10', replace
restore

preserve
    use "`DATAPATH'/country_disparities.dta", clear
    merge m:1 country using `top10', keep(3) nogen
    reshape wide arrests convicted, i(ApprehensionAOR country) j(post)
    rename arrests0 n_pre
    rename arrests1 n_post
    gen pct_change = (n_post/n_pre - 1) * 100
    keep ApprehensionAOR country n_pre n_post pct_change
    replace ApprehensionAOR = subinstr(ApprehensionAOR, " Area of Responsibility", "", .)
    rename ApprehensionAOR aor
    sort aor country
    export delimited using "`DATAPATH'/country_aor_heatmap.csv", replace
    display _newline "Saved: `DATAPATH'/country_aor_heatmap.csv"
restore

*===============================================================
* PART 6: Per-AOR top-3 nationalities (post-period composition)
*===============================================================

preserve
    use "`DATAPATH'/country_disparities.dta", clear
    keep if post == 1
    bys ApprehensionAOR: egen aor_total = total(arrests)
    gen pct_share = arrests/aor_total * 100
    gsort ApprehensionAOR -arrests
    by ApprehensionAOR: gen rank = _n
    keep if rank <= 3
    keep ApprehensionAOR rank country arrests pct_share
    replace ApprehensionAOR = subinstr(ApprehensionAOR, " Area of Responsibility", "", .)
    rename ApprehensionAOR aor
    list, sepby(aor) noobs
    export delimited using "`DATAPATH'/country_aor_top3.csv", replace
    display _newline "Saved: `DATAPATH'/country_aor_top3.csv"
restore

*===============================================================
* PART 7: AOR-level enforcement intensity (per 100k unauthorized)
* Requires mpi_state_unauth.csv and aor_state_crosswalk.dta
*===============================================================

capture confirm file "`DATAPATH'/mpi_state_unauth.csv"
local has_state = (_rc == 0)
capture confirm file "`DATAPATH'/aor_state_crosswalk.dta"
local has_xwalk = (_rc == 0)

if `has_state' & `has_xwalk' {
    preserve
        import delimited using "`DATAPATH'/mpi_state_unauth.csv", clear varnames(1)
        tempfile mpi_state
        save `mpi_state'

        use "`DATAPATH'/aor_state_crosswalk.dta", clear
        merge 1:1 state using `mpi_state', keep(3) nogen
        collapse (sum) unauth_pop, by(aor)
        tempfile aor_unauth
        save `aor_unauth'

        use "`DATAPATH'/country_disparities.dta", clear
        collapse (sum) arrests convicted, by(ApprehensionAOR post)
        replace ApprehensionAOR = subinstr(ApprehensionAOR, " Area of Responsibility", "", .)
        rename ApprehensionAOR aor
        merge m:1 aor using `aor_unauth', keep(1 3) nogen
        gen arrests_per_100k = arrests/unauth_pop * 100000
        reshape wide arrests convicted arrests_per_100k, i(aor unauth_pop) j(post)
        rename arrests_per_100k0 pre_intensity
        rename arrests_per_100k1 post_intensity
        gen intensity_pct_change = (post_intensity/pre_intensity - 1) * 100
        gsort -post_intensity
        list aor unauth_pop pre_intensity post_intensity intensity_pct_change, noobs
        export delimited using "`DATAPATH'/aor_enforcement_intensity.csv", replace
        display _newline "Saved: `DATAPATH'/aor_enforcement_intensity.csv"
    restore
}
else {
    display _newline "PART 7 skipped (missing mpi_state_unauth.csv or aor_state_crosswalk.dta)"
    display "  To enable: provide MPI state-level unauthorized population estimates"
    display "  and a state→AOR crosswalk."
}

display _newline "===== Country disparities analysis complete ====="
