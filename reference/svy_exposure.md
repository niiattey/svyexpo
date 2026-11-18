# Describe an exposure data source

Wraps the exposure data you have, so that
[`svy_expose()`](https://niiattey.github.io/svyexpo/reference/svy_expose.md)
can link it to people. Four kinds of source are supported:

## Usage

``` r
svy_exposure(
  x,
  type = c("auto", "raster", "points", "grid", "areas"),
  value = "value",
  date = "date",
  unit = "id",
  lon = "lon",
  lat = "lat",
  crs = 4326,
  step = c("auto", "day", "month", "year", "layer"),
  agg_fun = c("mean", "median", "max", "min", "sum"),
  dates = NULL,
  static = FALSE,
  boundaries = NULL,
  boundary_id = NULL
)
```

## Arguments

- x:

  A `SpatRaster`, a data frame, or a file path.

- type:

  One of `"auto"`, `"raster"`, `"points"`, `"grid"`, `"areas"`.

- value, date:

  Column names of the exposure value and its date or timestamp (tables
  only).

- unit:

  Column naming the monitor or area (tables). Not needed for `grid`,
  where cells are identified by their coordinates.

- lon, lat:

  Coordinate columns (`points` and `grid`).

- crs:

  Coordinate reference system of `lon`/`lat`. Default WGS84.

- step:

  Length of one period: `"auto"` (infer from the dates), `"day"`,
  `"month"`, `"year"`, or `"layer"` (each date lasts until the next, for
  irregular series such as 8-day composites). Sub-daily table data are
  always aggregated to days.

- agg_fun:

  How to combine several readings in one period of a table: `"mean"`
  (default), `"median"`, `"max"`, `"min"` or `"sum"`.

- dates:

  For rasters: the date of each layer. If `NULL`, taken from
  [`terra::time()`](https://rspatial.github.io/terra/reference/time.html),
  then from dates in the layer names such as `pm25_2019-03` or
  `pm25_20190305`.

- static:

  `TRUE` for a raster with no time dimension (for example population
  density or distance to road). Every window then receives the same
  value.

- boundaries:

  Optional `sf` polygons for `areas`, used to find which area each
  person lives in.

- boundary_id:

  Column in `boundaries` holding the unit identifier that matches
  `unit`.

## Value

An object of class `svy_exposure_source`.

## Details

- **`raster`**: a `SpatRaster`, or a file path. One layer per time step
  (daily, monthly, annual or irregular), or a single static layer.

- **`points`**: a table of monitor or sensor readings with one row per
  monitor and time: an identifier, longitude, latitude, a date and a
  value. Sub-daily timestamps are aggregated to days first.

- **`grid`**: a table of regular grid cells in the same long format as
  `points` (for example a raster exported to CSV). Cells are treated as
  monitors at the cell centres.

- **`areas`**: a table of values for administrative units (district,
  region) and dates, with no coordinates. People are matched to a unit
  by a column in their data, or by `boundaries`, a polygon layer.

Tables can be a data frame or a path to a `.csv`, `.csv.gz` or
`.parquet` file. The type is detected from the columns unless you set
`type`.

## Examples

``` r
# Monitor readings
readings <- data.frame(
  monitor = rep(c("A", "B"), each = 3),
  lon = rep(c(-0.20, -0.18), each = 3), lat = 5.6,
  date = rep(as.Date("2020-01-01") + 0:2, 2),
  pm25 = c(30, 32, 31, 50, 52, 51)
)
svy_exposure(readings, unit = "monitor", value = "pm25")
#> <svy_exposure_source>: points
#> • Time step: day; 3 periods, 2020-01-01 to 2020-01-03
#> • 2 unit(s); 100% of unit-periods have a value
```
