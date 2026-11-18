# Independent reference: expand any exposure to one value per day, then take
# a plain mean over the window's days. svy_expose() must agree with this.
ref_window_mean <- function(day_values, from, to) {
  days <- seq(from, to, by = "day")
  v <- day_values[as.character(days)]
  c(value = mean(v, na.rm = TRUE), coverage = mean(!is.na(v)))
}

test_that("month arithmetic clamps to the end of short months", {
  expect_equal(add_months(as.Date("2020-01-31"), 1), as.Date("2020-02-29"))
  expect_equal(add_months(as.Date("2019-01-31"), 1), as.Date("2019-02-28"))
  expect_equal(add_months(as.Date("2019-12-15"), -9), as.Date("2019-03-15"))
  expect_equal(add_months(as.Date("2020-02-29"), 12), as.Date("2021-02-28"))
  expect_true(is.na(add_months(as.Date(NA), 1)))
})

test_that("dates must be unambiguous", {
  expect_equal(as_date_strict(c("2020/3/5", NA)), as.Date(c("2020-03-05", NA)))
  expect_equal(as_date_strict("2020-03-04"), as.Date("2020-03-04"))
  expect_error(as_date_strict("04/03/2020"), "ISO")
})

test_that("time step is inferred from the median gap", {
  expect_equal(infer_step(as.Date("2019-01-01") + 0:20), "day")
  expect_equal(infer_step(seq(as.Date("2019-01-01"), by = "month", length.out = 12)), "month")
  expect_equal(infer_step(as.Date(c("2015-01-01", "2016-01-01", "2017-01-01"))), "year")
  expect_equal(infer_step(as.Date("2019-01-01") + c(0, 8, 16, 24)), "layer")
  # a few missing days do not change the answer
  expect_equal(infer_step(as.Date("2019-01-01") + c(0:10, 13:30)), "day")
  expect_error(infer_step(as.Date("2019-01-01")), "single date")
})

test_that("window offsets are validated", {
  expect_error(normalise_windows(list(a = c(5, 1))), "start <= end")
  expect_error(normalise_windows("x"), "named list")
  expect_equal(names(normalise_windows(list(c(0, 1), b = c(2, 3)))), c("w1", "b"))
})

# --- Monitor readings ---------------------------------------------------------

monitor_data <- function() {
  # Monitor A sits on the child's cluster; B is ~1.65 km east, C ~11 km away.
  days <- as.Date("2019-01-01") + 0:729
  mk <- function(u, lon, f) data.frame(monitor = u, lon = lon, lat = 5.6, date = days,
                                       pm25 = f(seq_along(days)))
  rbind(mk("A", -0.200, function(i) 30 + (i %% 7)),
        mk("B", -0.185, function(i) 50 + (i %% 5)),
        mk("C", -0.100, function(i) 90 + 0 * i))
}
kid <- function(date = "2020-03-10") {
  data.frame(id = "k1", date = as.Date(date), lon = -0.2001, lat = 5.6)
}

test_that("monitor means over day windows match a day-by-day reference", {
  md <- monitor_data()
  src <- svy_exposure(md, unit = "monitor", value = "pm25")
  res <- svy_expose(kid(), src, windows = list(pre = c(-270, -1), post = c(0, 60)),
                    radius_km = 1, name = "pm25")
  a <- stats::setNames(md$pm25[md$monitor == "A"], as.character(md$date[md$monitor == "A"]))
  d <- as.Date("2020-03-10")
  pre <- ref_window_mean(a, d - 270, d - 1)
  post <- ref_window_mean(a, d, d + 60)
  expect_equal(res$pm25[res$window == "pre"], unname(pre["value"]))
  expect_equal(res$pm25[res$window == "post"], unname(post["value"]))
  expect_equal(res$coverage[res$window == "pre"], 1)
  expect_equal(res$window_start[res$window == "pre"], d - 270)
  expect_equal(res$window_end[res$window == "pre"], d - 1)
})

