# Derive hydraulic quantities from routed flow

Computes the family of time-and-motion quantities that a routed flood
implies: peak flow velocity, time of concentration (by one or more
methods), channel travel time, and the time-to-peak of the routed
hydrograph. These are the layers a geographer maps alongside depth.

## Usage

``` r
flood_hydraulics(
  x,
  length_m = 5000,
  overland_m = 100,
  retardance = 0.4,
  dt_hours = 24
)
```

## Arguments

- x:

  A `flood_project` whose `route` slot has been populated, or a
  `flood_route` object directly.

- length_m:

  Representative flow-path (channel) length in metres, used for time of
  concentration and travel time. Default `5000`.

- overland_m:

  Overland flow length in metres for the Kerby component. Default `100`.

- retardance:

  Kerby retardance coefficient. Default `0.4`.

- dt_hours:

  Time step of the routed hydrograph in hours, used to convert the
  time-to-peak index into hours. Default `24` (daily).

## Value

If `x` is a `flood_project`, the same object with its `hydraulics` slot
populated. Otherwise a list of class `flood_hydraulics` with elements
`peak_velocity_ms`, `tc` (a named vector of times of concentration in
minutes by method: `kirpich`, `kerby`, `kerby_kirpich`, `velocity`),
`travel_time_min`, and `time_to_peak_hours`.

## Details

Velocity comes from Manning's equation at the routed peak depth. Time of
concentration is available by the Kirpich channel method, the Kerby
overland method, the combined Kerby-Kirpich sum, and a velocity-based
travel time (flow-path length divided by peak velocity). Time-to-peak is
read directly from the routed hydrograph.

## See also

[`tc_kirpich`](https://gowusu.github.io/floodflow/reference/tc_kirpich.md),
[`tc_kerby`](https://gowusu.github.io/floodflow/reference/tc_kerby.md).

## Examples

``` r
disc <- data.frame(
  date = seq(as.Date("2020-06-01"), by = "day", length.out = 15),
  Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1, 0, 0, 0)
)
r <- flood_route(disc, method = "muskingum-cunge")
h <- flood_hydraulics(r, length_m = 4000, overland_m = 120)
h$tc
#>       kirpich         kerby kerby_kirpich      velocity 
#>        165.43         44.51        206.11         56.88 
h$peak_velocity_ms
#> [1] 1.172
```
