# svyexpo

**svyexpo** links geocoded household surveys (DHS, MICS, or your own) to
raster exposures and fits Bayesian spatial models of exposure–outcome
associations, including effects that vary across space.

Existing packages such as SUMMER and surveyPrev focus on small-area
**prevalence** mapping. svyexpo focuses on **associations**: how much an
environmental exposure (PM₂.₅, greenness, temperature) changes an
outcome, and where that effect is stronger or weaker.

## Installation

``` r

# install.packages("remotes")
remotes::install_github("niiattey/svyexpo")

# INLA is needed for model fitting and is not on CRAN:
install.packages("INLA",
  repos = c(getOption("repos"), INLA = "https://inla.r-inla-download.org/R/stable"),
  dep = TRUE)

# Needed for spatially varying coefficients (posterior sampling):
install.packages("sn")
```

Requires R \>= 4.1. Modules 1-4 (ingest, boundaries, exposure linkage,
adjacency) work without INLA; only model fitting and posterior summaries
need INLA, and spatially varying coefficients also need `sn`.

## Platform support and testing

Every push is tested on GitHub Actions:

| Platform | `R CMD check` | Model tests with INLA |
|----|----|----|
| Linux (Ubuntu) | passes (model tests skipped, see below) | passes |
| macOS (Apple silicon) | passes (model tests skipped, see below) | passes |
| Windows | passes | passes |

Intel Macs are not tested. Model tests on Linux and macOS run directly
with INLA required; on Windows they run inside `R CMD check`.

**Known issue.** Inside `R CMD check` on Linux and macOS, INLA’s own
program fails on models with a spatial graph (error: “N simultaneous
processes spawned”), while the same models run normally outside
`R CMD check` and on Windows. The package’s checks therefore skip model
fitting where INLA cannot fit a small test model, and a separate CI job
runs the model tests outside `R CMD check`. The cause is not yet
identified. It has not appeared in any run outside `R CMD check`.

## Workflow

