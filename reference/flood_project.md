# Create a flood project object

Constructs the container object that carries data and results through
every stage of the floodflow pipeline. A `flood_project` is a named list
with a fixed set of slots; pipeline functions read from and write to
these slots, so a single object accumulates the DEM, rainfall record,
fitted extreme-value model, routed discharge, water depth and derived
maps as it passes through the workflow.

## Usage

``` r
flood_project(name = "flood_project", crs = NULL, meta = list())
```

## Arguments

- name:

  Character scalar naming the project or study basin, used in printing
  and map titles. Defaults to `"flood_project"`.

- crs:

  Optional character scalar giving the target coordinate reference
  system as an EPSG string (for example `"EPSG:32630"` for UTM zone 30N,
  appropriate for Accra). Stored for later stages; not applied here.

- meta:

  Optional named list of user metadata to attach to the project (for
  example data provenance notes). Defaults to an empty list.

## Value

An object of class `flood_project`: a named list with slots `name`,
`crs`, `meta`, `dem`, `rainfall`, `extremes`, `scenario`, `roughness`,
`runoff`, `route`, `hydraulics`, `uncertainty`, `vulnerability` and
`log`. All data slots are `NULL` until populated by later pipeline
functions. The `log` slot is a character vector recording the stages
that have been run.

## Details

The constructor deliberately performs no geospatial work and has no
heavy dependencies, so it can be created and inspected without terra or
any modelling engine installed. Slots that are not yet populated are
held as `NULL`.

## See also

[`is_flood_project`](https://gowusu.github.io/floodflow/reference/is_flood_project.md)
to test the class.

## Examples

``` r
fp <- flood_project(name = "Odaw basin")
fp
#> <flood_project>
#>   name: Odaw basin
#>   crs:  <unset>
#>   populated: <none yet>
is_flood_project(fp)
#> [1] TRUE
```
