#' Time of concentration by the Kirpich method
#'
#' The Kirpich (1940) empirical formula for the time of concentration of a
#' channelised catchment, in the SI form with length in metres. Time of
#' concentration is the time for water to travel from the hydraulically most
#' distant point to the outlet, a key control on peak discharge timing.
#'
#' @param length_m Flow-path length in metres.
#' @param slope Channel slope (dimensionless, m/m).
#' @return Time of concentration in minutes.
#' @references Kirpich, Z. P. (1940) Time of concentration of small
#'   agricultural watersheds. Civil Engineering 10(6), 362.
#' @examples
#' tc_kirpich(1500, 0.05)
#' @export
tc_kirpich <- function(length_m, slope) {
  if (any(length_m <= 0) || any(slope <= 0)) {
    stop("`length_m` and `slope` must be positive.", call. = FALSE)
  }
  0.0195 * length_m^0.77 * slope^(-0.385)
}

#' Time of concentration by the Kerby method (overland flow)
#'
#' The Kerby formula for overland (sheet) flow time of concentration, suited to
#' the upstream portion of a catchment before channel flow begins. Often
#' combined with Kirpich channel time in the Kerby-Kirpich approach.
#'
#' @param length_m Overland flow length in metres.
#' @param slope Overland slope (dimensionless).
#' @param retardance Kerby retardance roughness coefficient (dimensionless);
#'   higher for rougher surfaces. Default \code{0.4} (average grass).
#' @return Overland time of concentration in minutes.
#' @references Kerby, W. S. (1959) Time of concentration for overland flow.
#'   Civil Engineering, 29(3), 174.
#' @examples
#' tc_kerby(100, 0.01, retardance = 0.4)
#' @export
tc_kerby <- function(length_m, slope, retardance = 0.4) {
  if (any(length_m <= 0) || any(slope <= 0) || retardance <= 0) {
    stop("`length_m`, `slope` and `retardance` must be positive.", call. = FALSE)
  }
  1.44 * (length_m * retardance)^0.467 * slope^(-0.235)
}

