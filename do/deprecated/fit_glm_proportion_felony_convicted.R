
library(readr)
library(dplyr)
library(ggplot2)
library(ggpubr)

##### Figures of proportion of arrestees with a felony or conviction ####
create_prop_arrestees <- function(arrest_col = "convicted",
                                  region_agg = TRUE,
                                  use_alt_methods = FALSE,
                                  methods = NA
                                  ){
  
  trajectory <- read_csv("data/glm_trajectory_type_convicted_ACS_MPI.csv")
  
  # filter arrest method
  initial_groups <- unique(c("state", "region", "window", arrest_col))
  
  trajectory <- trajectory %>%
    select(-c(pop_ACS, pop_MPI))
  
  # filter arrest method
  if (any(!is.na(methods))){
    if(use_alt_methods){
      trajectory <- trajectory %>%
        mutate(method = alt_method) %>%
        select(-alt_method) %>%
        filter(method %in% methods) %>%
        group_by(across(all_of(initial_groups))) %>%
        summarize(n_arrests = sum(n_arrests), .groups = "drop")
    } else{
      trajectory <- trajectory %>%
        select(-alt_method) %>%
        filter(method %in% methods) %>%
        group_by(across(all_of(initial_groups))) %>%
        summarize(n_arrests = sum(n_arrests), .groups = "drop")
    }
  } else{ # we want to use all the methods and aggregate them
    trajectory <- trajectory %>%
      select(-c(alt_method, method)) %>%
      group_by(across(all_of(initial_groups))) %>%
      summarize(n_arrests = sum(n_arrests), .groups = "drop")
  }

  # aggregate region
  if (region_agg){
    trajectory <- trajectory %>%
      mutate(region = ifelse(region == "EUCA", "EUCA", "non_EUCA")) %>%
      group_by(window, .data[[arrest_col]], region, state) %>%
      mutate(n_arrests = sum(n_arrests)) %>%
      ungroup() %>% 
      distinct()
  }
  
  trajectory <- trajectory %>%  
    group_by(window, region, state) %>%
    mutate(total_arrests = sum(n_arrests)) %>% 
    filter(.data[[arrest_col]] == 1) %>% 
    ungroup()
  
  # fit offset models to the data
  state_list <- na.omit(unique(trajectory$state))
  trajectory_predictions <- list()
  for (state_val in state_list){
    trajectory_filtered <- trajectory[trajectory$state == state_val,] %>%
      filter(total_arrests > 0)
    
   # if (nrow(trajectory_filtered) == 0) {
    #  next
    #}
    
    if(length(levels(as.factor(trajectory_filtered$region)))>1){
      mod = glm(n_arrests ~ as.factor(paste0(region)) + 
                  as.factor(paste0(window)) + 
                  offset(log(total_arrests)), 
                family = poisson, 
                data = trajectory_filtered)
      
      trajectory_filtered$pred <- predict(mod, 
                                          newdata = trajectory_filtered, 
                                          type = "response")
      
      trajectory_predictions[[state_val]] <- trajectory_filtered
    } else{
      mod = glm(n_arrests ~ as.factor(paste0(window)) + 
                  offset(log(total_arrests)), 
                family = poisson, 
                data = trajectory_filtered)
      
      trajectory_filtered$pred <- predict(mod, 
                                          newdata = trajectory_filtered, 
                                          type = "response")
      
      trajectory_predictions[[state_val]] <- trajectory_filtered
    }
  }
  
  trajectory <- do.call(rbind, trajectory_predictions)
  
  state_sums <- trajectory %>%
    group_by(window, region) %>%
    summarize(n_arrests = sum(n_arrests),
              pred = sum(pred),
              total_arrests = sum(total_arrests),
              .groups = "drop")
  
  title = paste0("Proportion of Arrestees\nwith ", arrest_col)
  if (any(!is.na(methods))){
    title = paste0(title, "\nArrest Method = ", paste(methods, collapse = ", "))
  } 
  if(use_alt_methods){
    title = paste0(title, " (Alt Classification)")
  }

  arr.plt <- ggplot(state_sums, aes(x = window, y = n_arrests/total_arrests, color = region))+
    geom_point()+
    geom_line(aes(group = region, x = window, y = pred/total_arrests, color = region))+
    ggtitle(title)+
    ylab("Proportion Arrestees")
  
  arr.plt
}

