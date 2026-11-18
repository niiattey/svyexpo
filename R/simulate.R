#' Simulate a small survey, boundary set and exposure raster
#'
#' Generates synthetic data with the same structure as a geocoded household
#' survey so the full workflow can be demonstrated and tested without
#' restricted data. Areas form a regular grid; clusters are displaced like
#' DHS clusters (up to 2 km urban, 5 km rural); the binary outcome depends on
#' the year-matched exposure at the true location and on a smooth spatial
#' area effect.
#'
#' @param n_side Number of areas along each side of the grid.
#' @param clusters_per_area Survey clusters per area.
#' @param records_per_cluster Records (e.g. children) per cluster.
#' @param years Survey years; each cluster is interviewed in one of them.
#'   The raster has one layer per year.
#' @param beta Log-odds change per standard deviation of exposure.
#' @param seed Random seed, or `NULL` to use the current RNG state. The
#'   global RNG state is restored on exit.
#'
#' @return A list with
#'   * `survey`: data frame with `id`, `cluster`, `lon`, `lat` (displaced),
#'     `date`, `weight`, `strata`, `urban`, `age_months` and binary `y`
#'   * `boundaries`: `sf` polygons with `area_id` and `area_name`
#'   * `raster`: `SpatRaster` with one exposure layer per year
#' @export
#' @examples
#' sim <- svy_simulate(n_side = 4, clusters_per_area = 3)
#' head(sim$survey)
svy_simulate <- function(n_side = 6, clusters_per_area = 5,
                         records_per_cluster = 20, years = 2014:2016,
                         beta = 0.4, seed = 1) {
  if (!is.null(seed)) {
    # Set the seed without permanently changing the user's RNG state.
    old_seed <- if (exists(".Random.seed", envir = globalenv())) {
      get(".Random.seed", envir = globalenv())
    }
    on.exit({
      if (is.null(old_seed)) {
        rm(".Random.seed", envir = globalenv())
      } else {
        assign(".Random.seed", old_seed, envir = globalenv())
      }
    }, add = TRUE)
    set.seed(seed)
  }
  xmin <- -2; xmax <- 0; ymin <- 6; ymax <- 8

  # Areas: regular grid of n_side x n_side cells.
  bbox <- sf::st_bbox(c(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
                      crs = sf::st_crs(4326))
  grid <- sf::st_make_grid(sf::st_as_sfc(bbox), n = c(n_side, n_side))
  n_area <- length(grid)
  boundaries <- sf::st_sf(
    area_id = sprintf("A%02d", seq_len(n_area)),
    area_name = paste("Area", seq_len(n_area)),
    geometry = grid
  )

  # Exposure surface: smooth spatial gradient plus a yearly shift.
  r <- terra::rast(xmin = xmin - 0.5, xmax = xmax + 0.5,
                   ymin = ymin - 0.5, ymax = ymax + 0.5,
                   resolution = 0.01, crs = "EPSG:4326")
  xy <- terra::crds(r, na.rm = FALSE)
  layers <- lapply(seq_along(years), function(k) {
    v <- 35 + 8 * sin(2 * xy[, 1]) + 6 * cos(3 * xy[, 2]) + 2 * (k - 1)
    terra::setValues(r, v)
  })
  raster <- terra::rast(layers)
  names(raster) <- paste0("exposure_", years)
  terra::time(raster, tstep = "years") <- years

  # Smooth area effect from area centroids.
  cen <- sf::st_coordinates(suppressWarnings(sf::st_centroid(boundaries)))
  area_eff <- 0.6 * sin(3 * cen[, 1]) + 0.4 * cos(2 * cen[, 2]) +
    stats::rnorm(n_area, 0, 0.15)
  area_eff <- area_eff - mean(area_eff)

  # Clusters: uniform within each grid cell.
  cell_bb <- lapply(grid, sf::st_bbox)
  n_clus <- n_area * clusters_per_area
  area_of <- rep(seq_len(n_area), each = clusters_per_area)
  true_lon <- vapply(area_of, function(a) stats::runif(1, cell_bb[[a]]$xmin, cell_bb[[a]]$xmax), numeric(1))
  true_lat <- vapply(area_of, function(a) stats::runif(1, cell_bb[[a]]$ymin, cell_bb[[a]]$ymax), numeric(1))
  urban <- stats::runif(n_clus) < 0.35
  year <- sample(years, n_clus, replace = TRUE)
  date <- as.Date(sprintf("%d-%02d-15", year, sample(1:12, n_clus, replace = TRUE)))

  # DHS-style displacement: random direction, up to 2 km (urban) / 5 km (rural).
  max_km <- ifelse(urban, 2, 5)
  d_km <- stats::runif(n_clus, 0, max_km)
  ang <- stats::runif(n_clus, 0, 2 * pi)
  lat <- true_lat + (d_km / 111.32) * sin(ang)
  lon <- true_lon + (d_km / (111.32 * cos(true_lat * pi / 180))) * cos(ang)

  # Exposure at the true location in the interview year.
  expo <- vapply(seq_len(n_clus), function(i) {
    layer <- match(year[i], years)
    terra::extract(raster[[layer]], cbind(true_lon[i], true_lat[i]))[[1]]
  }, numeric(1))
  expo_z <- (expo - mean(expo)) / stats::sd(expo)

  # Records within clusters.
  clus <- rep(seq_len(n_clus), each = records_per_cluster)
  age <- round(stats::runif(length(clus), 0, 59))
  eta <- -1 + beta * expo_z[clus] + area_eff[area_of[clus]] + 0.01 * (age - 30)
  y <- stats::rbinom(length(clus), 1, stats::plogis(eta))

  survey <- data.frame(
    id = sprintf("C%03d_%02d", clus, stats::ave(clus, clus, FUN = seq_along)),
    cluster = clus,
    lon = lon[clus],
    lat = lat[clus],
    date = date[clus],
    weight = 1,
    strata = boundaries$area_id[area_of[clus]],
    urban = urban[clus],
    age_months = age,
    y = y,
    stringsAsFactors = FALSE
  )

  list(survey = survey, boundaries = boundaries, raster = raster)
}
