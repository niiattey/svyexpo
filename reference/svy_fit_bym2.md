# Fit a BYM2 model with optional spatially varying coefficients

Fits a unit-level (individual or cluster) model with a BYM2 area random
effect using INLA. Covariates named in `svc` additionally get an
area-specific slope, so their effect can vary across space.

## Usage

``` r
svy_fit_bym2(
  data,
  formula,
  graph,
  area_col = "area_id",
  family = "binomial",
  Ntrials = NULL,
  E = NULL,
  svc = NULL,
  svc_model = c("besag", "bym2"),
  extra_terms = NULL,
  priors = svy_priors(),
  ...
)
```

## Arguments

- data:

  A data frame (or `sf` object) with outcome, covariates and area
  identifiers, e.g. survey records joined to
  [`svy_extract()`](https://niiattey.github.io/svyexpo/reference/svy_extract.md)
  output.

- formula:

  Fixed-effects formula, e.g. `stunted ~ pm25 + urban`.

- graph:

  An `svy_graph` from
  [`svy_adjacency()`](https://niiattey.github.io/svyexpo/reference/svy_adjacency.md).

- area_col:

  Area identifier column in `data` (and in `graph$index`).

- family:

  INLA likelihood, e.g. `"binomial"`, `"poisson"`, `"gaussian"`.

- Ntrials:

  For binomial models, the name of a trials column or a numeric vector.
  Defaults to 1 (Bernoulli).

- E:

  For Poisson models, the name of an offset (expected counts) column or
  a numeric vector.

- svc:

  Character vector of numeric covariates to give spatially varying
  slopes. Each must also appear in `formula`.

- svc_model:

  Latent model for the slope deviations: `"besag"` (ICAR) or `"bym2"`.

- extra_terms:

  Character vector of additional formula terms, e.g.
  `"f(cluster_idx, model = 'iid')"`.

- priors:

  Output of
  [`svy_priors()`](https://niiattey.github.io/svyexpo/reference/svy_priors.md).

- ...:

  Further arguments passed to
  [`INLA::inla()`](https://rdrr.io/pkg/INLA/man/inla.html).

## Value

An object of class `svy_fit`: a list with the INLA fit (`inla`), the
`graph`, the data used and model settings.

## Details

The model for record \\i\\ in area \\a\\ is \$\$g(\mu_i) = \beta_0 +
x_i^\top \beta + b_a + \sum_k z\_{ik} \gamma\_{ka}\$\$ where \\b_a\\ is
the BYM2 effect and \\\gamma\_{ka}\\ are the area deviations of the
slope for covariate \\z_k\\ (from `svc`). The total area-specific slope
is \\\beta_k + \gamma\_{ka}\\; see
[`svy_svc_effects()`](https://niiattey.github.io/svyexpo/reference/svy_svc_effects.md).

## Survey design

INLA fits a model-based analysis and does not use sampling weights.
Adjust for the design by including stratification variables (e.g. region
and urban/rural) as fixed effects, and consider a cluster-level iid
random effect via `extra_terms`. For design-based small-area prevalence,
see the SUMMER and surveyPrev packages.
