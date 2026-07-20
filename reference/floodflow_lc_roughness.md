# Default Manning's roughness by land-cover class

A named numeric vector of representative Manning's \\n\\ values for
common land-cover classes, drawn from standard hydraulic references and
distributed hydrological models. Used as the default lookup by
[`roughness`](https://gowusu.github.io/floodflow/reference/roughness.md)
when `method = "landcover"`. Users may supply their own table.

## Usage

``` r
floodflow_lc_roughness
```

## Format

A named numeric vector. Names are land-cover classes; values are
Manning's \\n\\.

## Value

A named numeric vector of length 8. Each element is a representative
Manning's roughness coefficient \\n\\ (dimensionless) and its name is
the land-cover class it applies to (`"water"`, `"urban"`, `"bare"`,
`"grassland"`, `"cropland"`, `"shrub"`, `"forest"`, `"wetland"`). It is
the default land-cover-to-roughness lookup table used by
[`roughness`](https://gowusu.github.io/floodflow/reference/roughness.md).

## Examples

``` r
floodflow_lc_roughness["forest"]
#> forest 
#>    0.1 
```
