# Extract exposures matched to each record's survey year

For a multi-year raster stack (one layer per year), extracts the layer
that matches each record's interview year, optionally lagged and
averaged over several years. Only the layers that are needed are read.

## Usage

``` r
svy_extract_by_year(
  buffers,
  raster,
  date_col = "date",
  lag_years = 0,
  window_years = 1,
  layer_years = NULL,
  fun = "mean",
  id_col = "id",
  name = "exposure",
  max_cells_in_memory = 3e+07
)
```

## Arguments

- buffers:

  An `sf` polygon object, usually from
  [`svy_buffers()`](https://niiattey.github.io/svyexpo/reference/svy_buffers.md).

- raster:

  A `SpatRaster`, a file path, or a GDAL virtual path such as
  `"/vsicurl/https://.../pm25_2019.tif"` for Cloud-Optimized GeoTIFFs.

- date_col:

  Name of the `Date` column used for matching.

- lag_years:

  Years to lag the exposure. `1` uses the year before interview.

- window_years:

  Number of consecutive years to average, ending at the lagged year. `3`
  with `lag_years = 0` averages the interview year and the two years
  before it. Records with any missing year get `NA`.

- layer_years:

  Integer vector giving the year of each raster layer. If `NULL`, years
  are taken from
  [`terra::time()`](https://rspatial.github.io/terra/reference/time.html)
  or, failing that, from four-digit years in the layer names (e.g.
  `"pm25_2016"`).

- fun:

  Summary function name passed to `exact_extract()`, e.g. `"mean"`,
  `"median"`, `"max"`, `"sum"`.

- id_col:

  Identifier column in `buffers` to carry into the output.

- name:

  Name of the output exposure column.

- max_cells_in_memory:

  Upper limit on raster cells held in memory. Lower it on machines with
  little RAM.

## Value

A data frame with `id_col`, `exposure_year` (the last year of the
window) and the exposure column.
