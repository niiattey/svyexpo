# svyexpo 0.0.0.9000

* New exposure assignment interface: `svy_exposure()` describes a raster,
  monitor CSV, gridded table or area-level table; `svy_expose()` assigns
  exposure over user-defined windows (days, weeks, months or years from a
  birth or interview anchor), for one or several buffer radii, with a
  coverage report and a minimum-coverage rule; `svy_windows()` gives presets.
  `svy_extract_by_year()` is kept for annual rasters.

* Initial skeleton: ingest, boundaries, exposure linkage, adjacency,
  BYM2/SVC models and outputs, with a simulated-data workflow.
