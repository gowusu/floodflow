make_route <- function() {
  disc <- data.frame(
    date = seq(as.Date("2020-06-01"), by = "day", length.out = 20),
    Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1, rep(0, 8))
  )
  flood_route(disc, method = "muskingum-cunge",
              width = 20, slope = 0.001, n = 0.035)
}

test_that("tc_kirpich matches a published example", {
  # Kirpich original example: L=1500 ft (457 m), S=0.05 -> ~7 min
  tc <- tc_kirpich(1500 * 0.3048, 0.05)
  expect_equal(tc, 7, tolerance = 1.0)
})

test_that("tc_kirpich is monotonic in length and slope", {
  expect_true(tc_kirpich(2000, 0.01) > tc_kirpich(1000, 0.01))
  expect_true(tc_kirpich(1000, 0.05) < tc_kirpich(1000, 0.01))
})

test_that("tc_kirpich validates inputs", {
  expect_error(tc_kirpich(-1, 0.01), "positive")
  expect_error(tc_kirpich(1000, 0), "positive")
})

test_that("tc_kerby increases with retardance", {
  expect_true(tc_kerby(100, 0.01, 0.8) > tc_kerby(100, 0.01, 0.4))
})

test_that("tc_kerby validates inputs", {
  expect_error(tc_kerby(100, 0.01, -1), "positive")
  expect_error(tc_kerby(-1, 0.01), "positive")
})

test_that("flood_hydraulics returns the full family", {
  h <- flood_hydraulics(make_route(), length_m = 4000, overland_m = 120)
  expect_s3_class(h, "flood_hydraulics")
  expect_named(h$tc, c("kirpich", "kerby", "kerby_kirpich", "velocity"))
  expect_true(h$peak_velocity_ms > 0)
  expect_true(h$travel_time_min > 0)
  expect_true(h$time_to_peak_hours >= 0)
  expect_true(all(h$tc > 0))
})

test_that("kerby-kirpich combines overland and channel", {
  h <- flood_hydraulics(make_route(), length_m = 4000, overland_m = 120)
  # Combined should exceed the Kerby overland component alone
  expect_true(h$tc[["kerby_kirpich"]] > h$tc[["kerby"]])
})

test_that("velocity-based Tc shortens with faster flow", {
  # Steeper slope -> faster velocity -> shorter velocity-Tc
  disc <- data.frame(
    date = seq(as.Date("2020-06-01"), by = "day", length.out = 12),
    Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1)
  )
  gentle <- flood_hydraulics(flood_route(disc, slope = 0.001), length_m = 4000)
  steep  <- flood_hydraulics(flood_route(disc, slope = 0.02), length_m = 4000)
  expect_true(steep$tc[["velocity"]] < gentle$tc[["velocity"]])
})

test_that("longer flow path lengthens travel time", {
  short <- flood_hydraulics(make_route(), length_m = 2000)$travel_time_min
  long  <- flood_hydraulics(make_route(), length_m = 8000)$travel_time_min
  expect_true(long > short)
})

test_that("flood_hydraulics validates inputs", {
  expect_error(flood_hydraulics(flood_project()), "No routing")
  expect_error(flood_hydraulics(make_route(), length_m = -1), "positive")
})

test_that("flood_hydraulics populates a project and logs the stage", {
  fp <- flood_project(name = "t")
  fp$route <- make_route()
  fp <- flood_hydraulics(fp)
  expect_false(is.null(fp$hydraulics))
  expect_true("hydraulics" %in% fp$log)
})

test_that("time to peak is event-relative and sensible", {
  # A single clean event: peak is a few steps after onset, not tens
  disc <- data.frame(
    date = seq(as.Date("2020-06-01"), by = "day", length.out = 15),
    Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1, 0, 0, 0)
  )
  r <- flood_route(disc, method = "muskingum-cunge")
  h <- flood_hydraulics(r, dt_hours = 24)
  # Rise from onset to peak is a handful of days, so well under the record span
  expect_true(h$time_to_peak_hours >= 0)
  expect_true(h$time_to_peak_hours <= 15 * 24)
})

test_that("time to peak does not scale with record length", {
  # Embed the same event in a long quiet record; time-to-peak must not blow up
  event <- c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1)
  long_Q <- c(rep(0, 500), event, rep(0, 500))
  disc <- data.frame(
    date = seq(as.Date("2000-01-01"), by = "day",
               length.out = length(long_Q)),
    Q_mm = long_Q
  )
  r <- flood_route(disc, method = "kinematic")
  h <- flood_hydraulics(r, dt_hours = 24)
  # Should reflect the ~6-day rise, not the ~500-day offset into the record
  expect_true(h$time_to_peak_hours < 30 * 24)
})

test_that("print.flood_hydraulics runs and returns invisibly", {
  h <- flood_hydraulics(make_route())
  expect_output(print(h), "flood_hydraulics")
  out <- withVisible(print(h))
  expect_false(out$visible)
})
