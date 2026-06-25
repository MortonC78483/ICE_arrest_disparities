*===============================================================
* Clean state field in DDP arrest data
* Step 1: Single-state imputation for AORs that map cleanly to one state
*
* Source DDP data has ~15% of records with empty apprehension_state.
* For 11 AORs, the records-with-state are >93% in a single state, so
* empty-state records can be confidently imputed to that state.
*
* Multi-state AORs (Atlanta, Boston, Chicago, etc.) are NOT imputed
* in this script — they require proportional allocation, handled
* separately if needed.
*
* Outputs:
*   ddp_arrests_state_cleaned.dta  (full DDP data with state_clean filled)
*===============================================================

clear all
set more off

local DATAPATH "/Users/patler/Dropbox/Immigrant_Apprehensions/Data"

use "`DATAPATH'/AdminArrests_MidMar.dta", clear

* Standardize AOR variable
gen aor_short = subinstr(ApprehensionAOR, " Area of Responsibility", "", .)

* Drop records with no AOR or HQ
display "Before dropping invalid AORs:  `=_N' records"
drop if missing(aor_short) | aor_short == "" | aor_short == "HQ"
display "After:                          `=_N' records"

* Standardize state variable to uppercase, trimmed (DDP data already mostly uppercase)
gen state_clean = trim(upper(apprehension_state))
replace state_clean = "" if state_clean == "."

* Count empty-state records before imputation
count if state_clean == ""
display _newline "Empty-state records before imputation: `r(N)'"

*===============================================================
* SINGLE-STATE IMPUTATION
* For each AOR below, >93% of records-with-state are in one state.
* Empty-state records in these AORs are confidently imputed.
*===============================================================

* Use AORs to predict states (11)
replace state_clean = "ARIZONA"    if aor_short == "Phoenix"        & state_clean == ""
replace state_clean = "NEW YORK"   if aor_short == "Buffalo"        & state_clean == ""
replace state_clean = "NEW YORK"   if aor_short == "New York City"  & state_clean == ""
replace state_clean = "CALIFORNIA" if aor_short == "San Diego"      & state_clean == ""
replace state_clean = "TEXAS"      if aor_short == "Houston"        & state_clean == ""
replace state_clean = "TEXAS"      if aor_short == "Harlingen"      & state_clean == ""
replace state_clean = "TEXAS"      if aor_short == "San Antonio"    & state_clean == ""
replace state_clean = "TEXAS"      if aor_short == "Dallas"         & state_clean == ""
replace state_clean = "FLORIDA"    if aor_short == "Miami"          & state_clean == ""
replace state_clean = "CALIFORNIA" if aor_short == "Los Angeles"    & state_clean == ""
replace state_clean = "CALIFORNIA" if aor_short == "San Francisco"  & state_clean == ""

* Tag whether record was imputed
gen byte state_imputed = (state_clean != "" & (apprehension_state == "" | missing(apprehension_state)))

* Counts after imputation
count if state_clean == ""
display _newline "Empty-state records after single-state imputation: `r(N)'"

count if state_imputed == 1
display "Records imputed in this step: `r(N)'"

*===============================================================
* Report remaining empty-state breakdown by AOR
*===============================================================

display _newline "Remaining empty-state records by AOR:"
preserve
    keep if state_clean == ""
    contract aor_short, freq(empty_n)
    gsort -empty_n
    list, noobs
restore

*===============================================================
* Footnote-ready missingness statistics
* (Documents that the remaining empty-state records are concentrated
*  in earlier years and not in the Term 2 post-inauguration period)
*===============================================================

display _newline "===== MISSINGNESS BY YEAR (post-imputation) ====="
display "Use these figures for footnoting state-level analyses."

gen year = year(date)
preserve
    gen empty_state = (state_clean == "")
    collapse (sum) empty_state (count) total = date, by(year)
    gen pct_empty = empty_state / total * 100
    format pct_empty %5.2f
    list year total empty_state pct_empty, noobs
restore

display _newline "===== MISSINGNESS BY TERM 2 WINDOW (post-imputation) ====="

preserve
    gen empty_state = (state_clean == "")
    gen str10 t2_period = "outside_t2"
    replace t2_period = "pre_t2"  if inrange(date, mdy(1,20,2025) - 414, mdy(1,19,2025))
    replace t2_period = "post_t2" if inrange(date, mdy(1,20,2025), mdy(1,20,2025) + 414)
    collapse (sum) empty_state (count) total = date, by(t2_period)
    gen pct_empty = empty_state / total * 100
    format pct_empty %5.2f
    list t2_period total empty_state pct_empty, noobs
restore

display _newline "Suggested footnote text:"
display "  After single-state imputation for 11 AORs that map to one state"
display "  (>93% concordance in records with state info), [N] records (X.X% of total)"
display "  remain without an apprehension state. Within the Term 2 post-inauguration"
display "  period, only X.XX% of records lack state information; among earlier records,"
display "  the rate is X.XX%."

*===============================================================
* Save cleaned dataset
*===============================================================

save "`DATAPATH'/ddp_arrests_state_cleaned.dta", replace
display _newline "Saved: `DATAPATH'/ddp_arrests_state_cleaned.dta"
display "  Variables added: state_clean (cleaned/imputed state), state_imputed (0/1 flag), year"
display "  Original apprehension_state preserved unchanged"
