# Print a flood hydraulics result

Print a flood hydraulics result

## Usage

``` r
# S3 method for class 'flood_hydraulics'
print(x, ...)
```

## Arguments

- x:

  A `flood_hydraulics` object.

- ...:

  Ignored, present for S3 method consistency.

## Value

The object `x`, invisibly; prints a compact summary.

## Examples

``` r
disc <- data.frame(date = seq(as.Date("2020-06-01"), by = "day",
                               length.out = 12),
                   Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1))
print(flood_hydraulics(flood_route(disc)))
#> <flood_hydraulics>
#>   peak velocity:   1.17 m/s
#>   time of concentration (min):
#>     Kirpich:       196.4
#>     Kerby:         40.9
#>     Kerby-Kirpich: 234.3
#>     velocity:      71.1
#>   travel time:     71.1 min
#>   time to peak:    72.0 hours
```
