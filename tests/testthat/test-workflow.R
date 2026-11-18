test_that("simulated data has the expected structure", {
  sim <- sim_small()
  expect_equal(nrow(sim$survey), 9 * 2 * 3)
  expect_equal(nrow(sim$boundaries), 9)
  expect_equal(terra::nlyr(sim$raster), 3)
  expect_true(all(sim$survey$y %in% 0:1))
})

test_that("simulation does not change the global RNG state", {
  set.seed(99)
  before <- .Random.seed
  sim_small()
  expect_identical(.Random.seed, before)
})

test_that("modules 1-4 chain together on simulated data", {
  sim <- sim_small()
  pts <- svy_standardize(sim$survey, id = "id", cluster = "cluster",
                         lon = "lon", lat = "lat", date = "date",
                         weight = "weight", strata = "strata", urban = "urban")
  pts <- suppressMessages(svy_assign_areas(pts, sim$boundaries))
  expo <- svy_extract_by_year(svy_buffers(pts), sim$raster, name = "pm25")
  dat <- merge(sf::st_drop_geometry(pts), expo, by = "id")
  graph <- svy_adjacency(sim$boundaries)

  expect_equal(nrow(dat), nrow(sim$survey))
  expect_false(anyNA(dat$pm25))
  expect_true(all(dat$area_id %in% graph$index$area_id))
})

test_that("BYM2 model fits and returns area and SVC summaries", {
  skip_if_no_inla()
  sim <- svy_simulate(n_side = 4, clusters_per_area = 4, records_per_cluster = 10)
  pts <- svy_standardize(sim$survey, "id", "cluster", "lon", "lat",
                         date = "date", urban = "urban")
  pts <- suppressMessages(svy_assign_areas(pts, sim$boundaries))
  expo <- svy_extract_by_year(svy_buffers(pts), sim$raster, name = "pm25")
  dat <- merge(sf::st_drop_geometry(pts), expo, by = "id")
  dat$pm25_z <- as.numeric(scale(dat$pm25))
  graph <- svy_adjacency(sim$boundaries)

  fit <- svy_fit_bym2(dat, y ~ pm25_z + urban, graph, svc = "pm25_z",
                      num.threads = "1:1")
  expect_s3_class(fit, "svy_fit")

  ae <- svy_area_effects(fit)
  expect_equal(nrow(ae), 16)
  expect_true(all(ae$prob_exceed >= 0 & ae$prob_exceed <= 1))

  sv <- svy_svc_effects(fit, "pm25_z", n_samples = 50)
  expect_equal(nrow(sv), 16)

  dg <- svy_diagnostics(fit)
  expect_true(all(c("dic", "waic", "log_score") %in% names(dg)))
})
