#' Analyse rainfall extremes and test for a changing climate
#'
#' Reduces a daily rainfall record to annual maxima and fits the generalized
#' extreme value (GEV) distribution, both as a stationary model and as a
#' non-stationary model whose location parameter trends linearly with time. A
#' likelihood-ratio test compares the two, providing a formal test of whether
#' extreme rainfall has intensified over the record. Design return levels (for
#' example the 100-year daily rainfall) are computed from the stationary fit.
#'
#' By default a small internal maximum-likelihood engine is used, so no extra
#' package is required. If \pkg{extRemes} is installed and \code{engine =
#' "extRemes"}, that package is used for the stationary fit instead.
#'
#' @param x A \code{flood_project} whose \code{rainfall} slot holds a
#'   \code{data.frame}, or a \code{data.frame} directly. The data frame must
#'   have a \code{date} column (of class \code{Date} or coercible) and a
#'   \code{precip_mm} column of daily rainfall in millimetres.
#' @param periods Numeric vector of return periods, in years, at which to report
#'   design rainfall. Defaults to \code{c(2, 10, 25, 50, 100)}.
#' @param engine Which fitting engine to use: \code{"internal"} (default, no
#'   dependencies) or \code{"extRemes"} (uses the \pkg{extRemes} package if
#'   installed).
#'
#' @return If \code{x} is a \code{flood_project}, the same object with its
#'   \code{extremes} slot populated and the stage recorded in the log. If
#'   \code{x} is a \code{data.frame}, the extremes result list directly. The
#'   result is a list of class \code{flood_extremes} with elements:
#'   \code{annual_max} (a data frame of year and maximum), \code{stationary}
#'   (fitted parameters and negative log-likelihood), \code{trend} (the
#'   non-stationary fit, including the per-year location trend \code{mu1}),
#'   \code{lr_test} (a list with the likelihood-ratio \code{statistic},
#'   \code{df} and \code{p_value}), \code{trend_detected} (logical, \code{TRUE}
#'   when \code{p_value < 0.05}), and \code{return_levels} (a data frame of
#'   \code{period} and \code{level_mm}).
#'
#' @examples
#' # Build a synthetic 40-year daily rainfall record with a mild upward trend
#' set.seed(1)
#' dates <- seq(as.Date("1985-01-01"), as.Date("2024-12-31"), by = "day")
#' yr <- as.integer(format(dates, "%Y"))
#' base <- rgamma(length(dates), shape = 0.7, scale = 6)
#' trend <- 1 + 0.02 * (yr - 1985)
#' precip <- round(base * trend * rbinom(length(dates), 1, 0.3), 1)
#' rain <- data.frame(date = dates, precip_mm = precip)
#'
#' res <- flood_extremes(rain)
#' res$return_levels
#' res$trend_detected
#'
#' @references
#' Coles, S. (2001) An Introduction to Statistical Modeling of Extreme Values.
#' Springer. \doi{10.1007/978-1-4471-3675-0}
#'
#' @seealso \code{\link{flood_scenario}} to turn these design levels into a
#'   climate-adjusted event.
#' @export
flood_extremes <- function(x, periods = c(2, 10, 25, 50, 100),
                           engine = c("internal", "extRemes")) {
  engine <- match.arg(engine)

  is_project <- is_flood_project(x)
  rain <- if (is_project) x$rainfall else x

  if (is.null(rain)) {
    stop("No rainfall data found. Populate the project's `rainfall` slot, or pass a data frame.",
         call. = FALSE)
  }
  if (!is.data.frame(rain) ||
      !all(c("date", "precip_mm") %in% names(rain))) {
    stop("Rainfall must be a data frame with `date` and `precip_mm` columns.",
         call. = FALSE)
  }
  if (!inherits(rain$date, "Date")) {
    rain$date <- as.Date(rain$date)
  }
  if (any(is.na(rain$date))) {
    stop("Some `date` values could not be parsed as dates.", call. = FALSE)
  }

  # Annual maxima
  yr <- as.integer(format(rain$date, "%Y"))
  am <- stats::aggregate(rain$precip_mm, list(year = yr), max, na.rm = TRUE)
  names(am) <- c("year", "max_mm")
  am <- am[is.finite(am$max_mm), , drop = FALSE]

  if (nrow(am) < 10L) {
    warning("Fewer than 10 annual maxima; extreme value estimates will be unreliable.",
            call. = FALSE)
  }

  tt <- am$year - min(am$year)

  # Stationary fit
  if (engine == "extRemes" && requireNamespace("extRemes", quietly = TRUE)) {
    ext <- extRemes::fevd(am$max_mm, type = "GEV")
    pars <- ext$results$par
    stat <- list(par = stats::setNames(
      c(pars[["location"]], pars[["scale"]], pars[["shape"]]),
      c("mu", "sigma", "shape")),
      nll = ext$results$value, convergence = 0L)
  } else {
    stat <- fit_gev_stationary(am$max_mm)
  }

  # Non-stationary (trend in location)
  trend <- fit_gev_trend(am$max_mm, tt)

  # Likelihood-ratio test: 2 * (ll_trend - ll_stat) = 2 * (nll_stat - nll_trend)
  lr_stat <- max(2 * (stat$nll - trend$nll), 0)
  p_value <- stats::pchisq(lr_stat, df = 1, lower.tail = FALSE)

  # Return levels from the stationary fit
  rl <- gev_return_level(stat$par[["mu"]], stat$par[["sigma"]],
                         stat$par[["shape"]], periods)
  return_levels <- data.frame(period = periods, level_mm = round(rl, 2))

  result <- structure(
    list(
      annual_max = am,
      stationary = stat,
      trend = trend,
      lr_test = list(statistic = lr_stat, df = 1, p_value = p_value),
      trend_detected = isTRUE(p_value < 0.05),
      return_levels = return_levels,
      engine = engine
    ),
    class = "flood_extremes"
  )

  if (is_project) {
    x$extremes <- result
    x <- log_stage(x, "extremes")
    return(x)
  }
  result
}

#' Print a flood extremes result
#'
#' @param x A \code{flood_extremes} object.
#' @param ... Ignored, present for S3 method consistency.
#' @return The object \code{x}, invisibly; prints a compact summary.
#' @examples
#' set.seed(1)
#' rain <- data.frame(
#'   date = seq(as.Date("1990-01-01"), as.Date("2020-12-31"), by = "day"),
#'   precip_mm = round(rgamma(11323, 0.7, scale = 6), 1)
#' )
#' print(flood_extremes(rain))
#' @export
print.flood_extremes <- function(x, ...) {
  cat("<flood_extremes>\n")
  cat("  years of record: ", nrow(x$annual_max), "\n", sep = "")
  cat("  GEV (stationary): mu=", round(x$stationary$par[["mu"]], 2),
      " sigma=", round(x$stationary$par[["sigma"]], 2),
      " shape=", round(x$stationary$par[["shape"]], 3), "\n", sep = "")
  cat("  location trend (mm/yr): ", round(x$trend$par[["mu1"]], 4), "\n", sep = "")
  cat("  trend test: LR=", round(x$lr_test$statistic, 2),
      " p=", signif(x$lr_test$p_value, 3),
      if (x$trend_detected) "  (intensifying)" else "  (no significant trend)",
      "\n", sep = "")
  cat("  return levels (mm):\n")
  for (i in seq_len(nrow(x$return_levels))) {
    cat(sprintf("    %4d-yr: %.1f\n",
                x$return_levels$period[i], x$return_levels$level_mm[i]))
  }
  invisible(x)
}
