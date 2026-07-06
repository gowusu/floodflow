#' Generate a climate-adjusted design flood event
#'
#' Turns the design return levels from \code{\link{flood_extremes}} into a
#' scenario for a chosen future, so that a flood can be modelled under
#' present-day or changed-climate conditions. Three methods are offered, from
#' zero-dependency to full-fidelity:
#'
#' \describe{
#'   \item{\code{"trend"}}{Extrapolate the fitted non-stationary location trend
#'     forward to a target year. Uses only the record already analysed.}
#'   \item{\code{"delta"}}{Scale the stationary return levels by a change factor
#'     (for example 1.15 for a 15\% increase). The default and recommended route
#'     for data-scarce settings; change factors can come from published CMIP6
#'     summaries per Shared Socioeconomic Pathway.}
#'   \item{\code{"cmip6"}}{Placeholder for ingesting downscaled CMIP6
#'     projections directly. Requires the \pkg{epwshiftr} package and network
#'     access; not yet implemented, and currently returns an informative error.}
#' }
#'
#' @param x A \code{flood_project} whose \code{extremes} slot has been populated
#'   by \code{\link{flood_extremes}}, or a \code{flood_extremes} object directly.
#' @param method One of \code{"delta"} (default), \code{"trend"} or
#'   \code{"cmip6"}.
#' @param change_factor Numeric multiplier for \code{method = "delta"}. A value
#'   of 1 leaves rainfall unchanged; 1.15 raises it by 15\%. Ignored by other
#'   methods.
#' @param horizon_year Target year for \code{method = "trend"}. The location
#'   trend is projected from the end of the record to this year. Ignored by
#'   other methods.
#' @param scenario_label Optional character label for the scenario (for example
#'   \code{"SSP5-8.5 2050"}), stored with the result and used in maps.
#'
#' @return If \code{x} is a \code{flood_project}, the same object with its
#'   \code{scenario} slot populated. Otherwise a list of class
#'   \code{flood_scenario} with elements \code{method}, \code{label},
#'   \code{baseline} (the present-day return-level data frame), \code{adjusted}
#'   (a data frame of \code{period} and \code{level_mm} under the scenario), and
#'   \code{change} (the ratio of adjusted to baseline at each period).
#'
#' @examples
#' set.seed(1)
#' rain <- data.frame(
#'   date = seq(as.Date("1985-01-01"), as.Date("2024-12-31"), by = "day"),
#'   precip_mm = round(rgamma(14610, 0.7, scale = 6) *
#'                     rbinom(14610, 1, 0.3), 1)
#' )
#' ext <- flood_extremes(rain)
#'
#' # 15% wetter design storm
#' sc <- flood_scenario(ext, method = "delta", change_factor = 1.15,
#'                      scenario_label = "SSP2-4.5 2050")
#' sc$adjusted
#'
#' @references
#' IPCC (2021). \emph{Climate Change 2021: The Physical Science Basis}.
#'   Contribution of Working Group I to the Sixth Assessment Report of the
#'   Intergovernmental Panel on Climate Change. Cambridge University Press.
#'
#' @seealso \code{\link{flood_extremes}} for the design levels this adjusts.
#' @export
flood_scenario <- function(x, method = c("delta", "trend", "cmip6"),
                           change_factor = 1.15, horizon_year = NULL,
                           scenario_label = NULL) {
  method <- match.arg(method)

  is_project <- is_flood_project(x)
  ext <- if (is_project) x$extremes else x

  if (is.null(ext) || !inherits(ext, "flood_extremes")) {
    stop("No extremes result found. Run flood_extremes() first.", call. = FALSE)
  }

  baseline <- ext$return_levels
  periods <- baseline$period

  if (method == "delta") {
    if (!is.numeric(change_factor) || length(change_factor) != 1L ||
        change_factor <= 0) {
      stop("`change_factor` must be a single positive number.", call. = FALSE)
    }
    par <- ext$stationary$par
    adj <- gev_return_level(par[["mu"]] * change_factor,
                            par[["sigma"]] * change_factor,
                            par[["shape"]], periods)
    label <- scenario_label %||%
      sprintf("delta x%.2f", change_factor)

  } else if (method == "trend") {
    if (is.null(horizon_year)) {
      stop("`horizon_year` is required for method = \"trend\".", call. = FALSE)
    }
    last_year <- max(ext$annual_max$year)
    if (horizon_year <= last_year) {
      warning("`horizon_year` is not beyond the record; trend projection is zero or negative.",
              call. = FALSE)
    }
    # Project location forward using the fitted trend, keep scale & shape
    dt <- horizon_year - min(ext$annual_max$year)
    mu_future <- ext$trend$par[["mu0"]] + ext$trend$par[["mu1"]] * dt
    adj <- gev_return_level(mu_future, ext$trend$par[["sigma"]],
                            ext$trend$par[["shape"]], periods)
    label <- scenario_label %||% sprintf("trend to %d", horizon_year)

  } else if (method == "cmip6") {
    require_engine("epwshiftr", "flood_scenario(method = \"cmip6\")")
    stop("Direct CMIP6 ingestion is not yet implemented. Use method = \"delta\" with a change factor derived from CMIP6 summaries.",
         call. = FALSE)
  }

  adjusted <- data.frame(period = periods, level_mm = round(adj, 2))
  change <- round(adjusted$level_mm / baseline$level_mm, 3)

  result <- structure(
    list(method = method, label = label,
         baseline = baseline, adjusted = adjusted, change = change),
    class = "flood_scenario"
  )

  if (is_project) {
    x$scenario <- result
    x <- log_stage(x, "scenario")
    return(x)
  }
  result
}

#' Null-coalescing helper
#' @noRd
`%||%` <- function(a, b) if (is.null(a)) b else a

#' Print a flood scenario
#'
#' @param x A \code{flood_scenario} object.
#' @param ... Ignored, present for S3 method consistency.
#' @return The object \code{x}, invisibly; prints a compact summary.
#' @examples
#' set.seed(1)
#' rain <- data.frame(
#'   date = seq(as.Date("1990-01-01"), as.Date("2020-12-31"), by = "day"),
#'   precip_mm = round(rgamma(11323, 0.7, scale = 6), 1)
#' )
#' print(flood_scenario(flood_extremes(rain), change_factor = 1.2))
#' @export
print.flood_scenario <- function(x, ...) {
  cat("<flood_scenario>\n")
  cat("  method: ", x$method, "  label: ", x$label, "\n", sep = "")
  cat("  period   baseline   adjusted   change\n")
  for (i in seq_len(nrow(x$baseline))) {
    cat(sprintf("  %5d-yr   %7.1f    %7.1f    x%.2f\n",
                x$baseline$period[i], x$baseline$level_mm[i],
                x$adjusted$level_mm[i], x$change[i]))
  }
  invisible(x)
}
