test_that("points are assigned within, to the nearest area, or NA", {
  sim <- sim_small()
  pts <- svy_standardize(
    data.frame(id = 1:3, cl = 1:3,
               x = c(-1.5, 0.02, 3),   # inside, just outside (~2 km), far
               y = c(6.5, 7, 7)),
    "id", "cl", "x", "y"
  )
  expect_message(
    expect_warning(out <- svy_assign_areas(pts, sim$boundaries), "more than"),
    "nearest"
  )
  expect_equal(out$area_match, c("within", "nearest", "none"))
  expect_false(is.na(out$area_id[2]))
  expect_true(is.na(out$area_id[3]))
})

test_that("svy_boundaries downloads and standardises GADM", {
  skip_on_cran()
  b <- tryCatch(
    svy_boundaries("GHA", level = 1, resolution = 2),
    error = function(e) NULL
  )
  skip_if(is.null(b), "GADM download not available")
  expect_s3_class(b, "sf")
  expect_true(all(c("area_id", "area_name", "country") %in% names(b)))
  expect_equal(unique(b$country), "GHA")
})
