# Assign exposures to people over their own time windows

For each person, averages an exposure around their home location over
one or more time windows measured from an anchor date, and reports how
much of each window had data. It works the same way for rasters, monitor
readings, gridded tables and area-level tables (see
[`svy_exposure()`](https://niiattey.github.io/svyexpo/reference/svy_exposure.md)).

## Usage

``` r
svy_expose(
  data,
  exposure,
  windows = svy_windows("prenatal_postnatal"),
  radius_km = 5,
  window_unit = c("days", "weeks", "months", "years"),
  id = "id",
  date = "date",
  lon = "lon",
  lat = "lat",
  date_is = c("anchor", "interview"),
  age_months = NULL,
  assign = c("mean", "nearest", "idw"),
  idw_power = 2,
  fun = c("mean", "median", "max", "min"),
  min_coverage = 0.75,
  min_sources = 1,
  area = NULL,
  urban = "urban",
  name = "exposure",
  format = c("long", "wide")
)
```

## Arguments

- data:

  A data frame (or `sf` points) with one row per person, with columns
  for identifier, date and, unless `exposure` is area-level, longitude
  and latitude.

- exposure:

  An exposure source from
  [`svy_exposure()`](https://niiattey.github.io/svyexpo/reference/svy_exposure.md),
  or anything
  [`svy_exposure()`](https://niiattey.github.io/svyexpo/reference/svy_exposure.md)
  accepts (a raster, a data frame, a file path).

- windows:

  A named list of `c(start, end)` offsets, or a preset from
  [`svy_windows()`](https://niiattey.github.io/svyexpo/reference/svy_windows.md).

- radius_km:

  Buffer radius or radii in kilometres, for example `c(1, 2, 5)`. Use
  `"dhs"` for the DHS displacement rule (2 km urban, 5 km rural), which
  needs a column named `urban` (`TRUE`/`FALSE`, the DHS codes 1/2, or
  `"urban"`/`"rural"`).

- window_unit:

  Unit of the window offsets: `"days"` (default), `"weeks"`, `"months"`
  or `"years"`.

- id, date, lon, lat:

  Column names in `data`.

- date_is:

  `"anchor"` if `date` is already the date windows are measured from,
  for example date of birth. `"interview"` if `date` is the interview or
  measurement date and the anchor is the date of birth derived as
  `date - age_months`.

- age_months:

  Column with the child's age in months; needed when
  `date_is = "interview"`.

- assign:

  For monitor and grid sources: `"mean"` of monitors within the radius,
  `"nearest"` monitor within the radius, or `"idw"` (inverse-distance
  weighted mean).

- idw_power:

  Distance exponent for `"idw"`.

- fun:

  For rasters: how to summarise cells in the buffer, `"mean"`,
  `"median"`, `"max"` or `"min"`.

- min_coverage:

  Minimum share (0 to 1) of window days that must have data. Default
  0.75.

- min_sources:

  For monitor and grid sources: minimum number of monitors with data
  needed in a period. Default 1.

- area:

  Column in `data` naming each person's area, for area-level sources. If
  `NULL`, the source's `boundaries` are used.

- urban:

  Column in `data` flagging urban residence (for `radius_km = "dhs"`).

- name:

  Name of the exposure column in the output.

- format:

  `"long"` (one row per person, window and radius, with coverage and
  window dates) or `"wide"` (one row per person, one column per window
  and radius).

## Value

A data frame of class `svy_exposure_result`. In long format: `id`,
`window`, `radius_km`, the exposure column, `coverage`, `window_start`
and `window_end`.

## Details

**Space.** For rasters, the exposure is the coverage-weighted summary of
raster cells inside a circle of the chosen radius. For monitor and grid
tables, monitors inside the radius are combined by `assign`: their
`"mean"`, the `"nearest"` one, or an inverse-distance weighted mean
(`"idw"`). For area tables, the person's area value is used and the
radius is ignored. Distances to monitors are great-circle distances in
metres.

**Time.** A window is a pair `c(start, end)` of offsets from the anchor
date, in `window_unit`, with both ends inclusive. `c(-270, -1)` in days
is the 270 days before the anchor date. Months and years follow the
calendar, so `c(-9, 0)` in months is the nine calendar months up to the
anchor date. Windows may overlap and be nested, so a cumulative window
is simply a long one. A day-level exposure is the mean over the days of
the window; periods longer than a day (a month of a monthly raster, a
year of an annual table) are weighted by how many of their days fall
inside the window.

**Completeness.** `coverage` is the share of the window's days that had
an exposure value. Windows below `min_coverage` return `NA`, so a window
that starts before the data begin is not silently averaged over a
fraction of its length.

## Examples

``` r
readings <- data.frame(
  monitor = rep(c("A", "B"), each = 400),
  lon = rep(c(-0.20, -0.18), each = 400), lat = 5.6,
  date = rep(as.Date("2019-01-01") + 0:399, 2),
  pm25 = c(rep(30, 400), rep(50, 400))
)
kids <- data.frame(id = 1:2, date = as.Date(c("2019-10-01", "2019-12-15")),
                   lon = -0.195, lat = 5.6)
src <- svy_exposure(readings, unit = "monitor", value = "pm25")
svy_expose(kids, src, windows = svy_windows("prenatal_postnatal"),
           radius_km = c(1, 5), name = "pm25")
#> Warning: 2 window/radius combinations have no exposure values at all.
#> ℹ Check that the exposure data cover the window dates and the people's
#>   locations, or lower `min_coverage`.
#> <svy_exposure_result>: 2 records, 2 windows, 2 radius settings; source: points
#>     window radius_km n pct_with_value median_coverage
#>  postnatal         1 2              0            0.25
#>   prenatal         1 2            100            1.00
#>  postnatal         5 2              0            0.25
#>   prenatal         5 2            100            1.00
#> 
#>  id    window radius_km pm25  coverage window_start window_end
#>   1  prenatal         1   30 1.0000000   2019-01-04 2019-09-30
#>   2  prenatal         1   30 1.0000000   2019-03-20 2019-12-14
#>   1 postnatal         1   NA 0.3479452   2019-10-01 2020-09-29
#>   2 postnatal         1   NA 0.1424658   2019-12-15 2020-12-13
#>   1  prenatal         5   40 1.0000000   2019-01-04 2019-09-30
#>   2  prenatal         5   40 1.0000000   2019-03-20 2019-12-14
#> # ... with 2 more rows
```
