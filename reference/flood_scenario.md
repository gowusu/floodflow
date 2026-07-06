# Generate a climate-adjusted design flood event

Turns the design return levels from
[`flood_extremes`](https://gowusu.github.io/floodflow/reference/flood_extremes.md)
into a scenario for a chosen future, so that a flood can be modelled
under present-day or changed-climate conditions. Three methods are
offered, from zero-dependency to full-fidelity:

## Usage

``` r
flood_scenario(
  x,
  method = c("delta", "trend", "cmip6"),
  change_factor = 1.15,
  horizon_year = NULL,
  scenario_label = NULL
)
```

## Arguments

- x:

  A `flood_project` whose `extremes` slot has been populated by
  [`flood_extremes`](https://gowusu.github.io/floodflow/reference/flood_extremes.md),
  or a `flood_extremes` object directly.

- method:

  One of `"delta"` (default), `"trend"` or `"cmip6"`.

- change_factor:

  Numeric multiplier for `method = "delta"`. A value of 1 leaves
  rainfall unchanged; 1.15 raises it by 15%. Ignored by other methods.

- horizon_year:

  Target year for `method = "trend"`. The location trend is projected
  from the end of the record to this year. Ignored by other methods.

- scenario_label:

  Optional character label for the scenario (for example
  `"SSP5-8.5 2050"`), stored with the result and used in maps.

## Value

If `x` is a `flood_project`, the same object with its `scenario` slot
populated. Otherwise a list of class `flood_scenario` with elements
`method`, `label`, `baseline` (the present-day return-level data frame),
`adjusted` (a data frame of `period` and `level_mm` under the scenario),
and `change` (the ratio of adjusted to baseline at each period).

## Details

- `"trend"`:

  Extrapolate the fitted non-stationary location trend forward to a
  target year. Uses only the record already analysed.

- `"delta"`:

  Scale the stationary return levels by a change factor (for example
  1.15 for a 15% increase). The default and recommended route for
  data-scarce settings; change factors can come from published CMIP6
  summaries per Shared Socioeconomic Pathway.

- `"cmip6"`:

  Placeholder for ingesting downscaled CMIP6 projections directly; not
  yet implemented, and currently returns an informative error. Use
  `"delta"` with a CMIP6-derived change factor in the meantime.

## References

IPCC (2021). *Climate Change 2021: The Physical Science Basis*.
Contribution of Working Group I to the Sixth Assessment Report of the
Intergovernmental Panel on Climate Change. Cambridge University Press.

## See also

[`flood_extremes`](https://gowusu.github.io/floodflow/reference/flood_extremes.md)
for the design levels this adjusts.

## Examples

``` r
set.seed(1)
rain <- data.frame(
  date = seq(as.Date("1985-01-01"), as.Date("2024-12-31"), by = "day"),
  precip_mm = round(rgamma(14610, 0.7, scale = 6) *
                    rbinom(14610, 1, 0.3), 1)
)
ext <- flood_extremes(rain)

# 15% wetter design storm
sc <- flood_scenario(ext, method = "delta", change_factor = 1.15,
                     scenario_label = "SSP2-4.5 2050")
sc$adjusted
#>   period level_mm
#> 1      2    28.69
#> 2     10    39.70
#> 3     25    45.48
#> 4     50    49.88
#> 5    100    54.35
```
