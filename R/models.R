# Module 5: Models ------------------------------------------------------------

#' Default penalised complexity (PC) priors
#'
#' PC priors shrink towards a simpler model unless the data support more
#' complexity (Simpson et al., 2017, Statistical Science 32:1-28). The
#' defaults follow Riebler et al. (2016, Statistical Methods in Medical
#' Research 25:1145-1165).
#'
#' @param bym2_prec `c(U, alpha)` for the BYM2 precision: P(sd > U) = alpha.
#' @param bym2_phi `c(u, alpha)` for the BYM2 mixing parameter phi (the
#'   proportion of residual variance that is spatially structured):
#'   P(phi < u) = alpha.
#' @param svc_prec `c(U, alpha)` for the precision of spatially varying
#'   coefficients.
#' @return A list of INLA `hyper` specifications.
#' @export
#' @examples
#' svy_priors(bym2_prec = c(0.5, 0.01))
svy_priors <- function(bym2_prec = c(1, 0.01), bym2_phi = c(0.5, 2 / 3),
                       svc_prec = c(1, 0.01)) {
  list(
    bym2 = list(
      prec = list(prior = "pc.prec", param = bym2_prec),
      phi = list(prior = "pc", param = bym2_phi)
    ),
    svc = list(
      prec = list(prior = "pc.prec", param = svc_prec)
    )
  )
}

#' Fit a BYM2 model with optional spatially varying coefficients
#'
#' Fits a unit-level (individual or cluster) model with a BYM2 area random
#' effect using INLA. Covariates named in `svc` additionally get an
#' area-specific slope, so their effect can vary across space.
#'
#' The model for record \eqn{i} in area \eqn{a} is
#' \deqn{g(\mu_i) = \beta_0 + x_i^\top \beta + b_a + \sum_k z_{ik} \gamma_{ka}}
#' where \eqn{b_a} is the BYM2 effect and \eqn{\gamma_{ka}} are the area
#' deviations of the slope for covariate \eqn{z_k} (from `svc`). The total
#' area-specific slope is \eqn{\beta_k + \gamma_{ka}}; see [svy_svc_effects()].
#'
#' @section Survey design:
#' INLA fits a model-based analysis and does not use sampling weights. Adjust
#' for the design by including stratification variables (e.g. region and
#' urban/rural) as fixed effects, and consider a cluster-level iid random
#' effect via `extra_terms`. For design-based small-area prevalence,
#' see the SUMMER and surveyPrev packages.
#'
#' @param data A data frame (or `sf` object) with outcome, covariates and
#'   area identifiers, e.g. survey records joined to [svy_extract()] output.
#' @param formula Fixed-effects formula, e.g. `stunted ~ pm25 + urban`.
#' @param graph An `svy_graph` from [svy_adjacency()].
#' @param area_col Area identifier column in `data` (and in `graph$index`).
#' @param family INLA likelihood, e.g. `"binomial"`, `"poisson"`,
#'   `"gaussian"`.
#' @param Ntrials For binomial models, the name of a trials column or a
#'   numeric vector. Defaults to 1 (Bernoulli).
#' @param E For Poisson models, the name of an offset (expected counts)
#'   column or a numeric vector.
#' @param svc Character vector of numeric covariates to give spatially
#'   varying slopes. Each must also appear in `formula`.
#' @param svc_model Latent model for the slope deviations: `"besag"` (ICAR)
#'   or `"bym2"`.
#' @param extra_terms Character vector of additional formula terms, e.g.
#'   `"f(cluster_idx, model = 'iid')"`.
#' @param priors Output of [svy_priors()].
#' @param ... Further arguments passed to `INLA::inla()`.
#'
#' @return An object of class `svy_fit`: a list with the INLA fit (`inla`),
#'   the `graph`, the data used and model settings.
#' @export
svy_fit_bym2 <- function(data, formula, graph, area_col = "area_id",
                         family = "binomial", Ntrials = NULL, E = NULL,
                         svc = NULL, svc_model = c("besag", "bym2"),
                         extra_terms = NULL, priors = svy_priors(), ...) {
  check_inla()
  check_class(graph, "svy_graph")
  svc_model <- match.arg(svc_model)
  if (inherits(data, "sf")) data <- sf::st_drop_geometry(data)
  data <- as.data.frame(data)
  check_columns(data, area_col)
  check_columns(data, all.vars(formula))

  # Index areas exactly as in the graph.
  data$svy_area_idx <- graph$index$area_idx[
    match(as.character(data[[area_col]]), graph$index[[area_col]])
  ]
  missing_area <- is.na(data$svy_area_idx)
  if (any(missing_area)) {
    cli::cli_warn("Dropped {sum(missing_area)} record{?s} whose area is not in {.arg graph}.")
    data <- data[!missing_area, , drop = FALSE]
  }

  terms <- c(
    paste(deparse(formula, width.cutoff = 500L), collapse = " "),
    "f(svy_area_idx, model = 'bym2', graph = .svy_adj, scale.model = TRUE,
       constr = TRUE, hyper = .svy_hyper_bym2)"
  )

  fixed_vars <- attr(stats::terms(formula), "term.labels")
  for (v in svc) {
    if (!v %in% fixed_vars) {
      cli::cli_abort("{.arg svc} variable {.val {v}} must also be a main effect in {.arg formula}.")
    }
    if (!is.numeric(data[[v]])) {
      cli::cli_abort("{.arg svc} variable {.val {v}} must be numeric.")
    }
    idx <- paste0("svy_svc_idx_", v)
    data[[idx]] <- data$svy_area_idx
    hyper <- if (svc_model == "bym2") ".svy_hyper_bym2" else ".svy_hyper_svc"
    terms <- c(terms, sprintf(
      "f(%s, %s, model = '%s', graph = .svy_adj, scale.model = TRUE,
         constr = TRUE, hyper = %s)",
      idx, v, svc_model, hyper
    ))
  }
  terms <- c(terms, extra_terms)

  # INLA evaluates f() arguments in the formula environment.
  env <- new.env(parent = environment(formula) %||% globalenv())
  env$.svy_adj <- graph$adj
  env$.svy_hyper_bym2 <- priors$bym2
  env$.svy_hyper_svc <- priors$svc
  full_formula <- stats::as.formula(paste(terms, collapse = " + "), env = env)

  resolve <- function(x) if (is.character(x) && length(x) == 1) data[[x]] else x
  fit <- INLA::inla(
    full_formula,
    family = family,
    data = data,
    Ntrials = resolve(Ntrials),
    E = resolve(E),
    control.compute = list(dic = TRUE, waic = TRUE, cpo = TRUE, config = TRUE),
    control.predictor = list(compute = TRUE, link = 1),
    ...
  )

  structure(
    list(
      inla = fit,
      graph = graph,
      data = data,
      area_col = area_col,
      formula = full_formula,
      family = family,
      svc = svc
    ),
    class = "svy_fit"
  )
}

#' @export
print.svy_fit <- function(x, ...) {
  cli::cli_text("{.cls svy_fit}: {x$family} BYM2 model, {nrow(x$data)} records, {nrow(x$graph$index)} areas")
  if (length(x$svc)) cli::cli_text("Spatially varying coefficients: {.val {x$svc}}")
  cli::cli_h3("Fixed effects")
  print(round(x$inla$summary.fixed[, c("mean", "sd", "0.025quant", "0.975quant")], 4))
  cli::cli_h3("Hyperparameters")
  print(round(x$inla$summary.hyperpar[, c("mean", "sd", "0.025quant", "0.975quant")], 4))
  invisible(x)
}
