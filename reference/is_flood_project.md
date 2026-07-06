# Test whether an object is a flood project

Test whether an object is a flood project

## Usage

``` r
is_flood_project(x)
```

## Arguments

- x:

  An object to test.

## Value

A single logical value: `TRUE` if `x` inherits from class
`flood_project`, otherwise `FALSE`.

## Examples

``` r
is_flood_project(flood_project())
#> [1] TRUE
is_flood_project(list())
#> [1] FALSE
```
