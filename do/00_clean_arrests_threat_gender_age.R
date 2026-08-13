library(haven)
library(tigris)
library(tidyr)
library(arrow)
library(dplyr)
library(readr)

# create duplicate ID dataframe
raw_arrests <- read_parquet("data/raw/arrests-latest.parquet") %>%
  select(unique_identifier, duplicate_likely) %>%
  filter(duplicate_likely == T)
write_csv(raw_arrests, "data/processed/duplicates.csv")

# load raw arrests data to get the other variables
raw_arrests <- read_parquet("data/raw/arrests-latest.parquet") %>%
 filter((as.Date(apprehension_date) >= as.Date("2022-10-01")) &
        (as.Date(apprehension_date) <= as.Date("2026-03-10"))) %>%
  rename("ApprehensionDate" = "apprehension_date", 
         "ApprehensionAOR" = "apprehension_aor",
         "ApprehensionMethod" = "apprehension_method",
         "ApprehensionCriminality" = "apprehension_criminality"
         ) %>%
  select("unique_identifier", "ApprehensionDate","ApprehensionAOR",
         "ApprehensionMethod","ApprehensionCriminality","apprehension_state",
         "citizenship_country", "gender", "birth_year", "case_threat_level")
         

raw_arrests <- raw_arrests %>%
  mutate(aor_short = sub(" Area of Responsibility", "", ApprehensionAOR))

raw_arrests[is.na(raw_arrests$apprehension_state),]$apprehension_state = ""

raw_arrests$state_clean = raw_arrests$apprehension_state

STATES = c(toupper(state.name), "DISTRICT OF COLUMBIA")
raw_arrests[!(raw_arrests$state_clean %in% STATES),]$state_clean = ""

raw_arrests <- raw_arrests |> 
  mutate(state_clean = case_when(
    state_clean == "" & aor_short == "Phoenix" ~ "ARIZONA",
    state_clean == "" & aor_short %in% c("Buffalo", "New York City") ~ "NEW YORK",
    state_clean == "" & aor_short %in% c("San Diego", "Los Angeles") ~ "CALIFORNIA",
    state_clean == "" & aor_short %in% c("Houston", "Harlingen", "San Antonio", "Dallas") ~ "TEXAS",
    state_clean == "" & aor_short == "Miami" ~ "FLORIDA",
    TRUE ~ state_clean 
  ))

raw_arrests[is.na(raw_arrests$aor_short),]$aor_short = ""
raw_arrests[raw_arrests$aor_short == "HQ",]$aor_short = ""
summary(as.factor(raw_arrests$aor_short))

raw_arrests <- raw_arrests |>
  mutate(aor_short = case_when(
    aor_short == "" & state_clean %in% c("ALASKA", "WASHINGTON", "OREGON") ~ "Seattle",
    aor_short == "" & state_clean %in% c("HAWAII") ~ "San Francisco",
    aor_short == "" & state_clean %in% c("UTAH", "NEVADA", "IDAHO", "MONTANA") ~ "Salt Lake City",
    aor_short == "" & state_clean %in% c("ARIZONA") ~ "Phoenix",
    aor_short == "" & state_clean %in% c("NEW MEXICO") ~ "El Paso",
    aor_short == "" & state_clean %in% c("OKLAHOMA") ~ "Dallas",
    aor_short == "" & state_clean %in% c("WYOMING", "COLORADO") ~ "Denver",
    aor_short == "" & state_clean %in% c("UTAH", "NEVADA", "IDAHO", "MONTANA") ~ "Salt Lake City",
    aor_short == "" & state_clean %in% c("MINNESOTA", "IOWA", "NEBRASKA", "SOUTH DAKOTA", "NORTH DAKOTA") ~ "St. Paul",
    aor_short == "" & state_clean %in% c("WISCONSIN", "ILLINOIS", "INDIANA", "KENTUCKY", "MISSOURI", "KANSAS") ~ "Chicago",
    aor_short == "" & state_clean %in% c("ARKANSAS", "LOUISIANA", "TENNESSEE", "MISSISSIPPI", "ALABAMA") ~ "New Orleans",
    aor_short == "" & state_clean %in% c("FLORIDA") ~ "Miami",
    aor_short == "" & state_clean %in% c("GEORGIA", "SOUTH CAROLINA", "NORTH CAROLINA") ~ "Atlanta",
    aor_short == "" & state_clean %in% c("VIRGINIA", "DISTRICT OF COLUMBIA") ~ "Washington",
    aor_short == "" & state_clean %in% c("MICHIGAN", "OHIO") ~ "Detroit",
    aor_short == "" & state_clean %in% c("MARYLAND") ~ "Baltimore",
    aor_short == "" & state_clean %in% c("NEW JERSEY") ~ "Newark",
    aor_short == "" & state_clean %in% c("DELAWARE", "PENNSYLVANIA", "WEST VIRGINIA") ~ "Philadelphia",
    aor_short == "" & state_clean %in% c("VERMONT", "NEW HAMPSHIRE", "MAINE", "MASSACHUSETTS", "CONNECTICUT", "RHODE ISLAND") ~ "Boston",
    TRUE ~ aor_short
  ))

summary(as.factor(raw_arrests$aor_short))

raw_arrests <- raw_arrests %>%
  filter(aor_short != "" & state_clean != "")

write_dta(raw_arrests, "data/processed/ddp_arrests_state_threat_gender_age_cleaned.dta")

summary(as.factor(raw_arrests$aor_short))
summary(as.factor(raw_arrests$state_clean))

