# create the glm trajectories with state, region, and 2-month period
library(haven)
library(tigris)
library(tidyr)
library(arrow)
library(readr)
library(lubridate)
library(stringr)
library(tidycensus)
library(dplyr)

#### constants from disparity_helpers.py ####
INAUG_DATE = "2025-01-20"
WINDOW_DAYS = 60
TOTAL_DAYS_EACH_SIDE = 7*WINDOW_DAYS

LEA_METHODS = c('287(g) Program','Anti-Smuggling','CAP Federal Incarceration','CAP Local Incarceration',
  'CAP State Incarceration','Criminal Alien Program','ERO Reprocessed Arrest',
  'Law Enforcement Agency Response Unit','Organized Crime Drug Enforcement Task Force',
  'Other Agency (turned over to INS)','Other Task Force','Probation and Parole',
  'Custodial Arrest','Patrol Border','Patrol Interior')

CA_METHODS = c('Located','Non-Custodial Arrest','Worksite Enforcement')

# ALTERNATIVE_LEA_METHODS = c('287(g) Program','CAP Federal Incarceration','CAP Local Incarceration',
#                             'CAP State Incarceration','Criminal Alien Program',
#                             'Law Enforcement Agency Response Unit','Organized Crime Drug Enforcement Task Force',
#                             'Other Agency (turned over to INS)','Probation and Parole',
#                             'Custodial Arrest')
# 
# ALTERNATIVE_CA_METHODS = c('Located','Non-Custodial Arrest','Worksite Enforcement')

  
MCA = c('MEXICO','GUATEMALA','EL SALVADOR','HONDURAS','NICARAGUA','COSTA RICA','PANAMA','BELIZE')

CARIBBEAN = c('CUBA','DOMINICAN REPUBLIC','HAITI','JAMAICA','TRINIDAD AND TOBAGO','BAHAMAS','BARBADOS',
  'ANTIGUA AND BARBUDA','SAINT LUCIA','GRENADA','DOMINICA','SAINT VINCENT AND THE GRENADINES',
  'SAINT KITTS AND NEVIS','ST. LUCIA','ST. KITTS-NEVIS','ST. VINCENT-GRENADINES','ANTIGUA-BARBUDA',
  'BRITISH VIRGIN ISLANDS','TURKS AND CAICOS ISLANDS','BERMUDA','NETHERLANDS ANTILLES','GUADELOUPE',
  'CURACAO','ARUBA','ANGUILLA','MONTSERRAT','CAYMAN ISLANDS','SINT MAARTEN(DUTCH)','SINT EUSTATIUS'
)
SA = c('BRAZIL','COLOMBIA','VENEZUELA','ECUADOR','PERU','ARGENTINA','BOLIVIA','CHILE','PARAGUAY',
  'URUGUAY','GUYANA','SURINAME','FRENCH GUIANA')
