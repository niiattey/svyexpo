# Download administrative boundaries from GADM

A thin wrapper around
[`geodata::gadm()`](https://rspatial.github.io/geodata/reference/gadm.html)
that returns an `sf` object with two standard columns, `area_id` and
`area_name`, and repairs invalid geometries. Downloads are cached in
`path` (see the `svyexpo.cache_dir` option in
[svyexpo-package](https://niiattey.github.io/svyexpo/reference/svyexpo-package.md))
so each country is downloaded once.

## Usage

``` r
svy_boundaries(country, level = 1, path = NULL, resolution = 1)
```

## Arguments

- country:

  One or more ISO3 country codes, e.g. `c("GHA", "UGA")`.

- level:

  Administrative level (0 = country, 1 = region, 2 = district).

- path:

  Download directory. Defaults to the package cache directory.

- resolution:

  `1` for full resolution, `2` for simplified polygons (smaller files,
  faster plotting).

## Value

An `sf` polygon object with columns `area_id`, `area_name`, `country`
and the original GADM attributes.

## Examples

``` r
if (FALSE) { # \dontrun{
gha <- svy_boundaries("GHA", level = 2)
} # }
```
