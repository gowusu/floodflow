###############################################################################
#  floodflow — complete spatial mapping script
#  Produces every map: roughness (Manning n), depth/inundation, velocity,
#  discharge (Manning), and travel-time (time-bound).
#
#  Runs on the base-R `volcano` DEM so it works with no downloads.
#  Swap in your own basin by changing the two rast() lines marked  <-- YOUR DATA
###############################################################################

library(terra)
library(floodflow)

## ---------------------------------------------------------------------------
## 1.  RAINFALL  (synthetic Accra-like record; replace with your gauge data)
## ---------------------------------------------------------------------------
set.seed(2026)
dates  <- seq(as.Date("1981-01-01"), as.Date("2024-12-31"), by = "day")
doy    <- as.integer(format(dates, "%j"))
yr     <- as.integer(format(dates, "%Y"))
season <- 0.5 + 0.5 * (exp(-((doy-160)^2)/(2*35^2)) +
                  0.6 * exp(-((doy-285)^2)/(2*30^2)))
cc     <- 1 + 0.030 * (yr - 1981)
rainfall <- data.frame(
  date = dates,
  precip_mm = round(rbinom(length(dates),1,0.28*season) *
              rgamma(length(dates),0.7,scale=9*season*cc), 1))

## ---------------------------------------------------------------------------
## 2.  TERRAIN INPUTS  (DEM, slope, HAND, NDVI)
## ---------------------------------------------------------------------------
dem   <- rast(volcano)                                   # <-- YOUR DATA: rast("dem.tif")
crs(dem) <- "EPSG:32630"                                 # give it a metric CRS

slope <- terrain(dem, v = "slope", unit = "radians")     # slope raster
slope_tan <- tan(slope)
slope_tan <- app(slope_tan, function(v) ifelse(v < 1e-4, 1e-4, v))  # floor

# HAND (Height Above Nearest Drainage) proxy: height above the lowest cell.
# For real work use whitebox::wbt_elevation_above_stream() instead.
hand  <- dem - global(dem, "min", na.rm = TRUE)[1,1]

# NDVI raster (synthetic here; replace with rast("ndvi.tif")). 0..1, greener low.
demn  <- (dem - global(dem,"min",na.rm=TRUE)[1,1]) /
         (global(dem,"max",na.rm=TRUE)[1,1] - global(dem,"min",na.rm=TRUE)[1,1])
set.seed(1)
ndvi  <- 0.8 - 0.6*demn + 0.15*setValues(dem, runif(ncell(dem)))  # <-- YOUR DATA
ndvi  <- app(ndvi, function(v) pmin(pmax(v,0),1))

## ---------------------------------------------------------------------------
## 3.  MAP 1 — ROUGHNESS (Manning's n) via the package
## ---------------------------------------------------------------------------
rough <- roughness(ndvi, method = "ndvi")   # returns $n as a SpatRaster
manning <- rough$n
plot(manning, main = "Map 1: Manning's n (roughness)")

## ---------------------------------------------------------------------------
## 4.  LUMPED PIPELINE  (rainfall -> runoff -> routed peak depth)
## ---------------------------------------------------------------------------
fp <- flood_project("your basin", crs = crs(dem))
fp$rainfall <- rainfall
fp <- flood_runoff(fp, engine = "simple")
# area_km2 scales runoff to discharge: larger area -> deeper flood. Raise it
# to see a fuller inundation map (try 50-400 for your basin's real area).
fp <- flood_route(fp, area_km2 = 200, hand = hand)   # hand -> spatial depth

peak_depth <- fp$route$peak_depth_m                # scalar peak depth (m)
width      <- fp$route$settings$width              # channel width used

## ---------------------------------------------------------------------------
## 5.  MAP 2 — DEPTH / INUNDATION (from the package)
## ---------------------------------------------------------------------------
depth <- fp$route$depth_raster                     # SpatRaster, built from HAND
plot(depth, main = "Map 2: Inundation depth (m)")
# (flood_map(fp, layer = "depth") draws the same thing via tmap/leaflet)

