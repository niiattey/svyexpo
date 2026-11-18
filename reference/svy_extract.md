# Extract raster values within buffers

Computes a coverage-weighted summary of raster cells within each polygon
using
[`exactextractr::exact_extract()`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html).
Cells partly inside a buffer count in proportion to the area covered,
and `NA` cells are ignored.

## Usage

``` r
svy_extract(
  buffers,
  raster,
  fun = "mean",
  layers = NULL,
  id_col = "id",
  prefix = NULL,
  max_cells_in_memory = 3e+07,
  cache_file = NULL
)
```

## Arguments

- buffers:

  An `sf` polygon object, usually from
  [`svy_buffers()`](https://niiattey.github.io/svyexpo/reference/svy_buffers.md).

- raster:

  A `SpatRaster`, a file path, or a GDAL virtual path such as
  `"/vsicurl/https://.../pm25_2019.tif"` for Cloud-Optimized GeoTIFFs.

- fun:

  Summary function name passed to `exact_extract()`, e.g. `"mean"`,
  `"median"`, `"max"`, `"sum"`.

- layers:

  Optional layer indices or names to extract. Default: all.

- id_col:

  Identifier column in `buffers` to carry into the output.

- prefix:

  Prefix for output columns. Defaults to `fun`. A single-layer result is
  named `prefix`; multi-layer results are `prefix_<layer>`.

- max_cells_in_memory:

  Upper limit on raster cells held in memory. Lower it on machines with
  little RAM.

- cache_file:

  Optional `.rds` or `.parquet` path. If the file exists it is returned
  without touching the raster; otherwise the result is written there.

## Value

A data frame with `id_col` and one column per layer.
