# Getting started with floodflow

`floodflow` turns a rainfall record and a bit of catchment description
into a flood hazard assessment, and it is built for places with sparse
data. The whole workflow is a chain of stages carried by a single
object, and every stage is designed to return something you could map.

This vignette runs end to end using only the pure-R core, so it works
without any of the optional modelling engines installed. Where an engine
(such as `terra`, `airGR` or `tmap`) would add capability, the text says
so.

``` r

library(floodflow)
```

## The project object

Everything hangs on one object,
[`flood_project()`](https://gowusu.github.io/floodflow/reference/flood_project.md),
which accumulates data and results as it passes through the pipeline. It
starts almost empty.

``` r

fp <- flood_project("Odaw basin, Accra", crs = "EPSG:32630")
fp
#> <flood_project>
#>   name: Odaw basin, Accra
#>   crs:  EPSG:32630
#>   populated: <none yet>
```

## A minimal end-to-end run

With a daily rainfall record in hand, a flood depth is only a few steps
away. Here we build a synthetic 31-year record, then run rainfall
analysis, runoff and routing.

``` r

dates <- seq(as.Date("1990-01-01"), as.Date("2020-12-31"), by = "day")
rain <- data.frame(
  date = dates,
  precip_mm = round(rgamma(length(dates), 0.7, scale = 7) *
                    rbinom(length(dates), 1, 0.3), 1)
)

fp$rainfall <- rain
fp <- flood_extremes(fp)
fp <- flood_runoff(fp, engine = "simple")
fp <- flood_route(fp, area_km2 = 300)

fp$route
#> <flood_route>
#>   method: muskingum-cunge
#>   peak depth:    1.50 m
#>   peak velocity: 1.19 m/s
#>   attenuation:   0.996 (routed peak / inflow peak)
#>   channel: width=20m  slope=0.001  n=0.035
```

That is the shortest path from rain to a routed flood depth. The
remaining stages add climate scenarios, roughness detail, hydraulics,
uncertainty, risk and mapping.

## Rainfall extremes and a test for change

[`flood_extremes()`](https://gowusu.github.io/floodflow/reference/flood_extremes.md)
fits the generalized extreme value distribution to annual maximum
rainfall and, at the same time, tests whether extremes are intensifying
by comparing a stationary fit against one whose location trends with
time.

``` r

fp$extremes
#> <flood_extremes>
#>   years of record: 31
#>   GEV (stationary): mu=28.56 sigma=7.68 shape=-0.012
#>   location trend (mm/yr): 0.0121
#>   trend test: LR=0.01 p=0.939  (no significant trend)
#>   return levels (mm):
#>        2-yr: 31.4
#>       10-yr: 45.6
#>       25-yr: 52.7
#>       50-yr: 57.9
#>      100-yr: 63.0
```

The `return_levels` give design rainfall by return period;
`trend_detected` reports the outcome of the likelihood-ratio test.

## Climate scenarios

[`flood_scenario()`](https://gowusu.github.io/floodflow/reference/flood_scenario.md)
turns today’s design rainfall into a future one. The `delta` method
scales by a change factor (for example from a published CMIP6 summary),
while `trend` projects the fitted trend forward. Here they sit side by
side.

``` r

baseline <- fp$extremes$return_levels
delta   <- flood_scenario(fp$extremes, method = "delta",
                          change_factor = 1.2)$adjusted
trend   <- flood_scenario(fp$extremes, method = "trend",
                          horizon_year = 2060)$adjusted

data.frame(
  period      = baseline$period,
  present_mm  = baseline$level_mm,
  delta_mm    = delta$level_mm,
  trend_mm    = trend$level_mm
)
#>   period present_mm delta_mm trend_mm
#> 1      2      31.37    37.64    32.03
#> 2     10      45.62    54.74    46.29
#> 3     25      52.67    63.21    53.35
#> 4     50      57.86    69.43    58.55
#> 5    100      62.96    75.55    63.66
```

## Roughness

Manning’s roughness is the most sensitive hydraulic input, so
[`roughness()`](https://gowusu.github.io/floodflow/reference/roughness.md)
makes the choice explicit. It can be a constant, a lookup from land
cover, or a function of vegetation index.

``` r

roughness(method = "constant", value = 0.035)$n
#> [1] 0.035
roughness(c("urban", "cropland", "forest", "water"), method = "landcover")$n
#> [1] 0.015 0.040 0.100 0.030
```

The land-cover values come from the built-in `floodflow_lc_roughness`
table, which you can replace with your own.

## The routing ladder

[`flood_route()`](https://gowusu.github.io/floodflow/reference/flood_route.md)
offers five methods of increasing physical detail. They share a depth
calculation but differ in how the flood wave attenuates. Sending one
hydrograph through several methods shows the ordering: kinematic routing
keeps the peak highest, diffusive attenuates it most.

``` r

event <- data.frame(
  date = seq(as.Date("2020-06-01"), by = "day", length.out = 20),
  Q_mm = c(0, 1, 3, 8, 18, 30, 50, 40, 30, 20, 12, 7, 4, 2, 1, rep(0, 5))
)

sapply(c("kinematic", "muskingum-cunge", "diffusive"),
       function(m) flood_route(event, method = m, area_km2 = 300)$attenuation)
#>       kinematic muskingum-cunge       diffusive 
#>          0.9957          0.9957          0.9958
```

Values nearer 1 retain more of the peak. The attenuation falls as the
method adds diffusion, which is the physically expected ordering.

## Hydraulics

From a routed flood,
[`flood_hydraulics()`](https://gowusu.github.io/floodflow/reference/flood_hydraulics.md)
derives velocity, time of concentration by several formulae, travel time
and an event-relative time-to-peak.

``` r

fp <- flood_hydraulics(fp, length_m = 12000, overland_m = 200)
fp$hydraulics$tc
#>       kirpich         kerby kerby_kirpich      velocity 
#>        385.48         56.51        437.03        168.78
```

## Uncertainty and calibration

[`flood_uncertainty()`](https://gowusu.github.io/floodflow/reference/flood_uncertainty.md)
applies GLUE: it samples the uncertain parameters, weights each run by
its agreement with an observed depth, and returns a predictive band plus
inverse parameter estimates. It reports the equifinality among
parameters rather than hiding it.

``` r

u <- flood_uncertainty(fp$route,
                       observed_depth_m = fp$route$peak_depth_m,
                       n_sim = 1000, seed = 1)
u$depth_band
#>  lower median  upper 
#>  1.446  1.502  1.554
u$obs_in_band
#> [1] TRUE
```

## Vulnerability and risk

[`flood_vulnerability()`](https://gowusu.github.io/floodflow/reference/flood_vulnerability.md)
combines the hazard with exposure and social vulnerability as
`Risk = Hazard x Exposure x Vulnerability`, so the output is a map of
where deep water meets vulnerable people, not just where water goes.

``` r

set.seed(2)
v <- flood_vulnerability(
  runif(100, 0, fp$route$peak_depth_m),  # hazard (depth) per cell
  exposure = rpois(100, 60),             # population
  vulnerability = runif(100)             # deprivation index
)
v$summary
#>       min      mean       max 
#> 0.0000000 0.1795485 1.0000000
```

## Mapping

[`flood_map()`](https://gowusu.github.io/floodflow/reference/flood_map.md)
renders a chosen layer. With `tmap` or `leaflet` installed and a spatial
layer, it draws an interactive map; otherwise it returns a tidy summary
so the pipeline still works. The scalar example here returns a summary.

``` r

flood_map(fp, layer = "depth")$data
#>   layer   min  mean   max
#> 1 depth 1.502 1.502 1.502
```

## Optional engines

The core shown above is pure R. Installing optional engines upgrades
individual stages: `extRemes` for extreme value fitting, `airGR` for
GR4J runoff, `terra` and `whitebox` for spatial terrain work, `ranger`
for the surrogate, and `tmap` or `leaflet` for interactive maps. Each
stage checks for its engine and falls back or reports clearly when it is
absent, so nothing here breaks if an engine is missing.

For the full range of workflows, including spatial-raster and
engine-based scenarios, see the getting-started guide that ships with
the package.
