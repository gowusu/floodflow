# Quantify uncertainty and invert for parameters (GLUE)

Applies Generalized Likelihood Uncertainty Estimation (GLUE) to the
routing stage. Uncertain parameters (Manning's roughness and channel
width) are sampled from priors, the flood depth is predicted for each
sample, and each sample is weighted by an informal likelihood measuring
its agreement with an observed depth. This yields a predictive
uncertainty band on flood depth and, as the inverse problem, weighted
parameter estimates conditioned on the observation.

## Usage

``` r
flood_uncertainty(
  x,
  observed_depth_m,
  n_sim = 5000,
  n_range = c(0.02, 0.08),
  width_range = c(10, 40),
  obs_error = 0.1,
  behavioural_fraction = 0.1,
  seed = NULL
)
```

## Arguments

- x:

  A `flood_project` whose `route` slot has been populated, or a
  `flood_route` object directly. The routing settings (slope, area, peak
  discharge) are taken from it.

- observed_depth_m:

  Observed peak flood depth in metres to condition on, for example from
  a surveyed high-water mark or satellite estimate.

- n_sim:

  Number of Monte-Carlo samples. Default `5000`.

- n_range:

  Length-2 numeric range for the Manning's \\n\\ prior. Default
  `c(0.02, 0.08)`.

- width_range:

  Length-2 numeric range for the channel width prior (m). Default
  `c(10, 40)`.

- obs_error:

  Relative observation error (standard deviation as a fraction of the
  observed depth) used in the Gaussian likelihood. Default `0.1`.

- behavioural_fraction:

  Fraction of samples, ranked by likelihood, kept as behavioural.
  Default `0.1`.

- seed:

  Optional integer seed for reproducibility.

## Value

If `x` is a `flood_project`, the same object with its `uncertainty` slot
populated. Otherwise a list of class `flood_uncertainty` with elements
`observed_depth_m`, `n_behavioural` (count kept), `depth_band` (named
vector: lower, median, upper of the weighted predictive band),
`obs_in_band` (logical), `estimates` (weighted-mean and range for each
parameter), `equifinality` (the n-width correlation among behavioural
sets), and `behavioural` (a data frame of kept samples and weights).

## Details

GLUE is the workhorse uncertainty method in hydrology. A key feature it
reveals is equifinality: many different parameter combinations can
reproduce the same observation, so individual parameters may stay
uncertain even when the prediction is well constrained. The function
reports the parameter spread honestly rather than collapsing it to a
single point.

## References

Beven, K. and Binley, A. (1992) The future of distributed models: model
calibration and uncertainty prediction. Hydrological Processes 6,
279–298.
[doi:10.1002/hyp.3360060305](https://doi.org/10.1002/hyp.3360060305)

## See also

[`flood_route`](https://gowusu.github.io/floodflow/reference/flood_route.md)
for the model being conditioned.

## Examples

``` r
disc <- data.frame(
  date = seq(as.Date("2020-06-01"), by = "day", length.out = 12),
  Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1)
)
r <- flood_route(disc, method = "muskingum-cunge", area_km2 = 300)
u <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                       n_sim = 2000, seed = 1)
u$depth_band
#>  lower median  upper 
#>  2.739  2.853  2.966 
u$obs_in_band
#> [1] TRUE
```