ASIA = c(
  'CHINA','INDIA','PHILIPPINES','VIETNAM','SOUTH KOREA','JAPAN','BANGLADESH','PAKISTAN',
  'INDONESIA','MALAYSIA','THAILAND','SRI LANKA','NEPAL','BURMA','MYANMAR','CAMBODIA','LAOS',
  'SINGAPORE','MONGOLIA','TAIWAN','AFGHANISTAN','UZBEKISTAN','KAZAKHSTAN','KYRGYZSTAN','TAJIKISTAN',
  'TURKMENISTAN','NORTH KOREA','BHUTAN','MALDIVES','BRUNEI','IRAN','IRAQ','SYRIA','LEBANON','JORDAN',
  'ISRAEL','YEMEN','SAUDI ARABIA','TURKEY','ARMENIA','AZERBAIJAN','GEORGIA','KUWAIT','QATAR',
  'BAHRAIN','UNITED ARAB EMIRATES','OMAN','PALESTINE',
  # DDP-specific spellings:
  'CHINA, PEOPLES REPUBLIC OF','TURKIYE','KOREA','HONG KONG','MACAU','EAST TIMOR',
  'PALESTINE BORN BEFORE 1948'
)
AFRICA = c(
  'NIGERIA','ETHIOPIA','EGYPT','KENYA','GHANA','SOMALIA','SUDAN','SOUTH SUDAN','SOUTH AFRICA',
  'SENEGAL','CAMEROON','LIBERIA','SIERRA LEONE','ERITREA','IVORY COAST',"COTE D'IVOIRE",'MALI',
  'MOROCCO','TUNISIA','ALGERIA','UGANDA','TANZANIA','ZIMBABWE','RWANDA','BURKINA FASO','CHAD',
  'NIGER','GAMBIA','GUINEA','TOGO','BENIN','MAURITANIA','ANGOLA','MOZAMBIQUE','ZAMBIA','MALAWI',
  'MADAGASCAR','BOTSWANA','NAMIBIA','LESOTHO','CONGO','DEMOCRATIC REPUBLIC OF THE CONGO',
  'CENTRAL AFRICAN REPUBLIC','EQUATORIAL GUINEA','GABON','COMOROS','CAPE VERDE','DJIBOUTI',
  'BURUNDI','LIBYA',
  # DDP-specific spellings:
  'DEM REP OF THE CONGO','GUINEA-BISSAU','MAURITIUS','SAO TOME AND PRINCIPE','ESWATINI'
)
EUCA = c(
  'CANADA','UNITED KINGDOM','IRELAND','GERMANY','FRANCE','ITALY','SPAIN','PORTUGAL','GREECE',
  'RUSSIA','UKRAINE','POLAND','ROMANIA','HUNGARY','CZECH REPUBLIC','SLOVAKIA','BULGARIA','SERBIA',
  'CROATIA','SLOVENIA','MACEDONIA','NORTH MACEDONIA','ALBANIA','BOSNIA AND HERZEGOVINA','BELGIUM',
  'NETHERLANDS','SWEDEN','NORWAY','DENMARK','FINLAND','ICELAND','SWITZERLAND','AUSTRIA',
  'LUXEMBOURG','CYPRUS','MALTA','ESTONIA','LATVIA','LITHUANIA','BELARUS','MOLDOVA','MONTENEGRO',
  'KOSOVO','AUSTRALIA','NEW ZEALAND','FIJI','SAMOA','TONGA','PAPUA NEW GUINEA',
  # DDP-specific spellings:
  'BOSNIA-HERZEGOVINA','USSR','YUGOSLAVIA','SERBIA AND MONTENEGRO','CZECHOSLOVAKIA','ANDORRA',
  'MONACO','MICRONESIA, FEDERATED STATES OF','MARSHALL ISLANDS','PALAU','FRENCH POLYNESIA'
)

STATES = c(toupper(state.name), "DISTRICT OF COLUMBIA")
data(fips_codes)
fips_codes <- fips_codes %>%
  dplyr::select(c(state_name, state_code)) %>%
  mutate(state_name = toupper(state_name)) %>%
  unique()

valid_county_fips = read_parquet("data/raw/ice-aor-county-shp.parquet") %>%
  select("STATEFP", "COUNTYFP", "NAME", "GEOID", "STATE_NAME") %>%
  mutate(STATE_NAME = toupper(STATE_NAME)) %>%
  filter(STATE_NAME %in% STATES)
  
#### process arrests dataset ####
get_region <- function(country){
  if (country %in% MCA){
    return("MCA")
  } else if (country %in% CARIBBEAN){
    return("CARIBBEAN")
  } else if (country %in% SA){
    return("SA")
  } else if (country %in% ASIA){
    return("ASIA")
  } else if (country %in% AFRICA){
    return("AFRICA")
  } else if (country %in% EUCA){
    return("EUCA")
  } else{
    return(NA)
  }
}
get_method <- function(method){
  if (method %in% LEA_METHODS){
    return("LEA")
  } else if (method %in% CA_METHODS){
    return("CA")
  } else{
    return("OTHER")
  }
}

