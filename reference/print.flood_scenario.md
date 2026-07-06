# Print a flood scenario

Print a flood scenario

## Usage

``` r
# S3 method for class 'flood_scenario'
print(x, ...)
```

## Arguments

- x:

  A `flood_scenario` object.

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
print(flood_scenario(flood_extremes(rain), change_factor = 1.2))
#> <flood_scenario>
#>   method: delta  label: delta x1.20
#>   period   baseline   adjusted   change
#>       2-yr      32.9       39.5    x1.20
#>      10-yr      43.0       51.6    x1.20
#>      25-yr      48.3       57.9    x1.20
#>      50-yr      52.2       62.7    x1.20
#>     100-yr      56.2       67.5    x1.20
```
