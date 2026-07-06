# Time of concentration by the Kerby method (overland flow)

The Kerby formula for overland (sheet) flow time of concentration,
suited to the upstream portion of a catchment before channel flow
begins. Often combined with Kirpich channel time in the Kerby-Kirpich
approach.

## Usage

``` r
tc_kerby(length_m, slope, retardance = 0.4)
```

## Arguments

- length_m:

  Overland flow length in metres.

- slope:

  Overland slope (dimensionless).

- retardance:

  Kerby retardance roughness coefficient (dimensionless); higher for
  rougher surfaces. Default `0.4` (average grass).

## Value

Overland time of concentration in minutes.

## References

Kerby, W. S. (1959) Time of concentration for overland flow. Civil
Engineering, 29(3), 174.

## Examples

``` r
tc_kerby(100, 0.01, retardance = 0.4)
#> [1] 23.79713
```
