test_that("flood_project constructs with expected slots", {
  fp <- flood_project(name = "Odaw basin")
  expect_s3_class(fp, "flood_project")
  expect_true(is_flood_project(fp))
  expect_identical(fp$name, "Odaw basin")

  data_slots <- c("dem", "rainfall", "extremes", "scenario", "roughness",
                  "runoff", "route", "hydraulics", "uncertainty",
                  "vulnerability")
  for (s in data_slots) {
    expect_null(fp[[s]], info = paste("slot", s, "should start NULL"))
  }
  expect_identical(fp$log, character(0))
})

test_that("flood_project validates its arguments", {
  expect_error(flood_project(name = c("a", "b")), "single character")
  expect_error(flood_project(name = 1), "single character")
  expect_error(flood_project(crs = 4326), "character string")
  expect_error(flood_project(meta = "notalist"), "must be a list")
})

test_that("crs and meta are stored", {
  fp <- flood_project(name = "x", crs = "EPSG:32630",
                      meta = list(source = "SRTM"))
  expect_identical(fp$crs, "EPSG:32630")
  expect_identical(fp$meta$source, "SRTM")
})

test_that("is_flood_project discriminates correctly", {
  expect_true(is_flood_project(flood_project()))
  expect_false(is_flood_project(list()))
  expect_false(is_flood_project(NULL))
  expect_false(is_flood_project(42))
})

test_that("log_stage appends stages", {
  fp <- flood_project()
  fp <- floodflow:::log_stage(fp, "extremes")
  fp <- floodflow:::log_stage(fp, "runoff")
  expect_identical(fp$log, c("extremes", "runoff"))
})

test_that("print returns object invisibly and prints key fields", {
  fp <- flood_project(name = "Odaw basin", crs = "EPSG:32630")
  expect_output(print(fp), "flood_project")
  expect_output(print(fp), "Odaw basin")
  expect_output(print(fp), "EPSG:32630")
  ret <- withVisible(print(fp))
  expect_false(ret$visible)
  expect_s3_class(ret$value, "flood_project")
})

test_that("summary returns a status data frame", {
  fp <- flood_project()
  out <- summary(fp)
  expect_s3_class(out, "data.frame")
  expect_named(out, c("slot", "status"))
  expect_true(all(out$status == "empty"))
})

test_that("require_engine errors cleanly for a missing package", {
  expect_error(
    floodflow:::require_engine("thispackagedoesnotexist12345", "test"),
    "not installed"
  )
})

test_that("has_engine returns a logical", {
  expect_type(floodflow:::has_engine("stats"), "logical")
  expect_true(floodflow:::has_engine("stats"))
  expect_false(floodflow:::has_engine("thispackagedoesnotexist12345"))
})
