ex <- read_csv("data/glm_trajectory_type_threatlevel_convicted_ACS_MPI.csv") %>%
  mutate(window = ifelse(window < 0, "pre", "post")) %>%
  group_by(window, region, pop_ACS, pop_MPI) %>%
  summarize(total_arrests = sum(n_arrests)) %>%
  group_by(window, region) %>%
  summarize(total_arrests = sum(total_arrests),
            total_ratio_ACS = sum(total_arrests)/sum(pop_ACS)*100000,
            total_ratio_MPI = sum(total_arrests)/sum(pop_MPI)*100000) %>%
  pivot_wider(id_cols = "region", names_from = "window", values_from = c("total_arrests", "total_ratio_ACS", "total_ratio_MPI"))


