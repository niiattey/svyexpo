# Changelog

## svyexpo 0.0.0.9000

- New exposure assignment interface:
  [`svy_exposure()`](https://niiattey.github.io/svyexpo/reference/svy_exposure.md)
  describes a raster, monitor CSV, gridded table or area-level table;
  [`svy_expose()`](https://niiattey.github.io/svyexpo/reference/svy_expose.md)
  assigns exposure over user-defined windows (days, weeks, months or
  years from a birth or interview anchor), for one or several buffer
  radii, with a coverage report and a minimum-coverage rule;
  [`svy_windows()`](https://niiattey.github.io/svyexpo/reference/svy_windows.md)
  gives presets.
  [`svy_extract_by_year()`](https://niiattey.github.io/svyexpo/reference/svy_extract_by_year.md)
  is kept for annual rasters.

- Initial skeleton: ingest, boundaries, exposure linkage, adjacency,
  BYM2/SVC models and outputs, with a simulated-data workflow.
