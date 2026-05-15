*===============================================================
* State_disparities.do
* Term 2 (DDP) — State-level enforcement intensity and
* region-of-birth disparate impact
* East, Patler, Cox (2026)
*
* Two analyses:
*   (1) State enforcement intensity (arrests per 100k unauthorized)
*       — pre vs. post Trump 2.0 inauguration
*   (2) Region-of-birth disparate impact within destination states
*       — regional arrest share vs. regional share of unauthorized population
*
* Inputs:
*   ddp_arrests_state_cleaned.dta    (from Clean_state_field.do)
*   mpi_state_unauth.csv             (51 rows, MPI 2023 state totals)
*   MPI/mpi_state_region.csv         (44 jurisdictions, MPI 2023)
*
* Missing-state strategy: DROP (Strategy B). Multi-state AORs
* (Atlanta, Boston, Chicago, etc.) that we did not impute leave
* a residual share of records with state_clean == "". These are
* dropped from the per-capita analysis and reported in a footnote.
*===============================================================

clear all
set more off

local DATAPATH "/Users/patler/Dropbox/Immigrant_Apprehensions/Data"
local FIGPATH  "/Users/patler/Dropbox/Immigrant_Apprehensions/Figures/ddp"

*===============================================================
* PART 1: Load cleaned DDP data, restrict to Term 2 windows
*===============================================================

use "`DATAPATH'/ddp_arrests_state_cleaned.dta", clear

count
local n_total = r(N)

* Normalize date to Stata %td (date) — the file may store it as %tc (datetime ms)
local dfmt : format date
if "`dfmt'" == "%tc" {
    gen long _ddate = dofc(date)
    drop date
    rename _ddate date
    format date %td
    display "Converted date from %tc (datetime) to %td (date)."
}

keep if inrange(date, mdy(1,20,2025) - 414, mdy(1,20,2025) + 414)
gen byte post = (date >= mdy(1,20,2025))
drop if ApprehensionAOR == "HQ Area of Responsibility" | missing(ApprehensionAOR)

count if state_clean == ""
local n_dropped = r(N)
display _newline "Records dropped (state_clean missing): `n_dropped'"
drop if state_clean == ""

count
local n_kept = r(N)
display "Records retained for state-level analysis: `n_kept'"

gen byte convicted = (ApprehensionCriminality == "1 Convicted Criminal")
gen ones = 1

*===============================================================
* PART 2: Country → MPI region crosswalk
* MPI's six regions: Mexico and Central America; Caribbean;
* South America; Europe/Canada/Oceania; Asia; Africa.
*===============================================================

rename citizenship_country country
replace country = trim(upper(country))   // DDP stores countries in ALL CAPS — standardize

gen str30 mpi_region = ""

* Helper: assign region for any country in a local list (lists are Title Case;
* comparison uppercases each list element to match the standardized country var).
* Avoids Stata's `expression too long` error from long inlist() calls.

local mca `" "Mexico" "Guatemala" "El Salvador" "Honduras" "Nicaragua" "Costa Rica" "Panama" "Belize" "'
foreach c of local mca {
    replace mpi_region = "Mexico and Central America" if country == upper("`c'")
}

local carib `" "Cuba" "Dominican Republic" "Haiti" "Jamaica" "Trinidad and Tobago" "Bahamas" "Barbados" "Antigua and Barbuda" "Saint Lucia" "Grenada" "Dominica" "Saint Vincent and the Grenadines" "Saint Kitts and Nevis" "'
foreach c of local carib {
    replace mpi_region = "Caribbean" if country == upper("`c'")
}

local sa `" "Brazil" "Colombia" "Venezuela" "Ecuador" "Peru" "Argentina" "Bolivia" "Chile" "Paraguay" "Uruguay" "Guyana" "Suriname" "'
foreach c of local sa {
    replace mpi_region = "South America" if country == upper("`c'")
}

