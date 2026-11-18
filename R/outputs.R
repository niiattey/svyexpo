# Module 6: Outputs -----------------------------------------------------------

#' Posterior summaries of area random effects
#'
#' Returns the posterior of the total BYM2 effect (structured plus
#' unstructured) for every area in the graph, including areas without survey
#' data, whose estimates borrow strength from their neighbours.
#'
#' @param fit An `svy_fit` from [svy_fit_bym2()].
#' @param exceed Threshold for exceedance probabilities, on the linear
#'   predictor scale. `prob_exceed` is P(effect > `exceed` | data).
#' @param exponentiate If `TRUE`, report `exp(effect)` (odds ratios for
#'   logistic models, rate ratios for Poisson models). `exceed` stays on the
#'   linear scale.
#'
#' @return A data frame with the area id, `mean`, `sd`, `q025`, `q500`,
#'   `q975` and `prob_exceed`.
#' @export
svy_area_effects <- function(fit, exceed = 0, exponentiate = FALSE) {
  check_inla()
  check_class(fit, "svy_fit")
  n <- nrow(fit$graph$index)
  # BYM2 returns 2n rows: first n are the total effect, last n the
  # structured part only.
  s <- fit$inla$summary.random$svy_area_idx[seq_len(n), ]
  marg <- fit$inla$marginals.random$svy_area_idx[seq_len(n)]

  prob <- vapply(marg, function(m) 1 - INLA::inla.pmarginal(exceed, m), numeric(1))

  if (exponentiate) {
    mean <- vapply(marg, function(m) INLA::inla.emarginal(exp, m), numeric(1))
    sd <- vapply(marg, function(m) {
      sqrt(max(INLA::inla.emarginal(function(x) exp(2 * x), m) -
                 INLA::inla.emarginal(exp, m)^2, 0))
    }, numeric(1))
    q <- exp(s[, c("0.025quant", "0.5quant", "0.975quant")])
  } else {
    mean <- s$mean
    sd <- s$sd
    q <- s[, c("0.025quant", "0.5quant", "0.975quant")]
  }

  out <- data.frame(
    fit$graph$index[[fit$area_col]], mean, sd, q, prob,
    row.names = NULL
  )
  names(out) <- c(fit$area_col, "mean", "sd", "q025", "q500", "q975", "prob_exceed")
  out
}

#' Posterior summaries of spatially varying coefficients
#'
#' Combines the global slope \eqn{\beta_k} with each area's deviation
#' \eqn{\gamma_{ka}} using joint posterior samples, so uncertainty in both
#' parts is propagated.
#'
#' @param fit An `svy_fit` fitted with `svc`.
#' @param var One of the `svc` covariates.
#' @param n_samples Number of joint posterior samples.
#' @param exceed Threshold for `prob_exceed` = P(slope > `exceed` | data).
#' @param exponentiate Report `exp(slope)` (e.g. odds ratio per unit).
#' @param seed Random seed for `INLA::inla.posterior.sample()`. Note that a
#'   non-zero seed makes INLA sample in a single thread.
#'
#' @return A data frame with the area id and posterior `mean`, `sd`,
#'   `q025`, `q500`, `q975`, `prob_exceed` of the area-specific slope.
#' @export
svy_svc_effects <- function(fit, var, n_samples = 1000, exceed = 0,
                            exponentiate = FALSE, seed = 0L) {
  check_inla()
  check_sn()
  check_class(fit, "svy_fit")
  if (!var %in% fit$svc) {
    cli::cli_abort("{.val {var}} was not fitted as a spatially varying coefficient.")
  }
  n <- nrow(fit$graph$index)
  idx_name <- paste0("svy_svc_idx_", var)

  sel <- list(1, seq_len(n))
  names(sel) <- c(var, idx_name)
  draws <- INLA::inla.posterior.sample(n_samples, fit$inla, selection = sel,
                                       seed = seed)

  slopes <- vapply(draws, function(d) {
    lat <- d$latent
    beta <- lat[paste0(var, ":1"), 1]
    gamma <- lat[paste0(idx_name, ":", seq_len(n)), 1]
    beta + gamma
  }, numeric(n))
  slopes <- matrix(slopes, nrow = n)

  prob <- rowMeans(slopes > exceed)
  if (exponentiate) slopes <- exp(slopes)
  q <- t(apply(slopes, 1, stats::quantile, probs = c(0.025, 0.5, 0.975)))

  out <- data.frame(
    fit$graph$index[[fit$area_col]],
    rowMeans(slopes), apply(slopes, 1, stats::sd), q, prob,
    row.names = NULL
  )
  names(out) <- c(fit$area_col, "mean", "sd", "q025", "q500", "q975", "prob_exceed")
  out
}

#' Model fit diagnostics
#'
#' @param fit An `svy_fit`.
#' @return A one-row data frame with DIC, WAIC, effective number of
#'   parameters (WAIC), the log-score (minus the mean log CPO; lower is
#'   better) and the number of CPO failures. Compare models fitted to the
#'   same data only.
#' @export
svy_diagnostics <- function(fit) {
  check_class(fit, "svy_fit")
  m <- fit$inla
  data.frame(
    dic = m$dic$dic,
    waic = m$waic$waic,
    p_eff_waic = m$waic$p.eff,
    log_score = -mean(log(m$cpo$cpo), na.rm = TRUE),
    cpo_failures = sum(m$cpo$failure > 0, na.rm = TRUE)
  )
}

#' Map area-level estimates
#'
#' @param estimates Output of [svy_area_effects()] or [svy_svc_effects()].
#' @param boundaries The `sf` polygons used to build the graph.
#' @param fill Column to map, e.g. `"mean"` or `"prob_exceed"`.
#' @param area_col Area identifier column shared by both inputs.
#' @param midpoint Centre of the diverging colour scale. Defaults to 0, or 1
#'   when all values are positive (exponentiated estimates). Ignored for
#'   `prob_exceed`, which uses a 0-1 sequential scale.
#' @param title Optional plot title.
#'
#' @return A `ggplot` object.
#' @export
svy_map <- function(estimates, boundaries, fill = "mean", area_col = "area_id",
                    midpoint = NULL, title = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("{.fn svy_map} requires the {.pkg ggplot2} package.")
  }
  check_columns(estimates, c(area_col, fill), arg = "estimates")
  check_columns(boundaries, area_col, arg = "boundaries")

  map <- merge(boundaries[area_col], estimates, by = area_col, all.x = TRUE)
  map$.fill <- map[[fill]]

  p <- ggplot2::ggplot(map) +
    ggplot2::geom_sf(ggplot2::aes(fill = .fill), colour = "grey40", linewidth = 0.1) +
    ggplot2::labs(fill = fill, title = title) +
    ggplot2::theme_void()

  if (fill == "prob_exceed") {
    p + ggplot2::scale_fill_viridis_c(limits = c(0, 1), na.value = "grey90")
  } else {
    midpoint <- midpoint %||% if (all(map$.fill > 0, na.rm = TRUE)) 1 else 0
    p + ggplot2::scale_fill_gradient2(
      low = "#2166ac", mid = "#f7f7f7", high = "#b2182b",
      midpoint = midpoint, na.value = "grey90"
    )
  }
}

utils::globalVariables(".fill")
