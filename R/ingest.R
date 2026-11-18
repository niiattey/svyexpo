# Module 1: Ingest ------------------------------------------------------------
#
# Every downstream function expects survey records as an `sf` POINT object
# with these standard columns:
#
#   id       unique record identifier (character)
#   cluster  sampling cluster / enumeration area identifier
#   lon/lat  cluster coordinates in WGS84 (also stored as geometry)
#   date     interview date (Date), optional
#   weight   sampling weight, optional
#   strata   sampling stratum, optional
#   urban    TRUE for urban clusters, FALSE for rural, optional
#
# Outcome and covariate columns are carried through unchanged.

#' Standard column names used throughout svyexpo
#'
#' @return A named character vector describing each standard column.
#' @export
#' @examples
#' svy_schema()
svy_schema <- function() {
  c(
    id = "Unique record identifier",
    cluster = "Sampling cluster identifier",
    lon = "Longitude (WGS84)",
    lat = "Latitude (WGS84)",
    date = "Interview date (Date, optional)",
    weight = "Sampling weight (optional)",
    strata = "Sampling stratum (optional)",
    urban = "TRUE = urban, FALSE = rural (optional)"
  )
}

#' Standardise survey records to the svyexpo schema
#'
#' Renames user-specified columns to the standard names in [svy_schema()],
#' removes records with missing coordinates and returns an `sf` POINT object.
#' Records at (0, 0) are treated as missing because DHS uses this value for
#' clusters without GPS data.
#'
#' @param data A data frame with one row per survey record.
#' @param id,cluster,lon,lat Names of the columns holding the record
#'   identifier, cluster identifier, longitude and latitude.
#' @param date,weight,strata,urban Optional column names for interview date,
#'   sampling weight, stratum and urban/rural status. `urban` may be logical,
#'   `"U"`/`"R"`, `"urban"`/`"rural"`, or DHS-coded `1` (urban) / `2` (rural).
#' @param crs Coordinate reference system of `lon`/`lat`. Defaults to WGS84.
#'
#' @return An `sf` object with standard columns first, followed by all other
#'   columns of `data`. Original columns whose names clash with a standard
#'   name are kept with an `orig_` prefix.
#' @export
#' @examples
#' df <- data.frame(
#'   hhid = c("a", "b", "c"), clust = c(1, 1, 2),
#'   x = c(-0.20, -0.21, 0), y = c(5.60, 5.61, 0),
#'   stunted = c(0, 1, 0), res = c("U", "U", "R")
#' )
#' svy_standardize(df, id = "hhid", cluster = "clust", lon = "x", lat = "y",
#'                 urban = "res")
svy_standardize <- function(data, id, cluster, lon, lat,
                            date = NULL, weight = NULL, strata = NULL,
                            urban = NULL, crs = 4326) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }
  if (inherits(data, "sf")) {
    data <- sf::st_drop_geometry(data)
  }

  mapping <- c(
    id = id, cluster = cluster, lon = lon, lat = lat,
    date = date, weight = weight, strata = strata, urban = urban
  )
  check_columns(data, unname(mapping))

  core <- lapply(mapping, function(col) data[[col]])
  core$id <- as.character(core$id)
  core$lon <- as.numeric(core$lon)
  core$lat <- as.numeric(core$lat)
  if (!is.null(core$weight)) core$weight <- as.numeric(core$weight)
  if (!is.null(core$date)) core$date <- as.Date(core$date)
  if (!is.null(core$urban)) core$urban <- parse_urban(core$urban)

  if (anyDuplicated(core$id)) {
    cli::cli_abort("{.arg id} column {.val {id}} contains duplicate values.")
  }

  # Carry the remaining columns through, protecting standard names.
  rest <- data[setdiff(names(data), unname(mapping))]
  clash <- intersect(names(rest), names(svy_schema()))
  if (length(clash) > 0) {
    names(rest)[match(clash, names(rest))] <- paste0("orig_", clash)
  }
  out <- cbind(as.data.frame(core, stringsAsFactors = FALSE), rest)

  # DHS codes missing GPS as (0, 0); treat as missing.
  bad <- is.na(out$lon) | is.na(out$lat) | (out$lon == 0 & out$lat == 0)
  if (any(bad)) {
    cli::cli_warn(
      "Dropped {sum(bad)} record{?s} with missing or (0, 0) coordinates."
    )
    out <- out[!bad, , drop = FALSE]
  }

  sf::st_as_sf(out, coords = c("lon", "lat"), crs = crs, remove = FALSE)
}

