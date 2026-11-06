raw_dir <- file.path("data", "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

census_base <- paste0(
  "https://www2.census.gov/programs-surveys/acs/summary_file/",
  "2024/table-based-SF/data/5YRData"
)

tables <- c(
  education = "acsdt5y2024-b15003.dat",
  income = "acsdt5y2024-b19013.dat"
)

downloads <- c(
  tables,
  state_codes = "https://www2.census.gov/geo/docs/reference/state.txt"
)

for (table_file in downloads) {
  source_url <- if (grepl("^https://", table_file)) {
    table_file
  } else {
    paste(census_base, table_file, sep = "/")
  }
  destination_name <- basename(table_file)
  destination <- file.path(raw_dir, destination_name)
  if (file.exists(destination) && file.info(destination)$size > 0) {
    message("Using existing Census download: ", destination)
    next
  }

  temporary_file <- tempfile(tmpdir = raw_dir)
  download.file(
    source_url,
    destfile = temporary_file,
    mode = "wb",
    method = "libcurl"
  )

  if (!file.exists(temporary_file) || file.info(temporary_file)$size == 0) {
    stop("Census download was empty: ", destination_name)
  }

  if (!file.rename(temporary_file, destination)) {
    stop("Could not save Census download to: ", destination)
  }
  message("Saved Census download: ", destination)
}

county_path <- file.path(raw_dir, "florida_counties.geojson")
if (!file.exists(county_path) || file.info(county_path)$size == 0) {
  options(tigris_use_cache = TRUE)
  florida_counties <- tigris::counties(
    state = "FL",
    cb = TRUE,
    year = 2024,
    class = "sf"
  )

  if (nrow(florida_counties) != 67 ||
      !any(florida_counties$GEOID == "12115")) {
    stop("Census 2024 Florida county boundaries were incomplete.")
  }

  temporary_file <- tempfile(fileext = ".geojson", tmpdir = raw_dir)
  sf::st_write(florida_counties, temporary_file, quiet = TRUE)
  if (!file.rename(temporary_file, county_path)) {
    stop("Could not save Census county boundaries to: ", county_path)
  }
  message("Saved Census county boundaries: ", county_path)
}
