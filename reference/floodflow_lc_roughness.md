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

## Examples

``` r
floodflow_lc_roughness["forest"]
#> forest 
#>    0.1 
```
