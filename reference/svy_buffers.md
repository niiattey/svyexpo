# Create displacement-aware buffers around survey clusters

DHS displaces urban clusters by up to 2 km and rural clusters by up to 5
km (1% of rural clusters by up to 10 km). Buffers of matching size
ensure the true location falls inside the extraction area. Buffers are
built in the local UTM zone of each point so distances are exact in
metres, then returned in WGS84.

## Usage

``` r
svy_buffers(points, urban_m = 2000, rural_m = 5000, radius = NULL)
```

## Arguments

- points:

  An `sf` POINT object from
  [`svy_standardize()`](https://niiattey.github.io/svyexpo/reference/svy_standardize.md).

- urban_m, rural_m:

  Buffer radius in metres for urban and rural clusters. Requires an
  `urban` column. Rural radius is used where `urban` is `NA`.

- radius:

  A single radius in metres for all points. Overrides
  `urban_m`/`rural_m`; use it for surveys without urban/rural status or
  for sensitivity analyses.

## Value

An `sf` polygon object with the attributes of `points` and a `buffer_m`
column.
