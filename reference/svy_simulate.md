# Simulate a small survey, boundary set and exposure raster

Generates synthetic data with the same structure as a geocoded household
survey so the full workflow can be demonstrated and tested without
restricted data. Areas form a regular grid; clusters are displaced like
DHS clusters (up to 2 km urban, 5 km rural); the binary outcome depends
on the year-matched exposure at the true location and on a smooth
spatial area effect.

## Usage

``` r
svy_simulate(
  n_side = 6,
  clusters_per_area = 5,
  records_per_cluster = 20,
  years = 2014:2016,
  beta = 0.4,
  seed = 1
)
```

## Arguments

- n_side:

  Number of areas along each side of the grid.

- clusters_per_area:

  Survey clusters per area.

- records_per_cluster:

  Records (e.g. children) per cluster.

- years:

  Survey years; each cluster is interviewed in one of them. The raster
  has one layer per year.

- beta:

  Log-odds change per standard deviation of exposure.

- seed:

  Random seed, or `NULL` to use the current RNG state. The global RNG
  state is restored on exit.

## Value

A list with

- `survey`: data frame with `id`, `cluster`, `lon`, `lat` (displaced),
  `date`, `weight`, `strata`, `urban`, `age_months` and binary `y`

- `boundaries`: `sf` polygons with `area_id` and `area_name`

- `raster`: `SpatRaster` with one exposure layer per year

## Examples

``` r
sim <- svy_simulate(n_side = 4, clusters_per_area = 3)
head(sim$survey)
#>        id cluster       lon      lat       date weight strata urban age_months
#> 1 C001_01       1 -1.762098 6.218099 2015-04-15      1    A01  TRUE         21
#> 2 C001_02       1 -1.762098 6.218099 2015-04-15      1    A01  TRUE          9
#> 3 C001_03       1 -1.762098 6.218099 2015-04-15      1    A01  TRUE         39
#> 4 C001_04       1 -1.762098 6.218099 2015-04-15      1    A01  TRUE         11
#> 5 C001_05       1 -1.762098 6.218099 2015-04-15      1    A01  TRUE         56
#> 6 C001_06       1 -1.762098 6.218099 2015-04-15      1    A01  TRUE         53
#>   y
#> 1 1
#> 2 0
#> 3 0
#> 4 0
#> 5 1
#> 6 1
```
