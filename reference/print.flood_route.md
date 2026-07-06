# Print a flood route result

Print a flood route result

## Usage

``` r
# S3 method for class 'flood_route'
print(x, ...)
```

## Arguments

- x:

  A `flood_route` object.

- ...:

  Ignored, present for S3 method consistency.

## Value

The object `x`, invisibly; prints a compact summary.

## Examples

``` r
disc <- data.frame(date = seq(as.Date("2020-06-01"), by = "day",
                               length.out = 12),
                   Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1))
print(flood_route(disc))
#> <flood_route>
#>   method: muskingum-cunge
#>   peak depth:    1.48 m
#>   peak velocity: 1.17 m/s
#>   attenuation:   0.997 (routed peak / inflow peak)
#>   channel: width=20m  slope=0.001  n=0.035
```
