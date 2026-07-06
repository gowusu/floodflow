#' Route flow and compute water depth
#'
#' Converts the discharge series from \code{\link{flood_runoff}} into a routed
#' hydrograph and a water depth, using one of five methods that form a
#' complexity ladder. All methods obtain depth from Manning's equation for a
#' wide channel; they differ in how the flood wave is routed, from a steady
#' baseline to progressively more physics.
#'
#' \describe{
#'   \item{\code{"manning-normal"}}{Steady uniform flow. Depth is the Manning
#'     normal depth of the (unrouted) peak discharge. The fast baseline.}
#'   \item{\code{"kinematic"}}{Kinematic wave: near-pure translation of the
#'     hydrograph with negligible attenuation. Suited to steeper channels.}
#'   \item{\code{"diffusive"}}{Diffusive wave: adds hydraulic diffusion so the
#'     peak attenuates and backwater effects appear.}
#'   \item{\code{"muskingum-cunge"}}{Physically-based storage routing at
#'     diffusive-wave accuracy and low cost. The pragmatic default.}
#'   \item{\code{"dynamic"}}{Uses the discharge-scaled hydraulic diffusivity as
#'     the best stable approximation available in pure R. Full two-dimensional
#'     Saint-Venant hydrodynamics are out of scope; for those, couple to a
#'     dedicated hydraulic model.}
#' }
#'
#' All routing is carried out with the numerically stable Muskingum-Cunge
#' family, varying its diffusion to represent each rung of the ladder.
#'
#' @param x A \code{flood_project} whose \code{runoff} slot has been populated,
#'   or a discharge \code{data.frame} with columns \code{date} and \code{Q_mm}.
#' @param method One of \code{"muskingum-cunge"} (default), \code{"manning-normal"},
#'   \code{"kinematic"}, \code{"diffusive"} or \code{"dynamic"}.
#' @param width Representative channel width in metres. Default \code{20}.
#' @param slope Representative bed slope (dimensionless). Default \code{0.001}.
#' @param n Manning's roughness. If \code{x} is a project with a scalar
#'   roughness set, that value is used unless \code{n} is given explicitly.
#'   Default \code{0.035}.
#' @param celerity Wave celerity in m/s for routing. Default \code{1.5}.
#' @param dx Reach length in metres for routing. Default \code{1000}.
#' @param dt Time step in seconds. Default \code{86400} (daily).
#' @param area_km2 Catchment area in square kilometres, used to convert runoff
#'   depth (mm/day) to volumetric discharge (m^3/s). Default \code{100}.
#' @param hand Optional Height Above Nearest Drainage surface as a numeric
#'   vector or, with \pkg{terra} installed, a \code{SpatRaster}. When supplied,
#'   the scalar peak depth is turned into a spatial inundation-depth field
#'   (flooding cells whose height above drainage is below the peak water level),
#'   stored as \code{depth_raster} and drawn by \code{\link{flood_map}}. A raw
#'   DEM may be passed for a crude proxy. Default \code{NULL} (no spatial depth).
#'
#' @return If \code{x} is a \code{flood_project}, the same object with its
#'   \code{route} slot populated. Otherwise a list of class \code{flood_route}
#'   with elements \code{method}, \code{routed} (a data frame of \code{date},
#'   \code{Q_cms} inflow and \code{Q_routed} outflow), \code{peak_depth_m},
#'   \code{peak_velocity_ms}, \code{attenuation} (routed peak divided by inflow
#'   peak), \code{depth_raster} (a spatial inundation-depth field when
#'   \code{hand} was supplied, otherwise \code{NULL}) and the hydraulic settings
#'   used.
#'
#' @examples
#' set.seed(1)
#' dates <- seq(as.Date("2020-06-01"), by = "day", length.out = 30)
#' Q <- c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1, rep(0, 18))
#' disc <- data.frame(date = dates, Q_mm = Q)
#'
#' r_mc  <- flood_route(disc, method = "muskingum-cunge")
#' r_kin <- flood_route(disc, method = "kinematic")
#' # Kinematic attenuates less than Muskingum-Cunge
#' r_kin$attenuation >= r_mc$attenuation
#'
#' # Spatial inundation depth from a HAND surface (a numeric vector here; a
#' # terra SpatRaster works the same way and produces a mappable raster)
#' hand <- c(0, 0.5, 1, 2, 4, 6)
#' r_spatial <- flood_route(disc, area_km2 = 300, hand = hand)
#' r_spatial$depth_raster        # deepest in the valley, dry on high ground
#'
#' @references
#' Cunge, J. A. (1969). On the subject of a flood propagation computation
#'   method (Muskingum method). \emph{Journal of Hydraulic Research}, 7(2),
#'   205-230.
#'
#' Manning, R. (1891). On the flow of water in open channels and pipes.
#'   \emph{Transactions of the Institution of Civil Engineers of Ireland}, 20,
#'   161-207.
#'
#' @seealso \code{\link{flood_runoff}} for the discharge this routes.
#' @export
flood_route <- function(x,
                        method = c("muskingum-cunge", "manning-normal",
                                   "kinematic", "diffusive", "dynamic"),
                        width = 20, slope = 0.001, n = 0.035,
                        celerity = 1.5, dx = 1000, dt = 86400,
                        area_km2 = 100, hand = NULL) {
  method <- match.arg(method)

  is_project <- is_flood_project(x)
  if (is_project) {
    if (is.null(x$runoff)) {
      stop("No runoff found. Run flood_runoff() first.", call. = FALSE)
    }
    disc <- x$runoff$discharge
    # Use a scalar roughness from the project if present and n not overridden
    if (missing(n) && !is.null(x$roughness) &&
        is.numeric(x$roughness$n) && length(x$roughness$n) == 1L) {
      n <- x$roughness$n
    }
  } else {
    disc <- x
  }

  if (!is.data.frame(disc) || !all(c("date", "Q_mm") %in% names(disc))) {
    stop("Discharge must be a data frame with `date` and `Q_mm` columns.",
         call. = FALSE)
  }
  if (!is.numeric(width) || width <= 0) {
    stop("`width` must be a positive number.", call. = FALSE)
  }
  if (!is.numeric(n) || n <= 0) {
    stop("`n` must be a positive number.", call. = FALSE)
  }

  # Convert runoff depth (mm/day) to volumetric discharge (m^3/s)
  # Q_cms = depth[m/day] * area[m^2] / seconds_per_day
  area_m2 <- area_km2 * 1e6
  Q_cms <- (disc$Q_mm / 1000) * area_m2 / 86400

  # Route the hydrograph (except steady manning-normal)
  if (method == "manning-normal") {
    Q_routed <- Q_cms
  } else {
    D <- method_diffusivity(method, max(Q_cms), width, slope)
    Q_routed <- mc_route(Q_cms, celerity, D, dx, dt)
  }

  # Depth and velocity at the routed peak
  peak_Q <- max(Q_routed)
  peak_depth <- manning_depth(peak_Q, n, width, slope)
  peak_vel <- manning_velocity(peak_depth, n, slope)

  attenuation <- if (max(Q_cms) > 0) peak_Q / max(Q_cms) else 1

  routed <- data.frame(
    date = disc$date,
    Q_cms = round(Q_cms, 4),
    Q_routed = round(Q_routed, 4)
  )

  # Optional spatial inundation depth. When a HAND (Height Above Nearest
  # Drainage) surface or a DEM is supplied, flood every cell whose height above
  # drainage is below the peak water depth, to depth (peak_depth - HAND). This
  # turns the scalar depth into a mappable raster.
  depth_raster <- NULL
  if (!is.null(hand)) {
    depth_raster <- inundation_from_hand(hand, peak_depth)
  }

  result <- structure(
    list(
      method = method,
      routed = routed,
      peak_depth_m = round(peak_depth, 3),
      peak_velocity_ms = round(peak_vel, 3),
      attenuation = round(attenuation, 4),
      depth_raster = depth_raster,
      settings = list(width = width, slope = slope, n = n,
                      celerity = celerity, dx = dx, dt = dt,
                      area_km2 = area_km2)
    ),
    class = "flood_route"
  )

  if (is_project) {
    x$route <- result
    x <- log_stage(x, "route")
    return(x)
  }
  result
}

#' Print a flood route result
#'
#' @param x A \code{flood_route} object.
#' @param ... Ignored, present for S3 method consistency.
#' @return The object \code{x}, invisibly; prints a compact summary.
#' @examples
#' disc <- data.frame(date = seq(as.Date("2020-06-01"), by = "day",
#'                                length.out = 12),
#'                    Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1))
#' print(flood_route(disc))
#' @export
print.flood_route <- function(x, ...) {
  cat("<flood_route>\n")
  cat("  method: ", x$method, "\n", sep = "")
  cat(sprintf("  peak depth:    %.2f m\n", x$peak_depth_m))
  cat(sprintf("  peak velocity: %.2f m/s\n", x$peak_velocity_ms))
  cat(sprintf("  attenuation:   %.3f (routed peak / inflow peak)\n",
              x$attenuation))
  cat("  channel: width=", x$settings$width, "m  slope=", x$settings$slope,
      "  n=", x$settings$n, "\n", sep = "")
  invisible(x)
}
