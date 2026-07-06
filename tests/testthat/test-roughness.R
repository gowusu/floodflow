test_that("constant roughness returns the given value", {
  r <- roughness(method = "constant", value = 0.03)
  expect_s3_class(r, "flood_roughness")
  expect_identical(r$n, 0.03)
  expect_identical(r$method, "constant")
})

test_that("constant roughness validates its value", {
  expect_error(roughness(method = "constant", value = -1), "positive")
  expect_error(roughness(method = "constant", value = c(0.02, 0.03)),
               "single positive")
  expect_error(roughness(method = "constant", value = "x"), "single positive")
})

test_that("landcover lookup maps classes to n with correct ordering", {
  cls <- c("urban", "grassland", "forest")
  r <- roughness(cls, method = "landcover")
  expect_equal(r$n, unname(floodflow_lc_roughness[cls]))
  # physical ordering: paved < grass < forest
  expect_true(r$n[1] < r$n[2] && r$n[2] < r$n[3])
})

test_that("landcover errors on unknown classes", {
  expect_error(roughness(c("forest", "volcano"), method = "landcover"),
               "Unknown land-cover")
})

test_that("landcover accepts a user-supplied table", {
  custom <- c(a = 0.01, b = 0.09)
  r <- roughness(c("a", "b", "a"), method = "landcover", table = custom)
  expect_equal(r$n, c(0.01, 0.09, 0.01))
})

test_that("landcover rejects a malformed table", {
  expect_error(
    roughness(c("a"), method = "landcover", table = c(0.01, 0.02)),
    "named numeric"
  )
})

test_that("ndvi method is monotonic and bounded", {
  nd <- c(0, 0.25, 0.5, 0.75, 1)
  r <- roughness(nd, method = "ndvi")
  expect_true(all(diff(r$n) >= 0))
  expect_true(all(r$n >= 0.020 & r$n <= 0.120))
})

test_that("ndvi clamps out-of-range values", {
  r_low <- roughness(-0.5, method = "ndvi")
  r_zero <- roughness(0, method = "ndvi")
  r_hi <- roughness(2, method = "ndvi")
  r_one <- roughness(1, method = "ndvi")
  expect_equal(r_low$n, r_zero$n)
  expect_equal(r_hi$n, r_one$n)
})

test_that("ndvi validates the n bounds", {
  expect_error(roughness(0.5, method = "ndvi", n_min = 0.1, n_max = 0.05),
               "n_min < n_max")
  expect_error(roughness(0.5, method = "ndvi", n_min = -0.1), "n_min < n_max|0 <")
})

test_that("ndvi rejects non-numeric input", {
  expect_error(roughness(c("a", "b"), method = "ndvi"), "numeric")
})

test_that("missing input errors for landcover and ndvi", {
  expect_error(roughness(method = "landcover"), "needs land-cover")
  expect_error(roughness(method = "ndvi"), "needs NDVI")
})

test_that("roughness populates a project and logs the stage", {
  fp <- flood_project(name = "t")
  fp <- roughness(fp, method = "constant", value = 0.05)
  expect_false(is.null(fp$roughness))
  expect_true("roughness" %in% fp$log)
  expect_identical(fp$roughness$n, 0.05)
})

test_that("roughness summary is correct for a vector", {
  r <- roughness(c(0.02, 0.06, 0.10), method = "ndvi", n_min = 0.02, n_max = 0.10)
  # ndvi 0.02,0.06,0.10 -> small values near n_min; check summary structure
  expect_named(r$summary, c("min", "mean", "max"))
  expect_true(r$summary[["min"]] <= r$summary[["mean"]])
  expect_true(r$summary[["mean"]] <= r$summary[["max"]])
})

test_that("print.flood_roughness runs and returns invisibly", {
  r <- roughness(method = "constant", value = 0.04)
  expect_output(print(r), "flood_roughness")
  out <- withVisible(print(r))
  expect_false(out$visible)
})

# ---- Raster path: skip-guarded on terra (CRAN-safe) ----

test_that("ndvi method works on a SpatRaster", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 10, ncols = 10, vals = seq(0, 1, length.out = 100))
  out <- roughness(r, method = "ndvi")
  expect_s4_class(out$n, "SpatRaster")
  rng <- terra::global(out$n, c("min", "max"), na.rm = TRUE)
  expect_true(rng[1, 1] >= 0.020 && rng[1, 2] <= 0.120)
})

test_that("landcover method works on a SpatRaster", {
  skip_if_not_installed("terra")
  # Build a small raster of class labels via a level table
  m <- terra::rast(nrows = 4, ncols = 4,
                   vals = rep(0:3, length.out = 16))
  levels(m) <- data.frame(id = 0:3,
                          cover = c("water", "urban", "forest", "cropland"))
  out <- roughness(m, method = "landcover")
  expect_s4_class(out$n, "SpatRaster")
})