# get_alt_method <- function(method){
#   if (method %in% ALTERNATIVE_LEA_METHODS){
#     return("LEA")
#   } else if (method %in% ALTERNATIVE_CA_METHODS){
#     return("CA")
#   } else{
#     return("OTHER")
#   }
# }

# load arrests dataset
arrests <- read_dta("data/processed/ddp_arrests_state_threat_gender_age_cleaned.dta") 

if(remove_duplicates){
  duplicates <- read_csv("data/processed/duplicates.csv")
  
  arrests <- arrests %>%
    filter(!(unique_identifier %in% duplicates$unique_identifier))
}

arrests <- arrests %>%
  filter((year(ymd(ApprehensionDate)) - birth_year) >= 18) %>% # filter out children
  select(c(ApprehensionDate, ApprehensionMethod, 
           ApprehensionCriminality, case_threat_level,
           state_clean, aor_short, citizenship_country)) %>%
  #mutate(felony = ifelse(!is.na(case_threat_level) & case_threat_level %in% c(1, 2), 1, 0 )) %>%
  mutate(threat_level = ifelse(!is.na(case_threat_level) & case_threat_level == 1, 1, 
                               ifelse(!is.na(case_threat_level) & case_threat_level == 2, 2, 0))) %>%
  mutate(citizenship_region = unlist(lapply(citizenship_country, get_region))) %>%
  mutate(method = unlist(lapply(ApprehensionMethod, get_method))) %>%
  #mutate(alt_method = unlist(lapply(ApprehensionMethod, get_alt_method))) %>%
  mutate(convicted = ifelse(ApprehensionCriminality == "1 Convicted Criminal", 1, 0)) %>%
  select(-c(ApprehensionMethod, citizenship_country, ApprehensionCriminality, case_threat_level))

if(AOR == FALSE){
  # 6% of arrests are unknown state
  sum(arrests$state_clean == "")/nrow(arrests)
  
  # Require arrests to be in US states or DC
  arrests <- arrests %>%
    filter(state_clean %in% STATES)
} 

# get time periods
assign_window <- function(dates){
  days_from_inaug = as.numeric(as.Date(dates) - as.Date(INAUG_DATE))
  window_assignment = ifelse(days_from_inaug < 0, -((-days_from_inaug - 1) %/% WINDOW_DAYS + 1),
                             days_from_inaug %/% WINDOW_DAYS)
  window_assignment = ifelse(abs(days_from_inaug) > TOTAL_DAYS_EACH_SIDE, NA, window_assignment)
  return(window_assignment)
}
arrests$window <- assign_window(arrests$ApprehensionDate)
arrests <- arrests[!is.na(arrests$window),]

# create table of convicted/felony
table(arrests$convicted, arrests$threat_level)

if(AOR){
  arrests_type_convicted_summed <- arrests %>%
    rename("aor" = "aor_short",
           "region" = "citizenship_region") %>%
    group_by(aor, region, window, convicted, threat_level, method) %>%#, alt_method) %>%
    summarize(n_arrests = n()) %>%
    ungroup() %>%
    tidyr::complete(aor, region, window, convicted, threat_level, method, 
                    #alt_method, 
                    fill = list(n_arrests = 0))
} else{
  arrests_type_convicted_summed <- arrests %>%
    select(-aor_short) %>%
    rename("state" = "state_clean",
           "region" = "citizenship_region") %>%
    group_by(state, region, window, convicted, threat_level, method) %>% #, alt_method) %>%
    summarize(n_arrests = n()) %>%
    ungroup() %>%
    tidyr::complete(state, region, window, convicted, threat_level, method, 
                    #alt_method, 
                    fill = list(n_arrests = 0))
}

#### MPI dataset ####
mpi_region <- read_csv("data/raw/mpi_state_region.csv") %>%
  mutate(state = toupper(state)) %>%
  rename("pop_MPI" = "unauth_pop") %>%
  mutate(region = toupper(region), 
         region = ifelse(region == "MEXICO AND CENTRAL AMERICA", "MCA",
                         ifelse(region == "EUROPE/CANADA/OCEANIA", "EUCA", 
                         ifelse(region == "SOUTH AMERICA", "SA", region))))

