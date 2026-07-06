#' Potential evapotranspiration by the Oudin formula
#'
#' Computes daily potential evapotranspiration (PET) from air temperature and
#' latitude alone, following Oudin et al. (2005). Because it needs no radiation,
#' humidity or wind data, it suits data-scarce settings where only temperature
#' is available. Extraterrestrial radiation is derived from solar geometry for
#' the given day of year and latitude.
#'
#' @param jday Integer vector of Julian day of year (1--366).
#' @param temp_c Numeric vector of mean daily air temperature in degrees
#'   Celsius, the same length as \code{jday}.
#' @param lat_deg Latitude in decimal degrees (positive north, negative south).
#'
#' @return A numeric vector of PET in millimetres per day, never negative.
#'
#' @references
#' Oudin, L. et al. (2005) Which potential evapotranspiration input for a lumped
#' rainfall-runoff model? Journal of Hydrology 303, 290--306.
#' \doi{10.1016/j.jhydrol.2004.08.026}
#'
#' @examples
#' # A year of PET for Accra (latitude ~5.6 N)
#' jd <- 1:365
#' temp <- 28 + 3 * sin(2 * pi * (jd - 40) / 365)
#' pet <- pet_oudin(jd, temp, lat_deg = 5.6)
#' range(pet)
#'
#' @export
pet_oudin <- function(jday, temp_c, lat_deg) {
  if (length(jday) != length(temp_c)) {
    stop("`jday` and `temp_c` must have the same length.", call. = FALSE)
  }
  if (!is.numeric(lat_deg) || length(lat_deg) != 1L) {
    stop("`lat_deg` must be a single number.", call. = FALSE)
  }
  lat <- lat_deg * pi / 180
  dr <- 1 + 0.033 * cos(2 * pi / 365 * jday)
  decl <- 0.409 * sin(2 * pi / 365 * jday - 1.39)
  ws <- acos(pmin(pmax(-tan(lat) * tan(decl), -1), 1))
  Re <- (24 * 60 / pi) * 0.0820 * dr *
    (ws * sin(lat) * sin(decl) + cos(lat) * cos(decl) * sin(ws))
  pet <- ifelse(temp_c + 5 > 0, Re / 2.45 * (temp_c + 5) / 100, 0)
  pmax(pet, 0)
}

#' Simple conceptual rainfall-runoff fallback
#'
#' A lightweight production-store model with a triangular unit-hydrograph
#' routing lag, used by \code{\link{flood_runoff}} when \pkg{airGR} is not
#' installed. It is not GR4J; it is a physically sane translator that conserves
#' mass and lags flow after rainfall, sufficient for teaching and for producing
#' a discharge series when the full engine is unavailable.
#'
#' @param P Numeric vector of daily rainfall (mm).
#' @param PET Numeric vector of daily PET (mm), same length as \code{P}.
#' @param store_max Production-store capacity (mm).
#' @param init Initial store fraction, in \eqn{[0, 1]}.
#' @param uh_days Half-width of the triangular unit hydrograph, in days.
#' @return A numeric vector of discharge (mm/day), never negative.
#' @noRd
runoff_simple <- function(P, PET, store_max = 100, init = 0.3, uh_days = 3) {
  n <- length(P)
  S <- init * store_max
  eff <- numeric(n)
  for (i in seq_len(n)) {
    S <- max(S + P[i] - PET[i], 0)
    frac <- S / store_max
    eff[i] <- max(frac * P[i] + max(S - store_max, 0), 0)
    S <- min(S, store_max)
  }
  uh <- c(seq_len(uh_days), rev(seq_len(uh_days - 1)))
  uh <- uh / sum(uh)
  Q <- as.numeric(stats::filter(eff, uh, sides = 1))
  Q[is.na(Q)] <- 0
  pmax(Q, 0)
}

