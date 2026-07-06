# Assign Manning's roughness

Produces a Manning's roughness coefficient (\\n\\) for use by the
routing stage, by one of three methods. Roughness is the single most
sensitive hydraulic parameter, so the function makes the choice explicit
and always lets the user override it.

## Usage

``` r
roughness(
  x = NULL,
  method = c("constant", "landcover", "ndvi"),
  value = 0.035,
  table = floodflow_lc_roughness,
  n_min = 0.02,
  n_max = 0.12,
  data = NULL
)
```

## Arguments

- x:

  A `flood_project`, or a data input directly. For `method = "constant"`
  the data input is ignored. For `method = "landcover"` it is a
  character/factor vector of classes or a land-cover `SpatRaster`. For
  `method = "ndvi"` it is a numeric vector or an NDVI `SpatRaster`.

- method:

  One of `"constant"`, `"landcover"` or `"ndvi"`.

- value:

  Manning's \\n\\ for `method = "constant"`. Default `0.035` (natural
  channel).

- table:

  Named numeric vector mapping land-cover classes to \\n\\ for
  `method = "landcover"`. Defaults to
  [`floodflow_lc_roughness`](https://gowusu.github.io/floodflow/reference/floodflow_lc_roughness.md).

- n_min, n_max:

  Roughness bounds for `method = "ndvi"`.

- data:

  Optional explicit data input when `x` is a `flood_project`; overrides
  looking in the project. Land-cover classes or NDVI values, as a vector
  or `SpatRaster`.

## Value

If `x` is a `flood_project`, the same object with its `roughness` slot
populated by a list of class `flood_roughness`. Otherwise the
`flood_roughness` list directly, with elements `method`, `n` (the
resulting roughness: a scalar, numeric vector, or `SpatRaster`), and
`summary` (min, mean and max of \\n\\).

## Details

- `"constant"`:

  A single \\n\\ applied everywhere. Simplest and fully reproducible.

- `"landcover"`:

  Look up \\n\\ from land-cover classes using a table (the built-in
  [`floodflow_lc_roughness`](https://gowusu.github.io/floodflow/reference/floodflow_lc_roughness.md)
  by default, or a user-supplied named vector).

- `"ndvi"`:

  Derive \\n\\ from NDVI with a monotonic empirical function, so
  remotely-sensed vegetation density sets roughness.

The function operates on plain vectors and, when terra is installed, on
raster inputs (`SpatRaster`). Raster handling is optional: if the input
is a raster and terra is not available, the function stops with an
informative message.

## References

Manning, R. (1891). On the flow of water in open channels and pipes.
*Transactions of the Institution of Civil Engineers of Ireland*, 20,
161-207.

Chow, V. T. (1959). *Open-Channel Hydraulics*. McGraw-Hill, New York.

## See also

[`floodflow_lc_roughness`](https://gowusu.github.io/floodflow/reference/floodflow_lc_roughness.md)
for the default lookup table.

## Examples

``` r
# Constant roughness
roughness(method = "constant", value = 0.03)
#> <flood_roughness>
#>   method: constant
#>   type:   constant
#>   Manning n: min=0.030 mean=0.030 max=0.030

# From land-cover classes
cls <- c("urban", "cropland", "forest", "water")
roughness(cls, method = "landcover")$n
#> [1] 0.015 0.040 0.100 0.030

# From NDVI values
roughness(c(0, 0.3, 0.6, 0.9), method = "ndvi")$n
#> [1] 0.02 0.05 0.08 0.11
```
