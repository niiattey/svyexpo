# Default penalised complexity (PC) priors

PC priors shrink towards a simpler model unless the data support more
complexity (Simpson et al., 2017, Statistical Science 32:1-28). The
defaults follow Riebler et al. (2016, Statistical Methods in Medical
Research 25:1145-1165).

## Usage

``` r
svy_priors(
  bym2_prec = c(1, 0.01),
  bym2_phi = c(0.5, 2/3),
  svc_prec = c(1, 0.01)
)
```

## Arguments

- bym2_prec:

  `c(U, alpha)` for the BYM2 precision: P(sd \> U) = alpha.

- bym2_phi:

  `c(u, alpha)` for the BYM2 mixing parameter phi (the proportion of
  residual variance that is spatially structured): P(phi \< u) = alpha.

- svc_prec:

  `c(U, alpha)` for the precision of spatially varying coefficients.

## Value

A list of INLA `hyper` specifications.

## Examples

``` r
svy_priors(bym2_prec = c(0.5, 0.01))
#> $bym2
#> $bym2$prec
#> $bym2$prec$prior
#> [1] "pc.prec"
#> 
#> $bym2$prec$param
#> [1] 0.50 0.01
#> 
#> 
#> $bym2$phi
#> $bym2$phi$prior
#> [1] "pc"
#> 
#> $bym2$phi$param
#> [1] 0.5000000 0.6666667
#> 
#> 
#> 
#> $svc
#> $svc$prec
#> $svc$prec$prior
#> [1] "pc.prec"
#> 
#> $svc$prec$param
#> [1] 1.00 0.01
#> 
#> 
#> 
```
