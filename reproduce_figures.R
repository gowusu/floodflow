###############################################################################
#  reproduce_figures.R
#  Regenerates every figure in the floodflow manual using R and the package.
#
#  The manual's figures were laid out with a plotting tool for print, but the
#  DATA behind each one comes from floodflow. This script reproduces that data
#  and draws each figure with base-R graphics, so every figure in the manual is
#  fully reproducible from the package itself.
#
#  Usage:  Rscript reproduce_figures.R      (writes PNGs to ./figures/)
###############################################################################

library(floodflow)
suppressWarnings(dir.create("figures", showWarnings = FALSE))
png_ <- function(name) png(file.path("figures", name), width = 900, height = 600, res = 110)

## ---------------------------------------------------------------------------
## Shared data: the synthetic Accra-like rainfall record used in Part 1
## ---------------------------------------------------------------------------
set.seed(2026)
dates <- seq(as.Date("1981-01-01"), as.Date("2024-12-31"), by = "day")
doy   <- as.integer(format(dates, "%j"))
yr    <- as.integer(format(dates, "%Y"))
season <- 0.5 + 0.5 * (exp(-((doy-160)^2)/(2*35^2)) +
                  0.6 * exp(-((doy-285)^2)/(2*30^2)))
cc    <- 1 + 0.030 * (yr - 1981)
rain  <- data.frame(date = dates,
  precip_mm = round(rbinom(length(dates),1,0.28*season) *
              rgamma(length(dates),0.7,scale=9*season*cc), 1))

fp <- flood_project("Odaw basin, Accra")
fp$rainfall <- rain
fp <- flood_extremes(fp)

## ---------------------------------------------------------------------------
## Figure 1 — annual maxima with the fitted trend
## ---------------------------------------------------------------------------
am <- tapply(rain$precip_mm, format(rain$date, "%Y"), max)
yrs <- as.integer(names(am))
png_("fig01_annual_maxima.png")
plot(yrs, am, type = "b", pch = 19, col = "#1f7a8c",
     xlab = "year", ylab = "annual max daily rain (mm)",
     main = "Annual maximum rainfall, 1981-2024")
abline(lm(am ~ yrs), col = "#c1462f", lwd = 2)
dev.off()

## ---------------------------------------------------------------------------
## Figure 2 — present vs future return levels
## ---------------------------------------------------------------------------
fs <- flood_scenario(fp, method = "delta", change_factor = 1.20,
                     scenario_label = "SSP2-4.5 2050")
rl <- fp$extremes$return_levels
png_("fig02_return_levels.png")
barplot(rbind(rl$level_mm, rl$level_mm * 1.20), beside = TRUE,
        names.arg = paste0(rl$period, "-yr"),
        col = c("#1f7a8c", "#c1462f"),
        ylab = "design rainfall (mm)",
        main = "Design rainfall: present vs mid-century (+20%)")
legend("topleft", c("present-day", "SSP2-4.5 2050"),
       fill = c("#1f7a8c", "#c1462f"), bty = "n")
dev.off()

## ---------------------------------------------------------------------------
## Figures 3 & 4 — the real June 2026 Accra event (cited GMet figures)
## ---------------------------------------------------------------------------
png_("fig03_daily_jump.png")
plot(c(2024, 2026), c(56, 169.2), type = "b", pch = 19, col = "#c1462f",
     lwd = 2, xlim = c(2023.7, 2026.3), ylim = c(0, 190), xaxt = "n",
     xlab = "", ylab = "highest daily rainfall (mm)",
     main = "Accra daily rainfall record: the future arrived early")
axis(1, at = c(2024, 2025, 2026))
abline(h = 114.5, lty = 2, col = "#1f7a8c")
abline(h = 137.3, lty = 2, col = "#0a3d52")
text(2024.2, 120, "present-day 100-yr (114 mm)", cex = 0.8, col = "#1f7a8c", pos = 4)
text(2024.2, 143, "SSP2-4.5 2050 100-yr (137 mm)", cex = 0.8, col = "#0a3d52", pos = 4)
dev.off()

png_("fig04_monthly_record.png")
barplot(c(380.3, 420.6, 593.2),
        names.arg = c("2015", "2002", "June 2026"),
        col = c("#8fc0c9", "#1f7a8c", "#c1462f"),
        ylab = "June rainfall (mm)",
        main = "Ghana's wettest month on record (June 2026)")
dev.off()

## ---------------------------------------------------------------------------
## Figure 5 — the flood hydrograph
## ---------------------------------------------------------------------------
fp <- flood_runoff(fp, engine = "simple")
q  <- fp$runoff$discharge
sub <- q[q$date >= "2024-06-01" & q$date <= "2024-09-30", ]
png_("fig05_hydrograph.png")
plot(sub$date, sub$Q_mm, type = "l", col = "#1f7a8c", lwd = 2,
     xlab = "date", ylab = "discharge (mm/day)",
     main = "Flood hydrograph (2024 wet season)")
dev.off()

## ---------------------------------------------------------------------------
## Figure 6 — the water balance (rainfall vs evaporative demand vs runoff)
## ---------------------------------------------------------------------------
mo   <- as.integer(format(rain$date, "%m"))
Pm   <- tapply(rain$precip_mm, mo, sum)
PETm <- tapply(fp$runoff$pet, mo, sum)
Qm   <- tapply(q$Q_mm, mo, sum)
png_("fig06_water_balance.png")
barplot(rbind(as.numeric(Pm), as.numeric(PETm)), beside = TRUE,
        names.arg = month.abb, col = c("#1f7a8c", "#c1462f"),
        ylab = "mm/month", main = "Water balance: rainfall, evaporation, runoff")
