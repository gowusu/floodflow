# Print a flood project

Print a flood project

## Usage

``` r
# S3 method for class 'flood_project'
print(x, ...)
```

## Arguments

- x:

  A `flood_project` object.

- ...:

  Ignored, present for S3 method consistency.

## Value

The `flood_project` object `x`, returned invisibly. Called for the side
effect of printing a compact summary to the console.

## Examples

``` r
print(flood_project(name = "Odaw basin"))
#> <flood_project>
#>   name: Odaw basin
#>   crs:  <unset>
#>   populated: <none yet>
```
