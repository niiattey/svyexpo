# Standard column names used throughout svyexpo

Standard column names used throughout svyexpo

## Usage

``` r
svy_schema()
```

## Value

A named character vector describing each standard column.

## Examples

``` r
svy_schema()
#>                                       id 
#>               "Unique record identifier" 
#>                                  cluster 
#>            "Sampling cluster identifier" 
#>                                      lon 
#>                      "Longitude (WGS84)" 
#>                                      lat 
#>                       "Latitude (WGS84)" 
#>                                     date 
#>        "Interview date (Date, optional)" 
#>                                   weight 
#>             "Sampling weight (optional)" 
#>                                   strata 
#>            "Sampling stratum (optional)" 
#>                                    urban 
#> "TRUE = urban, FALSE = rural (optional)" 
```
