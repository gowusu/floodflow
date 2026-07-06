make_ext <- function(trend_rate = 0.02, seed = 1) {
  set.seed(seed)
  dates <- seq(as.Date("1985-01-01"), as.Date("2024-12-31"), by = "day")
  yr <- as.integer(format(dates, "%Y"))
  cf <- 1 + trend_rate * (yr - min(yr))
  wet <- stats::rbinom(length(dates), 1, 0.3)
  amt <- stats::rgamma(length(dates), shape = 0.7, scale = 6) * cf
  rain <- data.frame(date = dates, precip_mm = round(wet * amt, 1))
  flood_extremes(rain)
}

test_that("delta method scales return levels proportionally", {
  ext <- make_ext()
  sc <- flood_scenario(ext, method = "delta", change_factor = 1.15)
  expect_s3_class(sc, "flood_scenario")
  # Location & scale scale by the factor, so levels scale by ~the factor
  expect_true(all(abs(sc$change - 1.15) < 0.02))
  expect_true(all(sc$adjusted$level_mm > sc$baseline$level_mm))
})

test_that("delta with factor 1 leaves levels unchanged", {
  ext <- make_ext()
  sc <- flood_scenario(ext, method = "delta", change_factor = 1)
  expect_equal(sc$adjusted$level_mm, sc$baseline$level_mm, tolerance = 1e-6)
})

test_that("delta validates the change factor", {
  ext <- make_ext()
  expect_error(flood_scenario(ext, method = "delta", change_factor = -1),
               "positive")
  expect_error(flood_scenario(ext, method = "delta", change_factor = c(1, 2)),
               "single positive")
})

test_that("trend method projects the location forward", {
  ext <- make_ext(trend_rate = 0.03)
  sc <- flood_scenario(ext, method = "trend", horizon_year = 2060)
  expect_s3_class(sc, "flood_scenario")
  # With a positive trend, future levels should exceed baseline
  expect_true(mean(sc$adjusted$level_mm) > mean(sc$baseline$level_mm))
})

test_that("trend method requires a horizon year", {
  ext <- make_ext()
  expect_error(flood_scenario(ext, method = "trend"), "horizon_year")
})

test_that("trend warns when horizon is within the record", {
  ext <- make_ext()
  expect_warning(flood_scenario(ext, method = "trend", horizon_year = 2000),
                 "not beyond")
})

test_that("cmip6 method errors informatively (not yet implemented)", {
  ext <- make_ext()
  # Either the engine guard or the not-implemented message should fire
  expect_error(flood_scenario(ext, method = "cmip6"))
})

test_that("flood_scenario populates a project and logs the stage", {
  fp <- flood_project(name = "t")
  set.seed(1)
  fp$rainfall <- data.frame(
    date = seq(as.Date("1990-01-01"), as.Date("2020-12-31"), by = "day"),
    precip_mm = round(stats::rgamma(11323, 0.7, scale = 6) *
                        stats::rbinom(11323, 1, 0.3), 1))
  fp <- flood_extremes(fp)
  fp <- flood_scenario(fp, change_factor = 1.2, scenario_label = "SSP2-4.5")
  expect_false(is.null(fp$scenario))
  expect_true("scenario" %in% fp$log)
  expect_identical(fp$scenario$label, "SSP2-4.5")
})

test_that("flood_scenario requires an extremes result", {
  expect_error(flood_scenario(flood_project()), "flood_extremes")
})

test_that("print.flood_scenario runs and returns invisibly", {
  sc <- flood_scenario(make_ext(), change_factor = 1.1)
  expect_output(print(sc), "flood_scenario")
  r <- withVisible(print(sc))
  expect_false(r$visible)
})