local asia `" "China" "India" "Philippines" "Vietnam" "South Korea" "Japan" "Bangladesh" "Pakistan" "Indonesia" "Malaysia" "Thailand" "Sri Lanka" "Nepal" "Burma" "Myanmar" "Cambodia" "Laos" "Singapore" "Mongolia" "Taiwan" "Afghanistan" "Uzbekistan" "Kazakhstan" "Kyrgyzstan" "Tajikistan" "Turkmenistan" "North Korea" "Bhutan" "Maldives" "Brunei" "Iran" "Iraq" "Syria" "Lebanon" "Jordan" "Israel" "Yemen" "Saudi Arabia" "Turkey" "Armenia" "Azerbaijan" "Georgia" "Kuwait" "Qatar" "Bahrain" "United Arab Emirates" "Oman" "Palestine" "'
foreach c of local asia {
    replace mpi_region = "Asia" if country == upper("`c'")
}

local africa `" "Nigeria" "Ethiopia" "Egypt" "Kenya" "Ghana" "Somalia" "Sudan" "South Sudan" "South Africa" "Senegal" "Cameroon" "Liberia" "Sierra Leone" "Eritrea" "Ivory Coast" "Cote d'Ivoire" "Mali" "Morocco" "Tunisia" "Algeria" "Uganda" "Tanzania" "Zimbabwe" "Rwanda" "Burkina Faso" "Chad" "Niger" "Gambia" "Guinea" "Togo" "Benin" "Mauritania" "Angola" "Mozambique" "Zambia" "Malawi" "Madagascar" "Botswana" "Namibia" "Lesotho" "Congo" "Democratic Republic of the Congo" "Central African Republic" "Equatorial Guinea" "Gabon" "Comoros" "Cape Verde" "Djibouti" "Burundi" "Libya" "'
foreach c of local africa {
    replace mpi_region = "Africa" if country == upper("`c'")
}

local euca `" "Canada" "United Kingdom" "Ireland" "Germany" "France" "Italy" "Spain" "Portugal" "Greece" "Russia" "Ukraine" "Poland" "Romania" "Hungary" "Czech Republic" "Slovakia" "Bulgaria" "Serbia" "Croatia" "Slovenia" "Macedonia" "North Macedonia" "Albania" "Bosnia and Herzegovina" "Belgium" "Netherlands" "Sweden" "Norway" "Denmark" "Finland" "Iceland" "Switzerland" "Austria" "Luxembourg" "Cyprus" "Malta" "Estonia" "Latvia" "Lithuania" "Belarus" "Moldova" "Montenegro" "Kosovo" "Australia" "New Zealand" "Fiji" "Samoa" "Tonga" "Papua New Guinea" "'
foreach c of local euca {
    replace mpi_region = "Europe/Canada/Oceania" if country == upper("`c'")
}

