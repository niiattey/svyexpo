# Exposure assignment -----------------------------------------------------------

#' Assign exposures to people over their own time windows
#'
#' For each person, averages an exposure around their home location over one
#' or more time windows measured from an anchor date, and reports how much of
#' each window had data. It works the same way for rasters, monitor
#' readings, gridded tables and area-level tables (see [svy_exposure()]).
#'
#' **Space.** For rasters, the exposure is the coverage-weighted summary of
#' raster cells inside a circle of the chosen radius. For monitor and grid
#' tables, monitors inside the radius are combined by `assign`: their `"mean"`,
#' the `"nearest"` one, or an inverse-distance weighted mean (`"idw"`). For
#' area tables, the person's area value is used and the radius is ignored.
#' Distances to monitors are great-circle distances in metres.
#'
#' **Time.** A window is a pair `c(start, end)` of offsets from the anchor
#' date, in `window_unit`, with both ends inclusive. `c(-270, -1)` in days is
#' the 270 days before the anchor date. Months and years follow the calendar,
#' so `c(-9, 0)` in months is the nine calendar months up to the anchor date.
#' Windows may overlap and be nested, so a cumulative window is simply a long
#' one. A day-level exposure is the mean over the days of the window; periods
#' longer than a day (a month of a monthly raster, a year of an annual table)
#' are weighted by how many of their days fall inside the window.
#'
#' **Completeness.** `coverage` is the share of the window's days that had an
#' exposure value. Windows below `min_coverage` return `NA`, so a window that
#' starts before the data begin is not silently averaged over a fraction of
#' its length.
#'
#' @param data A data frame (or `sf` points) with one row per person, with
#'   columns for identifier, date and, unless `exposure` is area-level,
#'   longitude and latitude.
#' @param exposure An exposure source from [svy_exposure()], or anything
#'   [svy_exposure()] accepts (a raster, a data frame, a file path).
#' @param windows A named list of `c(start, end)` offsets, or a preset from
#'   [svy_windows()].
#' @param radius_km Buffer radius or radii in kilometres, for example
#'   `c(1, 2, 5)`. Use `"dhs"` for the DHS displacement rule (2 km urban,
#'   5 km rural), which needs a column named `urban` (`TRUE`/`FALSE`, the DHS
#'   codes 1/2, or `"urban"`/`"rural"`).
#' @param window_unit Unit of the window offsets: `"days"` (default),
#'   `"weeks"`, `"months"` or `"years"`.
#' @param id,date,lon,lat Column names in `data`.
#' @param date_is `"anchor"` if `date` is already the date windows are
#'   measured from, for example date of birth. `"interview"` if `date` is the
#'   interview or measurement date and the anchor is the date of birth
#'   derived as `date - age_months`.
#' @param age_months Column with the child's age in months; needed when
#'   `date_is = "interview"`.
#' @param assign For monitor and grid sources: `"mean"` of monitors within the
#'   radius, `"nearest"` monitor within the radius, or `"idw"`
#'   (inverse-distance weighted mean).
#' @param idw_power Distance exponent for `"idw"`.
#' @param fun For rasters: how to summarise cells in the buffer, `"mean"`,
#'   `"median"`, `"max"` or `"min"`.
#' @param min_coverage Minimum share (0 to 1) of window days that must have
#'   data. Default 0.75.
#' @param min_sources For monitor and grid sources: minimum number of
#'   monitors with data needed in a period. Default 1.
#' @param area Column in `data` naming each person's area, for area-level
#'   sources. If `NULL`, the source's `boundaries` are used.
#' @param urban Column in `data` flagging urban residence (for
#'   `radius_km = "dhs"`).
#' @param name Name of the exposure column in the output.
#' @param format `"long"` (one row per person, window and radius, with
#'   coverage and window dates) or `"wide"` (one row per person, one column
#'   per window and radius).
#'
#' @return A data frame of class `svy_exposure_result`. In long format:
#'   `id`, `window`, `radius_km`, the exposure column, `coverage`,
#'   `window_start` and `window_end`.
#' @examples
#' readings <- data.frame(
#'   monitor = rep(c("A", "B"), each = 400),
#'   lon = rep(c(-0.20, -0.18), each = 400), lat = 5.6,
#'   date = rep(as.Date("2019-01-01") + 0:399, 2),
#'   pm25 = c(rep(30, 400), rep(50, 400))
#' )
#' kids <- data.frame(id = 1:2, date = as.Date(c("2019-10-01", "2019-12-15")),
#'                    lon = -0.195, lat = 5.6)
#' src <- svy_exposure(readings, unit = "monitor", value = "pm25")
#' svy_expose(kids, src, windows = svy_windows("prenatal_postnatal"),
#'            radius_km = c(1, 5), name = "pm25")
#' @export
svy_expose <- function(data, exposure,
                       windows = svy_windows("prenatal_postnatal"),
                       radius_km = 5,
                       window_unit = c("days", "weeks", "months", "years"),
                       id = "id", date = "date", lon = "lon", lat = "lat",
                       date_is = c("anchor", "interview"), age_months = NULL,
                       assign = c("mean", "nearest", "idw"), idw_power = 2,
                       fun = c("mean", "median", "max", "min"),
                       min_coverage = 0.75, min_sources = 1,
                       area = NULL, urban = "urban",
                       name = "exposure", format = c("long", "wide")) {
  window_unit <- match.arg(window_unit)
  date_is <- match.arg(date_is)
  assign <- match.arg(assign)
  fun <- match.arg(fun)
  format <- match.arg(format)
  if (!inherits(exposure, "svy_exposure_source")) exposure <- svy_exposure(exposure)
  src <- exposure

  if (!is.data.frame(data)) cli::cli_abort("{.arg data} must be a data frame or an {.cls sf} object.")
  if (!is.numeric(min_coverage) || min_coverage < 0 || min_coverage > 1) {
    cli::cli_abort("{.arg min_coverage} must be between 0 and 1.")
  }
  wins <- normalise_windows(windows)

  # People ----------------------------------------------------------------
  if (inherits(data, "sf")) {
    xy <- sf::st_coordinates(sf::st_transform(data, 4326))
    lonv <- xy[, 1]
    latv <- xy[, 2]
    data <- sf::st_drop_geometry(data)
    check_columns(data, c(id, date), arg = "data")
  } else {
    need <- c(id, date, if (src$kind != "areas" || is.null(area)) c(lon, lat))
    check_columns(data, need, arg = "data")
    lonv <- if (lon %in% names(data)) as.numeric(data[[lon]]) else rep(NA_real_, nrow(data))
    latv <- if (lat %in% names(data)) as.numeric(data[[lat]]) else rep(NA_real_, nrow(data))
  }
  n <- nrow(data)

  d <- as_date_strict(data[[date]], date)
  if (date_is == "interview") {
    if (is.null(age_months)) {
      cli::cli_abort("{.arg age_months} is needed when {.code date_is = \"interview\"}.")
    }
    check_columns(data, age_months, arg = "data")
    anchor <- add_months(d, -round(as.numeric(data[[age_months]])))
  } else {
    anchor <- d
  }
  n_no_anchor <- sum(is.na(anchor))
  if (n_no_anchor > 0) cli::cli_inform("{n_no_anchor} record{?s} with a missing date get {.val NA}.")

  from <- lapply(wins, function(w) add_units(anchor, w[1], window_unit))
  to <- lapply(wins, function(w) add_units(anchor, w[2], window_unit))

  # Locations: people sharing coordinates (a DHS cluster) are processed once.
  has_xy <- !is.na(lonv) & !is.na(latv)
  if (src$kind != "areas" && !all(has_xy)) {
    cli::cli_inform("{sum(!has_xy)} record{?s} without coordinates get {.val NA}.")
  }
  key <- ifelse(has_xy, sprintf("%.6f_%.6f", lonv, latv), NA_character_)
  if (src$kind == "areas" && !is.null(area)) {
    check_columns(data, area, arg = "data")
    key <- paste0("area_", as.character(data[[area]]))
    key[is.na(data[[area]])] <- NA_character_
  }
  ukey <- unique(key[!is.na(key)])
  loc_idx <- match(key, ukey)
  first <- match(ukey, key)
  locs <- data.frame(loc_id = seq_along(ukey), lon = lonv[first], lat = latv[first])
  if (urban %in% names(data)) locs$urban <- as_urban(data[[urban]][first])
  area_of_loc <- if (!is.null(area)) as.character(data[[area]][first]) else NULL

  # Radii -----------------------------------------------------------------
  dhs <- identical(radius_km, "dhs")
  if (dhs) {
    if (!"urban" %in% names(locs)) {
      cli::cli_abort(c("{.code radius_km = \"dhs\"} needs an urban/rural column.",
                       "i" = "Add a column named {.field {urban}}, or set {.arg urban}."))
    }
    radii <- list(dhs = ifelse(locs$urban %in% TRUE, 2000, 5000))
  } else {
    if (!is.numeric(radius_km) || anyNA(radius_km) || any(radius_km <= 0)) {
      cli::cli_abort("{.arg radius_km} must be positive numbers (kilometres), or {.val dhs}.")
    }
    radii <- stats::setNames(as.list(radius_km * 1000), format(radius_km, trim = TRUE))
  }
  if (src$kind == "areas") radii <- list(`NA` = NA_real_)

  # Time span needed -----------------------------------------------------
  rng <- c(min(unlist(lapply(from, as.numeric)), na.rm = TRUE),
           max(unlist(lapply(to, as.numeric)), na.rm = TRUE))
  rng <- as.Date(rng, origin = "1970-01-01")
  if (isTRUE(src$static)) {
    per <- data.frame(start = as.Date("1900-01-01"), end = as.Date("2999-12-31"))
    per$days <- as.integer(per$end - per$start) + 1L
    keep <- 1L
  } else {
    keep <- which(src$periods$end >= rng[1] & src$periods$start <= rng[2])
    if (length(keep) == 0) {
      cli::cli_warn(c(
        "The exposure data do not overlap any exposure window.",
        "i" = "Windows span {format(rng[1])} to {format(rng[2])}; data span {format(min(src$periods$start))} to {format(max(src$periods$end))}."
      ))
    }
    per <- src$periods[keep, , drop = FALSE]
  }

  # Assign ----------------------------------------------------------------
  out <- vector("list", length(radii) * length(wins))
  k <- 0
  for (rn in names(radii)) {
    V <- if (length(keep) == 0 || nrow(locs) == 0) {
      matrix(NA_real_, nrow(locs), max(length(keep), 1))
    } else {
      switch(src$kind,
        raster = values_raster(src, locs, radii[[rn]], keep, fun, dhs),
        points = , grid = values_points(src, locs, radii[[rn]], keep, assign,
                                       idw_power, min_sources),
        areas = values_areas(src, locs, keep, area_of_loc)
      )
    }
    if (length(keep) == 0) per <- data.frame(start = as.Date("1900-01-01"),
                                              end = as.Date("1900-01-01"), days = 1L)
    res <- window_mean(V, per, loc_idx, from, to)
    for (w in seq_along(wins)) {
      k <- k + 1
      value <- res[[w]]$value
      cov <- res[[w]]$coverage
      value[is.na(cov) | cov < min_coverage] <- NA_real_
      out[[k]] <- data.frame(
        id = data[[id]], window = names(wins)[w], radius_km = rn,
        value = value, coverage = cov,
        window_start = from[[w]], window_end = to[[w]],
        stringsAsFactors = FALSE
      )
    }
  }
  long <- do.call(rbind, out)
  names(long)[1] <- id
  names(long)[names(long) == "value"] <- name
  rownames(long) <- NULL

  empty <- stats::aggregate(long[[name]], list(window = long$window, radius_km = long$radius_km),
                            function(z) all(is.na(z)))
  empty <- empty[empty$x, ]
  if (nrow(empty) > 0) {
    cli::cli_warn(c(
      "{nrow(empty)} window/radius combination{?s} have no exposure values at all.",
      "i" = "Check that the exposure data cover the window dates and the people's locations, or lower {.arg min_coverage}."
    ))
  }

  meta <- list(windows = wins, window_unit = window_unit, radii = names(radii),
               min_coverage = min_coverage, kind = src$kind, step = src$step,
               name = name, id = id, assign = if (src$kind %in% c("points", "grid")) assign)
  if (format == "wide") {
    return(to_wide(long, meta))
  }
  structure(long, class = c("svy_exposure_result", "data.frame"), svy = meta)
}