#' Simulate discharge from rainfall
#'
#' Converts a daily rainfall record into a discharge (streamflow) series, the
#' link between rainfall in the sky and water in the channel. floodflow operates
#' on a daily timestep: each row of the rainfall data frame is one day, and
#' discharge is returned in mm/day; aggregate any sub-daily record to daily
#' totals before use. Potential
#' evapotranspiration is computed by the Oudin formula from temperature and
#' latitude. When \pkg{airGR} is installed, the GR4J lumped conceptual model is
#' used; otherwise a simple conceptual fallback runs so the pipeline still
#' produces a discharge series.
#'
#' GR4J parameters may be supplied; if not, illustrative defaults are used. In a
#' real study with observed discharge, calibrate the parameters (for example
#' with \code{airGR::Calibration_Michel}) before relying on the output.
#'
#' Infiltration is represented \emph{implicitly}, not as a separate step. Rainfall
#' is partitioned into runoff and soil storage by a production store (a
#' soil-moisture bucket of capacity \code{store_max}): when the soil is dry most
#' rain infiltrates and little runs off, and as it saturates the runoff fraction
#' rises toward one. This is a saturation-excess representation. There is no
#' explicit Green-Ampt, Horton, or SCS curve-number infiltration function in this
#' version (curve-number infiltration is planned for a future release).
#'
#' @param x A \code{flood_project} whose \code{rainfall} slot holds a data frame
#'   with \code{date} and \code{precip_mm}, or such a data frame directly. A
#'   \code{temp_c} column is used if present; otherwise a constant temperature
#'   is assumed.
#' @param lat_deg Latitude in decimal degrees, for PET. Defaults to \code{5.6}
#'   (Accra).
#' @param temp_c Constant air temperature (degrees C) used when the rainfall
#'   data has no \code{temp_c} column. Default \code{28}.
#' @param params Optional named numeric vector of GR4J parameters \code{X1},
#'   \code{X2}, \code{X3}, \code{X4}. Ignored by the fallback.
#' @param engine Which engine to use: \code{"auto"} (GR4J if \pkg{airGR} is
#'   present, else the fallback), \code{"airGR"} (require GR4J) or
#'   \code{"simple"} (force the fallback).
#'
#' @return If \code{x} is a \code{flood_project}, the same object with its
#'   \code{runoff} slot populated. Otherwise a list of class
#'   \code{flood_runoff} with elements \code{discharge} (a data frame of
#'   \code{date} and \code{Q_mm}), \code{pet} (the PET series), \code{engine}
#'   used, and \code{peak} (the maximum discharge and its date).
#'
#' @examples
#' set.seed(1)
#' dates <- seq(as.Date("2020-01-01"), as.Date("2021-12-31"), by = "day")
#' rain <- data.frame(
#'   date = dates,
#'   precip_mm = round(rgamma(length(dates), 0.7, scale = 8) *
#'                     rbinom(length(dates), 1, 0.4), 1)
#' )
#' rr <- flood_runoff(rain, engine = "simple")
#' rr$peak
#'
#' @seealso \code{\link{pet_oudin}} for the evapotranspiration input.
#' @export
flood_runoff <- function(x, lat_deg = 5.6, temp_c = 28,
                         params = NULL,
                         engine = c("auto", "airGR", "simple")) {
  engine <- match.arg(engine)

  is_project <- is_flood_project(x)
  rain <- if (is_project) x$rainfall else x

  if (is.null(rain)) {
    stop("No rainfall data found. Populate the project's `rainfall` slot, or pass a data frame.",
         call. = FALSE)
  }
  if (!is.data.frame(rain) || !all(c("date", "precip_mm") %in% names(rain))) {
    stop("Rainfall must be a data frame with `date` and `precip_mm` columns.",
         call. = FALSE)
  }
  if (!inherits(rain$date, "Date")) rain$date <- as.Date(rain$date)

  # Temperature series and PET
  jday <- as.integer(format(rain$date, "%j"))
  temp <- if ("temp_c" %in% names(rain)) rain$temp_c else rep(temp_c, nrow(rain))
  pet <- pet_oudin(jday, temp, lat_deg)

  # Resolve engine
  use_airgr <- switch(engine,
    auto  = has_engine("airGR"),
    airGR = { require_engine("airGR", "flood_runoff(engine = \"airGR\")"); TRUE },
    simple = FALSE
  )

  if (use_airgr) {
    P <- rain$precip_mm
    pr <- params %||% c(X1 = 350, X2 = 0.8, X3 = 90, X4 = 1.6)
    inputs <- airGR::CreateInputsModel(
      FUN_MOD = airGR::RunModel_GR4J,
      DatesR = as.POSIXct(rain$date, tz = "UTC"),
      Precip = P, PotEvap = pet
    )
    idx <- seq_along(P)
    runopts <- airGR::CreateRunOptions(
      FUN_MOD = airGR::RunModel_GR4J,
      InputsModel = inputs,
      IndPeriod_WarmUp = idx[1],
      IndPeriod_Run = idx,
      warnings = FALSE
    )
    sim <- airGR::RunModel_GR4J(
      InputsModel = inputs, RunOptions = runopts,
      Param = as.numeric(pr[c("X1", "X2", "X3", "X4")])
    )
    Q <- sim$Qsim
    eng <- "airGR (GR4J)"
  } else {
    Q <- runoff_simple(rain$precip_mm, pet)
    eng <- "simple (fallback)"
  }

  Q[is.na(Q)] <- 0
  discharge <- data.frame(date = rain$date, Q_mm = round(Q, 4))
  peak_i <- which.max(discharge$Q_mm)

  result <- structure(
    list(
      discharge = discharge,
      pet = pet,
      engine = eng,
      peak = list(Q_mm = discharge$Q_mm[peak_i],
                  date = discharge$date[peak_i])
    ),
    class = "flood_runoff"
  )

  if (is_project) {
    x$runoff <- result
    x <- log_stage(x, "runoff")
    return(x)
  }
  result
}

#' Print a flood runoff result
#'
#' @param x A \code{flood_runoff} object.
#' @param ... Ignored, present for S3 method consistency.
#' @return The object \code{x}, invisibly; prints a compact summary.
#' @examples
#' set.seed(1)
#' rain <- data.frame(
#'   date = seq(as.Date("2020-01-01"), as.Date("2020-12-31"), by = "day"),
#'   precip_mm = round(rgamma(366, 0.7, scale = 8) *
#'                     rbinom(366, 1, 0.4), 1)
#' )
#' print(flood_runoff(rain, engine = "simple"))
#' @export
print.flood_runoff <- function(x, ...) {
  cat("<flood_runoff>\n")
  cat("  engine: ", x$engine, "\n", sep = "")
  cat("  days:   ", nrow(x$discharge), "\n", sep = "")
  cat(sprintf("  peak discharge: %.2f mm/day on %s\n",
              x$peak$Q_mm, format(x$peak$date)))
  cat(sprintf("  mean PET: %.2f mm/day\n", mean(x$pet, na.rm = TRUE)))
  invisible(x)
}
