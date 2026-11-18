# Exposure sources --------------------------------------------------------------
#
# svy_exposure() turns whatever the user has (a raster or raster stack, a CSV
# of monitor readings, a table of gridded cells, or a table of area-level
# values) into one common object, so svy_expose() does not need to know the
# original format.

#' Describe an exposure data source
#'
#' Wraps the exposure data you have, so that [svy_expose()] can link it to
#' people. Four kinds of source are supported:
#'
#' * **`raster`**: a `SpatRaster`, or a file path. One layer per time step
#'   (daily, monthly, annual or irregular), or a single static layer.
#' * **`points`**: a table of monitor or sensor readings with one row per
#'   monitor and time: an identifier, longitude, latitude, a date and a
#'   value. Sub-daily timestamps are aggregated to days first.
#' * **`grid`**: a table of regular grid cells in the same long format as
#'   `points` (for example a raster exported to CSV). Cells are treated as
#'   monitors at the cell centres.
#' * **`areas`**: a table of values for administrative units (district,
#'   region) and dates, with no coordinates. People are matched to a unit by
#'   a column in their data, or by `boundaries`, a polygon layer.
#'
#' Tables can be a data frame or a path to a `.csv`, `.csv.gz` or `.parquet`
#' file. The type is detected from the columns unless you set `type`.
#'
#' @param x A `SpatRaster`, a data frame, or a file path.
#' @param type One of `"auto"`, `"raster"`, `"points"`, `"grid"`, `"areas"`.
#' @param value,date Column names of the exposure value and its date or
#'   timestamp (tables only).
#' @param unit Column naming the monitor or area (tables). Not needed for
#'   `grid`, where cells are identified by their coordinates.
#' @param lon,lat Coordinate columns (`points` and `grid`).
#' @param crs Coordinate reference system of `lon`/`lat`. Default WGS84.
#' @param step Length of one period: `"auto"` (infer from the dates),
#'   `"day"`, `"month"`, `"year"`, or `"layer"` (each date lasts until the
#'   next, for irregular series such as 8-day composites). Sub-daily table
#'   data are always aggregated to days.
#' @param agg_fun How to combine several readings in one period of a table:
#'   `"mean"` (default), `"median"`, `"max"`, `"min"` or `"sum"`.
#' @param dates For rasters: the date of each layer. If `NULL`, taken from
#'   `terra::time()`, then from dates in the layer names such as
#'   `pm25_2019-03` or `pm25_20190305`.
#' @param static `TRUE` for a raster with no time dimension (for example
#'   population density or distance to road). Every window then receives the
#'   same value.
#' @param boundaries Optional `sf` polygons for `areas`, used to find which
#'   area each person lives in.
#' @param boundary_id Column in `boundaries` holding the unit identifier that
#'   matches `unit`.
#'
#' @return An object of class `svy_exposure_source`.
#' @examples
#' # Monitor readings
#' readings <- data.frame(
#'   monitor = rep(c("A", "B"), each = 3),
#'   lon = rep(c(-0.20, -0.18), each = 3), lat = 5.6,
#'   date = rep(as.Date("2020-01-01") + 0:2, 2),
#'   pm25 = c(30, 32, 31, 50, 52, 51)
#' )
#' svy_exposure(readings, unit = "monitor", value = "pm25")
#' @export
svy_exposure <- function(x, type = c("auto", "raster", "points", "grid", "areas"),
                         value = "value", date = "date", unit = "id",
                         lon = "lon", lat = "lat", crs = 4326,
                         step = c("auto", "day", "month", "year", "layer"),
                         agg_fun = c("mean", "median", "max", "min", "sum"),
                         dates = NULL, static = FALSE,
                         boundaries = NULL, boundary_id = NULL) {
  type <- match.arg(type)
  step <- match.arg(step)
  agg_fun <- match.arg(agg_fun)

  if (is.character(x) && length(x) == 1) {
    if (!file.exists(x) && !grepl("^/vsi", x)) {
      cli::cli_abort("File {.file {x}} does not exist.")
    }
    if (grepl("\\.(csv|csv\\.gz|parquet)$", x, ignore.case = TRUE)) {
      x <- read_table_file(x)
    }
  }

  is_table <- is.data.frame(x)
  if (type == "auto") {
    type <- if (!is_table) "raster"
            else if (all(c(lon, lat) %in% names(x))) "points"
            else "areas"
  }
  if (type == "raster" && is_table) {
    cli::cli_abort("{.arg x} is a table but {.code type = \"raster\"}.")
  }
  if (type != "raster" && !is_table) {
    cli::cli_abort("{.arg x} is not a table; use {.code type = \"raster\"} for rasters.")
  }

  if (type == "raster") {
    return(source_raster(x, step, dates, static))
  }
  source_table(x, type, value, date, unit, lon, lat, crs, step, agg_fun,
               boundaries, boundary_id)
}

