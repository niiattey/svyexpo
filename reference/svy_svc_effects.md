# Posterior summaries of spatially varying coefficients

Combines the global slope \\\beta_k\\ with each area's deviation
\\\gamma\_{ka}\\ using joint posterior samples, so uncertainty in both
parts is propagated.

## Usage

``` r
svy_svc_effects(
  fit,
  var,
  n_samples = 1000,
  exceed = 0,
  exponentiate = FALSE,
  seed = 0L
)
```

## Arguments

- fit:

  An `svy_fit` fitted with `svc`.

- var:

  One of the `svc` covariates.

- n_samples:

  Number of joint posterior samples.

- exceed:

  Threshold for `prob_exceed` = P(slope \> `exceed` \| data).

- exponentiate:

  Report `exp(slope)` (e.g. odds ratio per unit).

- seed:

  Random seed for
  [`INLA::inla.posterior.sample()`](https://rdrr.io/pkg/INLA/man/posterior.sample.html).
  Note that a non-zero seed makes INLA sample in a single thread.

## Value

A data frame with the area id and posterior `mean`, `sd`, `q025`,
`q500`, `q975`, `prob_exceed` of the area-specific slope.
