# Daily rainfall and temperature for Accra, Ghana (1981 to present)

A long-term daily weather record for Accra, on which the manual's lumped
pipeline is built. It is real observed-and-reanalysis data retrieved
from the NASA POWER service with `sebkc::weather()` for the Odaw basin
(latitude 5.60 N, longitude 0.20 W), then reduced to the columns
floodflow consumes. It is bundled with the package so the examples and
manual keep working even if the online service is unavailable; drop it
straight onto a
[`flood_project`](https://gowusu.github.io/floodflow/reference/flood_project.md)
as the `rainfall` slot. See the manual for how to fetch an equivalent
record for your own location.

## Usage

``` r
accra_rainfall
```

## Format

A data frame with 16637 rows and 3 variables:

- date:

  Date. Calendar day, `YYYY-mm-dd`.

- precip_mm:

  numeric. Daily precipitation in millimetres (NASA POWER
  `PRECTOTCORR`).

- temp_c:

  numeric. Daily mean air temperature in degrees Celsius (NASA POWER
  `T2M`); used by the Oudin potential-evapotranspiration step inside
  [`flood_runoff`](https://gowusu.github.io/floodflow/reference/flood_runoff.md).

## Source

NASA POWER daily point data, <https://power.larc.nasa.gov>, for latitude
5.60, longitude -0.20, retrieved with `sebkc::weather()`.

## Value

A data frame of 16637 daily records (1981-01-01 to 2026-07-20) with
three columns: `date` (Date), `precip_mm` (numeric, mm) and `temp_c`
(numeric, degrees C). It is the default worked-example rainfall record
used throughout the floodflow manual.

## Examples

``` r
fp <- flood_project("Odaw basin, Accra")
fp$rainfall <- accra_rainfall
fp <- flood_extremes(fp)
fp$extremes
#> <flood_extremes>
#>   years of record: 46
#>   GEV (stationary): mu=30.47 sigma=9.18 shape=0.252
#>   location trend (mm/yr): 0.0427
#>   trend test: LR=0.13 p=0.72  (no significant trend)
#>   return levels (mm):
#>        2-yr: 34.0
#>       10-yr: 58.3
#>       25-yr: 75.6
#>       50-yr: 91.4
#>      100-yr: 110.1
```
