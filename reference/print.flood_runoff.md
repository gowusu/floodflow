# Print a flood runoff result

Print a flood runoff result

## Usage

``` r
# S3 method for class 'flood_runoff'
print(x, ...)
```

## Arguments

- x:

  A `flood_runoff` object.

- ...:

  Ignored, present for S3 method consistency.

## Value

The object `x`, invisibly; prints a compact summary.

## Examples

``` r
set.seed(1)
rain <- data.frame(
  date = seq(as.Date("2020-01-01"), as.Date("2020-12-31"), by = "day"),
  precip_mm = round(rgamma(366, 0.7, scale = 8) *
                    rbinom(366, 1, 0.4), 1)
)
print(flood_runoff(rain, engine = "simple"))
#> <flood_runoff>
#>   engine: simple (fallback)
#>   days:   366
#>   peak discharge: 5.48 mm/day on 2020-09-23
#>   mean PET: 4.83 mm/day
```
