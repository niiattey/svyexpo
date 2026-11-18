# Small simulated dataset shared across tests.
sim_small <- function() svy_simulate(n_side = 3, clusters_per_area = 2,
                                     records_per_cluster = 3, seed = 42)

# TRUE only if a small svyexpo model actually fits here. Some environments
# (notably R CMD check on Linux and macOS runners) have INLA installed but its
# binary fails on graph models, so a trivial probe model is not enough.
# Set SVYEXPO_REQUIRE_INLA=true to turn a skip into a failure (used by the
# dedicated model-test job in CI).
inla_works <- function() {
  if (!requireNamespace("INLA", quietly = TRUE) ||
      !requireNamespace("sn", quietly = TRUE)) {
    return(FALSE)
  }
  tryCatch({
    sim <- svy_simulate(n_side = 3, clusters_per_area = 2,
                        records_per_cluster = 5, seed = 7)
    dat <- sim$survey
    dat$area_id <- sim$boundaries$area_id[
      sf::st_nearest_feature(
        sf::st_as_sf(dat, coords = c("lon", "lat"), crs = 4326),
        sim$boundaries
      )
    ]
    suppressMessages(suppressWarnings(
      svy_fit_bym2(dat, y ~ age_months, svy_adjacency(sim$boundaries),
                   num.threads = "1:1", silent = 2L)
    ))
    TRUE
  }, error = function(e) FALSE)
}

skip_if_no_inla <- function() {
  ok <- inla_works()
  if (!ok && identical(Sys.getenv("SVYEXPO_REQUIRE_INLA"), "true")) {
    testthat::fail("INLA is required here (SVYEXPO_REQUIRE_INLA=true) but cannot fit a model.")
  }
  testthat::skip_if_not(ok, "INLA is not available or cannot fit a model here")
}
