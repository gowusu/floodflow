#' Default Manning's roughness by land-cover class
#'
#' A named numeric vector of representative Manning's \eqn{n} values for common
#' land-cover classes, drawn from standard hydraulic references and distributed
#' hydrological models. Used as the default lookup by \code{\link{roughness}}
#' when \code{method = "landcover"}. Users may supply their own table.
#'
#' @format A named numeric vector. Names are land-cover classes; values are
#'   Manning's \eqn{n}.
#'
#' @examples
#' floodflow_lc_roughness["forest"]
#'
#' @export
floodflow_lc_roughness <- c(
  water     = 0.030,
  urban     = 0.015,
  bare      = 0.025,
  grassland = 0.035,
  cropland  = 0.040,
  shrub     = 0.050,
  forest    = 0.100,
  wetland   = 0.070
)

#' NDVI to Manning's n
#'
#' Maps a normalized difference vegetation index (NDVI) to Manning's roughness
#' with a simple, monotonic empirical relationship: rougher surfaces correspond
#' to denser vegetation. NDVI is clamped to \eqn{[0, 1]} before scaling linearly
#' between \code{n_min} (bare) and \code{n_max} (dense vegetation).
#'
#' @param ndvi Numeric vector of NDVI values.
#' @param n_min,n_max Manning's \eqn{n} at bare and fully vegetated surfaces.
#' @return A numeric vector of Manning's \eqn{n}, the same length as \code{ndvi}.
#' @noRd
ndvi_to_manning <- function(ndvi, n_min = 0.020, n_max = 0.120) {
  ndvi <- pmin(pmax(ndvi, 0), 1)
  n_min + (n_max - n_min) * ndvi
}

