library(tidycensus)
library(tigris)
library(tidyverse)
library(sf)
library(ggrepel)
library(scales)

options(tigris_use_cache = TRUE)
options(timeout = max(300, getOption("timeout")))

tracts_list <- list()
vars <- c(
  "B01003_001", "B05006_002", "B05006_047", "B05006_095", 
  "B05006_130", "B05006_140", "B05006_154", "B05006_164", 
  "B05006_176"
)

tracts_list <- list()
for (st in state.abb) {
  cat("Pulling tracts for", st, "...\n")
  Sys.sleep(2) 
  
  tracts_list[[st]] <- get_acs(
    geography = "tract", 
    variables = vars, 
    state = st, 
    geometry = TRUE, 
    output = "wide",
    year = 2024,
    progress_bar = FALSE
  )
}

tracts_acs <- bind_rows(tracts_list) %>%
  mutate(EUCA = B05006_002E + B05006_130E + B05006_176E) %>%
  rename(
    "Total_PopE" = "B01003_001E",
    "ASIA" = "B05006_047E",
    "AFRICA" = "B05006_095E",
    "CARIBBEAN" = "B05006_140E",
    "MCA" = "B05006_154E", 
    "SA" = "B05006_164E"
  )

metros <- core_based_statistical_areas(cb = TRUE) %>% 
  filter(LSAD == "M1") %>% 
  select(CBSA_Name = NAME)

tracts_in_metros <- tracts_acs %>%
  st_centroid() %>% 
  st_join(metros, left = FALSE) %>% 
  st_drop_geometry()

groups <- c("EUCA", "ASIA", "AFRICA", "CARIBBEAN", "MCA", "SA")

evenness_results <- tracts_in_metros %>%
  select(CBSA_Name, Total_PopE, all_of(groups)) %>%
  pivot_longer(cols = all_of(groups), names_to = "Group", values_to = "Tract_Group_Pop") %>%
  group_by(CBSA_Name, Group) %>%
  mutate(
    Tract_Rest_Pop = Total_PopE - Tract_Group_Pop,
    Metro_Group_Pop = sum(Tract_Group_Pop, na.rm = TRUE),
    Metro_Rest_Pop = sum(Tract_Rest_Pop, na.rm = TRUE),
    Metro_Total_Pop = sum(Total_PopE, na.rm = TRUE)
  ) %>%
  filter(Metro_Group_Pop > 0 & Metro_Rest_Pop > 0) %>% 
  summarize(
    Evenness_Index = 0.5 * sum(abs((Tract_Group_Pop / Metro_Group_Pop) - (Tract_Rest_Pop / Metro_Rest_Pop)), na.rm = TRUE),
    Metro_Total_Pop = first(Metro_Total_Pop),
    Metro_Group_Pop = first(Metro_Group_Pop)
  )

write_csv(evenness_results, "data/processed/city_dissimilarity.csv")
