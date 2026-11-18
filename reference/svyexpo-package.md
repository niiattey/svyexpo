# svyexpo: survey exposure linkage and Bayesian spatial modelling

The package is organised as six modules. Each module takes and returns
ordinary R objects (data frames, `sf` objects, `SpatRaster`s), so any
step can be used on its own or swapped for your own code.

## Details

1.  **Ingest** –
    [`svy_standardize()`](https://niiattey.github.io/svyexpo/reference/svy_standardize.md),
    [`svy_from_dhs()`](https://niiattey.github.io/svyexpo/reference/svy_from_dhs.md):
    map survey records onto a common schema and attach cluster
    coordinates.

2.  **Boundaries** –
    [`svy_boundaries()`](https://niiattey.github.io/svyexpo/reference/svy_boundaries.md),
    [`svy_assign_areas()`](https://niiattey.github.io/svyexpo/reference/svy_assign_areas.md):
    download and cache GADM polygons and assign clusters to
    administrative areas.

3.  **Exposure linkage** –
    [`svy_buffers()`](https://niiattey.github.io/svyexpo/reference/svy_buffers.md),
    [`svy_extract()`](https://niiattey.github.io/svyexpo/reference/svy_extract.md),
    [`svy_extract_by_year()`](https://niiattey.github.io/svyexpo/reference/svy_extract_by_year.md):
    extract raster values within displacement-aware buffers, reading
    only the pixels that are needed.

4.  **Spatial structure** –
    [`svy_adjacency()`](https://niiattey.github.io/svyexpo/reference/svy_adjacency.md):
    build the neighbourhood graph, repair islands and index areas for
    INLA.

5.  **Models** –
    [`svy_fit_bym2()`](https://niiattey.github.io/svyexpo/reference/svy_fit_bym2.md):
    BYM2 models with optional spatially varying coefficients.

6.  **Outputs** –
    [`svy_area_effects()`](https://niiattey.github.io/svyexpo/reference/svy_area_effects.md),
    [`svy_svc_effects()`](https://niiattey.github.io/svyexpo/reference/svy_svc_effects.md),
    [`svy_diagnostics()`](https://niiattey.github.io/svyexpo/reference/svy_diagnostics.md),
    [`svy_map()`](https://niiattey.github.io/svyexpo/reference/svy_map.md):
    posterior summaries, exceedance probabilities, model diagnostics and
    maps.

[`svy_simulate()`](https://niiattey.github.io/svyexpo/reference/svy_simulate.md)
generates a small synthetic survey, boundary set and exposure raster so
that every step can be run without restricted data.

## Package options

- `svyexpo.cache_dir`: directory used to cache GADM downloads. Defaults
  to a session temporary directory; set it to a permanent folder to
  avoid repeated downloads, e.g.
  `options(svyexpo.cache_dir = tools::R_user_dir("svyexpo", "cache"))`.

## See also

Useful links:

- <https://github.com/niiattey/svyexpo>

- Report bugs at <https://github.com/niiattey/svyexpo/issues>

## Author

**Maintainer**: Patrick Attey-Yeboah <your.email@example.com>