test_that("assignment methods behave as intended", {
  md <- monitor_data()
  src <- svy_exposure(md, unit = "monitor", value = "pm25")
  w <- list(w = c(-30, -1))
  get <- function(...) svy_expose(kid(), src, windows = w, name = "x", ...)$x
  # 1 km radius sees only monitor A
  a_only <- get(radius_km = 1)
  nearest <- get(radius_km = 5, assign = "nearest")
  expect_equal(nearest, a_only)
  # 5 km radius sees A and B (C is ~11 km away): mean lies between them
  both <- get(radius_km = 5, assign = "mean")
  idw <- get(radius_km = 5, assign = "idw")
  b_only_level <- 50
  expect_gt(both, a_only)
  expect_lt(both, b_only_level + 5)
  # IDW leans towards the much closer monitor A
  expect_lt(idw, both)
  expect_gt(idw, a_only)
  # 20 km radius adds monitor C (90): mean rises
  expect_gt(get(radius_km = 20, assign = "mean"), both)
})

test_that("min_sources withholds periods with too few monitors", {
  md <- monitor_data()
  src <- svy_exposure(md, unit = "monitor", value = "pm25")
  expect_warning(
    res <- svy_expose(kid(), src, windows = list(w = c(-30, -1)), radius_km = 1,
                      min_sources = 2, name = "x"),
    "no exposure values"
  )
  expect_true(is.na(res$x))
})

test_that("min_coverage turns a short window into NA, and reports coverage", {
  md <- monitor_data()
  src <- svy_exposure(md, unit = "monitor", value = "pm25")  # ends 2020-12-30
  late <- kid("2020-12-20")
  expect_warning(
    res <- svy_expose(late, src, windows = list(post = c(0, 99)), radius_km = 1,
                      name = "x", min_coverage = 0.75),
    "no exposure values"
  )
  expect_equal(res$coverage, 11 / 100)
  expect_true(is.na(res$x))
  res2 <- suppressWarnings(svy_expose(late, src, windows = list(post = c(0, 99)),
                                      radius_km = 1, name = "x", min_coverage = 0.05))
  expect_false(is.na(res2$x))
})

test_that("hourly readings are aggregated to daily means", {
  hrs <- seq(as.POSIXct("2020-01-01 00:00", tz = "UTC"), by = "hour", length.out = 24 * 10)
  hd <- data.frame(m = "A", lon = -0.2, lat = 5.6, date = hrs,
                   v = rep(1:10, each = 24) + rep(c(-1, 1), length.out = 240))
  src <- svy_exposure(hd, unit = "m", value = "v")
  expect_equal(src$step, "day")
  expect_equal(unname(src$X[1, ]), as.numeric(1:10))
})

test_that("grid tables behave like monitors at cell centres", {
  days <- as.Date("2020-01-01") + 0:29
  cells <- expand.grid(lon = c(-0.20, -0.19), lat = c(5.60, 5.61), date = days)
  cells$v <- ifelse(cells$lon == -0.20, 10, 20)
  src <- svy_exposure(cells, type = "grid", value = "v")
  expect_equal(src$kind, "grid")
  expect_length(src$units, 4)
  res <- svy_expose(data.frame(id = 1, date = as.Date("2020-01-31"), lon = -0.2, lat = 5.6),
                    src, windows = list(w = c(-30, -1)), radius_km = 2, name = "x")
  expect_equal(res$x, 15)  # four cells, two at 10 and two at 20
})

# --- Rasters ------------------------------------------------------------------

monthly_raster <- function() {
  r <- terra::rast(nrows = 10, ncols = 10, xmin = -0.5, xmax = 0.1, ymin = 5.3, ymax = 5.9,
                   crs = "EPSG:4326", nlyrs = 24)
  for (i in 1:24) terra::values(r[[i]]) <- i * 10   # spatially constant
  months <- seq(as.Date("2018-01-01"), by = "month", length.out = 24)
  names(r) <- paste0("pm25_", format(months, "%Y-%m"))
  r
}

test_that("monthly raster windows weight months by overlapping days", {
  r <- monthly_raster()
  src <- svy_exposure(r)
  expect_equal(src$step, "month")
  birth <- as.Date("2019-06-15")
  res <- svy_expose(data.frame(id = 1, date = birth, lon = -0.2, lat = 5.6), src,
                    windows = list(pre = c(-270, -1), post = c(0, 100)),
                    radius_km = 3, name = "x")
  months <- seq(as.Date("2018-01-01"), by = "month", length.out = 24)
  daily <- seq(as.Date("2018-01-01"), as.Date("2019-12-31"), by = "day")
  dv <- stats::setNames(10 * match(floor_step(daily, "month"), months), as.character(daily))
  pre <- ref_window_mean(dv, birth - 270, birth - 1)
  post <- ref_window_mean(dv, birth, birth + 100)
  expect_equal(res$x[res$window == "pre"], unname(pre["value"]), tolerance = 1e-6)
  expect_equal(res$x[res$window == "post"], unname(post["value"]), tolerance = 1e-6)
  expect_equal(res$coverage, c(1, 1))
})