read_table_file <- function(path) {
  if (grepl("\\.parquet$", path, ignore.case = TRUE)) {
    if (!requireNamespace("arrow", quietly = TRUE)) {
      cli::cli_abort("Reading parquet needs the {.pkg arrow} package.")
    }
    return(as.data.frame(arrow::read_parquet(path)))
  }
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

# Date of each raster layer: explicit, then terra time, then layer names.
layer_dates_from_raster <- function(r) {
  tm <- terra::time(r)
  if (!all(is.na(tm))) {
    if (inherits(tm, "Date")) return(tm)
    if (inherits(tm, "POSIXt")) return(as_date_strict(tm))
    if (is.numeric(tm) && all(tm > 1800 & tm < 2200)) {
      return(as.Date(paste0(as.integer(tm), "-01-01")))
    }
  }
  nm <- names(r)
  pats <- list(
    list("(19|20)[0-9]{2}[-_.]?(0[1-9]|1[0-2])[-_.]?(0[1-9]|[12][0-9]|3[01])", 3),
    list("(19|20)[0-9]{2}[-_.](0[1-9]|1[0-2])", 2),
    list("(19|20)[0-9]{2}", 1)
  )
  for (p in pats) {
    m <- regmatches(nm, regexpr(p[[1]], nm))
    if (length(m) == length(nm)) {
      digits <- gsub("[^0-9]", "", m)
      y <- substr(digits, 1, 4)
      mo <- if (p[[2]] >= 2) substr(digits, 5, 6) else "01"
      dd <- if (p[[2]] == 3) substr(digits, 7, 8) else "01"
      return(as.Date(paste(y, mo, dd, sep = "-")))
    }
  }
  NULL
}

source_raster <- function(x, step, dates, static) {
  r <- as_spatraster(x)
  if (is.na(terra::crs(r)) || terra::crs(r) == "") {
    cli::cli_abort("The raster has no coordinate reference system.")
  }
  if (static) {
    return(structure(list(kind = "raster", raster = r, static = TRUE,
                          periods = NULL, layer_period = NULL, step = NA_character_),
                     class = "svy_exposure_source"))
  }
  d <- dates %||% layer_dates_from_raster(r)
  if (is.null(d)) {
    cli::cli_abort(c(
      "Could not determine the date of each raster layer.",
      "i" = "Pass {.arg dates}, set {.code terra::time(r) <- dates}, name layers with dates (e.g. {.val pm25_2019-03}), or use {.code static = TRUE}."
    ))
  }
  d <- as_date_strict(d, "dates")
  if (length(d) != terra::nlyr(r)) {
    cli::cli_abort("{.arg dates} must have one value per raster layer ({terra::nlyr(r)}).")
  }
  if (step == "auto") step <- infer_step(d)
  periods <- make_periods(d, step)
  layer_period <- match(floor_step(d, step), periods$start)
  if (anyDuplicated(layer_period)) {
    cli::cli_abort(c(
      "Two or more raster layers fall in the same {step}.",
      "i" = "Aggregate the layers first, or set {.arg step} to a finer value."
    ))
  }
  structure(list(kind = "raster", raster = r, static = FALSE, periods = periods,
                 layer_period = layer_period, step = step),
            class = "svy_exposure_source")
}

source_table <- function(df, type, value, date, unit, lon, lat, crs, step,
                         agg_fun, boundaries, boundary_id) {
  need <- c(value, date, if (type == "points") c(unit, lon, lat),
            if (type == "areas") unit, if (type == "grid") c(lon, lat))
  check_columns(df, need, arg = "x")

  raw_date <- df[[date]]
  subdaily <- has_time_of_day(raw_date)
  d <- as_date_strict(raw_date, date)
  val <- suppressWarnings(as.numeric(df[[value]]))
  if (all(is.na(val))) {
    cli::cli_abort("Column {.field {value}} has no numeric values.")
  }
  u <- switch(type,
    grid = paste(signif(as.numeric(df[[lon]]), 9), signif(as.numeric(df[[lat]]), 9), sep = "_"),
    as.character(df[[unit]])
  )
  keep <- !is.na(d) & !is.na(val) & !is.na(u)
  if (!any(keep)) cli::cli_abort("No usable rows: every row has a missing date, value or identifier.")
  if (sum(!keep) > 0) {
    cli::cli_inform("Dropped {sum(!keep)} row{?s} with a missing date, value or identifier.")
  }
  d <- d[keep]; val <- val[keep]; u <- u[keep]
  xy <- if (type != "areas") {
    data.frame(lon = as.numeric(df[[lon]])[keep], lat = as.numeric(df[[lat]])[keep])
  }

  if (step == "auto") step <- if (subdaily) "day" else infer_step(d)
  if (subdaily && step != "day") {
    cli::cli_inform("Sub-daily timestamps found; values are first aggregated to days.")
  }
  periods <- make_periods(d, step)
  period_start <- floor_step(d, step)
  pidx <- match(period_start, periods$start)

  units <- sort(unique(u))
  ui <- match(u, units)

  # Combine readings that share a unit and period (hourly -> daily, or
  # duplicated rows).
  key <- ui + (pidx - 1) * length(units)
  agg <- if (agg_fun == "mean") {
    s <- rowsum(val, key)
    n <- rowsum(rep(1, length(val)), key)
    stats::setNames(as.numeric(s) / as.numeric(n), rownames(s))
  } else {
    vapply(split(val, key), match.fun(agg_fun), numeric(1))
  }
  k <- as.numeric(names(agg))
  X <- matrix(NA_real_, length(units), nrow(periods))
  X[cbind((k - 1) %% length(units) + 1, (k - 1) %/% length(units) + 1)] <- agg

  unit_sf <- NULL
  if (type != "areas") {
    first <- !duplicated(ui)
    xyu <- xy[first, ][order(ui[first]), ]
    spread <- vapply(split(xy, ui), function(z) {
      max(diff(range(z$lon)), diff(range(z$lat)))
    }, numeric(1))
    if (any(spread > 1e-6)) {
      cli::cli_warn("{sum(spread > 1e-6)} unit{?s} have more than one coordinate; the first is used.")
    }
    unit_sf <- sf::st_as_sf(data.frame(unit = units, xyu), coords = c("lon", "lat"),
                            crs = crs, remove = FALSE)
    unit_sf <- sf::st_transform(unit_sf, 4326)
    xyu4326 <- sf::st_coordinates(unit_sf)
    unit_sf$lon <- xyu4326[, 1]
    unit_sf$lat <- xyu4326[, 2]
  }
  if (type == "areas" && !is.null(boundaries)) {
    check_class(boundaries, "sf")
    if (is.null(boundary_id)) cli::cli_abort("Give {.arg boundary_id} with {.arg boundaries}.")
    check_columns(boundaries, boundary_id, arg = "boundaries")
    boundaries <- sf::st_transform(boundaries, 4326)
  }

  structure(list(kind = type, X = X, units = units, unit_sf = unit_sf,
                 periods = periods, step = step, boundaries = boundaries,
                 boundary_id = boundary_id, static = FALSE),
            class = "svy_exposure_source")
}

#' @export
print.svy_exposure_source <- function(x, ...) {
  cli::cli_text("{.cls svy_exposure_source}: {.strong {x$kind}}")
  if (isTRUE(x$static)) {
    cli::cli_bullets(c("*" = "Static raster ({terra::nlyr(x$raster)} layer{?s}), no time dimension"))
  } else {
    p <- x$periods
    cli::cli_bullets(c(
      "*" = "Time step: {x$step}; {nrow(p)} period{?s}, {format(min(p$start))} to {format(max(p$end))}"
    ))
    if (x$kind == "raster") {
      cli::cli_bullets(c("*" = "{length(x$layer_period)} raster layer{?s}"))
    } else {
      pct <- round(100 * mean(!is.na(x$X)), 1)
      cli::cli_bullets(c("*" = "{length(x$units)} unit(s); {pct}% of unit-periods have a value"))
    }
  }
  invisible(x)
}
