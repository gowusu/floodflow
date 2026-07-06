# Print a flood map

Print a flood map

## Usage

``` r
# S3 method for class 'flood_map'
print(x, ...)
```

## Arguments

- x:

  A `flood_map` object.

- ...:

  Ignored, present for S3 method consistency.

## Value

The object `x`, invisibly; prints a compact summary.

## Examples

``` r
set.seed(1)
rain <- data.frame(
  date = seq(as.Date("2000-01-01"), as.Date("2010-12-31"), by = "day"),
  precip_mm = round(rgamma(4018, 0.7, scale = 6) *
                    rbinom(4018, 1, 0.3), 1)
)
fp <- flood_project("demo"); fp$rainfall <- rain
fp <- flood_route(flood_runoff(fp, engine = "simple"), area_km2 = 300)
print(flood_map(fp, layer = "depth"))
#> <flood_map>
#>   layer:  depth
#>   engine: none
#>   rendered interactive map: FALSE
#>   (install 'tmap' or 'leaflet' for interactive maps)
#>   values: min=1.405 mean=1.405 max=1.405
```