create_all_lea_ca_prop_arrestees <- function(arrest_col = "convicted",
                                             region_agg = TRUE,
                                             use_alt_methods = FALSE){
  all_arr.plt <- create_prop_arrestees(arrest_col,
                                       region_agg,
                                       use_alt_methods,
                                       methods = NA)
  lea_arr.plt <- create_prop_arrestees(arrest_col,
                                       region_agg,
                                       use_alt_methods,
                                       methods = "LEA")
  ca_arr.plt <- create_prop_arrestees(arrest_col,
                                     region_agg,
                                     use_alt_methods,
                                     methods = "CA")
  
  ggarrange(all_arr.plt, lea_arr.plt, ca_arr.plt, ncol = 3)
  
}
  
create_all_lea_ca_prop_arrestees(arrest_col = "convicted",
                                 region_agg = FALSE,
                                 use_alt_methods = FALSE)

create_all_lea_ca_prop_arrestees(arrest_col = "convicted",
                                 region_agg = TRUE,
                                 use_alt_methods = FALSE)

create_all_lea_ca_prop_arrestees(arrest_col = "felony",
                                 region_agg = FALSE,
                                 use_alt_methods = FALSE)

create_all_lea_ca_prop_arrestees(arrest_col = "felony",
                                 region_agg = TRUE,
                                 use_alt_methods = FALSE)


create_all_lea_ca_prop_arrestees(arrest_col = "convicted",
                                 region_agg = FALSE,
                                 use_alt_methods = TRUE)

create_all_lea_ca_prop_arrestees(arrest_col = "convicted",
                                 region_agg = TRUE,
                                 use_alt_methods = TRUE)

create_all_lea_ca_prop_arrestees(arrest_col = "felony",
                                 region_agg = FALSE,
                                 use_alt_methods = TRUE)

create_all_lea_ca_prop_arrestees(arrest_col = "felony",
                                 region_agg = TRUE,
                                 use_alt_methods = TRUE)



##### Figures of arrestees per 100k, faceted by conviction type ####
create_arrestees_100k <- function(trajectory, 
                                  pop_col, 
                                  region_agg = TRUE, 
                                  use_alt_methods = FALSE, 
                                  methods = NA,
                                  title = NA
){
  initial_groups <- unique(c("state", "region", "window", pop_col))
  
  deselect_pop_col = setdiff(c("pop_ACS", "pop_MPI"), pop_col)
  
  trajectory <- trajectory %>%
    select(-.data[[deselect_pop_col]])
  
  # filter arrest method
  if (any(!is.na(methods))){
    if(use_alt_methods){
      trajectory <- trajectory %>%
        mutate(method = alt_method) %>%
        select(-alt_method) %>%
        filter(method %in% methods) %>%
        group_by(across(all_of(initial_groups))) %>%
        summarize(n_arrests = sum(n_arrests), .groups = "drop")
    } else{
      trajectory <- trajectory %>%
        select(-alt_method) %>%
        filter(method %in% methods) %>%
        group_by(across(all_of(initial_groups))) %>%
        summarize(n_arrests = sum(n_arrests), .groups = "drop")
    }
  } else{ # we want to use all the methods and aggregate them
    trajectory <- trajectory %>%
      select(-c(alt_method, method)) %>%
      group_by(across(all_of(initial_groups))) %>%
      summarize(n_arrests = sum(n_arrests), .groups = "drop")
  }
  
  # aggregate region
  if (region_agg){
    trajectory <- trajectory %>%
      mutate(region = ifelse(region == "EUCA", "EUCA", "non_EUCA")) %>%
      group_by(window, region, state) %>%
      mutate(n_arrests = sum(n_arrests),
             pop = sum(.data[[pop_col]])) %>%
      select(-.data[[pop_col]]) %>%
      ungroup() %>% 
      distinct()
  } else{
    trajectory <- trajectory %>%
      group_by(window, region, state) %>%
      mutate(n_arrests = sum(n_arrests),
             pop = sum(.data[[pop_col]])) %>%
      select(-.data[[pop_col]]) %>%
      ungroup() %>% 
      distinct()
  }
  
  # fit offset models to the data
  state_list <- na.omit(unique(trajectory$state))
  trajectory_predictions <- list()
  for (state_val in state_list){
    trajectory_filtered <- trajectory[trajectory$state == state_val,]
    
    if(length(levels(as.factor(trajectory_filtered$region)))>1){
      mod = glm(n_arrests ~ as.factor(paste0(region)) + 
                  as.factor(paste0(window)) + 
                  offset(log(pop)), 
                family = poisson, 
                data = trajectory_filtered)
      
      trajectory_filtered$pred <- predict(mod, 
                                          newdata = trajectory_filtered, 
                                          type = "response")
      
      trajectory_predictions[[state_val]] <- trajectory_filtered
    } else{
      mod = glm(n_arrests ~ as.factor(paste0(window)) + 
                  offset(log(pop)), 
                family = poisson, 
                data = trajectory_filtered)
      
      trajectory_filtered$pred <- predict(mod, 
                                          newdata = trajectory_filtered, 
                                          type = "response")
      
      trajectory_predictions[[state_val]] <- trajectory_filtered
    }
  }
  
  trajectory <- do.call(rbind, trajectory_predictions)
  
  state_sums <- trajectory %>%
    group_by(window, region) %>%
    summarize(n_arrests = sum(n_arrests),
              pred = sum(pred),
              total_pop = sum(pop),
              .groups = "drop")
  
  # make plot
  if (is.na(title)){
    title = paste0("Arrests per 100k, \nDenominators = ", pop_col)
  }
  
  
  arr.plt <- ggplot(state_sums, aes(x = window, y = n_arrests/total_pop*100000, color = region))+
    geom_point()+
    geom_line(aes(group = region, x = window, y = pred/total_pop*100000, color = region))+
    ggtitle(title)+
    ylab("Arrests per 100k")
  
  arr.plt
}