#' Prepare a DHS recode file and GPS dataset
#'
#' Joins a DHS recode (e.g. KR, IR, HR, PR read with `haven::read_dta()`) to
#' the DHS GPS dataset and standardises it with [svy_standardize()].
#' Weights are divided by 1,000,000 and interview dates are converted from
#' century month code (CMC) with [cmc_to_date()].
#'
#' @param survey A DHS recode data frame.
#' @param gps The DHS GPS dataset, as an `sf` object or data frame with
#'   columns `DHSCLUST`, `LATNUM`, `LONGNUM` and `URBAN_RURA`.
#' @param id_vars Columns pasted together to form a unique record id. Use
#'   `c("v001", "v002", "v003", "bidx")` for the children's recode (KR) and
#'   `c("hv001", "hv002", "hvidx")` for the household member recode (PR).
#' @param cluster_var,weight_var,strata_var,cmc_var Recode variable names for
#'   cluster, weight, stratum and interview CMC. Use the `hv` equivalents
#'   (`hv001`, `hv005`, `hv022`, `hv008`) for household-based recodes.
#'
#' @section Calendars:
#' Ethiopia (Ethiopian calendar) and Nepal (Vikram Samvat) record CMC values
#' in local calendars. Convert them to the Gregorian calendar before using
#' interview dates for exposure matching. A warning is raised when the GPS
#' country code is `ET` or `NP`.
#'
#' @return An `sf` object in the standard schema. See [svy_standardize()].
#' @export
svy_from_dhs <- function(survey, gps,
                         id_vars = c("v001", "v002", "v003"),
                         cluster_var = "v001", weight_var = "v005",
                         strata_var = "v022", cmc_var = "v008") {
  check_columns(survey, c(id_vars, cluster_var, weight_var, strata_var, cmc_var),
                arg = "survey")
  if (inherits(gps, "sf")) gps <- sf::st_drop_geometry(gps)
  check_columns(gps, c("DHSCLUST", "LATNUM", "LONGNUM", "URBAN_RURA"),
                arg = "gps")

  if ("DHSCC" %in% names(gps) && any(gps$DHSCC %in% c("ET", "NP"))) {
    cli::cli_warn(c(
      "This survey uses a non-Gregorian calendar (Ethiopia or Nepal).",
      "i" = "Convert {.var {cmc_var}} to Gregorian CMC before matching exposures by date."
    ))
  }

  # Strip haven labels so joins and arithmetic behave predictably.
  plain <- function(x) as.vector(unclass(x))

  df <- data.frame(
    .id = do.call(paste, c(lapply(survey[id_vars], plain), sep = "_")),
    .cluster = plain(survey[[cluster_var]]),
    .weight = plain(survey[[weight_var]]) / 1e6,
    .strata = plain(survey[[strata_var]]),
    .date = cmc_to_date(plain(survey[[cmc_var]])),
    stringsAsFactors = FALSE
  )
  df <- cbind(df, survey[setdiff(names(survey), c(cluster_var, weight_var,
                                                  strata_var))])

  gps_small <- data.frame(
    .cluster = plain(gps$DHSCLUST),
    .lon = plain(gps$LONGNUM),
    .lat = plain(gps$LATNUM),
    .urban = plain(gps$URBAN_RURA)
  )
  df <- merge(df, gps_small, by = ".cluster", all.x = TRUE, sort = FALSE)

  unmatched <- sum(is.na(df$.lon))
  if (unmatched > 0) {
    cli::cli_warn("{unmatched} record{?s} had no matching cluster in {.arg gps}.")
  }

  svy_standardize(
    df,
    id = ".id", cluster = ".cluster", lon = ".lon", lat = ".lat",
    date = ".date", weight = ".weight", strata = ".strata", urban = ".urban"
  )
}

#' Convert century month codes to dates
#'
#' DHS and MICS record dates as century month codes (CMC), the number of
#' months since December 1899 (CMC 1 = January 1900).
#'
#' @param cmc Integer vector of century month codes.
#' @param day Day of the month assigned to each date. Defaults to 15, the
#'   middle of the month.
#' @return A `Date` vector.
#' @export
#' @examples
#' cmc_to_date(c(1369, 1380)) # January and December 2014
cmc_to_date <- function(cmc, day = 15) {
  cmc <- as.integer(cmc)
  year <- 1900L + (cmc - 1L) %/% 12L
  month <- (cmc - 1L) %% 12L + 1L
  out <- as.Date(rep(NA_character_, length(cmc)))
  ok <- !is.na(cmc)
  out[ok] <- as.Date(sprintf("%04d-%02d-%02d", year[ok], month[ok], day))
  out
}

# Convert the common urban/rural codings to logical.
parse_urban <- function(x) {
  x <- as.vector(unclass(x))
  if (is.logical(x)) return(x)
  if (is.numeric(x)) {
    if (!all(x %in% c(1, 2, NA))) {
      cli::cli_abort("Numeric {.arg urban} must be coded 1 = urban, 2 = rural.")
    }
    return(x == 1)
  }
  x <- tolower(trimws(as.character(x)))
  out <- ifelse(x %in% c("u", "urban"), TRUE,
                ifelse(x %in% c("r", "rural"), FALSE, NA))
  bad <- !is.na(x) & is.na(out)
  if (any(bad)) {
    cli::cli_abort("Unrecognised {.arg urban} values: {.val {unique(x[bad])}}.")
  }
  out
}
