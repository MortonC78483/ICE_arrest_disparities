# create draft figure 2, s2

library(broom)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)

#trajectory <- read_csv("data/glm_trajectory_type_convicted_ACS_MPI.csv") 
trajectory <- read_csv("data/glm_trajectory_type_threatlevel_convicted_ACS_MPI.csv") %>%
  filter(method == "CA") 

#### CREATE NATIONAL DATA ####
total_arrests <- trajectory %>%
  select(region, window, n_arrests) %>%
  group_by(region, window) %>%
  summarize(total_arrests = sum(n_arrests))

group_pop <- trajectory %>%
  filter(window == 0) %>%
  select(region, state, pop_ACS, pop_MPI) %>%
  unique() %>%
  group_by(region) %>%
  summarize(pop_ACS = sum(pop_ACS),
            pop_MPI = sum(pop_MPI))

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
  merge(group_pop) %>%
  mutate(ratio = n_arrests/total_arrests) 

pop_sums_euca_non <- group_pop %>%
  mutate(region = ifelse(region == "EUCA", "EUCA", "non-EUCA")) %>%
  group_by(region) %>%
  summarize(pop_ACS = sum(pop_ACS), pop_MPI = sum(pop_MPI))

state_sums_euca_non <- state_sums %>%
  ungroup() %>%
  mutate(region = ifelse(region == "EUCA", "EUCA", "non-EUCA")) %>%
  group_by(region, window, criminal_history) %>%
  summarize(n_arrests = sum(n_arrests),
            total_arrests = sum(total_arrests)) %>%
  merge(pop_sums_euca_non)
  

state_sums_euca_non <- state_sums_euca_non %>%
  mutate(ratio = n_arrests/total_arrests) 


all_group_sums <- state_sums_euca_non %>%
  ungroup() %>%
  group_by(window, criminal_history) %>%
  summarize(n_arrests = sum(n_arrests),
            total_arrests = sum(total_arrests)) %>%
  mutate(pop_ACS = sum(group_pop$pop_ACS),
         pop_MPI = sum(group_pop$pop_MPI))

all_group_sums <- all_group_sums %>%
  mutate(ratio = n_arrests/total_arrests)

#### COLOR PALETTE ####
all_regions <- unique(state_sums$region)
other_regions <- setdiff(all_regions, "EUCA")
pal <- c("EUCA" = "darkgrey", 
         setNames(scales::brewer_pal(palette = "Dark2")(length(other_regions)), other_regions))

pal_euca <- c("EUCA" = "darkgrey", "non-EUCA" = "darkblue")

#### Separate by criminal history group ####
# Figure 2: (a) Everybody together, the 3 criminal history groups, additive. 
# overall plot, with 3 lines, one for each conviction history. (b) faceted by regional group, additive.
make_linear_history <- function(data, pal, facet = FALSE){
  if(facet){
    data <- data %>%
      ungroup()
    mod = glm(ratio ~ criminal_history * window * region, 
              family = gaussian, 
              data = data)
    
    data$pred <- predict(mod, newdata = data, type = "response")
    
    plt.linear <- ggplot(data, aes(x = as.numeric(as.character(window)), 
                                   y = ratio, color = criminal_history,
                                   group = criminal_history))+
      geom_point()+
      geom_line(aes(x = as.numeric(as.character(window)), 
                    y = pred, color = criminal_history,
                    group = criminal_history))+
      ylab("Proportion of Arrests")+
      xlab("Window")+
      ggtitle("")+
      theme_minimal()+
      facet_wrap(vars(region))
  } else{
    data <- data %>%
      ungroup()
    mod = glm(ratio ~ criminal_history * window, 
              family = gaussian, 
              data = data)
    
    data$pred <- predict(mod, newdata = data, type = "response")
    
    plt.linear <- ggplot(data, aes(x = as.numeric(as.character(window)), 
                                   y = ratio, color = criminal_history,
                                   group = criminal_history))+
      geom_point()+
      geom_line(aes(x = as.numeric(as.character(window)), 
                    y = pred, color = criminal_history,
                    group = criminal_history))+
      ylab("Proportion of Arrests")+
      xlab("Window")+
      ggtitle("")+
      theme_minimal()
  }
  
  return(plt.linear)
}

part_a <- make_linear_history(all_group_sums, pal)
part_b <- make_linear_history(state_sums_euca_non, pal, facet = T)
part_c <- make_linear_history(state_sums, pal, facet = T)

ggarrange(part_a, part_b, common.legend = T)

ggarrange(part_a, part_c, common.legend = T)

make_linear_history_count <- function(data, pal, 
                                      facet = FALSE, common_scale = T){
  if(facet){
    data <- data %>%
      ungroup()
    mod = glm(n_arrests ~ criminal_history * window * region, 
              family = gaussian, 
              data = data)
    
    data$pred <- predict(mod, newdata = data, type = "response")
    
    plt.linear <- ggplot(data, aes(x = as.numeric(as.character(window)), 
                                   y = n_arrests, color = criminal_history,
                                   group = criminal_history))+
      geom_point()+
      geom_line(aes(x = as.numeric(as.character(window)), 
                    y = pred, color = criminal_history,
                    group = criminal_history))+
      ylab("Arrest Count")+
      xlab("Window")+
      ggtitle("")+
      theme_minimal()+
      facet_wrap(vars(region), scales = ifelse(common_scale, "fixed", "free_y"))
  } else{
    data <- data %>%
      ungroup()
    mod = glm(n_arrests ~ criminal_history * window, 
              family = gaussian, 
              data = data)
    
    data$pred <- predict(mod, newdata = data, type = "response")
    
    plt.linear <- ggplot(data, aes(x = as.numeric(as.character(window)), 
                                   y = n_arrests, color = criminal_history,
                                   group = criminal_history))+
      geom_point()+
      geom_line(aes(x = as.numeric(as.character(window)), 
                    y = pred, color = criminal_history,
                    group = criminal_history))+
      ylab("Arrest Count")+
      xlab("Window")+
      ggtitle("")+
      theme_minimal()
  }
  
  return(plt.linear)
}