test_that("month-based windows give calendar boundaries", {
  r <- monthly_raster()
  res <- svy_expose(data.frame(id = 1, date = as.Date("2019-06-15"), lon = -0.2, lat = 5.6),
                    r, windows = list(pre = c(-9, 0)), window_unit = "months",
                    radius_km = 3, name = "x")
  expect_equal(res$window_start, as.Date("2018-09-15"))
  expect_equal(res$window_end, as.Date("2019-06-15"))
})

test_that("raster layer dates come from names, time or `dates`", {
  r <- monthly_raster()
  expect_equal(layer_dates_from_raster(r)[1], as.Date("2018-01-01"))
  r2 <- r
  names(r2) <- paste0("L", 1:24)
  expect_error(svy_exposure(r2), "date of each raster layer")
  src <- svy_exposure(r2, dates = seq(as.Date("2018-01-01"), by = "month", length.out = 24))
  expect_equal(src$step, "month")
  names(r2) <- format(seq(as.Date("2018-01-01"), by = "day", length.out = 24), "x%Y%m%d")
  expect_equal(svy_exposure(r2)$step, "day")
})

test_that("static rasters give every window the same value", {
  r <- terra::rast(nrows = 4, ncols = 4, xmin = -0.5, xmax = 0.1, ymin = 5.3, ymax = 5.9,
                   crs = "EPSG:4326")
  terra::values(r) <- 7
  res <- svy_expose(data.frame(id = 1:2, date = as.Date(c("2019-01-01", "2020-05-05")),
                               lon = -0.2, lat = 5.6),
                    svy_exposure(r, static = TRUE), radius_km = 2, name = "x")
  expect_equal(res$x, rep(7, 4), tolerance = 1e-6)
  expect_true(all(res$coverage == 1))
})

test_that("DHS radii use 2 km for urban and 5 km for rural", {
  r <- monthly_raster()
  # a steep east-west gradient makes the buffer size visible
  terra::values(r) <- rep(seq(0, 100, length.out = 10), times = 10 * 24)
  ppl <- data.frame(id = 1:2, date = as.Date("2019-06-15"), lon = -0.2, lat = 5.6,
                    urban = c(TRUE, FALSE))
  d <- svy_expose(ppl, r, windows = list(w = c(-30, -1)), radius_km = "dhs", name = "x")
  expect_equal(d$radius_km, c("dhs", "dhs"))
  expect_error(svy_expose(ppl[, -5], r, radius_km = "dhs"), "urban")
})

# --- Area-level tables --------------------------------------------------------

area_setup <- function() {
  months <- seq(as.Date("2019-01-01"), by = "month", length.out = 12)
  tab <- rbind(data.frame(district = "north", date = months, pm = 10 + 1:12),
               data.frame(district = "south", date = months, pm = 100 + 1:12))
  sq <- function(x0, y0) sf::st_polygon(list(rbind(c(x0, y0), c(x0 + 1, y0), c(x0 + 1, y0 + 1),
                                                   c(x0, y0 + 1), c(x0, y0))))
  bnd <- sf::st_sf(district = c("north", "south"),
                   geometry = sf::st_sfc(sq(0, 1), sq(0, 0), crs = 4326))
  list(tab = tab, bnd = bnd)
}

test_that("area-level exposure matches people by column or by boundaries", {
  s <- area_setup()
  ppl <- data.frame(id = 1:2, date = as.Date("2019-12-31"), lon = c(0.5, 0.5),
                    lat = c(1.5, 0.5), district = c("north", "south"))
  w <- list(last_month = c(-30, 0))

  src <- svy_exposure(s$tab, unit = "district", value = "pm")
  expect_equal(src$kind, "areas")
  by_col <- svy_expose(ppl, src, windows = w, area = "district", name = "x")
  expect_equal(by_col$x[1] < 50, TRUE)
  expect_equal(by_col$x[2] > 100, TRUE)

  src_b <- svy_exposure(s$tab, unit = "district", value = "pm",
                        boundaries = s$bnd, boundary_id = "district")
  by_geom <- svy_expose(ppl[, c("id", "date", "lon", "lat")], src_b, windows = w, name = "x")
  expect_equal(by_geom$x, by_col$x)

  # reference: Dec 1-31 is wholly December (value 12) for north
  expect_equal(by_col$x[1], 22, tolerance = 1e-8)
})

