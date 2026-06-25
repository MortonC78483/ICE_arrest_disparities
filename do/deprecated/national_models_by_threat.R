
# source the functions in national_models
source("do/national_models.R")
rm(list = setdiff(ls(), lsf.str()))

#### CREATE NATIONAL DATA ####
trajectory <- read_csv("data/glm_trajectory_type_threatlevel_convicted_ACS_MPI.csv") %>%
  filter(method == "LEA")

national_pops <- trajectory %>%
  select(c(state, region, pop_ACS, pop_MPI)) %>%
  unique() %>%
  group_by(region) %>%
  summarize(pop_ACS = sum(pop_ACS),
            pop_MPI = sum(pop_MPI))

total_arrests <- trajectory %>%
  select(region, window, n_arrests) %>%
  group_by(region, window) %>%
  summarize(total_arrests = sum(n_arrests))

state_sums <- trajectory %>%
  mutate(criminal_history = as.factor(ifelse(threat_level == 1, "Case Threat Level = 1", 
                                             ifelse(threat_level == 2, "Case Threat Level = 2",
                                                    ifelse(convicted == 1, "Convicted Non-1,2 Threat",
                                                           "Non-Convicted"))))) %>%
  select(-c(convicted, threat_level, method, alt_method, 
            state, pop_ACS, pop_MPI)) %>%
  group_by(region, window, criminal_history) %>%
  summarize(n_arrests = sum(n_arrests)) %>%
  mutate(region = as.factor(region),
         window = as.factor(window)) %>%
  mutate(
    region = relevel(region, ref = "EUCA"),
    window = relevel(window, ref = "-1")
  ) %>%
  merge(total_arrests) %>%
  merge(national_pops) %>%
  mutate(ratio = n_arrests/pop_ACS*100000) 

pop_sums_euca_non <- national_pops %>%
  mutate(region = ifelse(region == "EUCA", "EUCA", "non-EUCA")) %>%
  group_by(region) %>%
  summarize(pop_ACS = sum(pop_ACS), pop_MPI = sum(pop_MPI))

state_sums_euca_non <- state_sums %>%
  ungroup() %>%
  mutate(region = ifelse(region == "EUCA", "EUCA", "non-EUCA")) %>%
  group_by(region, window, criminal_history) %>%
  summarize(n_arrests = sum(n_arrests),
            pop_ACS = sum(pop_ACS),
            pop_MPI = sum(pop_MPI))%>%
  mutate(ratio = n_arrests/pop_ACS*100000) 

#### COLOR PALETTE ####
all_regions <- unique(state_sums$region)
other_regions <- setdiff(all_regions, "EUCA")
pal <- c("EUCA" = "darkgrey", 
         setNames(scales::brewer_pal(palette = "Dark2")(length(other_regions)), other_regions))

pal_euca <- c("EUCA" = "darkgrey", "non-EUCA" = "darkblue")

for(level in c("Case Threat Level = 1", "Non-Convicted")){
  filtered_all_groups <- state_sums %>% filter(criminal_history == level)
  filtered_euca_non <- state_sums_euca_non %>% filter(criminal_history == level)
  
  # create a row for euca with just this level
  a <- make_linear_100k(filtered_all_groups, pal) + ggtitle(level)
  b <- make_linear_diffindiff(filtered_all_groups, pal)
  c <- make_linear_100k(filtered_euca_non, pal_euca)
  d <- make_linear_diffindiff(filtered_euca_non, pal_euca)

  plot(ggarrange(a, b, c, d))

  a <- make_mult_100k(filtered_all_groups, pal) + ggtitle(level)
  b <- make_mult_diffindiff(filtered_all_groups, pal)
  c <- make_mult_100k(filtered_euca_non, pal_euca)
  d <- make_mult_diffindiff(filtered_euca_non, pal_euca)
  
  plot(ggarrange(a, b, c, d))
}