| Module | Functions | What it does |
|----|----|----|
| 1\. Ingest | [`svy_standardize()`](https://niiattey.github.io/svyexpo/reference/svy_standardize.md), [`svy_from_dhs()`](https://niiattey.github.io/svyexpo/reference/svy_from_dhs.md), [`cmc_to_date()`](https://niiattey.github.io/svyexpo/reference/cmc_to_date.md) | Map any survey to a standard schema |
| 2\. Boundaries | [`svy_boundaries()`](https://niiattey.github.io/svyexpo/reference/svy_boundaries.md), [`svy_assign_areas()`](https://niiattey.github.io/svyexpo/reference/svy_assign_areas.md) | Download GADM, assign clusters to areas |
| 3\. Exposure | [`svy_exposure()`](https://niiattey.github.io/svyexpo/reference/svy_exposure.md), [`svy_expose()`](https://niiattey.github.io/svyexpo/reference/svy_expose.md), [`svy_windows()`](https://niiattey.github.io/svyexpo/reference/svy_windows.md) | Link rasters, monitor CSVs or area tables to people over their own time windows |
| 4\. Structure | [`svy_adjacency()`](https://niiattey.github.io/svyexpo/reference/svy_adjacency.md) | Adjacency graph with island repair |
| 5\. Models | [`svy_fit_bym2()`](https://niiattey.github.io/svyexpo/reference/svy_fit_bym2.md), [`svy_priors()`](https://niiattey.github.io/svyexpo/reference/svy_priors.md) | BYM2 + spatially varying coefficients (INLA) |
| 6\. Outputs | [`svy_area_effects()`](https://niiattey.github.io/svyexpo/reference/svy_area_effects.md), [`svy_svc_effects()`](https://niiattey.github.io/svyexpo/reference/svy_svc_effects.md), [`svy_diagnostics()`](https://niiattey.github.io/svyexpo/reference/svy_diagnostics.md), [`svy_map()`](https://niiattey.github.io/svyexpo/reference/svy_map.md) | Posterior summaries, exceedance probabilities, maps |

``` r

library(svyexpo)

pts   <- svy_from_dhs(kr, gps, id_vars = c("v001", "v002", "v003", "bidx"))
areas <- svy_boundaries("GHA", level = 2)
pts   <- svy_assign_areas(pts, areas)

expo  <- svy_expose(pts, svy_exposure("pm25_2000_2022.tif"),
                    windows = list(year_before = c(-364, 0)),
                    radius_km = "dhs", name = "pm25", format = "wide")
dat   <- merge(sf::st_drop_geometry(pts), expo, by = "id")
dat$pm25 <- dat$pm25_year_before_dhs

graph <- svy_adjacency(areas)
fit   <- svy_fit_bym2(dat, stunted ~ pm25 + urban, graph, svc = "pm25")
svy_map(svy_svc_effects(fit, "pm25", exponentiate = TRUE), areas)
```

Run
[`vignette("svyexpo")`](https://niiattey.github.io/svyexpo/articles/svyexpo.md)
for a full example on simulated data.

## Assigning exposure

[`svy_expose()`](https://niiattey.github.io/svyexpo/reference/svy_expose.md)
links an exposure to each person over time windows you define, measured
from an anchor date such as date of birth. The exposure can be a raster
or any table you already have.

``` r

people <- data.frame(id, date = birth_date, lon, lat)

# 1. Say what the exposure data are. Any of these:
src <- svy_exposure("pm25_monthly.tif")                  # raster, one layer per month
src <- svy_exposure("monitors.csv", unit = "monitor",    # monitor readings (CSV)
                    value = "pm25")                      #   id, lon, lat, date, value
src <- svy_exposure("cells.csv", type = "grid")          # raster saved as a table
src <- svy_exposure("districts.csv", unit = "district",  # area-level series
                    boundaries = gadm2, boundary_id = "district")

# 2. Choose windows and buffer sizes.
svy_expose(people, src,
           windows   = list(prenatal = c(-270, -1),      # days before birth
                            postnatal = c(0, 364),       # first year of life
                            cumulative = c(-270, 364)),
           radius_km = c(1, 2, 5),
           assign    = "mean",       # monitors: "mean", "nearest" or "idw"
           name      = "pm25")
```

- **Windows** are offsets from the anchor in days, weeks, months or
  years (`window_unit = "months"`); they can overlap, so a cumulative
  window is just a longer one.
  [`svy_windows()`](https://niiattey.github.io/svyexpo/reference/svy_windows.md)
  has presets (prenatal/postnatal, trimesters, first 1,000 days).
- **Anchor.** If you have an interview date and the child’s age, use
  `date_is = "interview", age_months = "age"` and the birth date is
  derived.
- **Mixed time steps.** Daily, hourly, monthly, annual or irregular data
  are all handled; periods longer than a day are weighted by the days
  that fall in the window. Hourly timestamps are averaged to days first.
- **Coverage.** Every result reports `coverage`, the share of the
  window’s days with data. Windows below `min_coverage` (default 0.75)
  are `NA`.
- **Buffers.** Any radius or set of radii, or `radius_km = "dhs"` for 2
  km urban and 5 km rural.

Run
[`vignette("exposure")`](https://niiattey.github.io/svyexpo/articles/exposure.md)
for worked examples with simulated data.

## Large rasters

svyexpo never loads a whole raster into memory:

- [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
  opens only the file header.
- When the area covered by all buffers is small, the raster is cropped
  to it once. Otherwise `exactextractr` reads it block by block under
  each buffer.
- Cloud-Optimized GeoTIFFs can be read straight from a URL with
  `"/vsicurl/https://..."`, downloading only the tiles needed.
- `svy_extract(cache_file = "pm25.parquet")` saves the extracted table,
  so later runs skip the raster entirely.

## Data use

DHS data cannot be redistributed. Examples and tests use
[`svy_simulate()`](https://niiattey.github.io/svyexpo/reference/svy_simulate.md);
apply for access to real data at <https://dhsprogram.com>.

## Limitations

- **Monitor data.** Averaging, nearest-monitor and inverse-distance
  assignment are simple ways to represent a person’s exposure from a
  sparse network. They do not model how pollution varies between
  monitors, so exposure misclassification can be large far from any
  monitor. Use the `radius_km` and `min_sources` settings to limit how
  far a reading is stretched, and report how many people have values.

- **Exposure windows.** Month and year windows follow the calendar, with
  both ends included. Use days when you need exact lengths.

- **Survey design.** INLA fits a model-based analysis and does not use
  sampling weights. Adjust for the design with stratification variables
  (for example region and urban/rural) as fixed effects, and consider a
  cluster-level random effect. For design-based small-area prevalence,
  use SUMMER or surveyPrev.

- **Location error.** Buffers of 2 km (urban) and 5 km (rural) account
  for DHS displacement but do not remove exposure misclassification, and
  a small share of rural clusters are displaced by up to 10 km.

- **Boundaries.** GADM boundaries can differ from the survey’s own
  administrative boundaries, so some clusters fall in a different area.

- **Calendars.** Interview dates from Ethiopia (Ethiopian calendar) and
  Nepal (Vikram Samvat) are not converted to the Gregorian calendar; a
  warning is raised.

- **Spatially varying effects.** With few clusters per area these
  estimates are weakly identified and depend on the priors. Report them
  with exceedance probabilities and check sensitivity to
  [`svy_priors()`](https://niiattey.github.io/svyexpo/reference/svy_priors.md).

- **Not yet validated on real survey files.** The DHS adapter and the
  models have been tested on simulated data only. Test on your own data
  before relying on results. Associations are not necessarily causal.

## Status

Experimental. Interfaces may change before version 0.1.0.

## Author

Patrick Attey-Yeboah, Department of Biomedical Sciences, University of
Cape Coast, Ghana.
[Portfolio](https://niiattey.github.io/personal_page/) ·
[GitHub](https://github.com/niiattey) · <niiatteyyeboah@gmail.com>

## Citation

If you use svyexpo in your work, please cite it with
`citation("svyexpo")` once a release and DOI are available.
