# constants
INAUG_DATE = "2025-01-20"
WINDOW_DAYS = 60

# run version of the script with maximum pre-period
TOTAL_DAYS_EACH_SIDE = 14*WINDOW_DAYS
FULL_PRE_PERIOD = TRUE
AOR = FALSE
remove_duplicates = FALSE
RAW_STATE = FALSE
source("do/01_make_glm_traj.R")

# run 01_make_glm_traj with all options
TOTAL_DAYS_EACH_SIDE = 9*WINDOW_DAYS
FULL_PRE_PERIOD = FALSE
AOR = TRUE
remove_duplicates = TRUE
source("do/01_make_glm_traj.R")

AOR = TRUE
remove_duplicates = FALSE
source("do/01_make_glm_traj.R")

AOR = FALSE
remove_duplicates = TRUE
source("do/01_make_glm_traj.R")

AOR = FALSE
remove_duplicates = FALSE
source("do/01_make_glm_traj.R")

AOR = FALSE
remove_duplicates = FALSE
RAW_STATE = TRUE
source("do/01_make_glm_traj.R")

