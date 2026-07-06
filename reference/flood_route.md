# Route flow and compute water depth

Converts the discharge series from
[`flood_runoff`](https://gowusu.github.io/floodflow/reference/flood_runoff.md)
into a routed hydrograph and a water depth, using one of five methods
that form a complexity ladder. All methods obtain depth from Manning's
equation for a wide channel; they differ in how the flood wave is
routed, from a steady baseline to progressively more physics.

## Usage

``` r
flood_route(
  x,
  method = c("muskingum-cunge", "manning-normal", "kinematic", "diffusive", "dynamic"),
  width = 20,
  slope = 0.001,
  n = 0.035,
  celerity = 1.5,
  dx = 1000,
  dt = 86400,
  area_km2 = 100,
  hand = NULL
)
```

## Arguments

- x:

  A `flood_project` whose `runoff` slot has been populated, or a
  discharge `data.frame` with columns `date` and `Q_mm`.

- method:

  One of `"muskingum-cunge"` (default), `"manning-normal"`,
  `"kinematic"`, `"diffusive"` or `"dynamic"`.

- width:

  Representative channel width in metres. Default `20`.

- slope:

  Representative bed slope (dimensionless). Default `0.001`.

- n:

  Manning's roughness. If `x` is a project with a scalar roughness set,
  that value is used unless `n` is given explicitly. Default `0.035`.

- celerity:

  Wave celerity in m/s for routing. Default `1.5`.

- dx:

  Reach length in metres for routing. Default `1000`.

- dt:

  Time step in seconds. Default `86400` (daily).

- area_km2:

  Catchment area in square kilometres, used to convert runoff depth
  (mm/day) to volumetric discharge (m^3/s). Default `100`.

- hand:

  Optional Height Above Nearest Drainage surface as a numeric vector or,
  with terra installed, a `SpatRaster`. When supplied, the scalar peak
  depth is turned into a spatial inundation-depth field (flooding cells
  whose height above drainage is below the peak water level), stored as
  `depth_raster` and drawn by
  [`flood_map`](https://gowusu.github.io/floodflow/reference/flood_map.md).
  A raw DEM may be passed for a crude proxy. Default `NULL` (no spatial
  depth).

## Value

If `x` is a `flood_project`, the same object with its `route` slot
populated. Otherwise a list of class `flood_route` with elements
`method`, `routed` (a data frame of `date`, `Q_cms` inflow and
`Q_routed` outflow), `peak_depth_m`, `peak_velocity_ms`, `attenuation`
(routed peak divided by inflow peak), `depth_raster` (a spatial
inundation-depth field when `hand` was supplied, otherwise `NULL`) and
the hydraulic settings used.

## Details

- `"manning-normal"`:

  Steady uniform flow. Depth is the Manning normal depth of the
  (unrouted) peak discharge. The fast baseline.

- `"kinematic"`:

  Kinematic wave: near-pure translation of the hydrograph with
  negligible attenuation. Suited to steeper channels.

- `"diffusive"`:

  Diffusive wave: adds hydraulic diffusion so the peak attenuates and
  backwater effects appear.

- `"muskingum-cunge"`:

  Physically-based storage routing at diffusive-wave accuracy and low
  cost. The pragmatic default.

- `"dynamic"`:

  Uses the discharge-scaled hydraulic diffusivity as the best stable
  approximation available in pure R. Full two-dimensional Saint-Venant
  hydrodynamics are out of scope; for those, couple to a dedicated
  hydraulic model.

All routing is carried out with the numerically stable Muskingum-Cunge
family, varying its diffusion to represent each rung of the ladder.

## References

Cunge, J. A. (1969). On the subject of a flood propagation computation
method (Muskingum method). *Journal of Hydraulic Research*, 7(2),
205-230.

Manning, R. (1891). On the flow of water in open channels and pipes.
*Transactions of the Institution of Civil Engineers of Ireland*, 20,
161-207.

## See also

[`flood_runoff`](https://gowusu.github.io/floodflow/reference/flood_runoff.md)
for the discharge this routes.

## Examples

``` r
set.seed(1)
dates <- seq(as.Date("2020-06-01"), by = "day", length.out = 30)
Q <- c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1, rep(0, 18))
disc <- data.frame(date = dates, Q_mm = Q)

r_mc  <- flood_route(disc, method = "muskingum-cunge")
r_kin <- flood_route(disc, method = "kinematic")
# Kinematic attenuates less than Muskingum-Cunge
r_kin$attenuation >= r_mc$attenuation
#> [1] TRUE

# Spatial inundation depth from a HAND surface (a numeric vector here; a
# terra SpatRaster works the same way and produces a mappable raster)
hand <- c(0, 0.5, 1, 2, 4, 6)
r_spatial <- flood_route(disc, area_km2 = 300, hand = hand)
r_spatial$depth_raster        # deepest in the valley, dry on high ground
#> [1] 2.8553495 2.3553495 1.8553495 0.8553495 0.0000000 0.0000000
```
