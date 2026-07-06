make_rain <- function(start = "1985-01-01", end = "2024-12-31",
                       trend_rate = 0, seed = 1) {
  set.seed(seed)
  dates <- seq(as.Date(start), as.Date(end), by = "day")
  yr <- as.integer(format(dates, "%Y"))
  cf <- 1 + trend_rate * (yr - min(yr))
  wet <- stats::rbinom(length(dates), 1, 0.3)
  amt <- stats::rgamma(length(dates), shape = 0.7, scale = 6) * cf
  data.frame(date = dates, precip_mm = round(wet * amt, 1))
}

test_that("gev_return_level increases with return period", {
  rl <- gev_return_level(40, 8, 0.1, c(2, 10, 50, 100))
  expect_true(all(diff(rl) > 0))
})

test_that("gev_return_level handles the Gumbel (shape ~ 0) limit", {
  rl_gumbel <- gev_return_level(40, 8, 0, 100)
  rl_near <- gev_return_level(40, 8, 1e-8, 100)
  expect_equal(rl_gumbel, rl_near, tolerance = 1e-3)
})

test_that("stationary GEV recovers known parameters", {
  set.seed(42)
  u <- runif(600)
  x <- 40 + (8 / 0.1) * ((-log(u))^(-0.1) - 1)  # GEV quantile, xi=0.1
  fit <- fit_gev_stationary(x)
  expect_equal(fit$par[["mu"]], 40, tolerance = 0.15 * 40)
  expect_equal(fit$par[["sigma"]], 8, tolerance = 0.25 * 8)
})

test_that("flood_extremes returns a well-formed result on a data frame", {
  res <- flood_extremes(make_rain())
  expect_s3_class(res, "flood_extremes")
  expect_true(all(c("annual_max", "stationary", "trend", "lr_test",
                    "trend_detected", "return_levels") %in% names(res)))
  expect_named(res$return_levels, c("period", "level_mm"))
  expect_true(all(diff(res$return_levels$level_mm) > 0))
})

test_that("flood_extremes detects a real trend and clears a flat record", {
  with_trend <- flood_extremes(make_rain(trend_rate = 0.03, seed = 7))
  no_trend <- flood_extremes(make_rain(trend_rate = 0, seed = 9))
  expect_true(with_trend$trend_detected)
  expect_false(no_trend$trend_detected)
})

test_that("flood_extremes populates a project and logs the stage", {
  fp <- flood_project(name = "test")
  fp$rainfall <- make_rain()
  fp <- flood_extremes(fp)
  expect_false(is.null(fp$extremes))
  expect_true("extremes" %in% fp$log)
})

test_that("flood_extremes validates input", {
  expect_error(flood_extremes(flood_project()), "No rainfall")
  expect_error(flood_extremes(data.frame(a = 1)), "date.*precip_mm|precip_mm")
})

test_that("flood_extremes warns on short records", {
  short <- make_rain(start = "2019-01-01", end = "2023-12-31")
  expect_warning(flood_extremes(short), "Fewer than 10")
})

test_that("print.flood_extremes runs and returns invisibly", {
  res <- flood_extremes(make_rain())
  expect_output(print(res), "flood_extremes")
  r <- withVisible(print(res))
  expect_false(r$visible)
})