create_arrestees_100k_ratio <- function(trajectory, 
                                  pop_col, 
                                  region_agg = TRUE, 
                                  numerator_col = "MCA",
                                  use_alt_methods = FALSE, 
                                  methods = NA,
                                  title = NA
){
  initial_groups <- unique(c("state", "region", "window", pop_col))
  
  deselect_pop_col = setdiff(c("pop_ACS", "pop_MPI"), pop_col)
  
  trajectory <- trajectory %>%
    select(-.data[[deselect_pop_col]])
  
  # filter arrest method
  if (any(!is.na(methods))){
    if(use_alt_methods){
      trajectory <- trajectory %>%
        mutate(method = alt_method) %>%
        select(-alt_method) %>%
        filter(method %in% methods) %>%
        group_by(across(all_of(initial_groups))) %>%
        summarize(n_arrests = sum(n_arrests), .groups = "drop")
    } else{
      trajectory <- trajectory %>%
        select(-alt_method) %>%
        filter(method %in% methods) %>%
        group_by(across(all_of(initial_groups))) %>%
        summarize(n_arrests = sum(n_arrests), .groups = "drop")
    }
  } else{ # we want to use all the methods and aggregate them
    trajectory <- trajectory %>%
      select(-c(alt_method, method)) %>%
      group_by(across(all_of(initial_groups))) %>%
      summarize(n_arrests = sum(n_arrests), .groups = "drop")
  }
  
  # aggregate region
  if (region_agg){
    trajectory <- trajectory %>%
      mutate(region = ifelse(region == "EUCA", "EUCA", "non_EUCA")) %>%
      group_by(window, region, state) %>%
      mutate(n_arrests = sum(n_arrests),
             pop = sum(.data[[pop_col]])) %>%
      select(-.data[[pop_col]]) %>%
      ungroup() %>% 
      mutate(region = ifelse(region == "EUCA", "EUCA", "Numerator")) %>%
      distinct() %>%
      filter(n_arrests > 0)
  } else{
    trajectory <- trajectory %>%
      filter(region %in% c(numerator_col, "EUCA")) %>%
      group_by(window, region, state) %>%
      mutate(n_arrests = sum(n_arrests),
             pop = sum(.data[[pop_col]])) %>%
      select(-.data[[pop_col]]) %>%
      ungroup() %>% 
      mutate(region = ifelse(region == "EUCA", "EUCA", "Numerator")) %>%
      distinct() %>%
      filter(n_arrests > 0)
  }
  
  
  # fit offset models to the data
  state_list <- na.omit(unique(trajectory$state))
  trajectory_predictions <- list()
  for (state_val in state_list){
    trajectory_filtered <- trajectory[trajectory$state == state_val,]
    
    if(length(levels(as.factor(trajectory_filtered$region)))>1){
      mod = glm(n_arrests ~ as.factor(paste0(region)) + 
                  as.factor(paste0(window)) + 
                  offset(log(pop)), 
                family = poisson, 
                data = trajectory_filtered)
      
      trajectory_filtered$pred <- predict(mod, 
                                          newdata = trajectory_filtered, 
                                          type = "response")
      
      trajectory_predictions[[state_val]] <- trajectory_filtered
    } else{
      mod = glm(n_arrests ~ as.factor(paste0(window)) + 
                  offset(log(pop)), 
                family = poisson, 
                data = trajectory_filtered)
      
      trajectory_filtered$pred <- predict(mod, 
                                          newdata = trajectory_filtered, 
                                          type = "response")
      
      trajectory_predictions[[state_val]] <- trajectory_filtered
    }
  }
  
  trajectory <- do.call(rbind, trajectory_predictions)
  
  state_sums <- trajectory %>%
    group_by(window, region) %>%
    summarize(n_arrests = sum(n_arrests),
              pred = sum(pred),
              total_pop = sum(pop),
              .groups = "drop")
  
  # make plot
  if (region_agg){
    if(is.na(title)){
      title = paste0("Arrest ratio per 100k, \nDenominators = ", pop_col)
    }
    ytitle = paste0("Non-EUCA arrests per 100k to EUCA arrests per 100k")
  } else{
    if(is.na(title)){
      title = paste0("Arrest ratio per 100k, \nDenominators = ", pop_col)
    }
    ytitle = paste0(numerator_col, " arrests per 100k to EUCA arrests per 100k")
  }
  state_sums_ratio <- state_sums %>%
    pivot_wider(names_from = region, values_from = c(n_arrests, pred, total_pop), id_cols = window) %>%
    mutate(ratio = (n_arrests_Numerator/total_pop_Numerator)/(n_arrests_EUCA/total_pop_EUCA),
           ratio_pred = (pred_Numerator/total_pop_Numerator)/(pred_EUCA/total_pop_EUCA))
  
  arr.plt <- ggplot(state_sums_ratio, aes(x = window, y = ratio))+
    geom_point()+
    geom_line(aes( x = window, y = ratio_pred))+
    ggtitle(title)+
    ylab(ytitle)+
    ylim(0, max(c(state_sums_ratio$ratio, state_sums_ratio$ratio_pred)))
  
  arr.plt
}

