# This code will fit a basic glm model with the different offsets to make trajectory figures
# uses output from make_glm_traj.R

library(readr)
library(dplyr)
library(ggplot2)
library(ggpubr)

trajectory <- read_csv("data/glm_trajectory_type_convicted_ACS_MPI.csv")

# we want to aggregate up to just the state level -- method and convicted aren't important
trajectory <- trajectory %>%
  filter(felony == 0) %>%
  group_by(state, region, felony, window, pop_ACS, pop_MPI) %>%
  summarize(n_arrests = sum(n_arrests)) %>%
  ungroup()
# if we want to compare just EUCA vs not EUCA
trajectory <- trajectory %>%
  #mutate(region = ifelse(region == "EUCA", "EUCA", "non_EUCA")) %>%
  group_by(window, region, state) %>%
  mutate(n_arrests = sum(n_arrests),
         pop_ACS = sum(pop_ACS),
         pop_MPI = sum(pop_MPI)) %>%
  unique()
  

# fit offset models to the data
# TODO: Make sure this is the same if the models are run separately by state (e.g. check California, WV)
# run a separate model for each state and store the results
state_list <- unique(trajectory$state)
trajectory_predictions <- c()
for (state_val in state_list){
  trajectory_filtered <- trajectory[trajectory$state == state_val,]
  
  mod_ACS = glm(n_arrests ~ as.factor(paste0(region, state)) + 
                  as.factor(paste0(window, state)) + 
                  offset(log(pop_ACS)), 
                family = poisson, 
                data = trajectory_filtered)
  
  mod_MPI = glm(n_arrests ~ as.factor(paste0(region, state)) + 
                  as.factor(paste0(window, state)) + 
                  offset(log(pop_MPI)), 
                family = poisson, 
                data = trajectory_filtered)
  
  trajectory_filtered$pred_ACS <- predict(mod_ACS, 
                                 newdata = trajectory_filtered, 
                                 type = "response")
  trajectory_filtered$pred_MPI <- predict(mod_MPI, 
                                 newdata = trajectory_filtered, 
                                 type = "response")
  
  trajectory_predictions <- rbind(trajectory_predictions, trajectory_filtered)
}

trajectory <- trajectory_predictions

#### PLOTS SUMMED ACROSS ALL STATES #####
state_sums <- trajectory %>%
  group_by(window, region) %>%
  summarize(n_arrests = sum(n_arrests),
            pred_ACS = sum(pred_ACS),
            pred_MPI = sum(pred_MPI),
            pop_ACS = sum(pop_ACS),
            pop_MPI = sum(pop_MPI))

logacs.plt <- ggplot(state_sums, aes(x = window, y = log(n_arrests), color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = log(pred_ACS), color = region))+
  ggtitle("log(ACS Predictions): Raw")+
  ylab("Arrests")

logmpi.plt <- ggplot(state_sums, aes(x = window, y = log(n_arrests), color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = log(pred_MPI), color = region))+
  ggtitle("log(MPI Predictions): Raw")+
  ylab("Arrests")

acs.plt <- ggplot(state_sums, aes(x = window, y = n_arrests, color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = pred_ACS, color = region))+
  ggtitle("ACS Predictions: Raw")+
  ylab("Arrests")

mpi.plt <- ggplot(state_sums, aes(x = window, y = n_arrests, color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = pred_MPI, color = region))+
  ggtitle("MPI Predictions: Raw")+
  ylab("Arrests")

acs_100k.plt <- ggplot(state_sums, aes(x = window, y = n_arrests/pop_ACS*100000, color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = pred_ACS/pop_ACS*100000, color = region))+
  ggtitle("ACS Predictions: Per 100K")+
  ylab("Arrests per 100K")

mpi_100k.plt <- ggplot(state_sums, aes(x = window, y = n_arrests/pop_MPI*100000, color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = pred_MPI/pop_MPI*100000, color = region))+
  ggtitle("MPI Predictions: Per 100K")+
  ylab("Arrests per 100K")

logacs_100k.plt <- ggplot(state_sums, aes(x = window, y = log(n_arrests/pop_ACS*100000), color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = log(pred_ACS/pop_ACS*100000), color = region))+
  ggtitle("log(ACS Predictions: Per 100K)")+
  ylab("Arrests per 100K")

logmpi_100k.plt <- ggplot(state_sums, aes(x = window, y = log(n_arrests/pop_MPI*100000), color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = log(pred_MPI/pop_MPI*100000), color = region))+
  ggtitle("log(MPI Predictions: Per 100K)")+
  ylab("Arrests per 100K")


ggarrange(logacs.plt, logmpi.plt, 
          logacs_100k.plt, logmpi_100k.plt)

ggarrange(acs.plt, mpi.plt, 
          acs_100k.plt, mpi_100k.plt)

#### SPAGHETTI PLOTS #####
logacs_spag.plt <- ggplot(trajectory, aes(x = window, y = log(n_arrests), color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = log(pred_ACS), color = region))+
  ggtitle("log(ACS Predictions: Raw)")+
  ylab("Arrests")

facet(logacs_spag.plt, facet.by = "state") +
  ylim(-2, 10)

logmpi_spag_100k.plt <- ggplot(trajectory, aes(x = window, y = log(n_arrests/pop_MPI*100000), color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = log(pred_MPI/pop_MPI*100000), color = region))+
  ggtitle("log(MPI Predictions: Per 100K)")+
  ylab("Arrests per 100K")

facet(logmpi_spag_100k.plt, facet.by = "state") + ylim(2, 9)

logacs_spag_100k.plt <- ggplot(trajectory, aes(x = window, y = log(n_arrests/pop_ACS*100000), color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = log(pred_ACS/pop_ACS*100000), color = region))+
  ggtitle("log(ACS Predictions: Per 100K)")+
  ylab("Arrests per 100K")

facet(logacs_spag_100k.plt, facet.by = "state") + ylim(2, 9)

#### INVESTIGATE BY-STATE PLOTS FOR TOP 5 STATES ONLY
trajectory %>%
  group_by(state) %>%
  summarize(sum(n_arrests)) %>%
  arrange(-`sum(n_arrests)`)

# Texas, Florida, California, New York, Arizona
trajectory_filtered <- trajectory %>%
  filter(state %in% c("TEXAS", "FLORIDA", "CALIFORNIA", "NEW YORK", "ARIZONA"))

logacs_spag.plt <- ggplot(trajectory_filtered, aes(x = window, y = log(n_arrests), color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = log(pred_ACS), color = region))+
  ggtitle("log(ACS Predictions: Raw)")+
  ylab("Arrests")

facet(logacs_spag.plt, facet.by = "state") 

##### 
