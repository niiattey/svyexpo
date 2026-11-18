# Standardise survey records to the svyexpo schema

Renames user-specified columns to the standard names in
[`svy_schema()`](https://niiattey.github.io/svyexpo/reference/svy_schema.md),
removes records with missing coordinates and returns an `sf` POINT
object. Records at (0, 0) are treated as missing because DHS uses this
value for clusters without GPS data.

## Usage

``` r
svy_standardize(
  data,
  id,
  cluster,
  lon,
  lat,
  date = NULL,
  weight = NULL,
  strata = NULL,
  urban = NULL,
  crs = 4326
)
```

## Arguments

- data:

  A data frame with one row per survey record.

- id, cluster, lon, lat:

  Names of the columns holding the record identifier, cluster
  identifier, longitude and latitude.

- date, weight, strata, urban:

  Optional column names for interview date, sampling weight, stratum and
  urban/rural status. `urban` may be logical, `"U"`/`"R"`,
  `"urban"`/`"rural"`, or DHS-coded `1` (urban) / `2` (rural).

- crs:

  Coordinate reference system of `lon`/`lat`. Defaults to WGS84.

## Value

An `sf` object with standard columns first, followed by all other
columns of `data`. Original columns whose names clash with a standard
name are kept with an `orig_` prefix.

## Examples

``` r
df <- data.frame(
  hhid = c("a", "b", "c"), clust = c(1, 1, 2),
  x = c(-0.20, -0.21, 0), y = c(5.60, 5.61, 0),
  stunted = c(0, 1, 0), res = c("U", "U", "R")
)
svy_standardize(df, id = "hhid", cluster = "clust", lon = "x", lat = "y",
                urban = "res")
#> Warning: Dropped 1 record with missing or (0, 0) coordinates.
#> Simple feature collection with 2 features and 6 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -0.21 ymin: 5.6 xmax: -0.2 ymax: 5.61
#> Geodetic CRS:  WGS 84
#>   id cluster   lon  lat urban stunted           geometry
#> 1  a       1 -0.20 5.60  TRUE       0   POINT (-0.2 5.6)
#> 2  b       1 -0.21 5.61  TRUE       1 POINT (-0.21 5.61)
```
