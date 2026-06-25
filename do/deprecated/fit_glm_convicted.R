

library(readr)
library(dplyr)
library(ggplot2)
library(ggpubr)

trajectory <- read_csv("data/glm_trajectory_convicted_ACS_MPI.csv")
trajectory <- trajectory %>%
  mutate(region = ifelse(region == "EUCA", "EUCA", "non_EUCA")) %>%
  group_by(state, region, window) %>%
  mutate(total_arrests = sum(n_arrests)) %>%
  filter(convicted == 1) %>%
  mutate(n_arrests = sum(n_arrests)) %>%
  mutate(prop_convicted = n_arrests/total_arrests) %>%
  select(c(region, state, window, total_arrests, n_arrests, convicted)) %>%
  unique()

# fit offset models to the data
mod = glm(n_arrests ~ as.factor(paste0(region, state)) + 
                as.factor(paste0(window, state)) + offset(log(total_arrests)), 
              family = poisson, 
              data = trajectory)

trajectory$pred <- predict(mod, newdata = trajectory, type = "response")

state_sums <- trajectory %>%
  group_by(window, region, convicted) %>%
  summarize(total_arrests = sum(total_arrests),
            conv_arrests = sum(n_arrests),
            pred = sum(pred))

plt <- ggplot(state_sums, aes(x = window, y = conv_arrests/total_arrests, color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = pred/total_arrests, color = region))+
  ggtitle("")+
  ylab("Proportion Arrests w/ Conviction")
plt

plt <- ggplot(state_sums, aes(x = window, y = log(conv_arrests/total_arrests), color = region))+
  geom_point()+
  geom_line(aes(group = region, x = window, y = log(pred/total_arrests), color = region))+
  ggtitle("")+
  ylab("Proportion Arrests w/ Conviction")
plt

###### Consider only
