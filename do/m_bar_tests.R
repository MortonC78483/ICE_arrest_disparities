
library(dplyr)
library(did)
library(haven)
library(ggplot2)
library(fixest)
library(HonestDiD)

df <- read_dta("https://raw.githubusercontent.com/Mixtape-Sessions/Advanced-DID/main/Exercises/Data/ehec_data.dta")


df_nonstaggered <- df %>% filter(year < 2016 & (is.na(yexp2)| yexp2 != 2015) )
df_nonstaggered <- df_nonstaggered %>% mutate(D = case_when( yexp2 == 2014 ~ 1, T ~ 0))
twfe_results <- fixest::feols(dins ~ i(year, D, ref = 2013) | stfips + year,
                              cluster = "stfips",
                              data = df_nonstaggered)
betahat <- summary(twfe_results)$coefficients
sigma <- summary(twfe_results)$cov.scaled
fixest::iplot(twfe_results)
delta_rm_results <-
  HonestDiD::createSensitivityResults_relativeMagnitudes(
    betahat = betahat, #coefficients
    sigma = sigma, #covariance matrix
    numPrePeriods = 5, #num. of pre-treatment coefs
    numPostPeriods = 2, #num. of post-treatment coefs
    Mbarvec = seq(0.5,2,by=0.5), #values of Mbar
    l_vec = c(0.5, 0.5)
  )
delta_rm_results


df_nonstaggered <- df %>% filter(year < 2018 & (is.na(yexp2)| yexp2 != 2015) )
df_nonstaggered <- df_nonstaggered %>% mutate(D = case_when( yexp2 == 2014 ~ 1, T ~ 0))
twfe_results <- fixest::feols(dins ~ i(year, D, ref = 2013) | stfips + year,
                              cluster = "stfips",
                              data = df_nonstaggered)
betahat <- summary(twfe_results)$coefficients
sigma <- summary(twfe_results)$cov.scaled
fixest::iplot(twfe_results)
delta_rm_results <-
  HonestDiD::createSensitivityResults_relativeMagnitudes(
    betahat = betahat, #coefficients
    sigma = sigma, #covariance matrix
    numPrePeriods = 5, #num. of pre-treatment coefs
    numPostPeriods = 4, #num. of post-treatment coefs
    Mbarvec = seq(0.5,2,by=0.5), #values of Mbar
    l_vec = c(0.25,0.25,0.25,0.25)
  )
delta_rm_results