* --- Special cases: DDP-specific spellings ---
replace mpi_region = "Asia"                  if country == "CHINA, PEOPLES REPUBLIC OF"
replace mpi_region = "Asia"                  if country == "TURKIYE"
replace mpi_region = "Asia"                  if country == "KOREA"
replace mpi_region = "Asia"                  if country == "HONG KONG"
replace mpi_region = "Asia"                  if country == "MACAU"
replace mpi_region = "Asia"                  if country == "EAST TIMOR"
replace mpi_region = "Africa"                if country == "DEM REP OF THE CONGO"
replace mpi_region = "Africa"                if country == "GUINEA-BISSAU"
replace mpi_region = "Africa"                if country == "MAURITIUS"
replace mpi_region = "Africa"                if country == "SAO TOME AND PRINCIPE"
replace mpi_region = "Africa"                if country == "ESWATINI"
replace mpi_region = "Caribbean"             if country == "ST. LUCIA"
replace mpi_region = "Caribbean"             if country == "ST. KITTS-NEVIS"
replace mpi_region = "Caribbean"             if country == "ST. VINCENT-GRENADINES"
replace mpi_region = "Caribbean"             if country == "ANTIGUA-BARBUDA"
replace mpi_region = "Caribbean"             if country == "BRITISH VIRGIN ISLANDS"
replace mpi_region = "Caribbean"             if country == "TURKS AND CAICOS ISLANDS"
replace mpi_region = "Caribbean"             if country == "BERMUDA"
replace mpi_region = "Caribbean"             if country == "NETHERLANDS ANTILLES"
replace mpi_region = "Caribbean"             if country == "GUADELOUPE"
replace mpi_region = "Caribbean"             if country == "CURACAO"
replace mpi_region = "Caribbean"             if country == "ARUBA"
replace mpi_region = "Caribbean"             if country == "ANGUILLA"
replace mpi_region = "Caribbean"             if country == "MONTSERRAT"
replace mpi_region = "Caribbean"             if country == "CAYMAN ISLANDS"
replace mpi_region = "Caribbean"             if country == "SINT MAARTEN(DUTCH)"
replace mpi_region = "Caribbean"             if country == "SINT EUSTATIUS"
replace mpi_region = "South America"         if country == "FRENCH GUIANA"
replace mpi_region = "Europe/Canada/Oceania" if country == "BOSNIA-HERZEGOVINA"
replace mpi_region = "Europe/Canada/Oceania" if country == "USSR"
replace mpi_region = "Europe/Canada/Oceania" if country == "YUGOSLAVIA"
replace mpi_region = "Europe/Canada/Oceania" if country == "SERBIA AND MONTENEGRO"
replace mpi_region = "Europe/Canada/Oceania" if country == "CZECHOSLOVAKIA"
replace mpi_region = "Europe/Canada/Oceania" if country == "ANDORRA"
replace mpi_region = "Europe/Canada/Oceania" if country == "MONACO"
replace mpi_region = "Europe/Canada/Oceania" if country == "MICRONESIA, FEDERATED STATES OF"
replace mpi_region = "Europe/Canada/Oceania" if country == "MARSHALL ISLANDS"
replace mpi_region = "Europe/Canada/Oceania" if country == "PALAU"
replace mpi_region = "Europe/Canada/Oceania" if country == "FRENCH POLYNESIA"
replace mpi_region = "Asia"                  if country == "PALESTINE BORN BEFORE 1948"
* UNKNOWN remains unmapped (not a country)

* --- Document any unmapped countries ---
count if mpi_region == ""
local n_unmapped = r(N)
if `n_unmapped' > 0 {
    preserve
        keep if mpi_region == ""
        contract country, freq(n)
        gsort -n
        local nrows = min(15, _N)
        display _newline "Top unmapped countries (will be excluded from regional disparate impact):"
        list in 1/`nrows', noobs
    restore
    display "Unmapped arrest records: `n_unmapped' (dropped from regional analysis only)"
}
else {
    display _newline "All citizenship_country values mapped to an MPI region. No unmapped records."
}

*===============================================================
* PART 2.5: Stage tempfiles
* Save record-level data + MPI denominator tables to tempfiles so
* the analysis sections can `use` them without nested preserves.
*===============================================================

tempfile records mpi_st mpi_reg
save `records'

preserve
    import delimited using "`DATAPATH'/mpi_state_unauth.csv", clear varnames(1) stringcols(1)
    gen state_upper = upper(state)
    replace state_upper = trim(state_upper)
    keep state_upper unauth_pop
    save `mpi_st'
restore

preserve
    import delimited using "`DATAPATH'/MPI/mpi_state_region.csv", clear varnames(1) stringcols(1 2)
    gen state_upper = upper(state)
    replace state_upper = trim(state_upper)
    keep state_upper region unauth_pop
    save `mpi_reg'
restore

*===============================================================
* PART 3: Analysis 1 — State enforcement intensity
* Arrests per 100,000 unauthorized residents, pre vs. post 1/20/2025
*===============================================================

use `records', clear
collapse (sum) arrests=ones convicted=convicted, by(state_clean post)
reshape wide arrests convicted, i(state_clean) j(post)
rename arrests0   n_pre
rename arrests1   n_post
rename convicted0 c_pre
rename convicted1 c_post
recode n_pre n_post c_pre c_post (.=0)