lines(seq(2, by = 3, length.out = 12), as.numeric(Qm), type = "b",
      pch = 19, col = "#0a3d52", lwd = 2)
legend("topright", c("rainfall (P)", "PET", "runoff (Q)"),
       fill = c("#1f7a8c", "#c1462f", NA),
       border = c("black", "black", NA),
       lty = c(NA, NA, 1), pch = c(NA, NA, 19), col = "#0a3d52", bty = "n")
dev.off()

## ---------------------------------------------------------------------------
## Figure 7 — the routing ladder (all five methods)
## ---------------------------------------------------------------------------
methods <- c("manning-normal","kinematic","diffusive","muskingum-cunge","dynamic")
cols <- c("#8fc0c9","#5aa0ac","#1f7a8c","#12596a","#0a3d52")
png_("fig07_routing_ladder.png")
plot(NA, xlim = c(1, nrow(sub)), ylim = c(0, max(sub$Q_mm)*1.1),
     xlab = "day", ylab = "routed discharge (mm/day)",
     main = "The same flood through five routing methods")
for (i in seq_along(methods)) {
  r <- flood_route(fp, method = methods[i], area_km2 = 400)
  rr <- r$route$routed
  rr <- rr[rr$date >= "2024-06-01" & rr$date <= "2024-09-30", ]
  lines(seq_len(nrow(rr)), rr$Q_routed, col = cols[i], lwd = 2)
}
legend("topright", methods, col = cols, lwd = 2, bty = "n", cex = 0.8)
dev.off()

## ---------------------------------------------------------------------------
## ---------------------------------------------------------------------------
## Figure (daily depth with rainfall overlay) — the two-axis event plot
## ---------------------------------------------------------------------------
ev_dates <- seq(as.Date("2021-06-10"), by = "day", length.out = 15)
ev_rain  <- data.frame(date = ev_dates,
                       precip_mm = c(0,5,15,35,60,45,30,18,10,5,2,1,0,0,0))
fpe <- flood_project("event"); fpe$rainfall <- ev_rain
fpe <- flood_runoff(fpe, engine = "simple")
fpe <- flood_route(fpe, area_km2 = 400, width = 25, slope = 0.002)
# depth from Manning's equation (inverted): d = (Q*n / (w*sqrt(S)))^(3/5)
Q_series <- fpe$route$routed$Q_routed
n <- fpe$route$settings$n; w <- fpe$route$settings$width
s <- max(fpe$route$settings$slope, 1e-4)
dd <- (Q_series * n / (w * sqrt(s)))^(3/5)
png_("fig_daily_depth.png")
plot(fpe$route$routed$date, dd, type = "l", col = "#c1462f", lwd = 2,
     xlab = "date", ylab = "flood depth (m)",
     main = "Daily flood depth through an event")
par(new = TRUE)
re <- ev_rain$precip_mm[match(fpe$route$routed$date, ev_rain$date)]
plot(fpe$route$routed$date, re, type = "h", lwd = 6, col = "#8fc0c9",
     axes = FALSE, xlab = "", ylab = "", ylim = c(max(re) * 2, 0))
axis(4); mtext("rainfall (mm/day)", side = 4, line = 2)
dev.off()

## Part 2 spatial figures (8-17): DEM, NDVI, roughness, discharge, depth,
## velocity, travel time, daily maps. All use the base-R volcano DEM + terra.
## ---------------------------------------------------------------------------
if (requireNamespace("terra", quietly = TRUE)) {
  library(terra)
  dem <- rast(volcano); crs(dem) <- "EPSG:32630"
  slope <- terrain(dem, v = "slope", unit = "radians")
  slope_tan <- app(tan(slope), function(v) ifelse(v < 1e-4, 1e-4, v))
  hand <- dem - global(dem, "min", na.rm = TRUE)[1,1]
  set.seed(1)
  demn <- (dem - global(dem,"min",na.rm=TRUE)[1,1]) /
          (global(dem,"max",na.rm=TRUE)[1,1] - global(dem,"min",na.rm=TRUE)[1,1])
  ndvi <- app(0.8 - 0.6*demn + 0.15*setValues(dem, runif(ncell(dem))),
              function(v) pmin(pmax(v,0),1))
  manning <- roughness(ndvi, method = "ndvi")$n

  png_("fig_dem.png");   plot(dem,   main = "Elevation (DEM)");            dev.off()
  png_("fig_ndvi.png");  plot(ndvi,  main = "NDVI (vegetation)");          dev.off()
  png_("fig_manning.png"); plot(manning, main = "Manning's n (roughness)"); dev.off()

  fp2 <- flood_route(fp, area_km2 = 200, hand = hand)
  depth <- fp2$route$depth_raster
  png_("fig_depth.png"); plot(depth, main = "Inundation depth (m)"); dev.off()

  df <- app(depth, function(v) ifelse(v < 0.05, 0.05, v))
  velocity <- (1/manning) * df^(2/3) * sqrt(slope_tan)
  png_("fig_velocity.png"); plot(velocity, main = "Velocity (m/s)"); dev.off()

  discharge <- velocity * fp2$route$settings$width * df
  png_("fig_discharge.png"); plot(discharge, main = "Discharge (m3/s)"); dev.off()

  outlet_r <- dem; values(outlet_r) <- NA
  outlet_r[which.min(values(dem))] <- 1
  travel <- (distance(outlet_r) / velocity) / 60
  png_("fig_travel.png"); plot(travel, main = "Travel time (min)"); dev.off()

  message("Spatial figures written to ./figures/")
} else {
  message("Install 'terra' to reproduce the Part 2 spatial figures.")
}

message("Done. All reproducible figures are in ./figures/")
