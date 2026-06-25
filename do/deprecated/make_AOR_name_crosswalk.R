aor_codes = c("NOL", "SEA", "PHO", "SND", "SFR", 
  "LOS", "DEN", "BOS", "PHI", "WAS", 
  "MIA", "ATL", "SLC", "CHI", "SPM", 
  "BAL", "DET", "NEW", "ELP", "BUF", 
  "NYC", "DAL", "SNA", "HOU")
aor_names = c("New Orleans", "Seattle", "Phoenix", "San Diego", "San Francisco",
              "Los Angeles", "Denver", "Boston", "Philadelphia", "Washington",
              "Miami", "Atlanta", "Salt Lake City", "Chicago", "St. Paul", 
              "Baltimore", "Detroit", "Newark", "El Paso", "Buffalo",
              "New York City", "Dallas", "San Antonio", "Houston")

write_csv(data.frame("aor_code" =  aor_codes, "aor_name" = aor_names), "data/crosswalks/aor_code_name_crosswalk.csv")