# Spatial step: one row per location, one column per period -------------------

values_raster <- function(src, locs, radius_m, keep, fun, dhs) {
  pts <- sf::st_as_sf(locs, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
  pts$id <- locs$loc_id
  buffers <- if (dhs) svy_buffers(pts) else svy_buffers(pts, radius = radius_m)

  if (isTRUE(src$static)) {
    if (terra::nlyr(src$raster) != 1) {
      cli::cli_abort("A static raster must have exactly one layer.")
    }
    ex <- svy_extract(buffers, src$raster, fun = fun, id_col = "id", prefix = ".v")
    return(matrix(ex[[2]], ncol = 1))
  }
  layers <- which(src$layer_period %in% keep)
  V <- matrix(NA_real_, nrow(locs), length(keep))
  # Read layers in batches so memory stays bounded for long daily series.
  batches <- split(layers, ceiling(seq_along(layers) / 366))
  for (b in batches) {
    ex <- svy_extract(buffers, src$raster, fun = fun, layers = b, id_col = "id",
                      prefix = ".v")
    V[, match(src$layer_period[b], keep)] <- as.matrix(ex[, -1, drop = FALSE])
  }
  V
}

# Great-circle distance in metres between two sets of lon/lat points.
haversine_matrix <- function(lon1, lat1, lon2, lat2) {
  rad <- pi / 180
  p1 <- lat1 * rad
  p2 <- lat2 * rad
  dlat <- outer(p1, p2, "-")
  dlon <- outer(lon1 * rad, lon2 * rad, "-")
  a <- sin(dlat / 2)^2 + outer(cos(p1), cos(p2)) * sin(dlon / 2)^2
  2 * 6371008.8 * asin(pmin(sqrt(a), 1))
}

values_points <- function(src, locs, radius_m, keep, assign, power, min_sources) {
  X <- src$X[, keep, drop = FALSE]
  ind <- !is.na(X)
  X0 <- X
  X0[!ind] <- 0
  indn <- ind * 1
  mon <- src$unit_sf
  rad <- rep_len(radius_m, nrow(locs))

  V <- matrix(NA_real_, nrow(locs), ncol(X))
  chunks <- split(seq_len(nrow(locs)), ceiling(seq_len(nrow(locs)) / 500))
  for (ch in chunks) {
    D <- haversine_matrix(locs$lon[ch], locs$lat[ch], mon$lon, mon$lat)
    inside <- D <= rad[ch]
    W <- switch(assign,
      mean = inside * 1,
      idw = inside / pmax(D, 1)^power,
      nearest = {
        W <- matrix(0, nrow(D), ncol(D))
        j <- max.col(-D, ties.method = "first")
        i <- seq_along(j)
        ok <- D[cbind(i, j)] <= rad[ch]
        W[cbind(i[ok], j[ok])] <- 1
        W
      }
    )
    Ws <- Matrix::Matrix(W, sparse = TRUE)
    Cs <- Matrix::Matrix((W > 0) * 1, sparse = TRUE)
    num <- as.matrix(Ws %*% X0)
    den <- as.matrix(Ws %*% indn)
    cnt <- as.matrix(Cs %*% indn)
    v <- num / den
    v[cnt < min_sources | den == 0] <- NA_real_
    V[ch, ] <- v
  }
  V
}

values_areas <- function(src, locs, keep, area_of_loc) {
  if (!is.null(area_of_loc)) {
    row <- match(area_of_loc, src$units)
  } else if (!is.null(src$boundaries)) {
    pts <- sf::st_as_sf(locs, coords = c("lon", "lat"), crs = 4326)
    hits <- sf::st_intersects(pts, src$boundaries)
    idx <- vapply(hits, function(h) if (length(h)) h[1] else NA_integer_, integer(1))
    row <- match(as.character(src$boundaries[[src$boundary_id]][idx]), src$units)
  } else {
    cli::cli_abort(c(
      "Area-level exposure needs to know each person's area.",
      "i" = "Pass {.arg area} (a column in {.arg data}), or give {.fn svy_exposure} {.arg boundaries} and {.arg boundary_id}."
    ))
  }
  if (anyNA(row)) {
    cli::cli_warn("{sum(is.na(row))} location{?s} could not be matched to an exposure area and get {.val NA}.")
  }
  src$X[row, keep, drop = FALSE]
}

# Accept TRUE/FALSE, DHS codes (1 urban, 2 rural) or "urban"/"rural".
as_urban <- function(x) {
  if (is.logical(x)) return(x)
  if (is.numeric(x)) return(ifelse(is.na(x), NA, x == 1))
  x <- tolower(trimws(as.character(x)))
  ifelse(x %in% c("urban", "u", "1", "true"), TRUE,
         ifelse(x %in% c("rural", "r", "2", "false"), FALSE, NA))
}

to_wide <- function(long, meta) {
  idc <- meta$id
  if (anyDuplicated(long[long$window == long$window[1] & long$radius_km == long$radius_km[1], idc])) {
    cli::cli_abort(c("{.code format = \"wide\"} needs one row per person.",
                     "i" = "Identifiers in {.field {idc}} are not unique; use the long format."))
  }
  first <- long[long$window == long$window[1] & long$radius_km == long$radius_km[1], idc, drop = FALSE]
  out <- first
  for (r in meta$radii) {
    for (w in names(meta$windows)) {
      sub <- long[long$window == w & long$radius_km == r, ]
      lab <- if (r %in% c("dhs", "NA")) r else paste0(r, "km")
      colname <- if (r == "NA") paste(meta$name, w, sep = "_") else paste(meta$name, w, lab, sep = "_")
      out[[colname]] <- sub[[meta$name]]
    }
  }
  rownames(out) <- NULL
  out
}

#' @export
print.svy_exposure_result <- function(x, ...) {
  m <- attr(x, "svy")
  if (is.null(m)) {
    # Attributes are lost when a result is subset or re-printed by other tools.
    return(print(unclass_df(x), ...))
  }
  idc <- m$id
  n <- length(unique(x[[idc]]))
  cli::cli_text("{.cls svy_exposure_result}: {n} record{?s}, {length(m$windows)} window{?s}, {length(m$radii)} radius setting{?s}; source: {m$kind}")
  s <- do.call(rbind, lapply(split(x, list(x$window, x$radius_km), drop = TRUE), function(z) {
    data.frame(window = z$window[1], radius_km = z$radius_km[1],
               n = nrow(z), with_value = round(100 * mean(!is.na(z[[m$name]])), 1),
               median_coverage = round(stats::median(z$coverage, na.rm = TRUE), 2))
  }))
  rownames(s) <- NULL
  names(s)[4] <- "pct_with_value"
  print(s, row.names = FALSE)
  cat("\n")
  print(utils::head(as.data.frame(unclass_df(x)), 6), row.names = FALSE)
  if (nrow(x) > 6) cat("# ... with", nrow(x) - 6, "more rows\n")
  invisible(x)
}

unclass_df <- function(x) {
  class(x) <- "data.frame"
  attr(x, "svy") <- NULL
  x
}
