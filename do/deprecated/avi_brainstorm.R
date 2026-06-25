trajectory <- read_csv("data/glm_trajectory_type_threatlevel_convicted_ACS_MPI.csv")  %>%
  filter(method == "CA") %>%
  mutate(after = ifelse(as.numeric(as.character(window))>=0, 1, 0)) %>%
  select(-c(convicted, method, alt_method)) %>%
  group_by(state, region, threat_level, pop_ACS, pop_MPI, after) %>%
  summarize(n_arrests = sum(n_arrests)) %>%
  group_by(threat_level, after, region) %>%
  summarize(n_arrests = sum(n_arrests),
            pop_ACS = sum(pop_ACS),
            pop_MPI = sum(pop_MPI)) %>%
  #mutate(region = ifelse(region == "EUCA", "EUCA", "nonEUCA")) %>%
  group_by(threat_level, after, region) %>%
  summarize(n_arrests = sum(n_arrests),
            pop_ACS = sum(pop_ACS),
            pop_MPI = sum(pop_MPI))
ggplot(trajectory, aes(x = after, y = n_arrests/pop_MPI*100000, color = region, group = region)) +
  geom_point()+
  geom_line()+
  facet_wrap("threat_level")
  

trajectory <- read_csv("data/glm_trajectory_type_threatlevel_convicted_ACS_MPI.csv")  %>%
  filter(method == "CA") %>%
  mutate(after = ifelse(as.numeric(as.character(window))>=0, 1, 0)) %>%
  select(-c(convicted, method, alt_method)) %>%
  group_by(state, region, threat_level, pop_ACS, pop_MPI, after) %>%
  summarize(n_arrests = sum(n_arrests)) %>%
  group_by(threat_level, after, region) %>%
  summarize(n_arrests = sum(n_arrests),
            pop_ACS = sum(pop_ACS),
            pop_MPI = sum(pop_MPI)) %>%
  group_by(threat_level, after) %>%
  summarize(n_arrests = sum(n_arrests),
            pop_ACS = sum(pop_ACS),
            pop_MPI = sum(pop_MPI))
  
  