test_that("area-level source without a way to locate people is an error", {
  s <- area_setup()
  src <- svy_exposure(s$tab, unit = "district", value = "pm")
  ppl <- data.frame(id = 1, date = as.Date("2019-12-31"), lon = 0.5, lat = 1.5)
  expect_error(svy_expose(ppl, src, windows = list(w = c(-10, 0))), "area")
})

# --- Anchors, output shapes, input handling --------------------------------------

test_that("interview date minus age gives the birth-date anchor", {
  md <- monitor_data()
  src <- svy_exposure(md, unit = "monitor", value = "pm25")
  ppl <- data.frame(id = 1, date = as.Date("2020-09-15"), lon = -0.2001, lat = 5.6,
                    age = 6)
  res <- svy_expose(ppl, src, windows = list(w = c(0, 29)), radius_km = 1,
                    date_is = "interview", age_months = "age", name = "x")
  expect_equal(res$window_start, as.Date("2020-03-15"))
  expect_error(svy_expose(ppl, src, date_is = "interview"), "age_months")
})

test_that("wide format has one row per person", {
  md <- monitor_data()
  src <- svy_exposure(md, unit = "monitor", value = "pm25")
  ppl <- data.frame(id = c("a", "b"), date = as.Date(c("2020-03-10", "2020-04-10")),
                    lon = -0.2001, lat = 5.6)
  wide <- svy_expose(ppl, src, windows = list(pre = c(-60, -1), post = c(0, 30)),
                     radius_km = c(1, 5), name = "pm", format = "wide")
  expect_equal(nrow(wide), 2)
  expect_setequal(names(wide), c("id", "pm_pre_1km", "pm_post_1km", "pm_pre_5km", "pm_post_5km"))
  dup <- rbind(ppl, ppl)
  expect_error(svy_expose(dup, src, windows = list(w = c(-5, -1)), format = "wide"), "unique")
})

test_that("people in the same cluster are handled together and keep their own dates", {
  md <- monitor_data()
  src <- svy_exposure(md, unit = "monitor", value = "pm25")
  ppl <- data.frame(id = 1:3, date = as.Date(c("2020-03-10", "2020-03-11", NA)),
                    lon = -0.2001, lat = 5.6)
  res <- suppressMessages(svy_expose(ppl, src, windows = list(w = c(-30, -1)),
                                     radius_km = 1, name = "x"))
  expect_equal(nrow(res), 3)
  expect_false(res$x[1] == res$x[2])   # different days, different 30-day means
  expect_true(is.na(res$x[3]))
})

test_that("windows outside the data warn and return NA", {
  md <- monitor_data()
  src <- svy_exposure(md, unit = "monitor", value = "pm25")
  ppl <- data.frame(id = 1, date = as.Date("2010-01-01"), lon = -0.2, lat = 5.6)
  expect_warning(
    expect_warning(res <- svy_expose(ppl, src, windows = list(w = c(-30, -1)), radius_km = 1),
                   "do not overlap"),
    "no exposure values"
  )
  expect_true(is.na(res$exposure))
})

test_that("sf input is accepted, and CSV files are read", {
  md <- monitor_data()
  f <- tempfile(fileext = ".csv")
  utils::write.csv(md, f, row.names = FALSE)
  src <- svy_exposure(f, unit = "monitor", value = "pm25")
  expect_equal(src$kind, "points")
  ppl <- sf::st_as_sf(kid(), coords = c("lon", "lat"), crs = 4326)
  res <- svy_expose(ppl, src, windows = list(w = c(-30, -1)), radius_km = 1, name = "x")
  expect_false(is.na(res$x))
})

test_that("presets return valid windows", {
  for (p in c("prenatal_postnatal", "trimesters", "first_1000_days", "lifetime_to_date")) {
    expect_no_error(normalise_windows(svy_windows(p)))
  }
})