* Merge MPI state totals — keep(3) drops non-US "states" (territories,
* armed forces, Mexican-state data entry errors) that have no MPI denominator
rename state_clean state_upper
merge 1:1 state_upper using `mpi_st', keep(3) nogen

    * Per-100k intensity by period
    gen pre_per100k  = n_pre  / unauth_pop * 100000
    gen post_per100k = n_post / unauth_pop * 100000
    gen pct_change_intensity = (post_per100k/pre_per100k - 1) * 100
    gen pp_change_intensity  = post_per100k - pre_per100k

    * Conviction shares
    gen pre_conv  = c_pre /n_pre  * 100
    gen post_conv = c_post/n_post * 100
    gen pp_conv_change = post_conv - pre_conv

    label variable pre_per100k         "Pre arrests per 100k unauthorized"
    label variable post_per100k        "Post arrests per 100k unauthorized"
    label variable pct_change_intensity "% change in per-capita intensity"
    label variable pp_change_intensity  "Δ per-100k (post − pre)"
    label variable pp_conv_change       "Δ % w/ conviction (pp)"

    format n_pre n_post unauth_pop %12.0fc
    format pre_per100k post_per100k pp_change_intensity %7.1f
    format pct_change_intensity pre_conv post_conv pp_conv_change %6.1f

    gsort -post_per100k
    display _newline "===== STATE ENFORCEMENT INTENSITY (sorted by post per-100k) ====="
    list state_upper unauth_pop n_pre n_post pre_per100k post_per100k ///
        pct_change_intensity pp_conv_change, noobs sep(0)

    gsort -pp_change_intensity
    display _newline "===== STATES WHERE INTENSITY GREW MOST (Δ per-100k, top 15) ====="
    list state_upper pre_per100k post_per100k pp_change_intensity pct_change_intensity in 1/15, noobs

    export delimited using "`DATAPATH'/state_enforcement_intensity.csv", replace
    save "`DATAPATH'/state_enforcement_intensity.dta", replace
    display _newline "Saved: `DATAPATH'/state_enforcement_intensity.csv (.dta)"

    *--- Figure: pre vs. post per-100k scatter, with 45° reference line ---
    twoway ///
        (function y = x, range(0 200) lcolor(gs10) lpattern(dash) lwidth(thin)) ///
        (scatter post_per100k pre_per100k, mlabel(state_upper) mlabsize(vsmall) ///
            mlabcolor(gs5) mcolor("83 74 183") msymbol(O) msize(small)),         ///
        xtitle("Pre per 100k unauthorized")                                      ///
        ytitle("Post per 100k unauthorized")                                     ///
        title("Term 2 state enforcement intensity (per 100k unauthorized)", size(small)) ///
        note("Points above 45° line: state intensified per-capita arrests post-1/20/2025") ///
        legend(off) graphregion(color(white))
    graph export "`FIGPATH'/state_intensity_scatter.png", replace width(2400)

*===============================================================
* PART 4: Analysis 2 — Region-of-birth disparate impact
* Per-100k regional intensity within destination states
* + disparity ratio (region's share of arrests / region's share of unauth)
*===============================================================

