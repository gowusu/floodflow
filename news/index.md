# Changelog

## floodflow 0.1.0

### Pipeline stages

- [`flood_extremes()`](https://gowusu.github.io/floodflow/reference/flood_extremes.md)
  fits the generalized extreme value distribution to annual maximum
  rainfall, both stationary and with a linear trend in location, and
  reports a likelihood-ratio test for changing extremes together with
  design return levels. A dependency-free maximum-likelihood engine is
  used by default; `extRemes` is used when installed and requested.

- [`flood_scenario()`](https://gowusu.github.io/floodflow/reference/flood_scenario.md)
  turns design return levels into a present-day or climate-adjusted
  event by three methods: `"delta"` (change-factor scaling, the
  default), `"trend"` (projecting the fitted location trend forward) and
  `"cmip6"` (reserved for downscaled projections).

- [`roughness()`](https://gowusu.github.io/floodflow/reference/roughness.md)
  assigns Manning’s roughness by three methods: `"constant"`,
  `"landcover"` (lookup from a table, defaulting to
  `floodflow_lc_roughness`, and user-overridable) and `"ndvi"` (a
  monotonic empirical function of vegetation index). Works on vectors
  and, where `terra` is installed, on rasters.

- [`flood_runoff()`](https://gowusu.github.io/floodflow/reference/flood_runoff.md)
  converts rainfall into a discharge series. Potential
  evapotranspiration is computed by the Oudin formula
  ([`pet_oudin()`](https://gowusu.github.io/floodflow/reference/pet_oudin.md))
  from temperature and latitude. GR4J via `airGR` is used when
  installed; otherwise a mass-conserving conceptual fallback with
  routing lag runs.

- [`flood_route()`](https://gowusu.github.io/floodflow/reference/flood_route.md)
  provides a five-method routing ladder that turns discharge into a
  routed hydrograph and a water depth: `"manning-normal"`,
  `"kinematic"`, `"diffusive"`, `"muskingum-cunge"` (default) and
  `"dynamic"`. Depth comes from Manning’s equation; hydrograph routing
  uses the numerically stable Muskingum-Cunge family, varying its
  diffusion across the ladder.

- [`flood_hydraulics()`](https://gowusu.github.io/floodflow/reference/flood_hydraulics.md)
  derives the time-and-motion family from routed flow: peak velocity,
  time of concentration by the Kirpich, Kerby, combined Kerby-Kirpich
  and velocity methods
  ([`tc_kirpich()`](https://gowusu.github.io/floodflow/reference/tc_kirpich.md),
  [`tc_kerby()`](https://gowusu.github.io/floodflow/reference/tc_kerby.md)),
  channel travel time, and an event-relative time-to-peak.

- [`flood_uncertainty()`](https://gowusu.github.io/floodflow/reference/flood_uncertainty.md)
  applies Generalized Likelihood Uncertainty Estimation (GLUE): it
  samples roughness and width from priors, weights each run by its
  agreement with an observed depth, and returns a predictive depth band
  and inverse parameter estimates. Equifinality among parameters is
  reported rather than hidden.

- [`flood_vulnerability()`](https://gowusu.github.io/floodflow/reference/flood_vulnerability.md)
  combines hazard, exposure and vulnerability into a normalised risk
  index (Risk = Hazard x Exposure x Vulnerability), identifying hotspots
  where deep flooding meets dense, susceptible population.

- [`flood_surrogate()`](https://gowusu.github.io/floodflow/reference/flood_surrogate.md)
  trains a fast emulator (random forest via `ranger`, or a log-linear
  fallback) of the depth model for rapid what-if exploration.

- [`flood_route()`](https://gowusu.github.io/floodflow/reference/flood_route.md)
  gains an optional `hand` argument: supply a Height Above Nearest
  Drainage surface (or a DEM) and it produces a spatial inundation-depth
  raster, `depth_raster`, which `flood_map(layer = "depth")` draws as a
  real inundation map.

- [`flood_map()`](https://gowusu.github.io/floodflow/reference/flood_map.md)
  renders a chosen layer (depth, risk, velocity, uncertainty) as an
  interactive map via `tmap` or `leaflet` when available, and always
  returns a tidy value summary so the pipeline works without mapping
  engines.

### Infrastructure

- Added the `flood_project` object that carries data and results through
  the pipeline, with [`print()`](https://rdrr.io/r/base/print.html) and
  [`summary()`](https://rspatial.github.io/terra/reference/summary.html)
  methods and an
  [`is_flood_project()`](https://gowusu.github.io/floodflow/reference/is_flood_project.md)
  predicate.
- Established the CRAN-ready package skeleton: lean `Imports` (only
  `stats` and `utils`), all modelling engines under `Suggests` with
  graceful guards, MIT license, `testthat` (edition 3) test suite, and
  continuous integration.
