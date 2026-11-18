# svyexpo <img src="man/figures/logo.png" align="right" height="139" alt="svyexpo hex sticker: a grid of squares forming a disc, with edge squares shrinking" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/niiattey/svyexpo/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/niiattey/svyexpo/actions/workflows/R-CMD-check.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**svyexpo** links geocoded household surveys (DHS, MICS, or your own) to
raster exposures and fits Bayesian spatial models of exposure–outcome
associations, including effects that vary across space.

Existing packages such as SUMMER and surveyPrev focus on small-area
**prevalence** mapping. svyexpo focuses on **associations**: how much an
environmental exposure (PM₂.₅, greenness, temperature) changes an outcome,
and where that effect is stronger or weaker.

## Installation

```r
# install.packages("remotes")
remotes::install_github("niiattey/svyexpo")

# INLA is needed for model fitting and is not on CRAN:
install.packages("INLA",
  repos = c(getOption("repos"), INLA = "https://inla.r-inla-download.org/R/stable"),
  dep = TRUE)

# Needed for spatially varying coefficients (posterior sampling):
install.packages("sn")
```

Requires R >= 4.1. Modules 1-4 (ingest, boundaries, exposure linkage,
adjacency) work without INLA; only model fitting and posterior summaries
need INLA, and spatially varying coefficients also need `sn`.

## Platform support and testing

Every push is tested on GitHub Actions:

| Platform | `R CMD check` | Model tests with INLA |
|---|---|---|
| Linux (Ubuntu) | passes (model tests skipped, see below) | passes |
| macOS (Apple silicon) | passes (model tests skipped, see below) | passes |
| Windows | passes | passes |

Intel Macs are not tested. Model tests on Linux and macOS run directly with
INLA required; on Windows they run inside `R CMD check`.

**Known issue.** Inside `R CMD check` on Linux and macOS, INLA's own program
fails on models with a spatial graph (error: "N simultaneous processes
spawned"), while the same models run normally outside `R CMD check` and on
Windows. The package's checks therefore skip model fitting where INLA cannot
fit a small test model, and a separate CI job runs the model tests outside
`R CMD check`. The cause is not yet identified. It has not appeared in any
run outside `R CMD check`.

## Workflow

| Module | Functions | What it does |
|---|---|---|
| 1. Ingest | `svy_standardize()`, `svy_from_dhs()`, `cmc_to_date()` | Map any survey to a standard schema |
| 2. Boundaries | `svy_boundaries()`, `svy_assign_areas()` | Download GADM, assign clusters to areas |
| 3. Exposure | `svy_buffers()`, `svy_extract()`, `svy_extract_by_year()` | Displacement-aware buffers, year-matched extraction |
| 4. Structure | `svy_adjacency()` | Adjacency graph with island repair |
| 5. Models | `svy_fit_bym2()`, `svy_priors()` | BYM2 + spatially varying coefficients (INLA) |
| 6. Outputs | `svy_area_effects()`, `svy_svc_effects()`, `svy_diagnostics()`, `svy_map()` | Posterior summaries, exceedance probabilities, maps |

```r
library(svyexpo)

pts   <- svy_from_dhs(kr, gps, id_vars = c("v001", "v002", "v003", "bidx"))
areas <- svy_boundaries("GHA", level = 2)
pts   <- svy_assign_areas(pts, areas)

expo  <- svy_extract_by_year(svy_buffers(pts), "pm25_2000_2022.tif", name = "pm25")
dat   <- merge(sf::st_drop_geometry(pts), expo, by = "id")

graph <- svy_adjacency(areas)
fit   <- svy_fit_bym2(dat, stunted ~ pm25 + urban, graph, svc = "pm25")
svy_map(svy_svc_effects(fit, "pm25", exponentiate = TRUE), areas)
```

Run `vignette("svyexpo")` for a full example on simulated data.

## Large rasters

svyexpo never loads a whole raster into memory:

- `terra::rast()` opens only the file header.
- When the area covered by all buffers is small, the raster is cropped to it
  once. Otherwise `exactextractr` reads it block by block under each buffer.
- Cloud-Optimized GeoTIFFs can be read straight from a URL with
  `"/vsicurl/https://..."`, downloading only the tiles needed.
- `svy_extract(cache_file = "pm25.parquet")` saves the extracted table, so
  later runs skip the raster entirely.

## Data use

DHS data cannot be redistributed. Examples and tests use `svy_simulate()`;
apply for access to real data at <https://dhsprogram.com>.

## Limitations

- **Survey design.** INLA fits a model-based analysis and does not use
  sampling weights. Adjust for the design with stratification variables
  (for example region and urban/rural) as fixed effects, and consider a
  cluster-level random effect. For design-based small-area prevalence, use
  SUMMER or surveyPrev.
- **Location error.** Buffers of 2 km (urban) and 5 km (rural) account for
  DHS displacement but do not remove exposure misclassification, and a small
  share of rural clusters are displaced by up to 10 km.
- **Boundaries.** GADM boundaries can differ from the survey's own
  administrative boundaries, so some clusters fall in a different area.
- **Calendars.** Interview dates from Ethiopia (Ethiopian calendar) and Nepal
  (Vikram Samvat) are not converted to the Gregorian calendar; a warning is
  raised.
- **Spatially varying effects.** With few clusters per area these estimates
  are weakly identified and depend on the priors. Report them with
  exceedance probabilities and check sensitivity to `svy_priors()`.
- **Not yet validated on real survey files.** The DHS adapter and the models
  have been tested on simulated data only. Test on your own data before
  relying on results. Associations are not necessarily causal.

## Status

Experimental. Interfaces may change before version 0.1.0.

## Author

Patrick Attey-Yeboah, Department of Biomedical Sciences, University of Cape
Coast, Ghana. [Portfolio](https://niiattey.github.io/personal_page/) ·
[GitHub](https://github.com/niiattey) · niiatteyyeboah@gmail.com

## Citation

If you use svyexpo in your work, please cite it with
`citation("svyexpo")` once a release and DOI are available.