part_a <- make_linear_history_count(all_group_sums, pal)
part_b <- make_linear_history_count(state_sums_euca_non, pal, facet = T)
part_c <- make_linear_history_count(state_sums, pal, facet = T, common_scale = F)

ggarrange(part_a, part_b, common.legend = T)
ggarrange(part_a, part_c, common.legend = T)

make_linear_history_100k <- function(data, pal, 
                                      facet = FALSE, common_scale = T){
  data <- data %>%
    ungroup() %>%
    mutate(arrests_100k = n_arrests/pop_ACS*100000)
  
  if(facet){
    
    mod = glm(arrests_100k ~ criminal_history * window * region, 
              family = gaussian, 
              data = data)
    
    data$pred <- predict(mod, newdata = data, type = "response")
    
    plt.linear <- ggplot(data, aes(x = as.numeric(as.character(window)), 
                                   y = arrests_100k, color = criminal_history,
                                   group = criminal_history))+
      geom_point()+
      geom_line(aes(x = as.numeric(as.character(window)), 
                    y = pred, color = criminal_history,
                    group = criminal_history))+
      ylab("Arrests/100k")+
      xlab("Window")+
      ggtitle("")+
      theme_minimal()+
      facet_wrap(vars(region), scales = ifelse(common_scale, "fixed", "free_y"))
  } else{
    mod = glm(arrests_100k ~ criminal_history * window, 
              family = gaussian, 
              data = data)
    
    data$pred <- predict(mod, newdata = data, type = "response")
    
    plt.linear <- ggplot(data, aes(x = as.numeric(as.character(window)), 
                                   y = arrests_100k, color = criminal_history,
                                   group = criminal_history))+
      geom_point()+
      geom_line(aes(x = as.numeric(as.character(window)), 
                    y = pred, color = criminal_history,
                    group = criminal_history))+
      ylab("Arrests/100k")+
      xlab("Window")+
      ggtitle("")+
      theme_minimal()
  }
  
  return(plt.linear)
}


part_a <- make_linear_history_100k(all_group_sums, pal)
part_b <- make_linear_history_100k(state_sums_euca_non, pal, facet = T)
part_c <- make_linear_history_100k(state_sums, pal, facet = T, common_scale = F)

ggarrange(part_a, part_b, common.legend = T)
ggarrange(part_a, part_c, common.legend = F)

#### DIFF IN DIFF
state_sums_euca_non_diff <- state_sums_euca_non %>%
  filter(criminal_history == "Case Threat Level = 1") %>%
  ungroup()
state_sums_diff <- state_sums %>%
  filter(criminal_history == "Case Threat Level = 1") %>%
  ungroup()

ggplot(state_sums_euca_non_diff, aes(x = as.numeric(as.character(window)), y = ratio, color = region, group = region)) +
  geom_line()

make_mult_diffindiff <- function(data, pal){
  mod.acs_all_groups = glm(n_arrests ~ region * window + offset(log(total_arrests)), 
                           family = poisson, 
                           data = data)
  
  mod.acs_all_groups_results <- tidy(mod.acs_all_groups, conf.int = TRUE)
  
  plot_data <- mod.acs_all_groups_results %>%
    filter(str_detect(term, "region") & str_detect(term, "window")) %>%
    mutate(
      clean_term = str_remove(term, "region"),
      clean_term = str_remove(clean_term, "window")
    ) %>%
    separate(clean_term, into = c("Region", "Window"), sep = ":") %>%
    mutate(
      Window = as.numeric(Window),
      Ratio = exp(estimate),
      Conf.Low = exp(conf.low),
      Conf.High = exp(conf.high)
    )
  
  baseline_windows <- tibble(
    Region = unique(plot_data$Region),
    Window = -1,
    Ratio = 1,
    Conf.Low = 1,
    Conf.High = 1
  )
  
  plot_data <- bind_rows(plot_data, baseline_windows) %>% 
    arrange(Region, Window)
  
  plt.acs_mult_diffindiff <- ggplot(plot_data, aes(x = Window, y = Ratio, color = Region, group = Region)) +
    geom_hline(yintercept = 1, linetype = "dashed") +
    geom_vline(xintercept = -0.5, linetype = "dashed") +
    geom_errorbar(aes(ymin = Conf.Low, ymax = Conf.High), position = position_dodge(0.3)) +
    geom_point(size = 2.5, position = position_dodge(0.3)) +
    geom_line(linewidth = 0.8, position = position_dodge(0.3)) +
    labs(
      x = "Event Study",
      y = "Non-EUCA high-threat arrest proportion/\nEUCA high-threat arrest proportion",
      caption = "(# non-EUCA level 1 arrests / total non-EUCA arrests) / (# EUCA level 1 arrests / total EUCA arrests),\n 
      where these are all divided by their respective proportions at window -1\n
      Y axis is how many times lower/higher (below/above 1) the non-EUCA high-threat arrest rate is than the EUCA rate, compared to this difference in window -1."
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")+
    scale_color_manual(values = pal)
  
  return(plt.acs_mult_diffindiff)
}
make_mult_diffindiff(state_sums_euca_non_diff, pal_euca)
make_mult_diffindiff(state_sums_diff, pal)+
  ggtitle("Community Arrests Only")
