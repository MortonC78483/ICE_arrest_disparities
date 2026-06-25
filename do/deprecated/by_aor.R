# AOR level work
library(haven)
library(tigris)
library(tidyr)
library(arrow)
library(readr)
library(lubridate)

# crosswalk
aor_county_crosswalk <- read_dta("data/crosswalks/aor_county_crosswalk.dta")

# first, dataset of the AOR/state, and the ACS and MPI populations in there by group
trajectory <- read_csv("data/glm_trajectory_type_threatlevel_convicted_ACS_MPI.csv")

trajectory <- trajectory %>%
  mutate(AOR = case_when(
  state %in% c("WASHINGTON", "OREGON", "ALASKA") ~ "Seattle",
  state %in% c("NEVADA", "UTAH", "IDAHO", "MONTANA") ~ "Salt_Lake_City",
  state %in% c("WYOMING", "COLORADO") ~ "Denver",
  state %in% c("NORTH DAKOTA", "SOUTH DAKOTA", "NEBRASKA", "IOWA", "MINNESOTA") ~ "St_Paul",
  state %in% c("KANSAS", "MISSOURI", "ILLINOIS", "INDIANA", "WISCONSIN", "KENTUCKY") ~ "Chicago",
  state %in% c("MICHIGAN", "OHIO") ~ "Detroit",
  state %in% c("LOUISIANA", "ARKANSAS", "TENNESSEE", "ALABAMA", "MISSISSIPPI") ~ "New_Orleans",
  state %in% c("SOUTH CAROLINA", "NORTH CAROLINA", "GEORGIA") ~ "Atlanta",
  state %in% c("VIRGINIA", "DISTRICT OF COLUMBIA") ~ "Washington",
  state %in% c("PENNSYLVANIA", "WEST VIRGINIA", "DELAWARE") ~ "Philadelphia",
  state %in% c("CONNECTICUT", "RHODE ISLAND", "MASSACHUSETTS", "NEW HAMPSHIRE", "VERMONT", "MAINE") ~ "Boston",
  state == "TEXAS" ~ "TEXAS",
  state == "CALIFORNIA" ~ "CALIFORNIA",
  state == "HAWAII" ~ "HAWAII",
  state == "OKLAHOMA" ~ "OKLAHOMA",
  state == "ARIZONA" ~ "ARIZONA",
  state == "NEW JERSEY" ~ "Newark",
  state == "MARYLAND" ~ "Baltimore",
  state == "NEW YORK" ~ "Newark",
  state == "FLORIDA" ~ "Miami",
  state == "NEW MEXICO" ~ "NEW MEXICO",
  TRUE ~ NA_character_ 
))

trajectory <- trajectory %>%
  group_by(AOR, region, window, convicted, threat_level, method, alt_method) %>%
  summarize(n_arrests = sum(n_arrests),
            pop_ACS = sum(pop_ACS),
            pop_MPI = sum(pop_MPI))

write_csv(trajectory, "data/glm_trajectory_type_threatlevel_convicted_ACS_MPI_AOR.csv")
