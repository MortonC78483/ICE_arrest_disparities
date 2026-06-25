# Create figure 2 and figures S5-S7
library(readr)
library(broom)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)

trajectory <- read_csv("data/glm_trajectory_type_threatlevel_convicted_ACS_MPI.csv") 
source("do/helper_functions.R")

# create four groups
trajectory <- trajectory %>%
  mutate(conv_method = ifelse(method == "LEA", 
                              ifelse(convicted == 1, "LEA_conv", "LEA_nonconv"),
                              ifelse(method == "CA", 
                                     ifelse(convicted == 1, "CA_conv", "CA_nonconv"),
                                     NA)))

conv_method_summary <- aggregate_data(trajectory, c("conv_method", "window"), 
                                      "pop_MPI", 
                                      TRUE) %>%
  filter(!is.na(conv_method))

write_csv(conv_method_summary, "data/conv_method_summary.csv")

ggplot(conv_method_summary, aes(x = as.numeric(as.character(window)), 
                                y = ratio, 
                                group = conv_method, 
                                color = conv_method))+
  geom_line()+
  ggtitle("Arrests per 100k by method + conviction status")+
  ylab("Arrests per 100k")+
  xlab("Window")+
  theme_minimal()

baseline_ratio <- conv_method_summary %>% 
  filter(window == -1) %>%
  rename("baseline_ratio" = "ratio") %>%
  select(c(conv_method, baseline_ratio)) %>%
  merge(conv_method_summary)

ggplot(baseline_ratio, aes(x = as.numeric(as.character(window)), 
                                y = ratio/baseline_ratio, 
                                group = conv_method, 
                                color = conv_method))+
  geom_line()+
  geom_hline(yintercept = 1, linetype = "dashed")+
  ggtitle("Multiplicative scale\nArrests per 100k by method + conviction status")+
  ylab("Arrests per 100k compared to time -1")+
  xlab("Window")+
  theme_minimal()


conv_method_all <- aggregate_data(trajectory, c("conv_method", "window"), 
                                  "pop_MPI", 
                                  TRUE) %>%
  filter(!is.na(conv_method))

ggplot(conv_method_all, aes(x = as.numeric(as.character(window)), 
                                y = ratio, 
                                group = conv_method, 
                                color = conv_method))+
  geom_line()+
  labs(x = "Event time (window)",
       y = "Difference in Arrests per 100k\nrelative to EUCA",
       title = "") +
  theme_minimal()


#### COLOR PALETTE ####
all_regions <- c("AFRICA", "ASIA", "CARIBBEAN", "EUCA", "MCA", "SA")
other_regions <- setdiff(all_regions, "EUCA")
pal <- c("EUCA" = "darkgrey", 
         setNames(scales::brewer_pal(palette = "Dark2")(length(other_regions)), other_regions))

pal_euca <- c("EUCA" = "darkgrey", "nonEUCA" = "darkblue")

#### FORMULAS ####
model_fml <- as.formula(
  paste0("ratio ~ i(window, region, ref = -1, ref2 = 'EUCA') | region + window")
)
wt_fml <- as.formula("~ pop")

pois_model_fml <- as.formula(
  paste0("n_arrests ~ i(window, region, ref = -1, ref2 = 'EUCA') | region + window")
)
offset_fml <- as.formula("~log_pop")

#### PLOT -- EUCA VS NON EUCA ####
conv_method <- aggregate_data(trajectory, c("conv_method", "region", "state", "window"), 
                              "pop_MPI", 
                              TRUE) %>%
  filter(!is.na(conv_method))

data_linear = list()
data_mult = list()
for (method in unique(conv_method$conv_method)){
  conv_method_filtered <- conv_method %>%
    filter(conv_method == method)
  
  data_linear[[method]] <- fit_linear_diffindiff(conv_method_filtered, model_fml, wt_fml) %>%
    mutate(method = method)
  
  data_mult[[method]] <- fit_mult_diffindiff(conv_method_filtered, pois_model_fml, offset_fml) %>%
    mutate(method = method)
}
data_linear <- bind_rows(data_linear) 
data_mult <- bind_rows(data_mult)

ggplot(data_linear, aes(x = window, y = est, color = method, group = method)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey50") +
  geom_point(size = 2.5, position = position_dodge(0.3)) +
  geom_errorbar(aes(ymin = lower, ymax = upper), position = position_dodge(0.3)) +
  geom_line(linewidth = 0.8, position = position_dodge(0.3)) +
  labs(x = "Event time (window)",
       y = "Difference in Arrests per 100k\nrelative to EUCA",
       title = "") +
  theme_minimal()

ggplot(data_mult, aes(x = window, y = est, color = method, group = method)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey50") +
  geom_point(size = 2.5, position = position_dodge(0.3)) +
  geom_errorbar(aes(ymin = lower, ymax = upper), position = position_dodge(0.3)) +
  geom_line(linewidth = 0.8, position = position_dodge(0.3)) +
  labs(x = "Event time (window)",
       y = "Difference in Arrests per 100k\nrelative to EUCA",
       title = "") +
  theme_minimal()

#### PLOT -- EUCA VS ALL REGIONS ####
conv_method <- aggregate_data(trajectory, c("conv_method", "region", "state", "window"), 
                              "pop_MPI", 
                              FALSE) %>%
  filter(!is.na(conv_method))

data_linear = list()
data_mult = list()
for (method in unique(conv_method$conv_method)){
  conv_method_filtered <- conv_method %>%
    filter(conv_method == method)
  
  data_linear[[method]] <- fit_linear_diffindiff(conv_method_filtered, model_fml, wt_fml) %>%
    mutate(method = method)
  
  data_mult[[method]] <- fit_mult_diffindiff(conv_method_filtered, pois_model_fml, offset_fml) %>%
    mutate(method = method)
}
data_linear <- bind_rows(data_linear) 
data_mult <- bind_rows(data_mult)

ggplot(data_linear, aes(x = window, y = est, color = method, group = method)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey50") +
  geom_point(size = 2.5, position = position_dodge(0.3)) +
  geom_errorbar(aes(ymin = lower, ymax = upper), position = position_dodge(0.3)) +
  geom_line(linewidth = 0.8, position = position_dodge(0.3)) +
  facet_wrap("region")+
  labs(x = "Event time (window)",
       y = "Difference in Arrests per 100k\nrelative to EUCA",
       title = "") +
  theme_minimal()

ggplot(data_mult, aes(x = window, y = est, color = method, group = method)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey50") +
  geom_point(size = 2.5, position = position_dodge(0.3)) +
  geom_errorbar(aes(ymin = lower, ymax = upper), position = position_dodge(0.3)) +
  geom_line(linewidth = 0.8, position = position_dodge(0.3)) +
  facet_wrap("region")+
  labs(x = "Event time (window)",
       y = "Difference in Arrests per 100k\nrelative to EUCA",
       title = "") +
  theme_minimal()


