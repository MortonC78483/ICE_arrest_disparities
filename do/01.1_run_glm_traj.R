# run 01_make_glm_traj with the two options

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
