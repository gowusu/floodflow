#' Internal routing engine
#'
#' Shared numerical routines for \code{\link{flood_route}}. Water depth is
#' obtained everywhere from Manning's equation for a wide channel; hydrograph
#' routing uses the Muskingum-Cunge family, whose grid diffusion is varied to
#' represent the different levels of the routing ladder. Muskingum-Cunge is
#' numerically stable and physically based, which is why it underlies every
#' method here rather than a hand-rolled explicit Saint-Venant solver.
#'
#' @name routing-internal
#' @keywords internal
NULL

#' Manning normal depth for a wide channel
#' @param Q Discharge (m^3/s).
#' @param n Manning's roughness.
#' @param width Channel width (m).
#' @param slope Bed slope (dimensionless); floored to avoid division by zero.
#' @return Water depth (m).
#' @noRd
manning_depth <- function(Q, n, width, slope) {
  slope <- pmax(slope, 1e-4)
  (Q * n / (width * sqrt(slope)))^(3 / 5)
}

#' Manning velocity for a wide channel
#' @noRd
manning_velocity <- function(depth, n, slope) {
  slope <- pmax(slope, 1e-4)
  (1 / n) * depth^(2 / 3) * sqrt(slope)
}

#' Muskingum-Cunge routing coefficients
#' @param c_wave Wave celerity (m/s).
#' @param diffusivity Hydraulic diffusivity (m^2/s).
#' @param dx Reach length (m).
#' @param dt Time step (s).
#' @return Named vector c1, c2, c3 (sum to 1).
#' @noRd
mc_coeffs <- function(c_wave, diffusivity, dx, dt) {
  C <- c_wave * dt / dx
  D <- 2 * diffusivity / (c_wave * dx)
  den <- 1 + C + D
  c(c1 = (-1 + C + D) / den,
    c2 = ( 1 + C - D) / den,
    c3 = ( 1 - C + D) / den)
}

#' Route an inflow hydrograph by Muskingum-Cunge
#' @param inflow Numeric inflow series.
#' @param c_wave,diffusivity,dx,dt As in \code{mc_coeffs}.
#' @return Routed outflow series, non-negative.
#' @noRd
mc_route <- function(inflow, c_wave, diffusivity, dx, dt) {
  k <- mc_coeffs(c_wave, diffusivity, dx, dt)
  O <- numeric(length(inflow))
  O[1] <- inflow[1]
  for (t in seq_along(inflow)[-1]) {
    O[t] <- k[["c1"]] * inflow[t] + k[["c2"]] * inflow[t - 1] +
      k[["c3"]] * O[t - 1]
  }
  pmax(O, 0)
}

#' Diffusivity implied by a routing method
#'
#' The five ladder methods share one solver but differ in how much numerical
#' diffusion (attenuation) they apply, mirroring the physics: kinematic adds
#' almost none, diffusive adds a lot, Muskingum-Cunge sits between, and the
#' dynamic setting uses the discharge-scaled hydraulic diffusivity.
#' @noRd
method_diffusivity <- function(method, Q, width, slope) {
  slope <- pmax(slope, 1e-4)
  hydraulic <- Q / (2 * width * slope)   # physical hydraulic diffusivity
  switch(method,
    "manning-normal" = 0,           # no routing (steady)
    "kinematic"      = 1,           # negligible: near-pure translation
    "diffusive"      = hydraulic,   # full hydraulic diffusion
    "muskingum-cunge" = 0.5 * hydraulic,
    "dynamic"        = hydraulic    # best stable approximation
  )
}

#' Inundation depth from a HAND surface
#'
#' Turns a scalar peak flood depth into a spatial inundation-depth field. Each
#' cell is flooded to \code{water_depth - hand} where that is positive, and dry
#' otherwise, following the Height Above Nearest Drainage (HAND) method. Works on
#' a numeric vector (returned as a numeric vector) or, when \pkg{terra} is
#' installed, on a \code{SpatRaster} (returned as a \code{SpatRaster}).
#'
#' If the supplied surface looks like a raw elevation model rather than a HAND
#' surface (all values well above zero), a crude HAND proxy is derived by
#' subtracting the minimum, so a DEM can be passed directly for a quick result.
#' For accurate work, supply a true HAND raster.
#'
#' @param hand A numeric vector or \code{SpatRaster} of height above drainage
#'   (metres), or a DEM.
#' @param water_depth Scalar peak water depth (m) from routing.
#' @return Inundation depth, same type as \code{hand}: cells above the flood are
#'   zero.
#' @noRd
inundation_from_hand <- function(hand, water_depth) {
  is_raster <- has_engine("terra") && inherits(hand, "SpatRaster")

  if (is_raster) {
    mn <- terra::global(hand, "min", na.rm = TRUE)[1, 1]
    # If it looks like a DEM (min well above 0), convert to a HAND proxy
    h <- if (mn > 5) hand - mn else hand
    d <- water_depth - h
    d <- terra::app(d, function(v) ifelse(v < 0, 0, v))
    return(d)
  }

  h <- as.numeric(hand)
  mn <- min(h, na.rm = TRUE)
  if (mn > 5) h <- h - mn
  d <- water_depth - h
  d[d < 0] <- 0
  d
}