setdiff(STATES, mpi_region$state)
mpi_region %>%
  group_by(region) %>%
  summarize(sum(pop_MPI))

mpi_region %>%
  group_by(state) %>%
  summarize(n = n()) %>%
  group_by(n) %>%
  summarize('number of states' = n())

mpi_region <- rbind(mpi_region, data.frame(region = "EUCA", 
                   state = setdiff(STATES, unique(mpi_region$state)),
                   pop_MPI = 1000)) %>% # attach states that aren't in the MPI data
  complete(region, state) 

mpi_region$pop_MPI <- replace_na(mpi_region$pop_MPI, 1000)

mpi_region %>%
  group_by(region) %>%
  summarize(sum(pop_MPI))

# merge in the AOR arrests data
if(AOR){
  # apportion MPI data
  county_population <- get_acs(
    geography = "county",
    variables = "B01001_001E",
    survey = "acs5",
    year = 2024
  )
  county_population <- county_population %>%
    select(GEOID, estimate) %>%
    rename("pop_total" = "estimate") %>%
    filter(GEOID %in% valid_county_fips$GEOID)
  
  # contains GEOID to AOR name, plus population of the GEOID
  aor_county <- read_parquet("data/raw/ice-aor-county-shp.parquet") %>%
    select(GEOID, area_of_responsibility_name) %>%
    rename("aor" = "area_of_responsibility_name") %>%
    mutate(state_fips = substr(GEOID, 1, 2)) 
  
  aor_county <- aor_county %>%
    mutate(aor = ifelse(aor == "St Paul", "St. Paul", aor_county$aor)) %>%
    merge(county_population)
  
  # GEOID to AOR is clean
  # we want to go from state to AOR, so we need for all the states, the proportion of a state population that
  # we should allocate to AOR1, AOR2, etc
  state_pops <- aor_county %>%
    group_by(state_fips) %>%
    summarize(pop_state = sum(pop_total))
  
  state_in_aor <- aor_county %>%
    group_by(aor, state_fips) %>%
    summarize(pop_state_in_aor = sum(pop_total))
  
  state_region_crosswalk <- fips_codes %>%
    filter(state_name %in% STATES) %>%
    distinct(state_code, state_name) %>%
    rename("state_fips" = "state_code",
           "state" = "state_name")
  
  state_in_aor <- state_in_aor %>%
    merge(state_pops, by = "state_fips") %>%
    mutate(prop_state_in_aor = pop_state_in_aor/pop_state) %>%
    merge(state_region_crosswalk, all.x = T) %>%
    filter(!is.na(state)) %>% # takes out Puerto Rico
    mutate(state = toupper(state))
  
  # 25 AORs, 6 regions, 3 methods, 3 alt methods, 3 threat levels, 2 conv status
  mpi_region = merge(mpi_region, state_in_aor, all = T) %>%
    mutate(pop_MPI_scaled = pop_MPI * prop_state_in_aor) %>%
    group_by(aor, region) %>%
    summarize(pop_MPI = sum(pop_MPI_scaled))
}

#### ACS dataset ####
# B05006_002E Europe
# B05006_047E Asia
# B05006_095E Africa
# B05006_130E Oceania
# B05006_140E Caribbean
# B05006_154E Central America
# B05006_160E Mexico
# B05006_164E South America
# B05006_176E North America
acs_region <- read_csv("data/raw/county_birth_region_2023_raw.csv") %>%
  filter(GEO_ID != "Geography") %>%
  rename("GEOID" = "GEO_ID") %>%
  mutate(GEOID = substr(GEOID, nchar(GEOID)-4, nchar(GEOID)),
         STATEFP = substr(GEOID, 1, 2)) %>%
  select(c("GEOID", "STATEFP", "B05006_002E", "B05006_047E", "B05006_095E", 
           "B05006_130E", "B05006_140E", "B05006_154E", 
           "B05006_164E", "B05006_176E")) %>%
  mutate(across(3:last_col(), as.numeric))
  