use `records', clear
keep if mpi_region != ""
collapse (sum) arrests=ones convicted=convicted, by(state_clean mpi_region post)
reshape wide arrests convicted, i(state_clean mpi_region) j(post)
rename arrests0   n_pre
rename arrests1   n_post
rename convicted0 c_pre
rename convicted1 c_post
recode n_pre n_post c_pre c_post (.=0)

* "No criminal conviction" arrests = total − arrests with a criminal conviction
gen non_pre  = n_pre  - c_pre
gen non_post = n_post - c_post

* Merge regional unauth totals
rename state_clean state_upper
rename mpi_region region
merge m:1 state_upper region using `mpi_reg', keep(3) nogen
    * keep(3) requires both arrest data AND MPI denominator —
    * states without sub-state breakdown (MT, ND, SD, WY, WV, VT, ME)
    * are automatically excluded here.

    * Per-100k regional intensity (total, criminal-conviction, no-conviction)
    gen pre_per100k       = n_pre   / unauth_pop * 100000
    gen post_per100k      = n_post  / unauth_pop * 100000
    gen conv_pre_per100k  = c_pre   / unauth_pop * 100000
    gen conv_post_per100k = c_post  / unauth_pop * 100000
    gen non_pre_per100k   = non_pre / unauth_pop * 100000
    gen non_post_per100k  = non_post/ unauth_pop * 100000
    gen pp_change    = post_per100k - pre_per100k
    gen pct_change   = (post_per100k/pre_per100k - 1) * 100

    * State-level totals (denominators for share-of-arrests calcs)
    bys state_upper: egen state_unauth_total   = total(unauth_pop)
    bys state_upper: egen state_n_post_total   = total(n_post)
    bys state_upper: egen state_n_pre_total    = total(n_pre)
    bys state_upper: egen state_c_post_total   = total(c_post)
    bys state_upper: egen state_c_pre_total    = total(c_pre)
    bys state_upper: egen state_non_post_total = total(non_post)
    bys state_upper: egen state_non_pre_total  = total(non_pre)

    * Region shares within state
    gen region_unauth_share = unauth_pop / state_unauth_total
    gen region_post_share   = n_post     / state_n_post_total
    gen region_pre_share    = n_pre      / state_n_pre_total
    gen region_conv_post_share = c_post  / state_c_post_total
    gen region_conv_pre_share  = c_pre   / state_c_pre_total
    gen region_non_post_share  = non_post/ state_non_post_total
    gen region_non_pre_share   = non_pre / state_non_pre_total

    * Three flavors of disparity: total, criminal-conviction, no-criminal-conviction
    gen disparity_post           = region_post_share      / region_unauth_share
    gen disparity_pre            = region_pre_share       / region_unauth_share
    gen disparity_conv_post      = region_conv_post_share / region_unauth_share
    gen disparity_conv_pre       = region_conv_pre_share  / region_unauth_share
    gen disparity_noncriminal_post = region_non_post_share/ region_unauth_share
    gen disparity_noncriminal_pre  = region_non_pre_share / region_unauth_share
    gen disparity_change = disparity_post - disparity_pre

    label variable pre_per100k         "Pre regional arrests per 100k unauthorized"
    label variable post_per100k        "Post regional arrests per 100k unauthorized"
    label variable conv_post_per100k   "Post criminal-conviction arrests per 100k"
    label variable non_post_per100k    "Post no-criminal-conviction arrests per 100k"
    label variable disparity_post      "Post total disparity (>1 = over-targeted)"
    label variable disparity_conv_post "Post criminal-conviction disparity"
    label variable disparity_noncriminal_post "Post no-criminal-conviction disparity"

    format n_pre n_post c_pre c_post non_pre non_post unauth_pop %12.0fc
    format pre_per100k post_per100k conv_pre_per100k conv_post_per100k non_pre_per100k non_post_per100k pp_change %7.1f
    format pct_change %6.1f
    format disparity_pre disparity_post disparity_change ///
        disparity_conv_pre disparity_conv_post ///
        disparity_noncriminal_pre disparity_noncriminal_post %5.2f

    *--- Top 15 destination states by post-period volume ---
    bys state_upper: egen tot_n_post = total(n_post)
    preserve
        keep state_upper tot_n_post
        duplicates drop
        gsort -tot_n_post
        keep in 1/15
        keep state_upper
        gen byte top15 = 1
        tempfile top15
        save `top15', replace
    restore
    merge m:1 state_upper using `top15', keep(1 3)
    gen byte is_top15 = (_merge == 3)
    drop _merge

    *--- Display: regional disparity in top 15 destination states ---
    sort state_upper region
    display _newline "===== REGION-OF-BIRTH DISPARITY (top 15 destination states, post-period) ====="
    display "  Disparity > 1: region over-represented in arrests vs. its share of unauthorized population"
    display "  Disparity < 1: region under-represented"
    list state_upper region n_post unauth_pop post_per100k disparity_post disparity_change ///
        if is_top15==1, sepby(state_upper) noobs

    *--- National-level: aggregate across states for an overall picture ---
    preserve
        collapse (sum) n_pre n_post c_pre c_post non_pre non_post unauth_pop, by(region)

        * Per-100k rates by criminality status
        gen nat_pre_per100k        = n_pre   / unauth_pop * 100000
        gen nat_post_per100k       = n_post  / unauth_pop * 100000
        gen nat_conv_pre_per100k   = c_pre   / unauth_pop * 100000
        gen nat_conv_post_per100k  = c_post  / unauth_pop * 100000
        gen nat_non_pre_per100k    = non_pre / unauth_pop * 100000
        gen nat_non_post_per100k   = non_post/ unauth_pop * 100000
        gen nat_pct_change         = (nat_post_per100k/nat_pre_per100k - 1) * 100

        * National totals (denominators for share-of-arrests calcs)
        egen tot_unauth     = total(unauth_pop)
        egen tot_arr_pre    = total(n_pre)
        egen tot_arr_post   = total(n_post)
        egen tot_c_pre      = total(c_pre)
        egen tot_c_post     = total(c_post)
        egen tot_non_pre    = total(non_pre)
        egen tot_non_post   = total(non_post)

        gen unauth_share    = unauth_pop / tot_unauth
        gen pre_share       = n_pre      / tot_arr_pre
        gen post_share      = n_post     / tot_arr_post
        gen conv_pre_share  = c_pre      / tot_c_pre
        gen conv_post_share = c_post     / tot_c_post
        gen non_pre_share   = non_pre    / tot_non_pre
        gen non_post_share  = non_post   / tot_non_post

        gen disp_pre              = pre_share       / unauth_share
        gen disp_post             = post_share      / unauth_share
        gen disp_conv_pre         = conv_pre_share  / unauth_share
        gen disp_conv_post        = conv_post_share / unauth_share
        gen disp_noncriminal_pre  = non_pre_share   / unauth_share
        gen disp_noncriminal_post = non_post_share  / unauth_share

        format n_pre n_post c_pre c_post non_pre non_post unauth_pop %12.0fc
        format nat_pre_per100k nat_post_per100k nat_conv_pre_per100k nat_conv_post_per100k ///
               nat_non_pre_per100k nat_non_post_per100k %7.1f
        format nat_pct_change %6.1f
        format unauth_share pre_share post_share conv_pre_share conv_post_share ///
               non_pre_share non_post_share %5.3f
        format disp_pre disp_post disp_conv_pre disp_conv_post ///
               disp_noncriminal_pre disp_noncriminal_post %5.2f

        gsort -nat_post_per100k
        display _newline "===== NATIONAL REGION-OF-BIRTH DISPARITY — TOTAL ====="
        list region n_post unauth_pop nat_post_per100k unauth_share post_share disp_post, noobs

        display _newline "===== NATIONAL DISPARITY — ARRESTS WITH A CRIMINAL CONVICTION ====="
        list region c_post nat_conv_post_per100k unauth_share conv_post_share disp_conv_post, noobs

        display _newline "===== NATIONAL DISPARITY — ARRESTS WITH NO CRIMINAL CONVICTION ====="
        list region non_post nat_non_post_per100k unauth_share non_post_share disp_noncriminal_post, noobs

        display _newline "===== KEY COMPARISON: CRIMINAL-CONVICTION vs NO-CONVICTION DISPARITY (post period) ====="
        display "If no-conviction disparity is more extreme than criminal-conviction disparity for"
        display "a region, the under-/over-targeting is driven by ICE's PROACTIVE enforcement,"
        display "not its downstream pickup of jail outputs."
        list region disp_post disp_conv_post disp_noncriminal_post, noobs

        export delimited using "`DATAPATH'/national_region_disparity.csv", replace
    restore

export delimited using "`DATAPATH'/state_region_disparity.csv", replace
save "`DATAPATH'/state_region_disparity.dta", replace
display _newline "Saved: `DATAPATH'/state_region_disparity.csv (.dta)"
display "Saved: `DATAPATH'/national_region_disparity.csv"

*===============================================================
* COVERAGE NOTES (paste-ready footnote text)
*===============================================================

display _newline "===== COVERAGE NOTE FOR PAPER ====="
display "Term-2 ±414 day window. Records with state_clean missing (`n_dropped' of `n_total',"
display "from multi-state AORs Atlanta/Boston/Chicago/etc.) are dropped from per-capita"
display "analyses. State-level enforcement intensity uses MPI 2023 unauthorized-population"
display "estimates as denominators (51 jurisdictions). Region-of-birth disparate-impact"
display "analysis is restricted to the 44 jurisdictions with sub-state regional breakdowns"
display "(MT, ND, SD, WY, WV, VT, ME excluded — MPI does not publish sub-state estimates"
display "below the regional total)."

display _newline "===== State_disparities.do complete ====="
