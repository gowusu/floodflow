# Print a roughness result

Print a roughness result

## Usage

``` r
# S3 method for class 'flood_roughness'
print(x, ...)
```

## Arguments

- x:

  A `flood_roughness` object.

- ...:

  Ignored, present for S3 method consistency.

## Value

The object `x`, invisibly; prints a compact summary.

## Examples

``` r
print(roughness(method = "constant", value = 0.04))
#> <flood_roughness>
#>   method: constant
#>   type:   constant
#>   Manning n: min=0.040 mean=0.040 max=0.040
```
