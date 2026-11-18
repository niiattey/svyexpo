# Convert century month codes to dates

DHS and MICS record dates as century month codes (CMC), the number of
months since December 1899 (CMC 1 = January 1900).

## Usage

``` r
cmc_to_date(cmc, day = 15)
```

## Arguments

- cmc:

  Integer vector of century month codes.

- day:

  Day of the month assigned to each date. Defaults to 15, the middle of
  the month.

## Value

A `Date` vector.

## Examples

``` r
cmc_to_date(c(1369, 1380)) # January and December 2014
#> [1] "2014-01-15" "2014-12-15"
```