#' Derive hydraulic quantities from routed flow
#'
#' Computes the family of time-and-motion quantities that a routed flood
#' implies: peak flow velocity, time of concentration (by one or more methods),
#' channel travel time, and the time-to-peak of the routed hydrograph. These are
#' the layers a geographer maps alongside depth.
#'
#' Velocity comes from Manning's equation at the routed peak depth. Time of
#' concentration is available by the Kirpich channel method, the Kerby overland
#' method, the combined Kerby-Kirpich sum, and a velocity-based travel time
#' (flow-path length divided by peak velocity). Time-to-peak is read directly
#' from the routed hydrograph.
#'
#' @param x A \code{flood_project} whose \code{route} slot has been populated,
#'   or a \code{flood_route} object directly.
#' @param length_m Representative flow-path (channel) length in metres, used for
#'   time of concentration and travel time. Default \code{5000}.
#' @param overland_m Overland flow length in metres for the Kerby component.
#'   Default \code{100}.
#' @param retardance Kerby retardance coefficient. Default \code{0.4}.
#' @param dt_hours Time step of the routed hydrograph in hours, used to convert
#'   the time-to-peak index into hours. Default \code{24} (daily).
#'
#' @return If \code{x} is a \code{flood_project}, the same object with its
#'   \code{hydraulics} slot populated. Otherwise a list of class
#'   \code{flood_hydraulics} with elements \code{peak_velocity_ms},
#'   \code{tc} (a named vector of times of concentration in minutes by method:
#'   \code{kirpich}, \code{kerby}, \code{kerby_kirpich}, \code{velocity}),
#'   \code{travel_time_min}, and \code{time_to_peak_hours}.
#'
#' @examples
#' disc <- data.frame(
#'   date = seq(as.Date("2020-06-01"), by = "day", length.out = 15),
#'   Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1, 0, 0, 0)
#' )
#' r <- flood_route(disc, method = "muskingum-cunge")
#' h <- flood_hydraulics(r, length_m = 4000, overland_m = 120)
#' h$tc
#' h$peak_velocity_ms
#'
#' @seealso \code{\link{tc_kirpich}}, \code{\link{tc_kerby}}.
#' @export
flood_hydraulics <- function(x, length_m = 5000, overland_m = 100,
                             retardance = 0.4, dt_hours = 24) {
  is_project <- is_flood_project(x)
  route <- if (is_project) x$route else x

  if (is.null(route) || !inherits(route, "flood_route")) {
    stop("No routing result found. Run flood_route() first.", call. = FALSE)
  }
  if (!is.numeric(length_m) || length_m <= 0) {
    stop("`length_m` must be a positive number.", call. = FALSE)
  }

  slope <- route$settings$slope
  v_peak <- route$peak_velocity_ms

  # Times of concentration (minutes)
  tc_k <- tc_kirpich(length_m, slope)
  tc_ke <- tc_kerby(overland_m, slope, retardance)
  tc_kk <- tc_ke + tc_kirpich(max(length_m - overland_m, 1), slope)
  tc_v <- (length_m / v_peak) / 60  # velocity method: L/V in minutes

  tc <- c(kirpich = round(tc_k, 2),
          kerby = round(tc_ke, 2),
          kerby_kirpich = round(tc_kk, 2),
          velocity = round(tc_v, 2))

  travel_time_min <- round((length_m / v_peak) / 60, 2)

  # Time to peak of the routed hydrograph, measured from the start of the
  # rising limb of the event (not the start of a possibly multi-year record).
  Qr <- route$routed$Q_routed
  peak_idx <- which.max(Qr)
  # Walk back from the peak to the last point where flow was near-zero or
  # started rising, to find the event onset.
  onset_idx <- peak_idx
  if (peak_idx > 1) {
    threshold <- 0.05 * Qr[peak_idx]
    j <- peak_idx
    while (j > 1 && Qr[j - 1] > threshold && Qr[j - 1] < Qr[j]) {
      j <- j - 1
    }
    onset_idx <- j
  }
  time_to_peak_hours <- round((peak_idx - onset_idx) * dt_hours, 2)

  result <- structure(
    list(
      peak_velocity_ms = v_peak,
      tc = tc,
      travel_time_min = travel_time_min,
      time_to_peak_hours = time_to_peak_hours,
      settings = list(length_m = length_m, overland_m = overland_m,
                      retardance = retardance, slope = slope)
    ),
    class = "flood_hydraulics"
  )

  if (is_project) {
    x$hydraulics <- result
    x <- log_stage(x, "hydraulics")
    return(x)
  }
  result
}

#' Print a flood hydraulics result
#'
#' @param x A \code{flood_hydraulics} object.
#' @param ... Ignored, present for S3 method consistency.
#' @return The object \code{x}, invisibly; prints a compact summary.
#' @examples
#' disc <- data.frame(date = seq(as.Date("2020-06-01"), by = "day",
#'                                length.out = 12),
#'                    Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1))
#' print(flood_hydraulics(flood_route(disc)))
#' @export
print.flood_hydraulics <- function(x, ...) {
  cat("<flood_hydraulics>\n")
  cat(sprintf("  peak velocity:   %.2f m/s\n", x$peak_velocity_ms))
  cat("  time of concentration (min):\n")
  cat(sprintf("    Kirpich:       %.1f\n", x$tc[["kirpich"]]))
  cat(sprintf("    Kerby:         %.1f\n", x$tc[["kerby"]]))
  cat(sprintf("    Kerby-Kirpich: %.1f\n", x$tc[["kerby_kirpich"]]))
  cat(sprintf("    velocity:      %.1f\n", x$tc[["velocity"]]))
  cat(sprintf("  travel time:     %.1f min\n", x$travel_time_min))
  cat(sprintf("  time to peak:    %.1f hours\n", x$time_to_peak_hours))
  invisible(x)
}