#' Assign Manning's roughness
#'
#' Produces a Manning's roughness coefficient (\eqn{n}) for use by the routing
#' stage, by one of three methods. Roughness is the single most sensitive
#' hydraulic parameter, so the function makes the choice explicit and always
#' lets the user override it.
#'
#' \describe{
#'   \item{\code{"constant"}}{A single \eqn{n} applied everywhere. Simplest and
#'     fully reproducible.}
#'   \item{\code{"landcover"}}{Look up \eqn{n} from land-cover classes using a
#'     table (the built-in \code{\link{floodflow_lc_roughness}} by default, or a
#'     user-supplied named vector).}
#'   \item{\code{"ndvi"}}{Derive \eqn{n} from NDVI with a monotonic empirical
#'     function, so remotely-sensed vegetation density sets roughness.}
#' }
#'
#' The function operates on plain vectors and, when \pkg{terra} is installed, on
#' raster inputs (\code{SpatRaster}). Raster handling is optional: if the input
#' is a raster and \pkg{terra} is not available, the function stops with an
#' informative message.
#'
#' @param x A \code{flood_project}, or a data input directly. For
#'   \code{method = "constant"} the data input is ignored. For
#'   \code{method = "landcover"} it is a character/factor vector of classes or a
#'   land-cover \code{SpatRaster}. For \code{method = "ndvi"} it is a numeric
#'   vector or an NDVI \code{SpatRaster}.
#' @param method One of \code{"constant"}, \code{"landcover"} or \code{"ndvi"}.
#' @param value Manning's \eqn{n} for \code{method = "constant"}. Default
#'   \code{0.035} (natural channel).
#' @param table Named numeric vector mapping land-cover classes to \eqn{n} for
#'   \code{method = "landcover"}. Defaults to \code{\link{floodflow_lc_roughness}}.
#' @param n_min,n_max Roughness bounds for \code{method = "ndvi"}.
#' @param data Optional explicit data input when \code{x} is a
#'   \code{flood_project}; overrides looking in the project. Land-cover classes
#'   or NDVI values, as a vector or \code{SpatRaster}.
#'
#' @return If \code{x} is a \code{flood_project}, the same object with its
#'   \code{roughness} slot populated by a list of class \code{flood_roughness}.
#'   Otherwise the \code{flood_roughness} list directly, with elements
#'   \code{method}, \code{n} (the resulting roughness: a scalar, numeric vector,
#'   or \code{SpatRaster}), and \code{summary} (min, mean and max of \eqn{n}).
#'
#' @examples
#' # Constant roughness
#' roughness(method = "constant", value = 0.03)
#'
#' # From land-cover classes
#' cls <- c("urban", "cropland", "forest", "water")
#' roughness(cls, method = "landcover")$n
#'
#' # From NDVI values
#' roughness(c(0, 0.3, 0.6, 0.9), method = "ndvi")$n
#'
#' @references
#' Manning, R. (1891). On the flow of water in open channels and pipes.
#'   \emph{Transactions of the Institution of Civil Engineers of Ireland}, 20,
#'   161-207.
#'
#' Chow, V. T. (1959). \emph{Open-Channel Hydraulics}. McGraw-Hill, New York.
#'
#' @seealso \code{\link{floodflow_lc_roughness}} for the default lookup table.
#' @export
roughness <- function(x = NULL,
                      method = c("constant", "landcover", "ndvi"),
                      value = 0.035,
                      table = floodflow_lc_roughness,
                      n_min = 0.020, n_max = 0.120,
                      data = NULL) {
  method <- match.arg(method)

  is_project <- is_flood_project(x)
  input <- if (is_project) data else x

  is_raster <- function(obj) {
    !is.null(obj) && has_engine("terra") && inherits(obj, "SpatRaster")
  }
  looks_like_raster <- function(obj) {
    !is.null(obj) && inherits(obj, "SpatRaster")
  }

  # Guard: raster input but terra unavailable
  if (looks_like_raster(input) && !has_engine("terra")) {
    stop("Raster input requires the 'terra' package. Install it with install.packages(\"terra\").",
         call. = FALSE)
  }

  if (method == "constant") {
    if (!is.numeric(value) || length(value) != 1L || value <= 0) {
      stop("`value` must be a single positive number.", call. = FALSE)
    }
    n <- value

  } else if (method == "landcover") {
    if (is.null(input)) {
      stop("method = \"landcover\" needs land-cover classes (a vector or raster).",
           call. = FALSE)
    }
    if (!is.numeric(table) || is.null(names(table))) {
      stop("`table` must be a named numeric vector of class -> n.", call. = FALSE)
    }
    if (is_raster(input)) {
      # Pull cell values, map each class label to n, write back to a raster
      vals <- terra::values(input)
      cls <- as.character(vals[, 1])
      mapped <- table[cls]
      if (any(is.na(mapped) & !is.na(cls))) {
        stop("Land-cover raster contains classes not present in `table`.",
             call. = FALSE)
      }
      n <- terra::setValues(input, mapped)
    } else {
      cls <- as.character(input)
      mapped <- table[cls]
      if (any(is.na(mapped) & !is.na(cls))) {
        bad <- unique(cls[is.na(mapped) & !is.na(cls)])
        stop("Unknown land-cover class(es): ", paste(bad, collapse = ", "),
             ". Add them to `table`.", call. = FALSE)
      }
      n <- unname(mapped)
    }

  } else if (method == "ndvi") {
    if (is.null(input)) {
      stop("method = \"ndvi\" needs NDVI values (a numeric vector or raster).",
           call. = FALSE)
    }
    if (!is.numeric(n_min) || !is.numeric(n_max) || n_min <= 0 || n_max <= n_min) {
      stop("Require 0 < n_min < n_max.", call. = FALSE)
    }
    if (is_raster(input)) {
      n <- terra::app(input, function(v) ndvi_to_manning(v, n_min, n_max))
    } else {
      if (!is.numeric(input)) {
        stop("NDVI input must be numeric.", call. = FALSE)
      }
      n <- ndvi_to_manning(input, n_min, n_max)
    }
  }

  # Summary works for scalar, vector, or raster
  smry <- roughness_summary(n)

  result <- structure(
    list(method = method, n = n, summary = smry),
    class = "flood_roughness"
  )

  if (is_project) {
    x$roughness <- result
    x <- log_stage(x, "roughness")
    return(x)
  }
  result
}

#' Summarise a roughness field regardless of type
#' @noRd
roughness_summary <- function(n) {
  if (inherits(n, "SpatRaster")) {
    rng <- terra::global(n, c("min", "mean", "max"), na.rm = TRUE)
    c(min = rng[1, 1], mean = rng[1, 2], max = rng[1, 3])
  } else {
    c(min = min(n, na.rm = TRUE),
      mean = mean(n, na.rm = TRUE),
      max = max(n, na.rm = TRUE))
  }
}

#' Print a roughness result
#'
#' @param x A \code{flood_roughness} object.
#' @param ... Ignored, present for S3 method consistency.
#' @return The object \code{x}, invisibly; prints a compact summary.
#' @examples
#' print(roughness(method = "constant", value = 0.04))
#' @export
print.flood_roughness <- function(x, ...) {
  cat("<flood_roughness>\n")
  cat("  method: ", x$method, "\n", sep = "")
  type <- if (inherits(x$n, "SpatRaster")) "raster" else
    if (length(x$n) == 1L) "constant" else "vector"
  cat("  type:   ", type, "\n", sep = "")
  cat(sprintf("  Manning n: min=%.3f mean=%.3f max=%.3f\n",
              x$summary[["min"]], x$summary[["mean"]], x$summary[["max"]]))
  invisible(x)
}
