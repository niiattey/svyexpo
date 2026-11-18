test_that("cmc_to_date converts century month codes", {
  expect_equal(cmc_to_date(c(1, 1369, 1380)),
               as.Date(c("1900-01-15", "2014-01-15", "2014-12-15")))
  expect_true(is.na(cmc_to_date(NA)))
})

test_that("svy_standardize renames columns and returns sf points", {
  df <- data.frame(hh = c("a", "b"), cl = 1:2, x = c(-1, -0.5), y = c(6, 7),
                   res = c("U", "R"), outcome = c(1, 0))
  out <- svy_standardize(df, id = "hh", cluster = "cl", lon = "x", lat = "y",
                         urban = "res")
  expect_s3_class(out, "sf")
  expect_equal(out$id, c("a", "b"))
  expect_equal(out$urban, c(TRUE, FALSE))
  expect_true("outcome" %in% names(out))
  expect_false("hh" %in% names(out))
})

test_that("missing and (0, 0) coordinates are dropped with a warning", {
  df <- data.frame(id = 1:3, cl = 1:3, x = c(-1, 0, NA), y = c(6, 0, 7))
  expect_warning(
    out <- svy_standardize(df, id = "id", cluster = "cl", lon = "x", lat = "y"),
    "Dropped 2"
  )
  expect_equal(nrow(out), 1)
})

test_that("clashing column names are preserved with a prefix", {
  df <- data.frame(rec = 1:2, cl = 1:2, x = c(-1, -1), y = c(6, 6),
                   weight = c(9, 9))
  out <- svy_standardize(df, id = "rec", cluster = "cl", lon = "x", lat = "y")
  expect_true("orig_weight" %in% names(out))
})

test_that("duplicate ids and missing columns are errors", {
  df <- data.frame(id = c(1, 1), cl = 1:2, x = c(-1, -1), y = c(6, 6))
  expect_error(svy_standardize(df, "id", "cl", "x", "y"), "duplicate")
  expect_error(svy_standardize(df, "id", "cl", "lon", "y"), "not found")
})

test_that("urban codings are parsed", {
  expect_equal(svyexpo:::parse_urban(c(1, 2, NA)), c(TRUE, FALSE, NA))
  expect_equal(svyexpo:::parse_urban(c("Urban", "rural")), c(TRUE, FALSE))
  expect_error(svyexpo:::parse_urban(c("town")), "Unrecognised")
})

test_that("svy_from_dhs joins GPS and rescales weights", {
  survey <- data.frame(v001 = c(1, 1, 2), v002 = c(1, 2, 1), v003 = 1,
                       v005 = c(1e6, 2e6, 5e5), v022 = 1, v008 = 1369,
                       hw70 = c(-250, -100, 50))
  gps <- data.frame(DHSCLUST = 1:2, LATNUM = c(6, 7), LONGNUM = c(-1, -0.5),
                    URBAN_RURA = c("U", "R"), DHSCC = "GH")
  out <- svy_from_dhs(survey, gps)
  expect_equal(nrow(out), 3)
  expect_equal(sort(out$weight), c(0.5, 1, 2))
  expect_equal(unique(out$date), as.Date("2014-01-15"))
  expect_true("hw70" %in% names(out))
})
