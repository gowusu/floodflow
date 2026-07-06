# Print a flood uncertainty result

Print a flood uncertainty result

## Usage

``` r
# S3 method for class 'flood_uncertainty'
print(x, ...)
```

## Arguments

- x:

  A `flood_uncertainty` object.

- ...:

  Ignored, present for S3 method consistency.

## Value

The object `x`, invisibly; prints a compact summary.

## Examples

``` r
disc <- data.frame(date = seq(as.Date("2020-06-01"), by = "day",
                               length.out = 12),
                   Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1))
r <- flood_route(disc, area_km2 = 300)
print(flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                        n_sim = 1000, seed = 1))
#> <flood_uncertainty> (GLUE)
#>   observed depth:   2.85 m
#>   behavioural sets: 100
#>   90% depth band:   [2.75, 2.95] m (median 2.85)
#>   observed in band: TRUE
#>   inverse estimates:
#>     Manning n: 0.0483  [0.0206, 0.0730]
#>     width:     27.5 m  [12.3, 39.6]
#>   equifinality (n-width corr): 0.99
```
