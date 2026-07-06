make_hydrograph <- function() {
  dates <- seq(as.Date("2020-06-01"), by = "day", length.out = 40)
  Q <- c(0, 1, 3, 8, 18, 30, 50, 40, 30, 20, 12, 7, 4, 2, 1, rep(0, 25))
  data.frame(date = dates, Q_mm = Q)
}

test_that("manning_depth round-trips through Manning's equation", {
  h <- manning_depth(50, 0.035, 20, 0.001)
  Q_back <- (1 / 0.035) * (20 * h) * h^(2 / 3) * sqrt(0.001)
  expect_equal(Q_back, 50, tolerance = 0.01)
})

test_that("manning_depth responds correctly to inputs", {
  h1 <- manning_depth(50, 0.035, 20, 0.001)
  expect_true(manning_depth(200, 0.035, 20, 0.001) > h1)   # more flow deeper
  expect_true(manning_depth(50, 0.035, 20, 0.01) < h1)     # steeper shallower
  expect_true(manning_depth(50, 0.07, 20, 0.001) > h1)     # rougher deeper
})

test_that("Muskingum-Cunge coefficients sum to one", {
  k <- mc_coeffs(1.5, 600, 1000, 600)
  expect_equal(sum(k), 1, tolerance = 1e-9)
})

test_that("mc_route attenuates, lags, and conserves mass", {
  I <- c(0, 2, 5, 10, 20, 35, 50, 40, 30, 20, 12, 7, 4, 2, 1, rep(0, 25))
  O <- mc_route(I, 1.5, 600, 1000, 600)
  expect_true(max(O) <= max(I) + 1e-6)            # attenuated
  expect_true(which.max(O) >= which.max(I))       # lagged
  expect_equal(sum(O) / sum(I), 1, tolerance = 0.02)  # mass conserved
  expect_true(all(O >= 0))
})

test_that("all five methods run and return a flood_route", {
  disc <- make_hydrograph()
  for (m in c("manning-normal", "kinematic", "diffusive",
              "muskingum-cunge", "dynamic")) {
    r <- flood_route(disc, method = m)
    expect_s3_class(r, "flood_route")
    expect_true(r$peak_depth_m > 0)
    expect_true(r$peak_velocity_ms > 0)
    expect_true(all(r$routed$Q_routed >= 0))
  }
})

test_that("routing ladder orders by attenuation", {
  disc <- make_hydrograph()
  kin <- flood_route(disc, method = "kinematic")$attenuation
  mc  <- flood_route(disc, method = "muskingum-cunge")$attenuation
  dif <- flood_route(disc, method = "diffusive")$attenuation
  # Less diffusion -> higher retained peak -> attenuation closer to 1
  expect_true(kin >= mc)
  expect_true(mc >= dif)
})

test_that("manning-normal does not attenuate (steady)", {
  disc <- make_hydrograph()
  r <- flood_route(disc, method = "manning-normal")
  expect_equal(r$attenuation, 1, tolerance = 1e-6)
})

test_that("velocity is consistent with depth via Manning", {
  disc <- make_hydrograph()
  r <- flood_route(disc, method = "muskingum-cunge",
                   width = 20, slope = 0.001, n = 0.035)
  v_check <- (1 / 0.035) * r$peak_depth_m^(2 / 3) * sqrt(0.001)
  expect_equal(r$peak_velocity_ms, round(v_check, 3), tolerance = 0.01)
})

test_that("flood_route validates inputs", {
  expect_error(flood_route(flood_project()), "No runoff")
  expect_error(flood_route(data.frame(a = 1)), "date.*Q_mm|Q_mm")
  expect_error(flood_route(make_hydrograph(), width = -1), "positive")
  expect_error(flood_route(make_hydrograph(), n = 0), "positive")
})

test_that("flood_route populates a project and logs the stage", {
  fp <- flood_project(name = "t")
  fp$runoff <- list(discharge = make_hydrograph())
  class(fp$runoff) <- "flood_runoff"
  fp <- flood_route(fp, method = "muskingum-cunge")
  expect_false(is.null(fp$route))
  expect_true("route" %in% fp$log)
})

test_that("flood_route uses a scalar project roughness when present", {
  fp <- flood_project(name = "t")
  fp$runoff <- structure(list(discharge = make_hydrograph()),
                         class = "flood_runoff")
  fp$roughness <- structure(list(method = "constant", n = 0.08),
                            class = "flood_roughness")
  fp <- flood_route(fp)
  expect_identical(fp$route$settings$n, 0.08)
})

test_that("bigger catchment area yields deeper water", {
  disc <- make_hydrograph()
  small <- flood_route(disc, area_km2 = 50)$peak_depth_m
  big <- flood_route(disc, area_km2 = 500)$peak_depth_m
  expect_true(big > small)
})

test_that("print.flood_route runs and returns invisibly", {
  r <- flood_route(make_hydrograph())
  expect_output(print(r), "flood_route")
  out <- withVisible(print(r))
  expect_false(out$visible)
})

# ---- Spatial inundation depth (HAND) ----

test_that("hand surface produces a spatial depth vector", {
  disc <- make_hydrograph()
  hand <- c(0, 0.5, 1, 2, 4, 6)
  r <- flood_route(disc, area_km2 = 300, hand = hand)
  expect_false(is.null(r$depth_raster))
  expect_length(r$depth_raster, length(hand))
  # deepest at the channel (hand = 0), dry on the highest ground
  expect_equal(which.max(r$depth_raster), which.min(hand))
  expect_true(all(r$depth_raster >= 0))
})

test_that("cells above the flood are dry", {
  disc <- make_hydrograph()
  r <- flood_route(disc, area_km2 = 300, hand = c(0, 1, 2, 100))
  # the 100 m cell is far above any flood depth
  expect_equal(r$depth_raster[4], 0)
})

test_that("inundation depth decreases with height above drainage", {
  disc <- make_hydrograph()
  hand <- c(0, 0.5, 1, 1.5, 2)
  r <- flood_route(disc, area_km2 = 300, hand = hand)
  flooded <- r$depth_raster[r$depth_raster > 0]
  expect_true(all(diff(flooded) <= 0))
})

test_that("a DEM-like surface is converted to a HAND proxy", {
  disc <- make_hydrograph()
  dem <- c(100, 100.5, 101, 103)   # min well above 0 -> treated as DEM
  r <- flood_route(disc, area_km2 = 300, hand = dem)
  # lowest DEM cell should be the deepest (its HAND proxy is 0)
  expect_equal(which.max(r$depth_raster), which.min(dem))
})

test_that("no hand means no depth raster (backward compatible)", {
  disc <- make_hydrograph()
  r <- flood_route(disc, area_km2 = 300)
  expect_null(r$depth_raster)
})

test_that("flood_map uses the spatial depth raster when present", {
  disc <- make_hydrograph()
  fp <- flood_project(name = "t")
  fp$route <- flood_route(disc, area_km2 = 300, hand = c(0, 1, 2, 5))
  m <- flood_map(fp, layer = "depth")
  # summary should reflect the vector of depths, not a single scalar
  expect_true(m$data$max >= m$data$min)
  expect_true(m$data$max > 0)
})

# Raster path skip-guarded
test_that("hand as a SpatRaster yields a SpatRaster depth", {
  skip_if_not_installed("terra")
  disc <- make_hydrograph()
  hand_r <- terra::rast(nrows = 5, ncols = 5,
                        vals = seq(0, 6, length.out = 25))
  r <- flood_route(disc, area_km2 = 300, hand = hand_r)
  expect_s4_class(r$depth_raster, "SpatRaster")
})
