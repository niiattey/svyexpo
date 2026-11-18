# TEMPORARY diagnostic: which INLA settings work under R CMD check?
test_that("diagnose INLA under check", {
  skip_if_not_installed("INLA")
  sim <- svy_simulate(n_side = 4, clusters_per_area = 4, records_per_cluster = 10)
  pts <- svy_standardize(sim$survey, "id", "cluster", "lon", "lat",
                         date = "date", urban = "urban")
  pts <- suppressMessages(svy_assign_areas(pts, sim$boundaries))
  expo <- svy_extract_by_year(svy_buffers(pts), sim$raster, name = "pm25")
  dat <- merge(sf::st_drop_geometry(pts), expo, by = "id")
  dat$pm25_z <- as.numeric(scale(dat$pm25))
  graph <- svy_adjacency(sim$boundaries)

  try_fit <- function(label, ...) {
    r <- tryCatch({
      svy_fit_bym2(dat, y ~ pm25_z + urban, graph, ...)
      "OK"
    }, error = function(e) paste("FAIL:", substr(conditionMessage(e), 1, 80)))
    paste0(label, " = ", r)
  }
  verbose_out <- tryCatch({
    out <- utils::capture.output(
      svy_fit_bym2(dat, y ~ pm25_z + urban, graph, verbose = TRUE,
                   num.threads = "1:1"),
      type = "output"
    )
    c("VERBOSE (no error)", utils::tail(out, 25))
  }, error = function(e) {
    c("VERBOSE err", substr(conditionMessage(e), 1, 300))
  })
  # does the raw binary run inside this environment?
  bin <- tryCatch(INLA::inla.getOption("inla.call"), error = function(e) "?")
  bin_run <- tryCatch(
    utils::capture.output(system2(bin, "-h", stdout = TRUE, stderr = TRUE))[1:2],
    error = function(e) conditionMessage(e)
  )
  mc <- paste("mc.cores", getOption("mc.cores", "unset"))
  res <- c(mc, paste("bin", bin), paste("bin -h:", bin_run), verbose_out,
    paste("ver", as.character(utils::packageVersion("INLA"))),
    paste("OMP_THREAD_LIMIT", Sys.getenv("OMP_THREAD_LIMIT", "unset")),
    paste("LIMIT_CORES", Sys.getenv("_R_CHECK_LIMIT_CORES_", "unset")),
    paste("cores", parallel::detectCores()),
    paste("inla.num.threads", INLA::inla.getOption("num.threads")),
    paste("inla.mode", INLA::inla.getOption("inla.mode")),
    try_fit("A default"),
    try_fit("B threads=1:1", num.threads = "1:1"),
    try_fit("C classic", inla.mode = "classic"),
    try_fit("D classic+1:1", inla.mode = "classic", num.threads = "1:1"),
    try_fit("E threads=2:1", num.threads = "2:1"),
    try_fit("F int.strategy=eb", control.inla = list(int.strategy = "eb"))
  )
  fail(paste(c("DIAGNOSTIC", res), collapse = "\n"))
})
