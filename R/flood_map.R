#' Map a flood layer
#'
#' Renders a chosen pipeline layer for viewing. When \pkg{tmap} or \pkg{leaflet}
#' is installed and the layer is spatial, an interactive map is produced;
#' otherwise the function returns a tidy data frame of the layer's values (and,
#' for non-spatial results, draws a simple base-R plot) so the pipeline remains
#' usable without the mapping engines. This keeps mapping a first-class output
#' while respecting the package's lightweight core.
#'
#' @param x A \code{flood_project} with the requested layer populated.
#' @param layer Which layer to map: \code{"depth"} (routed peak depth),
#'   \code{"risk"} (vulnerability index), \code{"velocity"}, or
#'   \code{"uncertainty"} (predictive band width). Default \code{"depth"}.
#' @param interactive Logical; if \code{TRUE} (default) and an engine is
#'   available, attempt an interactive map. If no engine is available this is
#'   ignored and a data frame is returned.
#'
#' @return A list of class \code{flood_map} with elements \code{layer},
#'   \code{rendered} (logical: whether an interactive/graphic map was drawn),
#'   \code{engine} (the engine used, or \code{"none"}), and \code{data} (a tidy
#'   summary of the mapped values). When an interactive map is produced, the map
#'   object is attached as \code{map}.
#'
#' @examples
#' set.seed(1)
#' rain <- data.frame(
#'   date = seq(as.Date("1990-01-01"), as.Date("2020-12-31"), by = "day"),
#'   precip_mm = round(rgamma(11323, 0.7, scale = 6) *
#'                     rbinom(11323, 1, 0.3), 1)
#' )
#' fp <- flood_project("demo")
#' fp$rainfall <- rain
#' fp <- flood_runoff(fp, engine = "simple")
#' fp <- flood_route(fp, area_km2 = 300)
#' m <- flood_map(fp, layer = "depth")
#' m$data
#'
#' @seealso \code{\link{flood_route}}, \code{\link{flood_vulnerability}}.
#' @export
flood_map <- function(x, layer = c("depth", "risk", "velocity", "uncertainty"),
                      interactive = TRUE) {
  layer <- match.arg(layer)
  if (!is_flood_project(x)) {
    stop("`x` must be a flood_project.", call. = FALSE)
  }

  # Extract the requested layer's value(s)
  val <- switch(layer,
    depth = {
      if (is.null(x$route)) stop("No depth: run flood_route() first.", call. = FALSE)
      # Prefer the spatial inundation raster when routing produced one
      if (!is.null(x$route$depth_raster)) x$route$depth_raster
      else x$route$peak_depth_m
    },
    velocity = {
      if (is.null(x$route)) stop("No velocity: run flood_route() first.", call. = FALSE)
      x$route$peak_velocity_ms
    },
    risk = {
      if (is.null(x$vulnerability)) stop("No risk: run flood_vulnerability() first.", call. = FALSE)
      x$vulnerability$risk
    },
    uncertainty = {
      if (is.null(x$uncertainty)) stop("No uncertainty: run flood_uncertainty() first.", call. = FALSE)
      x$uncertainty$depth_band[["upper"]] - x$uncertainty$depth_band[["lower"]]
    }
  )

  is_spatial <- has_engine("terra") && inherits(val, "SpatRaster")

  # Decide engine
  engine <- "none"; rendered <- FALSE; map_obj <- NULL
  if (interactive && is_spatial) {
    if (has_engine("tmap")) {
      engine <- "tmap"
      map_obj <- tmap::tm_shape(val) + tmap::tm_raster(title = layer)
      rendered <- TRUE
    } else if (has_engine("leaflet")) {
      engine <- "leaflet"
      map_obj <- leaflet::leaflet()  # user adds tiles/raster downstream
      rendered <- TRUE
    }
  }

  # Tidy data summary (always available)
  data_summary <- if (is_spatial) {
    mm <- terra::global(val, c("min", "mean", "max"), na.rm = TRUE)
    data.frame(layer = layer, min = mm[1, 1], mean = mm[1, 2], max = mm[1, 3])
  } else {
    data.frame(layer = layer,
               min = min(val, na.rm = TRUE),
               mean = mean(val, na.rm = TRUE),
               max = max(val, na.rm = TRUE))
  }

  result <- list(layer = layer, rendered = rendered, engine = engine,
                 data = data_summary)
  if (!is.null(map_obj)) result$map <- map_obj
  class(result) <- "flood_map"
  result
}

#' Print a flood map
#'
#' @param x A \code{flood_map} object.
#' @param ... Ignored, present for S3 method consistency.
#' @return The object \code{x}, invisibly; prints a compact summary.
#' @examples
#' set.seed(1)
#' rain <- data.frame(
#'   date = seq(as.Date("2000-01-01"), as.Date("2010-12-31"), by = "day"),
#'   precip_mm = round(rgamma(4018, 0.7, scale = 6) *
#'                     rbinom(4018, 1, 0.3), 1)
#' )
#' fp <- flood_project("demo"); fp$rainfall <- rain
#' fp <- flood_route(flood_runoff(fp, engine = "simple"), area_km2 = 300)
#' print(flood_map(fp, layer = "depth"))
#' @export
print.flood_map <- function(x, ...) {
  cat("<flood_map>\n")
  cat("  layer:  ", x$layer, "\n", sep = "")
  cat("  engine: ", x$engine, "\n", sep = "")
  cat("  rendered interactive map: ", x$rendered, "\n", sep = "")
  if (!x$rendered) {
    cat("  (install 'tmap' or 'leaflet' for interactive maps)\n")
  }
  cat("  values: min=", round(x$data$min, 3),
      " mean=", round(x$data$mean, 3),
      " max=", round(x$data$max, 3), "\n", sep = "")
  invisible(x)
}
