# Prepare a DHS recode file and GPS dataset

Joins a DHS recode (e.g. KR, IR, HR, PR read with `haven::read_dta()`)
to the DHS GPS dataset and standardises it with
[`svy_standardize()`](https://niiattey.github.io/svyexpo/reference/svy_standardize.md).
Weights are divided by 1,000,000 and interview dates are converted from
century month code (CMC) with
[`cmc_to_date()`](https://niiattey.github.io/svyexpo/reference/cmc_to_date.md).

## Usage

``` r
svy_from_dhs(
  survey,
  gps,
  id_vars = c("v001", "v002", "v003"),
  cluster_var = "v001",
  weight_var = "v005",
  strata_var = "v022",
  cmc_var = "v008"
)
```

## Arguments

- survey:

  A DHS recode data frame.

- gps:

  The DHS GPS dataset, as an `sf` object or data frame with columns
  `DHSCLUST`, `LATNUM`, `LONGNUM` and `URBAN_RURA`.

- id_vars:

  Columns pasted together to form a unique record id. Use
  `c("v001", "v002", "v003", "bidx")` for the children's recode (KR) and
  `c("hv001", "hv002", "hvidx")` for the household member recode (PR).

- cluster_var, weight_var, strata_var, cmc_var:

  Recode variable names for cluster, weight, stratum and interview CMC.
  Use the `hv` equivalents (`hv001`, `hv005`, `hv022`, `hv008`) for
  household-based recodes.

## Value

An `sf` object in the standard schema. See
[`svy_standardize()`](https://niiattey.github.io/svyexpo/reference/svy_standardize.md).

## Calendars

Ethiopia (Ethiopian calendar) and Nepal (Vikram Samvat) record CMC
values in local calendars. Convert them to the Gregorian calendar before
using interview dates for exposure matching. A warning is raised when
the GPS country code is `ET` or `NP`.
