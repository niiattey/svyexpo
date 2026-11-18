# Assign survey clusters to administrative areas

Points are matched to the polygon that contains them. Points that fall
outside every polygon (common for coastal clusters after DHS
displacement or with simplified boundaries) are assigned to the nearest
polygon if it lies within `max_dist` metres; otherwise they receive
`NA`.

## Usage

``` r
svy_assign_areas(points, boundaries, area_col = "area_id", max_dist = 10000)
```

## Arguments

- points:

  An `sf` POINT object, usually from
  [`svy_standardize()`](https://niiattey.github.io/svyexpo/reference/svy_standardize.md).

- boundaries:

  An `sf` polygon object, usually from
  [`svy_boundaries()`](https://niiattey.github.io/svyexpo/reference/svy_boundaries.md).

- area_col:

  Name of the area identifier column in `boundaries`.

- max_dist:

  Maximum distance in metres for nearest-polygon matching.

## Value

`points` with `area_col` added and a column `area_match` that is
`"within"`, `"nearest"` or `"none"`.
