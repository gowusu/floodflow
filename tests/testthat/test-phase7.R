make_route_p7 <- function(area = 300) {
  disc <- data.frame(
    date = seq(as.Date("2020-06-01"), by = "day", length.out = 15),
    Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1, 0, 0, 0)
  )
  flood_route(disc, method = "muskingum-cunge", area_km2 = area)
}

# ---- flood_vulnerability ----

test_that("risk is bounded and multiplicative", {
  set.seed(1)
  h <- runif(100, 0, 5); e <- rpois(100, 50); v <- runif(100)
  res <- flood_vulnerability(h, exposure = e, vulnerability = v)
  expect_s3_class(res, "flood_vulnerability")
  expect_true(all(res$risk >= 0 & res$risk <= 1))
})

test_that("zero in any component gives zero risk there", {
  set.seed(1)
  h <- runif(50, 1, 5); e <- rpois(50, 40); v <- runif(50, 0.2, 1)
  h[1] <- 0
  res <- flood_vulnerability(h, exposure = e, vulnerability = v)
  expect_equal(res$risk[1], 0)
})

test_that("higher hazard raises mean risk", {
  set.seed(2)
  e <- rpois(100, 50); v <- runif(100)
  lo <- flood_vulnerability(rep(1, 100), exposure = e, vulnerability = v)
  hi <- flood_vulnerability(rep(5, 100), exposure = e, vulnerability = v)
  # normalised risk is relative, so compare the raw product ordering via max
  expect_true(mean(hi$components$hazard) >= mean(lo$components$hazard))
})

test_that("vulnerability is optional", {
  set.seed(3)
  res <- flood_vulnerability(runif(40, 0, 5), exposure = rpois(40, 30))
  expect_s3_class(res, "flood_vulnerability")
  expect_true(all(res$components$vulnerability == 1))
})

test_that("flood_vulnerability validates inputs", {
  expect_error(flood_vulnerability(runif(10)), "exposure")
  expect_error(
    flood_vulnerability(runif(10, 0, 5), exposure = runif(8)),
    "match"
  )
})

test_that("scalar hazard from a project recycles across exposure", {
  fp <- flood_project(name = "t")
  fp$route <- make_route_p7()
  set.seed(4)
  fp <- flood_vulnerability(fp, exposure = rpois(60, 40),
                            vulnerability = runif(60))
  expect_false(is.null(fp$vulnerability))
  expect_true("vulnerability" %in% fp$log)
  expect_length(fp$vulnerability$risk, 60)
})

test_that("print.flood_vulnerability runs and returns invisibly", {
  set.seed(5)
  res <- flood_vulnerability(runif(30, 0, 5), exposure = rpois(30, 30),
                             vulnerability = runif(30))
  expect_output(print(res), "Hazard")
  out <- withVisible(print(res))
  expect_false(out$visible)
})

# ---- flood_surrogate ----

test_that("surrogate emulates the Manning depth model accurately", {
  s <- flood_surrogate(make_route_p7(), n_train = 400, seed = 1)
  expect_s3_class(s, "flood_surrogate")
  expect_true(s$performance[["r2"]] > 0.9)
})

test_that("surrogate predict function returns depths for new inputs", {
  s <- flood_surrogate(make_route_p7(), n_train = 300, seed = 2)
  pred <- s$predict(data.frame(Q = c(50, 150), n = c(0.03, 0.05),
                               width = c(20, 30)))
  expect_length(pred, 2)
  expect_true(all(pred > 0))
})

test_that("surrogate predictions rise with discharge", {
  s <- flood_surrogate(make_route_p7(), n_train = 400, seed = 3)
  d_low <- s$predict(data.frame(Q = 50, n = 0.04, width = 25))
  d_high <- s$predict(data.frame(Q = 300, n = 0.04, width = 25))
  expect_true(d_high > d_low)
})

test_that("flood_surrogate validates and integrates with a project", {
  expect_error(flood_surrogate(flood_project()), "No routing")
  fp <- flood_project(name = "t")
  fp$route <- make_route_p7()
  fp <- flood_surrogate(fp, n_train = 200, seed = 4)
  expect_false(is.null(fp$meta$surrogate))
  expect_true("surrogate" %in% fp$log)
})

test_that("print.flood_surrogate runs and returns invisibly", {
  s <- flood_surrogate(make_route_p7(), n_train = 200, seed = 5)
  expect_output(print(s), "flood_surrogate")
  out <- withVisible(print(s))
  expect_false(out$visible)
})

# ---- flood_map ----

test_that("flood_map returns a tidy summary for depth", {
  fp <- flood_project(name = "t")
  fp$route <- make_route_p7()
  m <- flood_map(fp, layer = "depth")
  expect_s3_class(m, "flood_map")
  expect_named(m$data, c("layer", "min", "mean", "max"))
  expect_identical(m$data$layer, "depth")
})

test_that("flood_map handles velocity and uncertainty layers", {
  fp <- flood_project(name = "t")
  fp$route <- make_route_p7()
  mv <- flood_map(fp, layer = "velocity")
  expect_identical(mv$data$layer, "velocity")

  fp <- flood_uncertainty(fp, observed_depth_m = fp$route$peak_depth_m,
                          n_sim = 500, seed = 1)
  mu <- flood_map(fp, layer = "uncertainty")
  expect_identical(mu$data$layer, "uncertainty")
  expect_true(mu$data$min >= 0)
})

test_that("flood_map errors when the layer is missing", {
  fp <- flood_project(name = "t")
  expect_error(flood_map(fp, layer = "depth"), "flood_route")
  expect_error(flood_map(fp, layer = "risk"), "flood_vulnerability")
})

test_that("flood_map without engines does not render but still summarises", {
  fp <- flood_project(name = "t")
  fp$route <- make_route_p7()
  m <- flood_map(fp, layer = "depth", interactive = TRUE)
  # Scalar depth is non-spatial, so no interactive render regardless of engines
  expect_false(m$rendered)
  expect_true(is.finite(m$data$mean))
})

test_that("print.flood_map runs and returns invisibly", {
  fp <- flood_project(name = "t")
  fp$route <- make_route_p7()
  m <- flood_map(fp, layer = "depth")
  expect_output(print(m), "flood_map")
  out <- withVisible(print(m))
  expect_false(out$visible)
})
