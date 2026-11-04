library(tidycensus)

variables <- c(
  total_adults = "B15003_001",
  bachelors = "B15003_022",
  masters = "B15003_023",
  professional = "B15003_024",
  doctorate = "B15003_025",
  income = "B19013_001"
)

data <- get_acs(
  geography = "tract",
  variables = variables,
  state = "FL",
  county = "Sarasota",
  year = 2024,
  survey = "acs5",
  output = "wide"
)

saveRDS(data, "data/sarasota_census.rds")

print("Census data downloaded successfully!")
