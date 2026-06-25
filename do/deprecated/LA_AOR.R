# Analyses specific to the Los Angeles AOR

library(readr)

trajectory <- read_csv("data/glm_trajectory_type_threatlevel_convicted_ACS_MPI_LAonly.csv") 

### MAKE GRAPHS ###
part_a <- make_linear_100k(state_sums, pal)+ggtitle("LA Only")
part_b <- make_linear_diffindiff(state_sums, pal)
part_c <- make_linear_100k(state_sums_euca_non, pal_euca)
part_d <- make_linear_diffindiff(state_sums_euca_non, pal_euca)
ggarrange(part_a, part_b,
          part_c, part_d, 
          nrow = 2, ncol = 2)

part_a <- make_mult_100k(state_sums, pal) + ggtitle("LA Only")
part_b <- make_mult_diffindiff(state_sums, pal)
part_c <- make_mult_100k(state_sums_euca_non, pal_euca)
part_d <- make_mult_diffindiff(state_sums_euca_non, pal_euca)
ggarrange(part_a, part_b,
          part_c, part_d, 
          nrow = 2, ncol = 2)
