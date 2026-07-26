# floodflow

**floodflow** is a map-first, climate-informed workflow for flood hazard
assessment in data-scarce basins. It chains rainfall extreme-value
analysis, rainfall–runoff simulation, terrain-based flow routing and
water-depth estimation into a single reproducible pipeline, built around
one project object that accumulates data and results as it flows through
the stages.

It is designed for teaching as much as for research: a companion
[floodflow
manual](https://gowusu.github.io/floodflow/articles/floodflow_manual.html)
explains every concept, derives the equations, and includes worked
exercises and projects, using the June 2026 Accra floods as a running
case study.

## Installation

``` r

# install.packages("remotes")
remotes::install_github("gowusu/floodflow")
```

The core is pure R. Optional engines (`terra`, `airGR`, `extRemes`,
`ranger`, `whitebox`, `tmap`) add power to individual stages and are
loaded only when needed; if one is missing, the relevant function tells
you which package to install rather than failing obscurely.

## Quick start

A flood depth from a rainfall record in six lines:

``` r

library(floodflow)

fp <- flood_project("test")
fp$rainfall <- data.frame(date = Sys.Date() + 0:10,
                          precip_mm = c(0,0,0,20,50,30,10,0,0,0,0))
fp <- flood_runoff(fp, lat_deg = 5.6)
fp <- flood_route(fp, width = 25, slope = 0.002, area_km2 = 400)
fp$route$peak_depth_m        # ~2.07 m
```

## Pipeline

    flood_project()      # create the project (ingest DEM + rainfall)
    flood_extremes()     # fit stationary/non-stationary GEV; test for a trend
    flood_scenario()     # trend / delta / CMIP6 climate-adjusted design event
    roughness()          # Manning's n: constant, land cover, or NDVI
    flood_runoff()       # rainfall -> discharge
    flood_route()        # manning-normal / kinematic / diffusive / muskingum-cunge / dynamic
    flood_hydraulics()   # velocity, time of concentration, travel time
    flood_uncertainty()  # GLUE ensemble and inverse calibration
    flood_vulnerability()# hazard x exposure x vulnerability
    flood_surrogate()    # fast machine-learning emulator
    flood_map()          # interactive and side-by-side maps

## Design principles

- **Map-first.** Every stage returns something that can be rendered as a
  map: discharge, velocity, travel time, depth and risk.
- **Climate as a toggle.** Any flood scenario can be produced for a
  present-day or a climate-adjusted design event, side by side.
- **Built for scarce data.** Defaults use satellite or reanalysis
  rainfall, temperature-based evapotranspiration, and regional pooling
  of short records.
- **Honest about limits.** The `dynamic` routing method is a stable 1-D
  approximation, not full 2-D hydrodynamics; the simple runoff model is
  a mass-conserving translator, not a calibrated GR4J. These are stated,
  not hidden.

## Documentation

- [**Manual (read
  online)**](https://gowusu.github.io/floodflow/articles/floodflow_manual.html)
  — the full teaching guide as a web page: theory boxes, worked
  equations, exercises and projects, and a spatial-mapping walkthrough,
  built on the real bundled `accra_rainfall` record.
- [Manual source on
  GitHub](https://github.com/gowusu/floodflow/blob/master/manual/floodflow_manual.md)
  (Markdown) and a [Word
  version](https://github.com/gowusu/floodflow/blob/master/manual/floodflow_manual.docx)
  for printing;
  [`reproduce_manual.R`](https://github.com/gowusu/floodflow/blob/master/manual/reproduce_manual.R)
  regenerates every figure.
- [Documentation site](https://gowusu.github.io/floodflow/) — function
  reference and vignettes rendered as web pages.
- [Getting-started
  guide](https://github.com/gowusu/floodflow/blob/master/GETTING-STARTED.md)
  — the full scenario matrix.
- Package help:
  [`?flood_route`](https://gowusu.github.io/floodflow/reference/flood_route.md),
  `example(flood_route)`, and `browseVignettes("floodflow")` after
  installation.

## Status

Version 0.1.0. All pipeline stages are implemented and tested (200+
internal checks). The core is pure R; geospatial and modelling engines
are optional and skip-guarded. External validation against gauged
catchments is the focus of the [v0.2
roadmap](https://gowusu.github.io/floodflow/floodflow_v0.2_roadmap.md).

## Citing floodflow

> Owusu, G. (2026). *floodflow: Climate-informed flood modelling in R.*
> Version 0.1.0. Department of Geography and Resource Development,
> University of Ghana.

## License

MIT © George Owusu
