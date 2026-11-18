# Posterior summaries of area random effects

Returns the posterior of the total BYM2 effect (structured plus
unstructured) for every area in the graph, including areas without
survey data, whose estimates borrow strength from their neighbours.

## Usage

``` r
svy_area_effects(fit, exceed = 0, exponentiate = FALSE)
```

## Arguments

- fit:

  An `svy_fit` from
  [`svy_fit_bym2()`](https://niiattey.github.io/svyexpo/reference/svy_fit_bym2.md).

- exceed:

  Threshold for exceedance probabilities, on the linear predictor scale.
  `prob_exceed` is P(effect \> `exceed` \| data).

- exponentiate:

  If `TRUE`, report `exp(effect)` (odds ratios for logistic models, rate
  ratios for Poisson models). `exceed` stays on the linear scale.

## Value

A data frame with the area id, `mean`, `sd`, `q025`, `q500`, `q975` and
`prob_exceed`.
