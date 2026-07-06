# Print a flood surrogate

Print a flood surrogate

## Usage

``` r
# S3 method for class 'flood_surrogate'
print(x, ...)
```

## Arguments

- x:

  A `flood_surrogate` object.

- ...:

  Ignored, present for S3 method consistency.

## Value

The object `x`, invisibly; prints a compact summary.

## Examples

``` r
disc <- data.frame(date = seq(as.Date("2020-06-01"), by = "day",
                               length.out = 12),
                   Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1))
print(flood_surrogate(flood_route(disc, area_km2 = 300),
                      n_train = 200, seed = 1))
#> <flood_surrogate>
#>   engine: ranger
#>   training samples: 200
#>   in-sample fit: RMSE=0.1676  R2=0.9811
#>   use $predict(data.frame(Q=, n=, width=)) for fast depth estimates
```
