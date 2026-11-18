# Model fit diagnostics

Model fit diagnostics

## Usage

``` r
svy_diagnostics(fit)
```

## Arguments

- fit:

  An `svy_fit`.

## Value

A one-row data frame with DIC, WAIC, effective number of parameters
(WAIC), the log-score (minus the mean log CPO; lower is better) and the
number of CPO failures. Compare models fitted to the same data only.