facet_arrestees_ratio <- function(pop_col, 
                                  region_agg = TRUE, 
                                  numerator_col = "MCA",
                                  use_alt_methods = FALSE, 
                                  methods = NA,
                                  title = NA){
  trajectory <- read_csv("data/glm_trajectory_type_convicted_ACS_MPI.csv")
  
  
  if(any(!is.na(methods))){
    title = paste0(methods, " ")
  } else{title = ""}
  
  # filter to people who have a felony conviction
  felonies <- trajectory %>%
    filter(felony == 1)
  felony.plt <- create_arrestees_100k_ratio(felonies, 
                                      pop_col = pop_col, 
                                      region_agg = region_agg, 
                                      numerator_col = numerator_col,
                                      use_alt_methods = use_alt_methods, 
                                      methods = methods,
                                      title = paste0(title,
                                                     "Arrests Ratio (Felony) per 100k, \nDenominators = ", 
                                                     pop_col))
  
  convicted_non_felony <- trajectory %>%
    filter(felony == 0 & convicted == 1)
  convicted_non_felony.plt <- create_arrestees_100k_ratio(convicted_non_felony, 
                                                    pop_col = pop_col, 
                                                    region_agg = region_agg, 
                                                    numerator_col = numerator_col,
                                                    use_alt_methods = use_alt_methods, 
                                                    methods = methods,
                                                    title = paste0(title,
                                                                   "Arrests Ratio (non-felony, convicted) per 100k, \nDenominators = ", 
                                                                   pop_col))
  
  non_convicted_non_felony <- trajectory %>%
    filter(felony == 0 & convicted == 0)
  non_convicted_non_felony.plt <- create_arrestees_100k_ratio(non_convicted_non_felony, 
                                                        pop_col = pop_col, 
                                                        region_agg = region_agg, 
                                                        numerator_col = numerator_col,
                                                        use_alt_methods = use_alt_methods, 
                                                        methods = methods,
                                                        title = paste0(title,
                                                                       "Arrests Ratio (non-convicted, non-felony) per 100k, \nDenominators = ", 
                                                                       pop_col))
  
  
  ggarrange(felony.plt, convicted_non_felony.plt, non_convicted_non_felony.plt, ncol = 3)
}


