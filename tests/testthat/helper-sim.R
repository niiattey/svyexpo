# Small simulated dataset shared across tests.
sim_small <- function() svy_simulate(n_side = 3, clusters_per_area = 2,
                                     records_per_cluster = 3, seed = 42)

# TRUE only if INLA is installed, its binary runs on this machine, and the
# sn package (needed for posterior sampling) is available. Some CI runners
# have INLA installed but cannot execute its binary.
inla_works <- function() {
  if (!requireNamespace("INLA", quietly = TRUE) ||
      !requireNamespace("sn", quietly = TRUE)) {
    return(FALSE)
  }
  tryCatch({
    suppressWarnings(INLA::inla(
      y ~ 1, data = data.frame(y = c(1, 2, 3, 4)), family = "gaussian",
      num.threads = "1:1", silent = 2L
    ))
    TRUE
  }, error = function(e) FALSE)
}

skip_if_no_inla <- function() {
  testthat::skip_if_not(inla_works(), "INLA is not available or cannot run")
}
