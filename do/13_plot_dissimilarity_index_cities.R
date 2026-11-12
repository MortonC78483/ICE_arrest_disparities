library(readr)
library(tidyverse)

evenness_results <- read_csv("data/processed/city_dissimilarity.csv")

scatter_data <- evenness_results %>%
  group_by(CBSA_Name, Metro_Total_Pop) %>%
  summarize(Avg_Evenness = mean(Evenness_Index, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    Label = case_when(
      CBSA_Name %in% head(arrange(., desc(Metro_Total_Pop))$CBSA_Name, 5) ~ CBSA_Name,
      CBSA_Name %in% head(arrange(., Metro_Total_Pop)$CBSA_Name, 5) ~ CBSA_Name,
      CBSA_Name %in% head(arrange(., desc(Avg_Evenness))$CBSA_Name, 5) ~ CBSA_Name,
      TRUE ~ ""
    )
  )

ggplot(evenness_results, aes(x = Group, y = Evenness_Index))+
  geom_boxplot()+
  theme_minimal() +
  labs(
    x = "Region",
    y = "Dissimilarity Index"
  )+
  ylim(0, 1)

ggsave("figures/supplement/clustering.pdf", width = 5, height = 5)