facet_arrestees_ratio(pop_col = "pop_MPI", 
                region_agg = TRUE, 
                use_alt_methods = FALSE, 
                methods = NA)

facet_arrestees <- function(pop_col, 
                            region_agg = TRUE, 
                            use_alt_methods = FALSE, 
                            methods = NA){
  trajectory <- read_csv("data/glm_trajectory_type_convicted_ACS_MPI.csv")
  

  if(any(!is.na(methods))){
    title = paste0(methods, " ")
  } else{title = ""}
  
  # filter to people who have a felony conviction
  felonies <- trajectory %>%
    filter(felony == 1)
  felony.plt <- create_arrestees_100k(felonies, 
                        pop_col = pop_col, 
                        region_agg = region_agg, 
                        use_alt_methods = use_alt_methods, 
                        methods = methods,
                        title = paste0(title,
                                       "Arrests (Felony) per 100k, \nDenominators = ", 
                                       pop_col))
  
  convicted_non_felony <- trajectory %>%
    filter(felony == 0 & convicted == 1)
  convicted_non_felony.plt <- create_arrestees_100k(convicted_non_felony, 
                        pop_col = pop_col, 
                        region_agg = region_agg, 
                        use_alt_methods = use_alt_methods, 
                        methods = methods,
                        title = paste0(title,
                                       "Arrests (non-felony, convicted) per 100k, \nDenominators = ", 
                                       pop_col))
  
  non_convicted_non_felony <- trajectory %>%
    filter(felony == 0 & convicted == 0)
  non_convicted_non_felony.plt <- create_arrestees_100k(non_convicted_non_felony, 
                        pop_col = pop_col, 
                        region_agg = region_agg, 
                        use_alt_methods = use_alt_methods, 
                        methods = methods,
                        title = paste0(title,
                                       "Arrests (non-convicted, non-felony) per 100k, \nDenominators = ", 
                                       pop_col))
  
  
  ggarrange(felony.plt, convicted_non_felony.plt, non_convicted_non_felony.plt, ncol = 3)
}


facet_arrestees(pop_col = "pop_MPI", 
                region_agg = TRUE, 
                use_alt_methods = FALSE, 
                methods = NA)

facet_arrestees(pop_col = "pop_MPI", 
                region_agg = TRUE, 
                use_alt_methods = FALSE, 
                methods = "LEA")

facet_arrestees(pop_col = "pop_MPI", 
                region_agg = TRUE, 
                use_alt_methods = FALSE, 
                methods = "CA")


facet_arrestees(pop_col = "pop_MPI", 
                region_agg = FALSE, 
                use_alt_methods = FALSE, 
                methods = NA)

facet_arrestees(pop_col = "pop_MPI", 
                region_agg = FALSE, 
                use_alt_methods = FALSE, 
                methods = "LEA")

facet_arrestees(pop_col = "pop_MPI", 
                region_agg = FALSE, 
                use_alt_methods = FALSE, 
                methods = "CA")



facet_arrestees(pop_col = "pop_ACS", 
                region_agg = TRUE, 
                use_alt_methods = FALSE, 
                methods = NA)

facet_arrestees(pop_col = "pop_ACS", 
                region_agg = TRUE, 
                use_alt_methods = FALSE, 
                methods = "LEA")

facet_arrestees(pop_col = "pop_ACS", 
                region_agg = TRUE, 
                use_alt_methods = FALSE, 
                methods = "CA")


facet_arrestees(pop_col = "pop_ACS", 
                region_agg = FALSE, 
                use_alt_methods = FALSE, 
                methods = NA)

facet_arrestees(pop_col = "pop_ACS", 
                region_agg = FALSE, 
                use_alt_methods = FALSE, 
                methods = "LEA")

facet_arrestees(pop_col = "pop_ACS", 
                region_agg = FALSE, 
                use_alt_methods = FALSE, 
                methods = "CA")




##### Figures of arrestees per 100k ####



#### PLOTS SUMMED ACROSS ALL STATES #####


# log_arr.plt <- ggplot(state_sums, aes(x = window, y = log(n_arrests/total_arrests), color = region))+
#   geom_point()+
#   geom_line(aes(group = region, x = window, y = log(pred/total_arrests), color = region))+
#   ggtitle("log(Predictions): Raw")+
#   ylab("Arrests")



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
