# DEPRECATED
#### CONSTANTS ####
model_fml <- as.formula(
  paste0("ratio ~ i(window, region, ref = -1, ref2 = 'EUCA') | region + window")
)
wt_fml <- as.formula("~ pop")

pois_model_fml <- as.formula(
  paste0("n_arrests ~ i(window, region, ref = -1, ref2 = 'EUCA') | region + window")
)
offset_fml <- as.formula("~log_pop")

#### READ DATA ####
trajectory <- read_csv("data/glm_trajectory_type_threatlevel_convicted_ACS_MPI.csv") %>%
  filter(state %in% c("CALIFORNIA", "FLORIDA", "TEXAS", "ARIZONA"))
source("do/helper_functions.R")

#### CLEAN DATA ####
data_state_allregion <- aggregate_data(trajectory, c("region", "window", "state"), "pop_MPI", agg_noneuca = FALSE)
data_state_nonEUCA <- aggregate_data(trajectory, c("region", "window", "state"), "pop_MPI", agg_noneuca = TRUE)
data_allregion <- aggregate_data(trajectory, c("region", "window"), "pop_MPI", agg_noneuca = FALSE)
data_nonEUCA <- aggregate_data(trajectory, c("region", "window"), "pop_MPI", agg_noneuca = TRUE)

# # calculate before and after effects
# ex <- data_nonEUCA %>%
#   select(-c(ratio, log_pop)) %>%
#   mutate(window = ifelse(as.numeric(as.character(window)) < 0, 0, 1)) %>%
#   group_by(region,state,  pop, window) %>%
#   summarize(n_arrests = sum(n_arrests))
# ex_before <- ex %>% filter(window == 0) %>% filter(n_arrests > 10) %>% select(-window)
# ex_after <- ex %>% 
#   filter(window == 1) %>% 
#   filter(n_arrests > 10) %>%
#   select(-window) %>%
#   rename("n_arrests_after" = "n_arrests") %>%
#   merge(ex_before) %>%
#   mutate(ratio = n_arrests_after/n_arrests)
# ex_after_euca <- ex_after %>%
#   filter(region == "EUCA") %>%
#   select(c(state, ratio)) %>%
#   rename("euca_ratio" = "ratio")
# ex_after <- ex_after %>%
#   filter(region != "EUCA") %>%
#   select(c(state, ratio)) %>%
#   rename("noneuca_ratio" = "ratio") %>%
#   merge(ex_after_euca) %>%
#   mutate(noneuca_to_euca_ratio = noneuca_ratio/euca_ratio)
# ex_after_threat0 <- ex_after

#### MAKE PLOTS LINEAR ####
plt.part_a <- linear_plot(data_allregion, model_fml, pal)
plt.part_b <- event_study_plot(fit_linear_diffindiff(data_state_allregion, model_fml, wt_fml), pal = pal)
plt.part_c <- linear_plot(data_nonEUCA, model_fml, pal_euca)
plt.part_d <- event_study_plot(fit_linear_diffindiff(data_state_nonEUCA, model_fml, wt_fml), pal = pal_euca)

plt.bottom <- ggarrange(plt.part_a, plt.part_b, common.legend = TRUE, legend = "right")
plt.top <- ggarrange(plt.part_c, plt.part_d, common.legend = TRUE, legend = "right")
ggarrange(plt.top, plt.bottom, nrow = 2)

#### MAKE PLOTS MULTIPLICATIVE ####
plt.part_a <- mult_plot(data = data_allregion, model_fml = model_fml, pal)
plt.part_b <- event_study_plot(fit_mult_diffindiff(data_state_allregion, pois_model_fml, offset_fml), pal = pal, baseline = 1)
plt.part_c <- mult_plot(data_nonEUCA, model_fml, pal_euca)
plt.part_d <- event_study_plot(fit_mult_diffindiff(data_state_nonEUCA, pois_model_fml, offset_fml), pal = pal_euca, baseline = 1)

plt.bottom <- ggarrange(plt.part_a, plt.part_b, common.legend = TRUE, legend = "right")
plt.top <- ggarrange(plt.part_c, plt.part_d, common.legend = TRUE, legend = "right")
ggarrange(plt.top, plt.bottom, nrow = 2)
