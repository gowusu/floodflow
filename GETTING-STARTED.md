# floodflow — getting-started guide

This guide is the practical companion to the package. The vignette gives a lean,
runnable tour; this document is the exhaustive reference, organised as a
**scenario matrix**. It shows every way the package is meant to be driven,
including the spatial-raster and engine-based workflows that the vignette cannot
run under automated checks.

Code blocks marked *(runs anywhere)* use only the pure-R core. Blocks marked
*(needs engine)* require an optional package and are shown for reference; install
the engine to run them.

---

## Contents

1. [Installation](#1-installation)
2. [The mental model](#2-the-mental-model)
3. [Scenario group A — climate and design scenarios](#3-scenario-group-a--climate-and-design-scenarios)
4. [Scenario group B — method scenarios](#4-scenario-group-b--method-scenarios)
5. [Scenario group C — data-availability scenarios](#5-scenario-group-c--data-availability-scenarios)
6. [Scenario group D — entry-point scenarios](#6-scenario-group-d--entry-point-scenarios)
7. [The Accra worked example](#7-the-accra-worked-example)
8. [Reference: stages and engines](#8-reference-stages-and-engines)

---

## 1. Installation

```r
# From the source tarball
install.packages("floodflow_0.1.0.tar.gz", repos = NULL, type = "source")

# Optional engines, installed only as needed
install.packages(c(
  "extRemes",   # extreme value fitting
  "airGR",      # GR4J rainfall-runoff
  "terra",      # raster / spatial work
  "whitebox",   # terrain analysis
  "ranger",     # machine-learning surrogate
  "tmap",       # interactive maps
  "leaflet"     # interactive maps
))

library(floodflow)
```

The core runs without any of these. Each stage checks for its engine and either
falls back to a pure-R method or reports clearly which package to install.

---

## 2. The mental model

Every analysis is carried by one object, created with `flood_project()`. Each
stage reads what it needs from the object and writes its result back, so the
object accumulates the whole analysis:

```
flood_project()        create the carrier object
  |> flood_extremes()      design rainfall + trend test
  |> flood_scenario()      present or climate-adjusted event
  |> roughness()           Manning's n
  |> flood_runoff()        rainfall -> discharge
  |> flood_route()         discharge -> routed depth
  |> flood_hydraulics()    velocity, time of concentration, travel time
  |> flood_uncertainty()   GLUE band + inverse calibration
  |> flood_vulnerability() hazard x exposure x vulnerability
  |> flood_surrogate()     fast emulator
  |> flood_map()           render a layer
```

You can run the whole chain, or any stage on its own with a plain data frame.

---

## 3. Scenario group A — climate and design scenarios

These vary the **climate future** applied to the design event. All run anywhere.

### A1. Present-day baseline

The design flood under today's climate: fit extremes, take a return level, and
route it. No scenario adjustment.

```r
ext <- flood_extremes(rain)              # rain: data.frame(date, precip_mm)
ext$return_levels                        # design rainfall by return period
```

### A2. Delta / change-factor (the default, recommended for scarce data)

Scale the design rainfall by a factor, typically taken from a published CMIP6
summary for the region and pathway.

```r
flood_scenario(ext, method = "delta", change_factor = 1.10)  # +10%
flood_scenario(ext, method = "delta", change_factor = 1.20)  # +20%
flood_scenario(ext, method = "delta", change_factor = 1.30)  # +30%
```

Mapping change factors to SSP pathways (illustrative values — substitute your
region's numbers):

```r
ssp <- c("SSP1-2.6" = 1.08, "SSP2-4.5" = 1.18, "SSP5-8.5" = 1.32)
lapply(names(ssp), function(s)
  flood_scenario(ext, method = "delta", change_factor = ssp[[s]],
                 scenario_label = s)$adjusted)
```

### A3. Trend projection

Project the fitted non-stationary location trend forward to a horizon year.
Uses only the record already in hand.

```r
flood_scenario(ext, method = "trend", horizon_year = 2050)
flood_scenario(ext, method = "trend", horizon_year = 2080)
```

### A4. CMIP6 ingestion (reserved)

The direct-ingestion path is reserved for downscaled projections and currently
returns an informative error, directing you to the delta method. This is by
design, so the behaviour is predictable:

```r
# Currently errors on purpose with guidance:
try(flood_scenario(ext, method = "cmip6"))
```

---

## 4. Scenario group B — method scenarios

These vary the **modelling method** at a stage.

### B1. All five routing methods compared *(runs anywhere)*

```r
methods <- c("manning-normal", "kinematic", "diffusive",
             "muskingum-cunge", "dynamic")
sapply(methods, function(m)
  flood_route(discharge, method = m, area_km2 = 300)$peak_depth_m)
```

`manning-normal` is steady (no attenuation); `kinematic` translates the wave
with little attenuation; `diffusive` attenuates most; `muskingum-cunge` is the
pragmatic default; `dynamic` is the best stable pure-R approximation. Note that
`dynamic` is **not** a full 2-D hydrodynamic solver — for true floodplain
hydrodynamics, couple to a dedicated model such as LISFLOOD-FP or HEC-RAS.

### B2. Roughness three ways *(runs anywhere)*

```r
roughness(method = "constant", value = 0.035)          # single value
roughness(landcover_classes, method = "landcover")     # lookup table
roughness(ndvi_values, method = "ndvi")                # from vegetation index
```

### B3. Runoff: engine vs. fallback

```r
flood_runoff(rain, engine = "simple")                  # pure-R  (runs anywhere)
flood_runoff(rain, engine = "airGR")                   # GR4J    (needs engine)
```

The `simple` fallback is a mass-conserving conceptual model with a routing lag;
it is a sane translator, not a calibrated GR4J. For a real study, use `airGR`
and calibrate the parameters against observed discharge.

### B4. Extremes: stationary vs. non-stationary *(runs anywhere)*

The test is automatic — `flood_extremes()` always fits both and reports the
likelihood-ratio outcome in `trend_detected`. To use the `extRemes` engine for
the stationary fit instead of the internal one:

```r
flood_extremes(rain, engine = "extRemes")              # needs engine
```

---

## 5. Scenario group C — data-availability scenarios

These reflect the real reason the package exists: it must work across very
different data situations.

### C1. Full stack vs. pure-R only

Everything above with `engine = "simple"` and scalar inputs runs with **no**
optional packages. Installing engines upgrades individual stages without
changing the workflow — the same function calls simply use a better method when
the engine is present.

### C2. Gauge rainfall vs. satellite / reanalysis *(runs anywhere)*

Any daily series with `date` and `precip_mm` columns works, whether from a gauge
or from a satellite/reanalysis product (CHIRPS, ERA5) exported to a data frame:

```r
rain_gauge <- data.frame(date = ..., precip_mm = ...)   # local gauge
rain_chirps <- data.frame(date = ..., precip_mm = ...)  # extracted CHIRPS
flood_extremes(rain_gauge)
flood_extremes(rain_chirps)
```

### C3. Lumped (scalar) vs. spatial (raster) inputs *(raster needs terra)*

The pipeline runs in a lumped mode with scalar catchment descriptors — this is
what all the runnable examples use. When `terra` is installed, the spatial
stages accept rasters:

```r
# needs engine: terra
library(terra)
dem  <- rast("dem.tif")
ndvi <- rast("ndvi.tif")

rough <- roughness(ndvi, method = "ndvi")      # per-cell Manning's n raster
lc    <- rast("landcover.tif")
rough_lc <- roughness(lc, method = "landcover")
```

The vulnerability stage likewise accepts hazard, exposure and vulnerability as
rasters and returns a risk raster:

```r
# needs engine: terra
flood_vulnerability(hazard_rast,
                    exposure = pop_rast,
                    vulnerability = deprivation_rast)
```

### C4. With vs. without an observed high-water mark

Without an observation, you get a deterministic estimate. With one (a surveyed
high-water mark or a satellite-derived depth), `flood_uncertainty()` gives a
calibrated band and inverse parameter estimates:

```r
# runs anywhere
flood_uncertainty(route, observed_depth_m = 4.0, n_sim = 3000, seed = 1)
```

---

## 6. Scenario group D — entry-point scenarios

These vary **how you drive** the package.

### D1. Full pipeline, piped *(runs anywhere)*

```r
fp <- flood_project("basin")
fp$rainfall <- rain
fp <- flood_extremes(fp)
fp <- flood_scenario(fp, method = "delta", change_factor = 1.2)
fp <- roughness(fp, method = "constant", value = 0.035)
fp <- flood_runoff(fp, engine = "simple")
fp <- flood_route(fp, area_km2 = 300)
fp <- flood_hydraulics(fp)
fp <- flood_uncertainty(fp, observed_depth_m = fp$route$peak_depth_m)
```

### D2. A single stage in isolation *(runs anywhere)*

Every stage accepts a plain data frame or the relevant object, so you can use
one piece without the rest — for example just the extreme value analysis:

```r
flood_extremes(rain)$return_levels
tc_kirpich(length_m = 5000, slope = 0.002)   # a single formula, standalone
```

### D3. Resuming mid-pipeline *(runs anywhere)*

Because the project carries state, you can stop, inspect, and continue. The
`log` slot records which stages have run:

```r
fp$log                     # e.g. "extremes" "runoff" "route"
fp <- flood_hydraulics(fp) # continue where you left off
```

---

## 7. The Accra worked example

A complete run for the Odaw basin, motivated by the June 2026 Accra floods. This
uses synthetic-but-realistic rainfall so it runs anywhere; swap in a real record
to reproduce for your basin.

```r
library(floodflow)
set.seed(2026)

# 44-year daily rainfall with a seasonal cycle and a warming trend
dates  <- seq(as.Date("1981-01-01"), as.Date("2024-12-31"), by = "day")
doy    <- as.integer(format(dates, "%j"))
yr     <- as.integer(format(dates, "%Y"))
season <- 0.5 + 0.5 * (exp(-((doy - 160)^2) / (2 * 35^2)) +
                       0.6 * exp(-((doy - 285)^2) / (2 * 30^2)))
cc     <- 1 + 0.030 * (yr - 1981)
rain <- data.frame(
  date = dates,
  precip_mm = round(rbinom(length(dates), 1, 0.28 * season) *
                    rgamma(length(dates), 0.7, scale = 9 * season * cc), 1)
)

fp <- flood_project("Odaw basin, Accra", crs = "EPSG:32630")
fp$rainfall <- rain
fp <- flood_extremes(fp)
fp <- flood_scenario(fp, method = "delta", change_factor = 1.20,
                     scenario_label = "SSP2-4.5 2050")
fp <- roughness(fp, method = "constant", value = 0.035)
fp <- flood_runoff(fp, lat_deg = 5.6, engine = "simple")
fp <- flood_route(fp, method = "muskingum-cunge",
                  width = 25, slope = 0.002, area_km2 = 400)
fp <- flood_hydraulics(fp, length_m = 12000, overland_m = 200)
fp <- flood_uncertainty(fp, observed_depth_m = 4.0, n_sim = 3000, seed = 1)

fp                         # summary of everything run
fp$extremes$return_levels  # present-day design rainfall
fp$scenario$adjusted       # climate-adjusted design rainfall
fp$route                   # peak depth and velocity
fp$uncertainty$depth_band  # calibrated depth band
```

Interpreting the output: the present-day 100-year design rainfall lands near the
magnitude of the June 2026 storm, and the +20% scenario shifts that same storm
to a shorter return period — the kind of statement the package is built to make.

---

## 8. Reference: stages and engines

| Stage | Function | Pure-R core | Optional engine |
|-------|----------|-------------|-----------------|
| Extremes | `flood_extremes()` | internal GEV | `extRemes` |
| Scenario | `flood_scenario()` | delta, trend | `epwshiftr` (CMIP6) |
| Roughness | `roughness()` | constant, lookup, NDVI | `terra` (rasters) |
| Runoff | `flood_runoff()` | conceptual fallback | `airGR` (GR4J) |
| Routing | `flood_route()` | all five methods | — |
| Hydraulics | `flood_hydraulics()` | all formulae | — |
| Uncertainty | `flood_uncertainty()` | GLUE | — |
| Vulnerability | `flood_vulnerability()` | H x E x V | `terra` (rasters) |
| Surrogate | `flood_surrogate()` | log-linear | `ranger` |
| Mapping | `flood_map()` | tidy summary | `tmap`, `leaflet` |

### Stated limits

- Delta scaling changes magnitude, not storm shape; cross-check against the
  non-stationary fit.
- The `dynamic` routing method is a stable approximation, not full 2-D
  Saint-Venant hydrodynamics.
- The `simple` runoff model is a mass-conserving translator, not a calibrated
  GR4J; calibrate `airGR` for real studies.
- The surrogate is classical machine learning that emulates the model's own
  runs, not an operational forecast system.
- Vulnerability proxies are coarse; the weighting is explicit and
  user-overridable.
