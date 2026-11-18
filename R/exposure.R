# Module 3: Exposure linkage --------------------------------------------------
#
# Memory strategy
# ---------------
# Rasters are never read in full. `terra::rast()` only opens the file header,
# and `exactextractr` reads the cells under each buffer block by block. When
# the area covered by all buffers is small enough (`max_cells_in_memory`),
# the raster is first cropped to that window so the pixels are read once,
# which is much faster for remote Cloud-Optimized GeoTIFFs ("/vsicurl/...").
# Extracted tables can be cached to disk (`cache_file`) so a raster is only
# touched once per analysis.

#' Create displacement-aware buffers around survey clusters
#'
#' DHS displaces urban clusters by up to 2 km and rural clusters by up to
#' 5 km (1% of rural clusters by up to 10 km). Buffers of matching size
#' ensure the true location falls inside the extraction area. Buffers are
#' built in the local UTM zone of each point so distances are exact in
#' metres, then returned in WGS84.
#'
#' @param points An `sf` POINT object from [svy_standardize()].
#' @param urban_m,rural_m Buffer radius in metres for urban and rural
#'   clusters. Requires an `urban` column. Rural radius is used where `urban`
#'   is `NA`.
#' @param radius A single radius in metres for all points. Overrides
#'   `urban_m`/`rural_m`; use it for surveys without urban/rural status or
#'   for sensitivity analyses.
#'
#' @return An `sf` polygon object with the attributes of `points` and a
#'   `buffer_m` column.
#' @export
svy_buffers <- function(points, urban_m = 2000, rural_m = 5000, radius = NULL) {
  check_class(points, "sf")

  if (!is.null(radius)) {
    dist <- rep(radius, nrow(points))
  } else {
    if (!"urban" %in% names(points)) {
      cli::cli_abort(c(
        "{.arg points} has no {.field urban} column.",
        "i" = "Supply {.arg radius} to use one buffer size for all points."
      ))
    }
    if (anyNA(points$urban)) {
      cli::cli_inform("{sum(is.na(points$urban))} point{?s} with unknown urban status use the rural radius.")
    }
    dist <- ifelse(points$urban %in% TRUE, urban_m, rural_m)
  }
  points$buffer_m <- dist

  wgs <- sf::st_transform(points, 4326)
  xy <- sf::st_coordinates(wgs)
  zone <- floor((xy[, "X"] + 180) / 6) + 1
  epsg <- ifelse(xy[, "Y"] >= 0, 32600 + zone, 32700 + zone)

  # Buffer each UTM zone group in its own projection, then restore order.
  out <- lapply(split(seq_len(nrow(wgs)), epsg), function(i) {
    code <- epsg[i[1]]
    g <- sf::st_transform(wgs[i, ], code)
    g <- sf::st_buffer(g, dist = g$buffer_m, nQuadSegs = 30)
    g$.row <- i
    sf::st_transform(g, 4326)
  })
  out <- do.call(rbind, out)
  out <- out[order(out$.row), ]
  out$.row <- NULL
  rownames(out) <- NULL
  out
}

#' Extract raster values within buffers
#'
#' Computes a coverage-weighted summary of raster cells within each polygon
#' using [exactextractr::exact_extract()]. Cells partly inside a buffer count
#' in proportion to the area covered, and `NA` cells are ignored.
#'
#' @param buffers An `sf` polygon object, usually from [svy_buffers()].
#' @param raster A `SpatRaster`, a file path, or a GDAL virtual path such as
#'   `"/vsicurl/https://.../pm25_2019.tif"` for Cloud-Optimized GeoTIFFs.
#' @param fun Summary function name passed to `exact_extract()`, e.g.
#'   `"mean"`, `"median"`, `"max"`, `"sum"`.
#' @param layers Optional layer indices or names to extract. Default: all.
#' @param id_col Identifier column in `buffers` to carry into the output.
#' @param prefix Prefix for output columns. Defaults to `fun`. A single-layer
#'   result is named `prefix`; multi-layer results are `prefix_<layer>`.
#' @param max_cells_in_memory Upper limit on raster cells held in memory.
#'   Lower it on machines with little RAM.
#' @param cache_file Optional `.rds` or `.parquet` path. If the file exists it
#'   is returned without touching the raster; otherwise the result is written
#'   there.
#'
#' @return A data frame with `id_col` and one column per layer.
#' @export
svy_extract <- function(buffers, raster, fun = "mean", layers = NULL,
                        id_col = "id", prefix = NULL,
                        max_cells_in_memory = 3e7, cache_file = NULL) {
  if (!is.null(cache_file) && file.exists(cache_file)) {
    cli::cli_inform("Reading cached extraction from {.file {cache_file}}.")
    return(cache_read(cache_file))
  }
  check_class(buffers, "sf")
  check_columns(buffers, id_col, arg = "buffers")
  if (length(fun) != 1) {
    cli::cli_abort("{.arg fun} must be a single summary function name.")
  }

  r <- as_spatraster(raster)
  if (!is.null(layers)) r <- r[[layers]]
  if (is.na(terra::crs(r)) || terra::crs(r) == "") {
    cli::cli_abort("The raster has no coordinate reference system.")
  }
  buffers <- sf::st_transform(buffers, terra::crs(r))

  r <- crop_if_small(r, buffers, max_cells_in_memory)

  vals <- exactextractr::exact_extract(
    r, buffers,
    fun = fun,
    max_cells_in_memory = max_cells_in_memory,
    progress = FALSE,
    force_df = TRUE
  )

  prefix <- prefix %||% fun
  names(vals) <- if (terra::nlyr(r) == 1) {
    prefix
  } else {
    paste(prefix, make.names(names(r)), sep = "_")
  }

  out <- data.frame(buffers[[id_col]], vals, check.names = FALSE)
  names(out)[1] <- id_col

  if (!is.null(cache_file)) cache_write(out, cache_file)
  out
}

