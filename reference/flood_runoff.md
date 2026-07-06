# Simulate discharge from rainfall

Converts a daily rainfall record into a discharge (streamflow) series,
the link between rainfall in the sky and water in the channel. floodflow
operates on a daily timestep: each row of the rainfall data frame is one
day, and discharge is returned in mm/day; aggregate any sub-daily record
to daily totals before use. Potential evapotranspiration is computed by
the Oudin formula from temperature and latitude. When airGR is
installed, the GR4J lumped conceptual model is used; otherwise a simple
conceptual fallback runs so the pipeline still produces a discharge
series.

## Usage

``` r
flood_runoff(
  x,
  lat_deg = 5.6,
  temp_c = 28,
  params = NULL,
  engine = c("auto", "airGR", "simple")
)
```

## Arguments

- x:

  A `flood_project` whose `rainfall` slot holds a data frame with `date`
  and `precip_mm`, or such a data frame directly. A `temp_c` column is
  used if present; otherwise a constant temperature is assumed.

- lat_deg:

  Latitude in decimal degrees, for PET. Defaults to `5.6` (Accra).

- temp_c:

  Constant air temperature (degrees C) used when the rainfall data has
  no `temp_c` column. Default `28`.

- params:

  Optional named numeric vector of GR4J parameters `X1`, `X2`, `X3`,
  `X4`. Ignored by the fallback.

- engine:

  Which engine to use: `"auto"` (GR4J if airGR is present, else the
  fallback), `"airGR"` (require GR4J) or `"simple"` (force the
  fallback).

## Value

If `x` is a `flood_project`, the same object with its `runoff` slot
populated. Otherwise a list of class `flood_runoff` with elements
`discharge` (a data frame of `date` and `Q_mm`), `pet` (the PET series),
`engine` used, and `peak` (the maximum discharge and its date).

## Details

GR4J parameters may be supplied; if not, illustrative defaults are used.
In a real study with observed discharge, calibrate the parameters (for
example with
[`airGR::Calibration_Michel`](https://rdrr.io/pkg/airGR/man/Calibration_Michel.html))
before relying on the output.

Infiltration is represented *implicitly*, not as a separate step.
Rainfall is partitioned into runoff and soil storage by a production
store (a soil-moisture bucket of capacity `store_max`): when the soil is
dry most rain infiltrates and little runs off, and as it saturates the
runoff fraction rises toward one. This is a saturation-excess
representation. There is no explicit Green-Ampt, Horton, or SCS
curve-number infiltration function in this version (curve-number
infiltration is planned for a future release).

## See also

[`pet_oudin`](https://gowusu.github.io/floodflow/reference/pet_oudin.md)
for the evapotranspiration input.

## Examples

``` r
set.seed(1)
dates <- seq(as.Date("2020-01-01"), as.Date("2021-12-31"), by = "day")
rain <- data.frame(
  date = dates,
  precip_mm = round(rgamma(length(dates), 0.7, scale = 8) *
                    rbinom(length(dates), 1, 0.4), 1)
)
rr <- flood_runoff(rain, engine = "simple")
rr$peak
#> $Q_mm
#> [1] 7.9298
#> 
#> $date
#> [1] "2021-12-07"
#> 
```
