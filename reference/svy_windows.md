# Ready-made exposure windows

Returns a named list of windows that can be passed to
[`svy_expose()`](https://niiattey.github.io/svyexpo/reference/svy_expose.md).
Offsets are relative to the anchor date (normally the date of birth).

## Usage

``` r
svy_windows(
  preset = c("prenatal_postnatal", "trimesters", "first_1000_days", "lifetime_to_date")
)
```

## Arguments

- preset:

  One of:

  - `"prenatal_postnatal"`: `prenatal` = 270 days before birth to the
    day before; `postnatal` = birth to 364 days after (first year of
    life).

  - `"trimesters"`: three prenatal trimesters of about 90 days each.

  - `"first_1000_days"`: conception (270 days before birth) to 730 days
    after birth.

  - `"lifetime_to_date"`: 0 to 5 years before the anchor date; use with
    an interview date as the anchor.

## Value

A named list of `c(start, end)` pairs in **days**. Pass
`window_unit = "days"` (the default) to
[`svy_expose()`](https://niiattey.github.io/svyexpo/reference/svy_expose.md).

## Examples

``` r
svy_windows("trimesters")
#> $trimester1
#> [1] -270 -181
#> 
#> $trimester2
#> [1] -180  -91
#> 
#> $trimester3
#> [1] -90  -1
#> 
```
