# DEPRECATED for version that makes the figures in functions

# Proportion of arrestees with a felony (or with any conviction)
# Option to filter by method (community arrest, etc)


library(readr)
library(dplyr)
library(ggplot2)
library(ggpubr)

trajectory <- read_csv("data/glm_trajectory_type_convicted_ACS_MPI.csv")

sum(trajectory$convicted*trajectory$n_arrests)/sum(trajectory$n_arrests)
sum(trajectory$felony*trajectory$n_arrests)/sum(trajectory$n_arrests)

# create table with conviction/felony
conv_fel_summary <- trajectory %>%
  select(convicted, felony, n_arrests) %>%
  group_by(convicted, felony) %>%
  summarize(sum(n_arrests))

# we want to aggregate up to just the state level -- method and convicted aren't important
trajectory <- trajectory %>%
  #filter(method == "LEA") %>% # CHANGE FOR DIFFERENT METHOD
  group_by(state, region, felony, window, pop_ACS, pop_MPI) %>%
  summarize(n_arrests = sum(n_arrests)) %>%
  ungroup()

# if we want to compare just EUCA vs not EUCA
trajectory <- trajectory %>%
  mutate(region = ifelse(region == "EUCA", "EUCA", "non_EUCA")) %>%
  group_by(window, felony, region, state) %>%
  mutate(n_arrests = sum(n_arrests),
         pop_ACS = sum(pop_ACS),
         pop_MPI = sum(pop_MPI)) %>%
  unique() %>%
  group_by(window, region, state) %>%
  mutate(total_arrests = sum(n_arrests)) %>%
  filter(felony == 1)

# fit offset models to the data
state_list <- unique(trajectory$state)
trajectory_predictions <- c()
for (state_val in state_list){
  if (nrow(trajectory_filtered) == 0) {
    next
  }
  
  trajectory_filtered <- trajectory[trajectory$state == state_val,] %>%
    filter(total_arrests > 0)
  
  if(length(levels(as.factor(trajectory_filtered$region)))>1){
    mod = glm(n_arrests ~ as.factor(paste0(region)) + 
                    as.factor(paste0(window)) + 
                    offset(log(total_arrests)), 
                  family = poisson, 
                  data = trajectory_filtered)
    
    trajectory_filtered$pred <- predict(mod, 
                                            newdata = trajectory_filtered, 
                                            type = "response")
    
    trajectory_predictions <- rbind(trajectory_predictions, trajectory_filtered)
  } else{
      mod = glm(n_arrests ~ as.factor(paste0(window)) + 
                  offset(log(total_arrests)), 
                family = poisson, 
                data = trajectory_filtered)
      
      trajectory_filtered$pred <- predict(mod, 
                                          newdata = trajectory_filtered, 
                                          type = "response")
      
      trajectory_predictions <- rbind(trajectory_predictions, trajectory_filtered)
    }
}

trajectory <- trajectory_predictions

#### PLOTS SUMMED ACROSS ALL STATES #####
state_sums <- trajectory %>%
  group_by(window, region) %>%
  summarize(n_arrests = sum(n_arrests),
            pred = sum(pred),
            total_arrests = sum(total_arrests))

# log_arr.plt <- ggplot(state_sums, aes(x = window, y = log(n_arrests/total_arrests), color = region))+
#   geom_point()+
#   geom_line(aes(group = region, x = window, y = log(pred/total_arrests), color = region))+
#   ggtitle("log(Predictions): Raw")+
#   ylab("Arrests")

arr.plt <- ggplot(state_sums, aes(x = window, y = n_arrests/total_arrests, color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = pred/total_arrests, color = region))+
  ggtitle("Proportion of Arrestees with Felony")+
  ylab("All Arrests")

arr.plt

##### ARRESTEES WITH A FELONY CONVICTION, PER 100K #####
# library(readr)
# library(dplyr)
# library(ggplot2)
# library(ggpubr)
# 
# trajectory <- read_csv("data/glm_trajectory_type_convicted_ACS_MPI.csv")
# 
# # we want to aggregate up to just the state level -- method and convicted aren't important
# trajectory <- trajectory %>%
#   
#   #filter(method == "LEA") %>% # CHANGE FOR DIFFERENT METHOD
#   group_by(state, region, window, pop_ACS, pop_MPI) %>%
#   summarize(n_arrests = sum(n_arrests)) %>%
#   ungroup()
# 
# # if we want to compare just EUCA vs not EUCA
# trajectory <- trajectory %>%
#   mutate(region = ifelse(region == "EUCA", "EUCA", "non_EUCA")) %>%
#   group_by(window, region, state) %>%
#   mutate(n_arrests = sum(n_arrests),
#          pop_ACS = sum(pop_ACS),
#          pop_MPI = sum(pop_MPI)) %>%
#   unique() %>%
#   group_by(window, region, state) %>%
#   mutate(total_arrests = sum(n_arrests))
# 
# # fit offset models to the data
# state_list <- unique(trajectory$state)
# trajectory_predictions <- c()
# for (state_val in state_list){
#   trajectory_filtered <- trajectory[trajectory$state == state_val,] %>%
#     filter(total_arrests > 0)
#   
#   if(length(levels(as.factor(trajectory_filtered$region)))>1){
#     mod = glm(n_arrests ~ as.factor(paste0(region)) + 
#                 as.factor(paste0(window)) + 
#                 offset(log(pop_ACS)), 
#               family = poisson, 
#               data = trajectory_filtered)
#     
#     trajectory_filtered$pred_ACS <- predict(mod, 
#                                         newdata = trajectory_filtered, 
#                                         type = "response")
#     
#     mod = glm(n_arrests ~ as.factor(paste0(region)) + 
#                 as.factor(paste0(window)) + 
#                 offset(log(pop_MPI)), 
#               family = poisson, 
#               data = trajectory_filtered)
#     
#     trajectory_filtered$pred_MPI <- predict(mod, 
#                                             newdata = trajectory_filtered, 
#                                             type = "response")
#     
#     trajectory_predictions <- rbind(trajectory_predictions, trajectory_filtered)
#   } else{
#     mod = glm(n_arrests ~ as.factor(paste0(window)) + 
#                 offset(log(pop_ACS)), 
#               family = poisson, 
#               data = trajectory_filtered)
#     
#     trajectory_filtered$pred_ACS <- predict(mod, 
#                                         newdata = trajectory_filtered, 
#                                         type = "response")
#     
#     mod = glm(n_arrests ~ as.factor(paste0(window)) + 
#                 offset(log(pop_MPI)), 
#               family = poisson, 
#               data = trajectory_filtered)
#     
#     trajectory_filtered$pred_MPI <- predict(mod, 
#                                             newdata = trajectory_filtered, 
#                                             type = "response")
#     
#     trajectory_predictions <- rbind(trajectory_predictions, trajectory_filtered)
#   }
# }
# 
# 
# 
