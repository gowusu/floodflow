# Summarise a flood project

Summarise a flood project

## Usage

``` r
# S3 method for class 'flood_project'
summary(object, ...)
```

## Arguments

- object:

  A `flood_project` object.

- ...:

  Ignored, present for S3 method consistency.

## Value

A `data.frame` with one row per pipeline slot and columns `slot` and
`status` (either `"populated"` or `"empty"`), returned invisibly after
printing.

## Examples

``` r
summary(flood_project(name = "Odaw basin"))
#> Summary of <flood_project> 'Odaw basin'
#>           slot status
#>            dem  empty
#>       rainfall  empty
#>       extremes  empty
#>       scenario  empty
#>      roughness  empty
#>         runoff  empty
#>          route  empty
#>     hydraulics  empty
#>    uncertainty  empty
#>  vulnerability  empty
```
