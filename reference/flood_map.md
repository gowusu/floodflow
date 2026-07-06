# Map a flood layer

Renders a chosen pipeline layer for viewing. When tmap or leaflet is
installed and the layer is spatial, an interactive map is produced;
otherwise the function returns a tidy data frame of the layer's values
(and, for non-spatial results, draws a simple base-R plot) so the
pipeline remains usable without the mapping engines. This keeps mapping
a first-class output while respecting the package's lightweight core.

## Usage

``` r
flood_map(
  x,
  layer = c("depth", "risk", "velocity", "uncertainty"),
  interactive = TRUE
)
```

## Arguments

- x:

  A `flood_project` with the requested layer populated.

- layer:

  Which layer to map: `"depth"` (routed peak depth), `"risk"`
  (vulnerability index), `"velocity"`, or `"uncertainty"` (predictive
  band width). Default `"depth"`.

- interactive:

  Logical; if `TRUE` (default) and an engine is available, attempt an
  interactive map. If no engine is available this is ignored and a data
  frame is returned.

## Value

A list of class `flood_map` with elements `layer`, `rendered` (logical:
whether an interactive/graphic map was drawn), `engine` (the engine
used, or `"none"`), and `data` (a tidy summary of the mapped values).
When an interactive map is produced, the map object is attached as
`map`.

## See also

[`flood_route`](https://gowusu.github.io/floodflow/reference/flood_route.md),
[`flood_vulnerability`](https://gowusu.github.io/floodflow/reference/flood_vulnerability.md).

## Examples

``` r
set.seed(1)
rain <- data.frame(
  date = seq(as.Date("1990-01-01"), as.Date("2020-12-31"), by = "day"),
  precip_mm = round(rgamma(11323, 0.7, scale = 6) *
                    rbinom(11323, 1, 0.3), 1)
)
fp <- flood_project("demo")
fp$rainfall <- rain
fp <- flood_runoff(fp, engine = "simple")
fp <- flood_route(fp, area_km2 = 300)
m <- flood_map(fp, layer = "depth")
m$data
#>   layer   min  mean   max
#> 1 depth 1.236 1.236 1.236
```
