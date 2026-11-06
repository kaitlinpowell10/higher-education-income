library(dplyr)
library(readr)
library(stringr)

read_table <- function(path, columns, geography_pattern) {
  readr::read_delim(
    path,
    delim = "|",
    col_select = all_of(columns),
    col_types = cols(.default = col_character()),
    show_col_types = FALSE,
    progress = FALSE
  ) |>
    filter(str_detect(GEO_ID, geography_pattern))
}

state_lookup <- read_delim(
  file.path("data", "raw", "state.txt"),
  delim = "|",
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) |>
  filter(STUSAB %in% state.abb) |>
  transmute(
    GEOID = STATE,
    NAME = STATE_NAME,
    STUSAB
  )

prepare_estimates <- function(geography_pattern, geography_lookup) {
  education <- read_table(
    file.path("data", "raw", "acsdt5y2024-b15003.dat"),
    c("GEO_ID", "B15003_E001", "B15003_E022", "B15003_E023",
      "B15003_E024", "B15003_E025"),
    geography_pattern
  )

  income <- read_table(
    file.path("data", "raw", "acsdt5y2024-b19013.dat"),
    c("GEO_ID", "B19013_E001"),
    geography_pattern
  )

  geography_lookup |>
    left_join(
      education |>
        mutate(GEO_ID = str_extract(GEO_ID, "[0-9]+$")) |>
        rename(GEOID = GEO_ID),
      by = "GEOID"
    ) |>
    left_join(
      income |>
        mutate(GEO_ID = str_extract(GEO_ID, "[0-9]+$")) |>
        rename(GEOID = GEO_ID),
      by = "GEOID"
    ) |>
    mutate(
      across(starts_with("B"), as.numeric),
      adults_25_plus = B15003_E001,
      bachelors_plus = B15003_E022 + B15003_E023 +
        B15003_E024 + B15003_E025,
      bachelors_plus_pct = 100 * bachelors_plus / adults_25_plus,
      median_household_income = B19013_E001
    ) |>
    filter(
      !is.na(NAME),
      adults_25_plus > 0,
      is.finite(bachelors_plus_pct),
      median_household_income > 0
    )
}

state_data <- prepare_estimates(
  "^0400000US[0-9]{2}$",
  state_lookup
) |>
  select(
    state = NAME, abbreviation = STUSAB, state_fips = GEOID,
    adults_25_plus, bachelors_plus, bachelors_plus_pct, median_household_income
  ) |>
  arrange(state)

if (nrow(state_data) != 50) {
  stop("Expected 50 states in the ACS data; found ", nrow(state_data), ".")
}

write_csv(state_data, file.path("data", "state_acs_2024.csv"))

county_geometry <- sf::st_read(
  file.path("data", "raw", "florida_counties.geojson"),
  quiet = TRUE
)
county_lookup <- county_geometry |>
  sf::st_drop_geometry() |>
  select(GEOID, NAME)

county_data <- prepare_estimates(
  "^0500000US12[0-9]{3}$",
  county_lookup
) |>
  mutate(county = paste(NAME, "County")) |>
  select(
    county, NAME, GEOID, adults_25_plus, bachelors_plus,
    bachelors_plus_pct, median_household_income
  ) |>
  arrange(county)

if (nrow(county_data) != 67) {
  stop("Expected 67 Florida counties in the ACS data; found ", nrow(county_data), ".")
}

write_csv(county_data, file.path("data", "florida_county_acs_2024.csv"))
sf::st_write(
  county_geometry |> select(GEOID, NAME),
  file.path("data", "florida_counties.geojson"),
  delete_dsn = TRUE,
  quiet = TRUE
)
message("Prepared 2024 ACS estimates for 50 states and 67 Florida counties.")
