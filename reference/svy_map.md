# Map area-level estimates

Map area-level estimates

## Usage

``` r
svy_map(
  estimates,
  boundaries,
  fill = "mean",
  area_col = "area_id",
  midpoint = NULL,
  title = NULL
)
```

## Arguments

- estimates:

  Output of
  [`svy_area_effects()`](https://niiattey.github.io/svyexpo/reference/svy_area_effects.md)
  or
  [`svy_svc_effects()`](https://niiattey.github.io/svyexpo/reference/svy_svc_effects.md).

- boundaries:

  The `sf` polygons used to build the graph.

- fill:

  Column to map, e.g. `"mean"` or `"prob_exceed"`.

- area_col:

  Area identifier column shared by both inputs.

- midpoint:

  Centre of the diverging colour scale. Defaults to 0, or 1 when all
  values are positive (exponentiated estimates). Ignored for
  `prob_exceed`, which uses a 0-1 sequential scale.

- title:

  Optional plot title.

## Value

A `ggplot` object.
