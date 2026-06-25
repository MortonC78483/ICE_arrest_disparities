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
  filter(method == "CA") %>%
  mutate(conv_method = ifelse(method == "CA", ifelse(convicted == 1, "CA_conv", "CA_nonconv"),
                                     NA))

conv_method_summary <- aggregate_data(trajectory, c("conv_method", "window"), 
                                      "pop_MPI", 
                                      TRUE) %>%
  filter(!is.na(conv_method))

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

#### PLOT -- TRIPLE DIFF ####
conv_method <- aggregate_data(trajectory, c("conv_method", "region", "state", "window"), 
                              "pop_MPI", 
                              TRUE) %>%
  filter(!is.na(conv_method))

fit_triple_diff(conv_method, model_fml, wt_fml)


data = conv_method %>%
  mutate(window = as.factor(window),
         region = as.factor(region),
         conv_method = as.factor(conv_method))%>%
  mutate(
    region = relevel(region, ref = "EUCA"),
    window = relevel(window, ref = "-1"),
    conv_method = relevel(conv_method, ref = "CA_conv")
  )

model_fml <- as.formula(
  paste0("ratio ~ window*region*conv_method | region + window + conv_method")
)
wt_fml <- as.formula("~ pop")

mod <- feols(model_fml, data = data, weights = wt_fml, cluster = ~state)
mod$coefs
fit_triple_diff <- function(data, model_fml, wt_fml){
  region_vals <- setdiff(unique(data$region), "EUCA")
  
  region_coefs <- list()
  
  for(cur_region in region_vals){
    data_filtered <- data %>% filter(region %in% c("EUCA", cur_region))
    fe_agg_noneuca <- feols(model_fml, data = data_filtered,
                            weights = wt_fml, cluster = ~state)
    region_coefs[[cur_region]] <- jackknife_supt(fe_agg_noneuca, model_fml, wt_fml, data_filtered) %>%
      mutate(region = cur_region)
  }
  
  region_coefs <- bind_rows(region_coefs) 
  return(region_coefs)
}

# for (method in unique(conv_method$conv_method)){
#   conv_method_filtered <- conv_method %>%
#     filter(conv_method == method)
#   
#   data_linear[[method]] <- fit_triple_diff(conv_method_filtered, model_fml, wt_fml) %>%
#     mutate(method = method)
#   
# }
# data_linear <- bind_rows(data_linear) 
# data_mult <- bind_rows(data_mult)
