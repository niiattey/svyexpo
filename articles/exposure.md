# Assigning exposure to people

This vignette shows how to give each person an exposure over time
windows you choose, using simulated data. You need a table of people
with an identifier, a date and coordinates, and an exposure in any of
four forms.

``` r

people <- data.frame(
  id   = 1:4,
  date = as.Date(c("2019-03-10", "2019-07-22", "2019-11-05", "2020-02-14")),  # birth dates
  lon  = c(-0.200, -0.198, -0.185, -0.190),
  lat  = 5.600
)
```

## Monitor readings from a CSV

Monitors have an identifier, a location, a date and a value. Daily,
hourly or monthly series are all fine.

``` r

set.seed(1)
days <- seq(as.Date("2018-01-01"), as.Date("2020-06-30"), by = "day")
monitors <- do.call(rbind, lapply(1:3, function(i) {
  data.frame(monitor = paste0("m", i),
             lon = c(-0.200, -0.186, -0.150)[i], lat = 5.6,
             date = days,
             pm25 = 40 + 10 * sin(2 * pi * as.numeric(days) / 365) + 5 * i +
               rnorm(length(days), sd = 4))
}))

src <- svy_exposure(monitors, unit = "monitor", value = "pm25")
src
#> <svy_exposure_source>: points
#> • Time step: day; 912 periods, 2018-01-01 to 2020-06-30
#> • 3 unit(s); 100% of unit-periods have a value
```

Windows are offsets from each person’s date, in days by default. Both
ends are included. Radii are in kilometres, and each combination of
window and radius is returned.

``` r

res <- svy_expose(
  people, src,
  windows = list(prenatal = c(-270, -1), postnatal = c(0, 364),
                 cumulative = c(-270, 364)),
  radius_km = c(1, 5),
  name = "pm25"
)
res
#> <svy_exposure_result>: 4 records, 3 windows, 2 radius settings; source: points
#>      window radius_km n pct_with_value median_coverage
#>  cumulative         1 4             75            0.89
#>   postnatal         1 4             50            0.80
#>    prenatal         1 4            100            1.00
#>  cumulative         5 4             75            0.89
#>   postnatal         5 4             50            0.80
#>    prenatal         5 4            100            1.00
#> 
#>  id    window radius_km     pm25  coverage window_start window_end
#>   1  prenatal         1 42.59160 1.0000000   2018-06-13 2019-03-09
#>   2  prenatal         1 47.98919 1.0000000   2018-10-25 2019-07-21
#>   3  prenatal         1 49.78117 1.0000000   2019-02-08 2019-11-04
#>   4  prenatal         1 47.01871 1.0000000   2019-05-20 2020-02-13
#>   1 postnatal         1 44.73595 1.0000000   2019-03-10 2020-03-08
#>   2 postnatal         1 44.98659 0.9452055   2019-07-22 2020-07-20
#> # ... with 18 more rows
```

`coverage` is the share of the window’s days with a value. These
monitors stop at the end of June 2020, so the postnatal windows of the
two latest births run past the data. With the default
`min_coverage = 0.75` their postnatal values are `NA`, instead of a mean
over only part of the year.

``` r

subset(res, window == "postnatal" & radius_km == "5",
       select = c(id, pm25, coverage, window_end))
#>    id     pm25  coverage window_end
#> 17  1 47.26723 1.0000000 2020-03-08
#> 18  2 47.54232 0.9452055 2020-07-20
#> 19  3       NA 0.6547945 2020-11-03
#> 20  4       NA 0.3780822 2021-02-12
```

## Choosing how monitors are combined

``` r

# A child 0.55 km from monitor m1 and 1 km from m2
child <- data.frame(id = 1, date = as.Date("2019-06-01"), lon = -0.195, lat = 5.6)
sapply(c("mean", "nearest", "idw"), function(a) {
  svy_expose(child, src, windows = list(w = c(-30, -1)),
             radius_km = 5, assign = a, name = "pm25")$pm25
})
#>     mean  nearest      idw 
#> 55.74160 49.82938 51.48954
```

## Calendar windows and interview dates

Windows can be given in weeks, months or years. If you have the
interview date and the child’s age instead of the birth date, the anchor
is derived for you.

``` r

survey <- transform(people, interview = date + 400, age_months = 13)
svy_expose(survey, src, date = "interview", date_is = "interview",
           age_months = "age_months",
           windows = list(prenatal = c(-9, 0)), window_unit = "months",
           radius_km = 5, name = "pm25")[, c("id", "pm25", "window_start", "window_end")]
#>   id     pm25 window_start window_end
#> 1  1 45.22511   2018-06-13 2019-03-13
#> 2  2 50.49380   2018-10-25 2019-07-25
#> 3  3 49.65421   2019-02-09 2019-11-09
#> 4  4 47.11831   2019-05-20 2020-02-20
```

## Rasters and area tables

The same call works for a raster stack with one layer per day, month or
year, a table of grid cells, or a table of district values. Only the
first line changes.

``` r

src <- svy_exposure("pm25_monthly.tif")
src <- svy_exposure("cells.csv", type = "grid")
src <- svy_exposure("districts.csv", unit = "district",
                    boundaries = gadm2, boundary_id = "district")
```

Raster layers are dated from
[`terra::time()`](https://rspatial.github.io/terra/reference/time.html),
from dates in their names such as `pm25_2019-03`, or from a `dates`
argument. Layers longer than a day, such as months, are weighted by the
days that fall inside each window.

## Wide format for modelling

``` r

svy_expose(people, src, windows = svy_windows("prenatal_postnatal"),
           radius_km = 5, name = "pm25", format = "wide")
#>   id pm25_prenatal_5km pm25_postnatal_5km
#> 1  1          45.04171           47.26723
#> 2  2          50.63367           47.54232
#> 3  3          49.84768                 NA
#> 4  4          46.82140                 NA
```
