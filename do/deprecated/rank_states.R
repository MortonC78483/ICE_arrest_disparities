# average post-treatment effect by state, EUCA vs non-EUCA

library(readr)
library(dplyr)
library(ggplot2)
library(ggpubr)
library(tidytext)
library(usmap) 

trajectory <- read_csv("data/glm_trajectory_type_threatlevel_convicted_ACS_MPI.csv")

# we want to aggregate up to just the state level -- method and convicted aren't important
trajectory <- trajectory %>%
  group_by(state, region, window, pop_ACS, pop_MPI) %>%
  summarize(n_arrests = sum(n_arrests)) %>%
  ungroup()

# if we want to compare just EUCA vs not EUCA
trajectory <- trajectory %>%
  mutate(region = ifelse(region == "EUCA", "EUCA", "non_EUCA")) %>%
  group_by(window, region, state) %>%
  mutate(n_arrests = sum(n_arrests),
         pop_ACS = sum(pop_ACS),
         pop_MPI = sum(pop_MPI)) %>%
  unique() %>%
  mutate(ratio_ACS = n_arrests/pop_ACS*100000,
         ratio_MPI = n_arrests/pop_MPI*100000)


# fit offset models to the data
state_list <- unique(trajectory$state)
trajectory_res <- list()
for (state_val in state_list){
  trajectory_filtered <- trajectory[trajectory$state == state_val,]
  trajectory_filtered <- trajectory_filtered %>%
    mutate(regionstate = as.factor(paste0(region, state)),
           windowstate = as.factor(paste0(window, state)))
  mod_ACS = glm(ratio_ACS ~ regionstate * windowstate,
                family = gaussian, 
                data = trajectory_filtered)
  
  mod_MPI = glm(ratio_MPI ~ regionstate * windowstate,
                family = gaussian, 
                data = trajectory_filtered)
  coef_ACS <- coef(mod_ACS)
  coef_MPI <- coef(mod_MPI)
  # get avg. treatment effect and range
  target_interaction_names <- paste0("regionstatenon_EUCA", state_val, ":windowstate", 0:7, state_val)
  post_treat_vals_ACS <- coef_ACS[names(coef_ACS) %in% target_interaction_names]
  post_treat_vals_MPI <- coef_MPI[names(coef_MPI) %in% target_interaction_names]
  
  state_df <- data.frame(
    state = state_val,
    min_effect_ACS = min(post_treat_vals_ACS, na.rm = TRUE),
    mean_effect_ACS = mean(post_treat_vals_ACS, na.rm = TRUE),
    max_effect_ACS = max(post_treat_vals_ACS, na.rm = TRUE),
    min_effect_MPI = min(post_treat_vals_MPI, na.rm = TRUE),
    mean_effect_MPI = mean(post_treat_vals_MPI, na.rm = TRUE),
    max_effect_MPI = max(post_treat_vals_MPI, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  
  trajectory_res[[state_val]] <- state_df
}

trajectory_df <- bind_rows(trajectory_res) 

long_data <- trajectory_df %>%
  pivot_longer(
    cols = starts_with(c("min_", "mean_", "max_")),
    names_to = c(".value", "metric"),
    names_pattern = "(.*)_effect_(.*)"
  )

plot_ready_data <- long_data %>%
  mutate(state_ranked = reorder_within(state, mean, metric))

ggplot(filter(plot_ready_data, metric == "ACS"), 
       aes(x = reorder(state, mean), y = mean)) +
  geom_col(alpha = 0.8) +
  geom_errorbar(aes(ymin = min, ymax = max), width = 0.3) +
  coord_flip() +
  theme_minimal() +
  labs(title = "Mean post-treatment effect on non-EUCA arrests per 100k",
       subtitle = "Linear models by state, ranked by mean effect\n(ACS Denoms) ",
       x = "State", y = "Mean Effect on non-EUCA arrests per 100k")

ggplot(filter(plot_ready_data, metric == "MPI"), 
       aes(x = reorder(state, mean), y = mean)) +
  geom_col(alpha = 0.8) +
  geom_errorbar(aes(ymin = min, ymax = max), width = 0.3) +
  coord_flip() +
  theme_minimal() +
  labs(title = "Mean post-treatment effect on non-EUCA arrests per 100k",
       subtitle = "Linear models by state, ranked by mean effect\n(MPI Denoms)",
       x = "State", y = "Mean Effect on non-EUCA arrests per 100k")

map_data <- trajectory_df %>%
  rename(state = state)

plot_usmap(data = map_data, values = "mean_effect_ACS", color = "white", size = 0.3) +
  scale_fill_gradient2(
    mid = "blue", 
    high = "red", 
    midpoint = 0,
    name = "Mean Effect"
  ) +
  theme(legend.position = "right") +
  labs(title = "Mean post-treatment effect on non-EUCA arrests per 100k",
       subtitle = "Linear models by state, ranked by mean effect\n(ACS Denoms)",)


plot_usmap(data = map_data, values = "mean_effect_MPI", color = "white", size = 0.3) +
  scale_fill_gradient2(
    mid = "blue", 
    high = "red", 
    midpoint = 0,
    name = "Mean Effect"
  ) +
  theme(legend.position = "right") +
  labs(title = "Mean post-treatment effect on non-EUCA arrests per 100k",
       subtitle = "Linear models by state, ranked by mean effect\n(MPI Denoms)",)
