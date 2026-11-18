#' svyexpo: survey exposure linkage and Bayesian spatial modelling
#'
#' The package is organised as six modules. Each module takes and returns
#' ordinary R objects (data frames, `sf` objects, `SpatRaster`s), so any step
#' can be used on its own or swapped for your own code.
#'
#' 1. **Ingest** -- [svy_standardize()], [svy_from_dhs()]: map survey records
#'    onto a common schema and attach cluster coordinates.
#' 2. **Boundaries** -- [svy_boundaries()], [svy_assign_areas()]: download and
#'    cache GADM polygons and assign clusters to administrative areas.
#' 3. **Exposure linkage** -- [svy_buffers()], [svy_extract()],
#'    [svy_extract_by_year()]: extract raster values within
#'    displacement-aware buffers, reading only the pixels that are needed.
#' 4. **Spatial structure** -- [svy_adjacency()]: build the neighbourhood
#'    graph, repair islands and index areas for INLA.
#' 5. **Models** -- [svy_fit_bym2()]: BYM2 models with optional spatially
#'    varying coefficients.
#' 6. **Outputs** -- [svy_area_effects()], [svy_svc_effects()],
#'    [svy_diagnostics()], [svy_map()]: posterior summaries, exceedance
#'    probabilities, model diagnostics and maps.
#'
#' [svy_simulate()] generates a small synthetic survey, boundary set and
#' exposure raster so that every step can be run without restricted data.
#'
#' @section Package options:
#' * `svyexpo.cache_dir`: directory used to cache GADM downloads. Defaults to
#'   a session temporary directory; set it to a permanent folder to avoid
#'   repeated downloads, e.g.
#'   `options(svyexpo.cache_dir = tools::R_user_dir("svyexpo", "cache"))`.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom stats as.formula quantile setNames
#' @importFrom utils head
## usethis namespace: end
NULL