if(AOR){
  aor_county_crosswalk <- read_parquet("data/raw/ice-aor-county-shp.parquet") %>%
    select(GEOID, area_of_responsibility_name) %>%
    rename("aor" = "area_of_responsibility_name") %>%
    select(GEOID, aor) %>%
    filter(GEOID %in% valid_county_fips$GEOID)
  
  aor_county_crosswalk <- aor_county_crosswalk %>%
    mutate(aor = ifelse(aor == "St Paul", "St. Paul", aor_county_crosswalk$aor))
  
  acs_region <- acs_region %>%
    merge(aor_county_crosswalk, by = "GEOID") %>% # we need to get counties assigned to AORs
    group_by(aor) %>%
    summarize(across(where(is.double), sum)) %>%
    mutate(EUCA = B05006_002E+B05006_130E+B05006_176E) %>%
    rename("ASIA" = "B05006_047E",
           "AFRICA" = "B05006_095E",
           "CARIBBEAN" = "B05006_140E",
           "MCA" = "B05006_154E", 
           "SA" = "B05006_164E") %>%
    select(-c(B05006_002E,B05006_130E,B05006_176E)) %>%
    pivot_longer(cols = -"aor", names_to = "region", values_to = "pop_ACS")

  } else{
  acs_region <- acs_region %>%
    group_by(STATEFP) %>%
    summarize(across(where(is.double), sum)) %>%
    mutate(EUCA = B05006_002E+B05006_130E+B05006_176E) %>%
    rename("ASIA" = "B05006_047E",
           "AFRICA" = "B05006_095E",
           "CARIBBEAN" = "B05006_140E",
           "MCA" = "B05006_154E", 
           "SA" = "B05006_164E") %>%
    select(-c(B05006_002E,B05006_130E,B05006_176E)) %>%
    merge(fips_codes, by.x = "STATEFP", by.y = "state_code") %>%
    select(-STATEFP) %>%
    pivot_longer(cols = -"state_name", names_to = "region", values_to = "pop_ACS") %>%
    rename("state" = "state_name")
}

#### JOINED POP dataset ####
acs_mpi_region <- merge(acs_region, mpi_region, all = T)

#### Join in the data
arrests_with_denom <- merge(data.frame(arrests_type_convicted_summed), 
                            data.frame(acs_mpi_region), all.x = T) %>% 
  filter(!is.na(region)) %>%
  filter(!is.na(pop_ACS) & !is.na(pop_MPI))

arrests_with_denom_na <- merge(data.frame(arrests_type_convicted_summed), 
                            data.frame(acs_mpi_region), all.x = T) %>% 
  filter(!is.na(region)) %>%
  filter(is.na(pop_ACS) | is.na(pop_MPI))
if(nrow(arrests_with_denom_na) > 0){
  warning("Some NAs created when making dataset!")
}

arrests_with_denom$pop_MPI <- replace_na(arrests_with_denom$pop_MPI, 1000)
#25 AORs, 6 regions, 3 methods, 3 alt methods, 3 threat levels, 2 conv status, 10 periods = 81000

if (AOR & remove_duplicates){
  print("writing duplicates removed csv (AOR level)")
  write_csv(arrests_with_denom, "data/processed/glm_trajectory_type_threatlevel_convicted_ACS_MPI_AOR_no_duplicates.csv")
} else if(AOR) {
  print("writing full csv (AOR level)")
  write_csv(arrests_with_denom, "data/processed/glm_trajectory_type_threatlevel_convicted_ACS_MPI_AOR.csv")
} else if(remove_duplicates){
  print("writing duplicates removed csv (state level)")
  write_csv(arrests_with_denom, "data/processed/glm_trajectory_type_threatlevel_convicted_ACS_MPI_no_duplicates.csv")
} else{
  print("writing full csv (state level)")
  write_csv(arrests_with_denom, "data/processed/glm_trajectory_type_threatlevel_convicted_ACS_MPI.csv")
}
