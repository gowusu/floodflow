make_route_u <- function(area = 300) {
  disc <- data.frame(
    date = seq(as.Date("2020-06-01"), by = "day", length.out = 15),
    Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1, 0, 0, 0)
  )
  flood_route(disc, method = "muskingum-cunge",
              width = 25, slope = 0.001, n = 0.045, area_km2 = area)
}

test_that("flood_uncertainty returns a well-formed GLUE result", {
  r <- make_route_u()
  u <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                         n_sim = 2000, seed = 1)
  expect_s3_class(u, "flood_uncertainty")
  expect_true(u$n_behavioural > 0)
  expect_named(u$depth_band, c("lower", "median", "upper"))
  expect_true(u$depth_band[["lower"]] <= u$depth_band[["median"]])
  expect_true(u$depth_band[["median"]] <= u$depth_band[["upper"]])
})

test_that("the observation falls inside its own predictive band", {
  r <- make_route_u()
  u <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                         n_sim = 3000, seed = 2)
  expect_true(u$obs_in_band)
})

test_that("inverse estimates lie within the specified priors", {
  r <- make_route_u()
  u <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                         n_sim = 3000, n_range = c(0.02, 0.08),
                         width_range = c(10, 40), seed = 3)
  expect_true(u$estimates$n[["mean"]] >= 0.02 &&
                u$estimates$n[["mean"]] <= 0.08)
  expect_true(u$estimates$width[["mean"]] >= 10 &&
                u$estimates$width[["mean"]] <= 40)
})

test_that("GLUE preserves parameter uncertainty (equifinality)", {
  r <- make_route_u()
  u <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                         n_sim = 4000, seed = 4)
  # Behavioural n should span a range, not collapse
  expect_true(u$estimates$n[["upper"]] - u$estimates$n[["lower"]] > 0.005)
  # n and width trade off, so strong correlation is expected
  expect_true(abs(u$equifinality) > 0.5)
})

test_that("tighter behavioural fraction narrows the band", {
  r <- make_route_u()
  wide <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                            n_sim = 4000, behavioural_fraction = 0.3, seed = 5)
  tight <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                             n_sim = 4000, behavioural_fraction = 0.02, seed = 5)
  wide_w <- wide$depth_band[["upper"]] - wide$depth_band[["lower"]]
  tight_w <- tight$depth_band[["upper"]] - tight$depth_band[["lower"]]
  expect_true(tight_w <= wide_w)
})

test_that("reproducible with a seed", {
  r <- make_route_u()
  u1 <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                          n_sim = 1000, seed = 42)
  u2 <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                          n_sim = 1000, seed = 42)
  expect_identical(u1$depth_band, u2$depth_band)
  expect_identical(u1$estimates, u2$estimates)
})

test_that("flood_uncertainty validates inputs", {
  r <- make_route_u()
  expect_error(flood_uncertainty(flood_project(), observed_depth_m = 1),
               "No routing")
  expect_error(flood_uncertainty(r, observed_depth_m = -1), "positive")
  expect_error(flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                                 behavioural_fraction = 1.5), "\\(0, 1\\)")
  expect_error(flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                                 n_range = 0.05), "length-2")
})

test_that("flood_uncertainty populates a project and logs the stage", {
  fp <- flood_project(name = "t")
  fp$route <- make_route_u()
  fp <- flood_uncertainty(fp, observed_depth_m = fp$route$peak_depth_m,
                          n_sim = 1000, seed = 6)
  expect_false(is.null(fp$uncertainty))
  expect_true("uncertainty" %in% fp$log)
})

test_that("behavioural weights sum to one", {
  r <- make_route_u()
  u <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                         n_sim = 2000, seed = 7)
  expect_equal(sum(u$behavioural$weight), 1, tolerance = 1e-9)
})

test_that("print.flood_uncertainty runs and returns invisibly", {
  r <- make_route_u()
  u <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
                         n_sim = 1000, seed = 8)
  expect_output(print(u), "GLUE")
  out <- withVisible(print(u))
  expect_false(out$visible)
})
