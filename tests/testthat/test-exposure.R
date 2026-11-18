test_that("buffers use urban/rural radii in metres", {
  pts <- svy_standardize(
    data.frame(id = 1:2, cl = 1:2, x = c(-1, -0.5), y = c(6, 7), u = c(TRUE, FALSE)),
    "id", "cl", "x", "y", urban = "u"
  )
  b <- svy_buffers(pts)
  expect_equal(b$buffer_m, c(2000, 5000))
  area <- as.numeric(sf::st_area(b))
  expect_equal(area, pi * c(2000, 5000)^2, tolerance = 0.01)
  expect_equal(b$id, pts$id)
})

test_that("a single radius overrides urban status", {
  pts <- svy_standardize(data.frame(id = 1, cl = 1, x = -1, y = 6),
                         "id", "cl", "x", "y")
  expect_error(svy_buffers(pts), "no .*urban")
  expect_equal(svy_buffers(pts, radius = 1000)$buffer_m, 1000)
})

test_that("buffers spanning UTM zones keep their order", {
  pts <- svy_standardize(
    data.frame(id = c("w", "e", "s"), cl = 1:3, x = c(-1, 1, 30), y = c(6, 6, -1)),
    "id", "cl", "x", "y"
  )
  b <- svy_buffers(pts, radius = 3000)
  expect_equal(b$id, c("w", "e", "s"))
  cen <- sf::st_coordinates(suppressWarnings(sf::st_centroid(b)))
  expect_equal(unname(cen[, "X"]), c(-1, 1, 30), tolerance = 1e-3)
})

# exactextractr stores coverage fractions in single precision, so summaries of
# a constant raster can differ from the constant by about 1e-5.
test_that("svy_extract returns one row per buffer with coverage-weighted means", {
  r <- terra::rast(xmin = -2, xmax = 0, ymin = 5, ymax = 7, resolution = 0.01,
                   crs = "EPSG:4326", vals = 10)
  pts <- svy_standardize(data.frame(id = 1:3, cl = 1:3, x = c(-1, -1.5, 5),
                                    y = c(6, 6.5, 6)), "id", "cl", "x", "y")
  b <- svy_buffers(pts, radius = 2000)
  out <- svy_extract(b, r)
  expect_equal(names(out), c("id", "mean"))
  expect_equal(out$mean[1:2], c(10, 10), tolerance = 1e-4)
  expect_true(is.na(out$mean[3])) # outside the raster
})

test_that("svy_extract works from a file path and caches results", {
  r <- terra::rast(xmin = -2, xmax = 0, ymin = 5, ymax = 7, resolution = 0.05,
                   crs = "EPSG:4326", vals = 3)
  tif <- tempfile(fileext = ".tif")
  terra::writeRaster(r, tif)
  pts <- svy_standardize(data.frame(id = 1, cl = 1, x = -1, y = 6),
                         "id", "cl", "x", "y")
  b <- svy_buffers(pts, radius = 5000)
  cache <- tempfile(fileext = ".rds")
  first <- svy_extract(b, tif, cache_file = cache)
  expect_true(file.exists(cache))
  expect_message(second <- svy_extract(b, tif, cache_file = cache), "cached")
  expect_equal(first, second)
})

test_that("large windows skip cropping and still extract correctly", {
  r <- terra::rast(xmin = -2, xmax = 0, ymin = 5, ymax = 7, resolution = 0.01,
                   crs = "EPSG:4326", vals = 7)
  pts <- svy_standardize(data.frame(id = 1:2, cl = 1:2, x = c(-1.9, -0.1),
                                    y = c(5.1, 6.9)), "id", "cl", "x", "y")
  b <- svy_buffers(pts, radius = 2000)
  out <- svy_extract(b, r, max_cells_in_memory = 1000)
  expect_equal(out$mean, c(7, 7), tolerance = 1e-4)
})

test_that("year matching selects the right layer, lag and window", {
  r <- terra::rast(xmin = -2, xmax = 0, ymin = 5, ymax = 7, resolution = 0.05,
                   crs = "EPSG:4326", nlyrs = 4)
  for (k in 1:4) r[[k]] <- 2010 + k # layer value equals its year
  names(r) <- paste0("pm25_", 2011:2014)

  pts <- svy_standardize(
    data.frame(id = 1:3, cl = 1:3, x = -1, y = 6,
               d = as.Date(c("2012-06-01", "2014-01-01", "2016-01-01"))),
    "id", "cl", "x", "y", date = "d"
  )
  b <- svy_buffers(pts, radius = 2000)

  expect_warning(same <- svy_extract_by_year(b, r), "2016")
  expect_equal(same$exposure, c(2012, 2014, NA), tolerance = 1e-6)

  lag1 <- suppressWarnings(svy_extract_by_year(b, r, lag_years = 1))
  expect_equal(lag1$exposure_year, c(2011, 2013, 2015))
  expect_equal(lag1$exposure, c(2011, 2013, NA), tolerance = 1e-6)

  win <- suppressWarnings(svy_extract_by_year(b, r, window_years = 2))
  expect_equal(win$exposure, c(2011.5, 2013.5, NA), tolerance = 1e-6)
})

test_that("layer years come from terra time metadata", {
  sim <- sim_small()
  expect_equal(svyexpo:::layer_years_from(sim$raster), 2014:2016)
})
