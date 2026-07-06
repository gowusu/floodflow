make_rain_series <- function(n_years = 2, seed = 1) {
  set.seed(seed)
  dates <- seq(as.Date("2020-01-01"),
               by = "day", length.out = n_years * 365)
  data.frame(
    date = dates,
    precip_mm = round(stats::rgamma(length(dates), 0.7, scale = 8) *
                        stats::rbinom(length(dates), 1, 0.4), 1)
  )
}

test_that("pet_oudin is positive and seasonal", {
  jd <- 1:365
  temp <- 28 + 3 * sin(2 * pi * (jd - 40) / 365)
  pet <- pet_oudin(jd, temp, lat_deg = 5.6)
  expect_true(all(pet >= 0))
  expect_true(diff(range(pet)) > 0.3)
  expect_length(pet, 365)
})

test_that("pet_oudin is zero when temperature is very low", {
  expect_equal(pet_oudin(180, -10, 5.6), 0)
})

test_that("pet_oudin validates inputs", {
  expect_error(pet_oudin(1:10, 1:5, 5.6), "same length")
  expect_error(pet_oudin(1:10, rep(20, 10), c(5, 6)), "single number")
})

test_that("runoff fallback conserves mass and lags flow", {
  rain <- make_rain_series()
  rr <- flood_runoff(rain, engine = "simple")
  expect_s3_class(rr, "flood_runoff")
  Q <- rr$discharge$Q_mm
  P <- rain$precip_mm
  expect_true(all(Q >= 0))
  expect_true(sum(Q) <= sum(P))                 # mass sane
  expect_true(which.max(Q) >= which.max(P))     # flow peaks at/after rain
})

test_that("runoff responds to rainfall (lagged correlation)", {
  rain <- make_rain_series()
  rr <- flood_runoff(rain, engine = "simple")
  Q <- rr$discharge$Q_mm
  P <- rain$precip_mm
  lc <- max(vapply(0:4, function(k)
    stats::cor(utils::head(P, length(P) - k), utils::tail(Q, length(Q) - k)),
    numeric(1)))
  expect_gt(lc, 0.3)
})

test_that("flood_runoff returns discharge aligned to dates", {
  rain <- make_rain_series()
  rr <- flood_runoff(rain, engine = "simple")
  expect_named(rr$discharge, c("date", "Q_mm"))
  expect_equal(nrow(rr$discharge), nrow(rain))
  expect_identical(rr$discharge$date, rain$date)
})

test_that("flood_runoff uses a temp_c column when present", {
  rain <- make_rain_series()
  rain$temp_c <- 26 + 4 * sin(2 * pi * seq_len(nrow(rain)) / 365)
  rr <- flood_runoff(rain, engine = "simple")
  expect_length(rr$pet, nrow(rain))
  expect_true(all(rr$pet >= 0))
})

test_that("flood_runoff populates a project and logs the stage", {
  fp <- flood_project(name = "t")
  fp$rainfall <- make_rain_series()
  fp <- flood_runoff(fp, engine = "simple")
  expect_false(is.null(fp$runoff))
  expect_true("runoff" %in% fp$log)
})

test_that("flood_runoff validates input", {
  expect_error(flood_runoff(flood_project()), "No rainfall")
  expect_error(flood_runoff(data.frame(a = 1)), "date.*precip_mm|precip_mm")
})

test_that("peak is reported with a date", {
  rr <- flood_runoff(make_rain_series(), engine = "simple")
  expect_true(is.numeric(rr$peak$Q_mm))
  expect_s3_class(rr$peak$date, "Date")
})

test_that("print.flood_runoff runs and returns invisibly", {
  rr <- flood_runoff(make_rain_series(), engine = "simple")
  expect_output(print(rr), "flood_runoff")
  out <- withVisible(print(rr))
  expect_false(out$visible)
})

# ---- airGR engine: skip-guarded (CRAN-safe) ----

test_that("flood_runoff runs with the airGR engine when available", {
  skip_if_not_installed("airGR")
  rr <- flood_runoff(make_rain_series(), engine = "airGR")
  expect_s3_class(rr, "flood_runoff")
  expect_match(rr$engine, "airGR")
  expect_true(all(rr$discharge$Q_mm >= 0))
})