#' Extract exposures matched to each record's survey year
#'
#' For a multi-year raster stack (one layer per year), extracts the layer
#' that matches each record's interview year, optionally lagged and averaged
#' over several years. Only the layers that are needed are read.
#'
#' @inheritParams svy_extract
#' @param date_col Name of the `Date` column used for matching.
#' @param lag_years Years to lag the exposure. `1` uses the year before
#'   interview.
#' @param window_years Number of consecutive years to average, ending at the
#'   lagged year. `3` with `lag_years = 0` averages the interview year and
#'   the two years before it. Records with any missing year get `NA`.
#' @param layer_years Integer vector giving the year of each raster layer.
#'   If `NULL`, years are taken from `terra::time()` or, failing that, from
#'   four-digit years in the layer names (e.g. `"pm25_2016"`).
#' @param name Name of the output exposure column.
#'
#' @return A data frame with `id_col`, `exposure_year` (the last year of the
#'   window) and the exposure column.
#' @export
svy_extract_by_year <- function(buffers, raster, date_col = "date",
                                lag_years = 0, window_years = 1,
                                layer_years = NULL, fun = "mean",
                                id_col = "id", name = "exposure",
                                max_cells_in_memory = 3e7) {
  check_class(buffers, "sf")
  check_columns(buffers, c(id_col, date_col), arg = "buffers")

  r <- as_spatraster(raster)
  yrs <- layer_years %||% layer_years_from(r)
  if (length(yrs) != terra::nlyr(r)) {
    cli::cli_abort("{.arg layer_years} must have one value per raster layer ({terra::nlyr(r)}).")
  }

  target <- as.integer(format(buffers[[date_col]], "%Y")) - as.integer(lag_years)
  value <- rep(NA_real_, nrow(buffers))
  unavailable <- integer(0)

  for (y in sort(unique(stats::na.omit(target)))) {
    needed <- seq(y - window_years + 1, y)
    if (!all(needed %in% yrs)) {
      unavailable <- c(unavailable, y)
      next
    }
    sel <- which(target == y)
    ex <- svy_extract(
      buffers[sel, ], r, fun = fun, layers = match(needed, yrs),
      id_col = id_col, prefix = ".v",
      max_cells_in_memory = max_cells_in_memory
    )
    value[sel] <- rowMeans(as.matrix(ex[, -1, drop = FALSE]))
  }

  if (length(unavailable) > 0) {
    cli::cli_warn(c(
      "No raster layer(s) for target year{?s} {.val {unavailable}}; exposure set to NA.",
      "i" = "Raster years available: {.val {range(yrs)}}."
    ))
  }

  out <- data.frame(buffers[[id_col]], target, value)
  names(out) <- c(id_col, "exposure_year", name)
  out
}

# Crop to the buffers' extent when that window fits in memory; otherwise
# leave the raster on disk and let exactextractr read it block by block.
crop_if_small <- function(r, buffers, max_cells) {
  bb <- sf::st_bbox(buffers)
  e <- terra::ext(bb[["xmin"]], bb[["xmax"]], bb[["ymin"]], bb[["ymax"]])
  e <- terra::intersect(e, terra::ext(r))
  if (is.null(e)) {
    cli::cli_warn("The buffers do not overlap the raster; all values will be NA.")
    return(r)
  }
  window_cells <- ((e$xmax - e$xmin) / terra::xres(r) + 2) *
    ((e$ymax - e$ymin) / terra::yres(r) + 2) * terra::nlyr(r)
  if (window_cells <= max_cells) {
    r <- terra::crop(r, e, snap = "out")
  }
  r
}

# Infer the year of each layer from time metadata or layer names.
layer_years_from <- function(r) {
  tm <- terra::time(r)
  if (!all(is.na(tm))) {
    if (inherits(tm, c("Date", "POSIXt"))) {
      return(as.integer(format(tm, "%Y")))
    }
    return(as.integer(tm))
  }
  m <- regmatches(names(r), regexpr("(19|20)[0-9]{2}", names(r)))
  if (length(m) == terra::nlyr(r)) {
    return(as.integer(m))
  }
  cli::cli_abort(c(
    "Could not determine the year of each raster layer.",
    "i" = "Set {.code terra::time(r, tstep = \"years\") <- years}, name layers with a year, or pass {.arg layer_years}."
  ))
}