## ---------------------------------------------------------------------------
## 6.  MAP 3 — VELOCITY  (Manning velocity per cell)
## ---------------------------------------------------------------------------
# Use the inundation depth where wet, a thin film elsewhere, so velocity is
# defined everywhere. floodflow's manning_velocity() is not exported, so we
# apply Manning's equation directly (identical formula): v = (1/n) R^(2/3) S^(1/2)
depth_field <- app(depth, function(v) ifelse(v < 0.05, 0.05, v))  # min 5 cm
velocity <- (1/manning) * depth_field^(2/3) * sqrt(slope_tan)
velocity <- app(velocity, function(v) ifelse(v > 8, 8, v))        # cap 8 m/s
plot(velocity, main = "Map 3: Flow velocity (m/s)")

## ---------------------------------------------------------------------------
## 7.  MAP 4 — DISCHARGE  (Manning method: Q = v * A = v * width * depth)
## ---------------------------------------------------------------------------
discharge <- velocity * width * depth_field
plot(discharge, main = "Map 4: Discharge (m3/s), Q = v x A")

## ---------------------------------------------------------------------------
## 8.  MAP 5 — TRAVEL TIME  (time-bound: distance-to-outlet / velocity)
## ---------------------------------------------------------------------------
# Build a distance-to-outlet raster using terra's robust "distance to nearest
# non-NA cell" method: make a raster that is NA everywhere except the outlet.
outlet_cell <- which.min(values(dem))          # lowest cell = outlet
outlet_r <- dem                                 # copy geometry
values(outlet_r) <- NA
outlet_r[outlet_cell] <- 1                      # mark the outlet
dist_r <- distance(outlet_r)                     # metres to outlet, per cell

vel_floor  <- app(velocity, function(v) ifelse(v < 0.1, 0.1, v))  # avoid blow-up
travel_min <- (dist_r / vel_floor) / 60          # minutes
travel_min <- app(travel_min, function(v) ifelse(v > 120, 120, v)) # cap 2 h
plot(travel_min, main = "Map 5: Travel time to outlet (minutes)")

## ---------------------------------------------------------------------------
## 9.  (OPTIONAL) RISK MAP  — needs exposure & vulnerability rasters
## ---------------------------------------------------------------------------
# hazard from depth; exposure & vulnerability are illustrative here
hazard   <- depth / global(depth, "max", na.rm = TRUE)[1,1]
set.seed(3)
exposure <- setValues(dem, rpois(ncell(dem), 50))
vuln     <- setValues(dem, runif(ncell(dem)))
risk <- flood_vulnerability(hazard, exposure = exposure, vulnerability = vuln)
fp$vulnerability <- risk
plot(risk$risk, main = "Map 6: Flood risk (Hazard x Exposure x Vulnerability)")
# flood_map(fp, layer = "risk")   # interactive version with tmap/leaflet

## ---------------------------------------------------------------------------
## 10. (BONUS) DISTRIBUTED RUNOFF RATE — per cell, not one number
## ---------------------------------------------------------------------------
# The uniform runoff rate treats the whole basin the same. A distributed rate
# gives each cell its own value: bare/paved cells shed more, vegetated cells
# less. Base rate comes from the package; a runoff coefficient scales it.
fp2 <- flood_runoff(fp, engine = "simple")          # discharge in mm/day
peak_mm_day <- max(fp2$runoff$discharge$Q_mm)
base_rate   <- peak_mm_day / 1000 / 86400            # m/s (uniform)

runoff_coef      <- app(ndvi, function(v) 0.9 - 0.7 * v)  # 0.2..0.9 from NDVI
runoff_rate_dist <- base_rate * runoff_coef          # SpatRaster, m/s per cell
plot(runoff_rate_dist, main = "Distributed runoff rate (m/s)")

# For distributed cumulative discharge, use this as the per-cell loading with
# whitebox::wbt_d8_mass_flux(dem, loading = runoff_rate_dist * cell_area, ...)
# (whitebox routes the loading downstream; see manual Section 21.)

## ---------------------------------------------------------------------------
##  All maps: manning, depth, velocity, discharge, travel_min, risk$risk,
##            runoff_rate_dist
##  To save any:  writeRaster(velocity, "velocity.tif", overwrite = TRUE)
###############################################################################
