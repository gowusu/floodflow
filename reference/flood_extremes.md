# Analyse rainfall extremes and test for a changing climate

Reduces a daily rainfall record to annual maxima and fits the
generalized extreme value (GEV) distribution, both as a stationary model
and as a non-stationary model whose location parameter trends linearly
with time. A likelihood-ratio test compares the two, providing a formal
test of whether extreme rainfall has intensified over the record. Design
return levels (for example the 100-year daily rainfall) are computed
from the stationary fit.

## Usage

``` r
flood_extremes(
  x,
  periods = c(2, 10, 25, 50, 100),
  engine = c("internal", "extRemes")
)
```

## Arguments

- x:

  A `flood_project` whose `rainfall` slot holds a `data.frame`, or a
  `data.frame` directly. The data frame must have a `date` column (of
  class `Date` or coercible) and a `precip_mm` column of daily rainfall
  in millimetres.

- periods:

  Numeric vector of return periods, in years, at which to report design
  rainfall. Defaults to `c(2, 10, 25, 50, 100)`.

- engine:

  Which fitting engine to use: `"internal"` (default, no dependencies)
  or `"extRemes"` (uses the extRemes package if installed).

## Value

If `x` is a `flood_project`, the same object with its `extremes` slot
populated and the stage recorded in the log. If `x` is a `data.frame`,
the extremes result list directly. The result is a list of class
`flood_extremes` with elements: `annual_max` (a data frame of year and
maximum), `stationary` (fitted parameters and negative log-likelihood),
`trend` (the non-stationary fit, including the per-year location trend
`mu1`), `lr_test` (a list with the likelihood-ratio `statistic`, `df`
and `p_value`), `trend_detected` (logical, `TRUE` when
`p_value < 0.05`), and `return_levels` (a data frame of `period` and
`level_mm`).

## Details

By default a small internal maximum-likelihood engine is used, so no
extra package is required. If extRemes is installed and
`engine = "extRemes"`, that package is used for the stationary fit
instead.

## References

Coles, S. (2001) An Introduction to Statistical Modeling of Extreme
Values. Springer.
[doi:10.1007/978-1-4471-3675-0](https://doi.org/10.1007/978-1-4471-3675-0)

## See also

[`flood_scenario`](https://gowusu.github.io/floodflow/reference/flood_scenario.md)
to turn these design levels into a climate-adjusted event.

## Examples

``` r
# Build a synthetic 40-year daily rainfall record with a mild upward trend
set.seed(1)
dates <- seq(as.Date("1985-01-01"), as.Date("2024-12-31"), by = "day")
yr <- as.integer(format(dates, "%Y"))
base <- rgamma(length(dates), shape = 0.7, scale = 6)
trend <- 1 + 0.02 * (yr - 1985)
precip <- round(base * trend * rbinom(length(dates), 1, 0.3), 1)
rain <- data.frame(date = dates, precip_mm = precip)

res <- flood_extremes(rain)
res$return_levels
#>   period level_mm
#> 1      2    34.59
#> 2     10    50.10
#> 3     25    57.54
#> 4     50    62.90
#> 5    100    68.10
res$trend_detected
#> [1] TRUE
```
