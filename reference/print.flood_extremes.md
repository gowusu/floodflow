# Print a flood extremes result

Print a flood extremes result

## Usage

``` r
# S3 method for class 'flood_extremes'
print(x, ...)
```

## Arguments

- x:

  A `flood_extremes` object.

- ...:

  Ignored, present for S3 method consistency.

## Value

The object `x`, invisibly; prints a compact summary.

## Examples

``` r
set.seed(1)
rain <- data.frame(
  date = seq(as.Date("1990-01-01"), as.Date("2020-12-31"), by = "day"),
  precip_mm = round(rgamma(11323, 0.7, scale = 6), 1)
)
print(flood_extremes(rain))
#> <flood_extremes>
#>   years of record: 31
#>   GEV (stationary): mu=30.96 sigma=5.23 shape=0.021
#>   location trend (mm/yr): -0.0202
#>   trend test: LR=0.03 p=0.855  (no significant trend)
#>   return levels (mm):
#>        2-yr: 32.9
#>       10-yr: 43.0
#>       25-yr: 48.3
#>       50-yr: 52.2
#>      100-yr: 56.2
```
