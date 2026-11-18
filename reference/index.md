# Package index

## 

Ingest

- [`svy_standardize()`](https://niiattey.github.io/svyexpo/reference/svy_standardize.md)
  : Standardise survey records to the svyexpo schema
- [`svy_from_dhs()`](https://niiattey.github.io/svyexpo/reference/svy_from_dhs.md)
  : Prepare a DHS recode file and GPS dataset
- [`cmc_to_date()`](https://niiattey.github.io/svyexpo/reference/cmc_to_date.md)
  : Convert century month codes to dates
- [`svy_schema()`](https://niiattey.github.io/svyexpo/reference/svy_schema.md)
  : Standard column names used throughout svyexpo

## 

Boundaries

- [`svy_boundaries()`](https://niiattey.github.io/svyexpo/reference/svy_boundaries.md)
  : Download administrative boundaries from GADM
- [`svy_assign_areas()`](https://niiattey.github.io/svyexpo/reference/svy_assign_areas.md)
  : Assign survey clusters to administrative areas

## 

Exposure linkage

- [`svy_exposure()`](https://niiattey.github.io/svyexpo/reference/svy_exposure.md)
  : Describe an exposure data source
- [`svy_expose()`](https://niiattey.github.io/svyexpo/reference/svy_expose.md)
  : Assign exposures to people over their own time windows
- [`svy_windows()`](https://niiattey.github.io/svyexpo/reference/svy_windows.md)
  : Ready-made exposure windows
- [`svy_buffers()`](https://niiattey.github.io/svyexpo/reference/svy_buffers.md)
  : Create displacement-aware buffers around survey clusters
- [`svy_extract()`](https://niiattey.github.io/svyexpo/reference/svy_extract.md)
  : Extract raster values within buffers
- [`svy_extract_by_year()`](https://niiattey.github.io/svyexpo/reference/svy_extract_by_year.md)
  : Extract exposures matched to each record's survey year

## 

Spatial structure

- [`svy_adjacency()`](https://niiattey.github.io/svyexpo/reference/svy_adjacency.md)
  : Build the spatial neighbourhood graph for areal models

## 

Models

- [`svy_fit_bym2()`](https://niiattey.github.io/svyexpo/reference/svy_fit_bym2.md)
  : Fit a BYM2 model with optional spatially varying coefficients
- [`svy_priors()`](https://niiattey.github.io/svyexpo/reference/svy_priors.md)
  : Default penalised complexity (PC) priors

## 

Outputs

- [`svy_area_effects()`](https://niiattey.github.io/svyexpo/reference/svy_area_effects.md)
  : Posterior summaries of area random effects
- [`svy_svc_effects()`](https://niiattey.github.io/svyexpo/reference/svy_svc_effects.md)
  : Posterior summaries of spatially varying coefficients
- [`svy_diagnostics()`](https://niiattey.github.io/svyexpo/reference/svy_diagnostics.md)
  : Model fit diagnostics
- [`svy_map()`](https://niiattey.github.io/svyexpo/reference/svy_map.md)
  : Map area-level estimates

## Simulated data

- [`svy_simulate()`](https://niiattey.github.io/svyexpo/reference/svy_simulate.md)
  : Simulate a small survey, boundary set and exposure raster
