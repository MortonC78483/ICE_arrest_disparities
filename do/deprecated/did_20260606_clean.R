library(tidyverse)
library(estimatr)
library(patchwork)

library(fixest)
library(ggfixest)
library(mvtnorm)

set.seed(8675309)


# CONFIG ------------------------------------------------------------------
# Switch denominator here: "ACS" or "MPI".
# Everything downstream (ratio, weights, formula) is built from this.
DENOM <- "ACS"

# Event-time window. Reference period is -1 and is dropped from estimation.
T_min <- -7
T_max <-  6

# Non-reference event times, in order: T_min..-2, 0..T_max
event_windows <- setdiff(T_min:T_max, -1)

pop_var    <- paste0("pop_", DENOM)       # e.g. pop_ACS / pop_MPI
ratio_var  <- paste0("ratio_", DENOM)     # e.g. ratio_ACS / ratio_MPI

# Model formula and weights, built once from the chosen denominator
model_fml <- as.formula(
  paste0(ratio_var, " ~ i(window, noneuca, ref = -1) | noneuca + window")
)
wt_fml <- as.formula(paste0("~", pop_var))


# FUNCTIONS ---------------------------------------------------------------

# Jackknife sup-t bands (state jackknife)
jackknife_supt <- function(fe_fit, data) {

  coef0    <- coef(fe_fit)
  states   <- unique(data$state)
  n_states <- length(states)

  # make the jackknife ####
  # G x K matrix of leave-one-state-out coefficients
  jackknife_est_matrix <- t(sapply(states, function(dropped_state) {
    coef(
      feols(model_fml,
            data    = subset(data, state != dropped_state),
            weights = wt_fml,
            cluster = ~state)
    )
  }))

  # the jackknife matrix contains 13 cols, 51 rows
  # center each column and take cross product of whole matrix 
  # to get the variance-covariance
  # TODO: compare this to a standard thing that doesn't consider covariances
  jackknife_est_means <- colMeans(jackknife_est_matrix) 
  vcov_unscaled <- jackknife_est_matrix |>
    scale(center = jackknife_est_means, scale = FALSE) |>
    crossprod()

  # TODO: should this change with weighting?
  scaling_factor <- (n_states - 1) / n_states # normal jackknife 
  
  vcov <- scaling_factor * vcov_unscaled
  se   <- sqrt(diag(vcov))

  # Gaussian sup-t critical value via simulation
  # (Montiel Olea & Plagborg-Møller 2019)
  sims <- rmvnorm(10000, sigma = cov2cor(vcov))
  critical_value <- quantile(apply(abs(sims), 1, max), 0.95)  # replaces 1.96

  # Event-time labels (excludes reference period -1, matching coef order)
  windows <- event_windows

  supt <- tibble(window = windows,
                 est    = coef0, se = se,
                 lower  = coef0 - critical_value * se,
                 upper  = coef0 + critical_value * se)

  # Add the reference period (-1) and order
  supt |>
    bind_rows(tibble(window = -1, est = 0, se = 0, lower = 0, upper = 0)) |>
    arrange(window)
}


# Event-study plot
event_study_plot <- function(estimates,
                             title = "Non-EUCA vs. EUCA: Difference in Arrests per 100k") {
  estimates |>
    ggplot(aes(x = window, y = est)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey50") +
    geom_pointrange(aes(ymin = lower, ymax = upper)) +
    labs(x = "Event time (window)",
         y = "Difference in Arrests per 100k relative to EUCA",
         title = title) +
    theme_minimal()
}


# (Claude helpfully made this command?)
# Build the analysis frame for a set of regions vs. EUCA.
# Aggregates to (noneuca, state, window) and computes the rate.
prep_data <- function(raw, regions = NULL) {
  d <- raw
  if (!is.null(regions)) {
    d <- filter(d, region %in% c(regions, "EUCA"))
  }
  d |>
    mutate(noneuca = as.numeric(region != "EUCA")) |>
    group_by(noneuca, state, window) |>
    summarize(pop      = sum(.data[[pop_var]]),
              n_arrests = sum(n_arrests),
              .groups  = "drop") |>
    # write back under the denominator-specific names the formula expects
    rename(!!pop_var := pop) |>
    mutate(!!ratio_var := n_arrests / .data[[pop_var]] * 100000)
}


# Fit + jackknife for one comparison region (used in the by-region loop)
get_feols <- function(comparison_region) {
  this_dat <- prep_data(dat, regions = comparison_region)
  this_mod <- feols(model_fml, data = this_dat,
                    weights = wt_fml, cluster = ~state)
  jackknife_supt(this_mod, this_dat) |>
    bind_cols(region = comparison_region)
}


###
### DATA ANALYSIS STARTS HERE
###

# Load data ---------------------------------------------------------------
dat <- read_csv("indiv_state_sums.csv")


# Aggregate Non-EUCA vs. EUCA ---------------------------------------------
dat_agg_noneuca <- prep_data(dat)

fe_agg_noneuca <- feols(model_fml, data = dat_agg_noneuca,
                        weights = wt_fml, cluster = ~state)

est_agg_noneuca  <- jackknife_supt(fe_agg_noneuca, dat_agg_noneuca)
plot_agg_noneuca <- event_study_plot(est_agg_noneuca) + 
  ggtitle("Difference in Arrests per 100k relative to EUCA (ACS Denom.)") + 
  theme_minimal(base_size = 18)


# Sanity check (SE inflation vs. nominal clustered SEs)
# nominal_se <- tibble(window = est_agg_noneuca$window[est_agg_noneuca$window != -1],
#                      nominal_se = fe_agg_noneuca$coeftable[, "Std. Error"])
# left_join(est_agg_noneuca, nominal_se, by = "window") |>
#   mutate(se_inflation = se / nominal_se) |> select(window, se_inflation)


# By region ---------------------------------------------------------------
regions <- c("AFRICA", "ASIA", "CARIBBEAN", "MCA", "SA")
coefs   <- map_dfr(regions, get_feols)

plot_region <- coefs |>
  ggplot(aes(x = window, y = est, color = region)) +
  geom_point() +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey50") +
  geom_pointrange(aes(ymin = lower, ymax = upper)) +
  facet_wrap(~ region) +
  labs(x = "Event time (window)",
       y = "Difference in Arrests per 100k relative to EUCA",
       title = "Difference in Arrests per 100k relative to EUCA (ACS Denom.)") +
  theme_minimal(base_size = 18) + theme(legend.position = "none")
  



# SAVE
# ggsave(plot_region, file = "region_ACS_event_study.pdf", 
#        width = 11, height = 8.5)
# ggsave(plot_agg_noneuca, file = "aggregate_ACS_event_study.pdf", 
#        width = 11, height = 8.5)


