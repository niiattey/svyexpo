# Module 2: Boundaries --------------------------------------------------------

#' Download administrative boundaries from GADM
#'
#' A thin wrapper around [geodata::gadm()] that returns an `sf` object with
#' two standard columns, `area_id` and `area_name`, and repairs invalid
#' geometries. Downloads are cached in `path` (see the `svyexpo.cache_dir`
#' option in [svyexpo-package]) so each country is downloaded once.
#'
#' @param country One or more ISO3 country codes, e.g. `c("GHA", "UGA")`.
#' @param level Administrative level (0 = country, 1 = region, 2 = district).
#' @param path Download directory. Defaults to the package cache directory.
#' @param resolution `1` for full resolution, `2` for simplified polygons
#'   (smaller files, faster plotting).
#'
#' @return An `sf` polygon object with columns `area_id`, `area_name`,
#'   `country` and the original GADM attributes.
#' @export
#' @examples
#' \dontrun{
#' gha <- svy_boundaries("GHA", level = 2)
#' }
svy_boundaries <- function(country, level = 1, path = NULL, resolution = 1) {
  path <- cache_dir(path)
  pieces <- lapply(country, function(iso) {
    v <- geodata::gadm(iso, level = level, path = path, resolution = resolution)
    if (is.null(v)) {
      cli::cli_abort("GADM download failed for {.val {iso}}.")
    }
    sf::st_as_sf(v)
  })
  out <- do.call(rbind, pieces)

  id_col <- paste0("GID_", level)
  name_col <- if (level == 0) "COUNTRY" else paste0("NAME_", level)
  out$area_id <- out[[id_col]]
  out$area_name <- out[[name_col]]
  out$country <- out$GID_0

  out <- sf::st_make_valid(out)
  out[, c("area_id", "area_name", "country",
          setdiff(names(out), c("area_id", "area_name", "country")))]
}

#' Assign survey clusters to administrative areas
#'
#' Points are matched to the polygon that contains them. Points that fall
#' outside every polygon (common for coastal clusters after DHS displacement
#' or with simplified boundaries) are assigned to the nearest polygon if it
#' lies within `max_dist` metres; otherwise they receive `NA`.
#'
#' @param points An `sf` POINT object, usually from [svy_standardize()].
#' @param boundaries An `sf` polygon object, usually from [svy_boundaries()].
#' @param area_col Name of the area identifier column in `boundaries`.
#' @param max_dist Maximum distance in metres for nearest-polygon matching.
#'
#' @return `points` with `area_col` added and a column `area_match` that is
#'   `"within"`, `"nearest"` or `"none"`.
#' @export
svy_assign_areas <- function(points, boundaries, area_col = "area_id",
                             max_dist = 10000) {
  check_class(points, "sf")
  check_class(boundaries, "sf")
  check_columns(boundaries, area_col, arg = "boundaries")
  if (area_col %in% names(points)) {
    cli::cli_abort("{.arg points} already has a column {.val {area_col}}.")
  }
  boundaries <- sf::st_transform(boundaries, sf::st_crs(points))

  hits <- sf::st_intersects(points, boundaries)
  # A point on a shared border can touch two polygons; keep the first.
  idx <- vapply(hits, function(h) if (length(h)) h[1] else NA_integer_,
                integer(1))
  match_type <- ifelse(is.na(idx), "none", "within")

  outside <- which(is.na(idx))
  if (length(outside) > 0) {
    nearest <- sf::st_nearest_feature(points[outside, ], boundaries)
    dist <- as.numeric(sf::st_distance(points[outside, ], boundaries[nearest, ],
                                       by_element = TRUE))
    close <- dist <= max_dist
    idx[outside[close]] <- nearest[close]
    match_type[outside[close]] <- "nearest"
  }

  points[[area_col]] <- boundaries[[area_col]][idx]
  points$area_match <- match_type

  n_near <- sum(match_type == "nearest")
  n_none <- sum(match_type == "none")
  if (n_near > 0) {
    cli::cli_inform("{n_near} point{?s} outside all polygons assigned to the nearest area.")
  }
  if (n_none > 0) {
    cli::cli_warn("{n_none} point{?s} more than {max_dist} m from any area; set to NA.")
  }
  points
}
