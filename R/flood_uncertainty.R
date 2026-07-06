#' Quantify uncertainty and invert for parameters (GLUE)
#'
#' Applies Generalized Likelihood Uncertainty Estimation (GLUE) to the routing
#' stage. Uncertain parameters (Manning's roughness and channel width) are
#' sampled from priors, the flood depth is predicted for each sample, and each
#' sample is weighted by an informal likelihood measuring its agreement with an
#' observed depth. This yields a predictive uncertainty band on flood depth and,
#' as the inverse problem, weighted parameter estimates conditioned on the
#' observation.
#'
#' GLUE is the workhorse uncertainty method in hydrology. A key feature it
#' reveals is equifinality: many different parameter combinations can reproduce
#' the same observation, so individual parameters may stay uncertain even when
#' the prediction is well constrained. The function reports the parameter spread
#' honestly rather than collapsing it to a single point.
#'
#' @param x A \code{flood_project} whose \code{route} slot has been populated,
#'   or a \code{flood_route} object directly. The routing settings (slope, area,
#'   peak discharge) are taken from it.
#' @param observed_depth_m Observed peak flood depth in metres to condition on,
#'   for example from a surveyed high-water mark or satellite estimate.
#' @param n_sim Number of Monte-Carlo samples. Default \code{5000}.
#' @param n_range Length-2 numeric range for the Manning's \eqn{n} prior.
#'   Default \code{c(0.02, 0.08)}.
#' @param width_range Length-2 numeric range for the channel width prior (m).
#'   Default \code{c(10, 40)}.
#' @param obs_error Relative observation error (standard deviation as a fraction
#'   of the observed depth) used in the Gaussian likelihood. Default \code{0.1}.
#' @param behavioural_fraction Fraction of samples, ranked by likelihood, kept as
#'   behavioural. Default \code{0.1}.
#' @param seed Optional integer seed for reproducibility.
#'
#' @return If \code{x} is a \code{flood_project}, the same object with its
#'   \code{uncertainty} slot populated. Otherwise a list of class
#'   \code{flood_uncertainty} with elements \code{observed_depth_m},
#'   \code{n_behavioural} (count kept), \code{depth_band} (named vector: lower,
#'   median, upper of the weighted predictive band), \code{obs_in_band}
#'   (logical), \code{estimates} (weighted-mean and range for each parameter),
#'   \code{equifinality} (the n-width correlation among behavioural sets), and
#'   \code{behavioural} (a data frame of kept samples and weights).
#'
#' @examples
#' disc <- data.frame(
#'   date = seq(as.Date("2020-06-01"), by = "day", length.out = 12),
#'   Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1)
#' )
#' r <- flood_route(disc, method = "muskingum-cunge", area_km2 = 300)
#' u <- flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
#'                        n_sim = 2000, seed = 1)
#' u$depth_band
#' u$obs_in_band
#'
#' @references
#' Beven, K. and Binley, A. (1992) The future of distributed models: model
#' calibration and uncertainty prediction. Hydrological Processes 6, 279--298.
#' \doi{10.1002/hyp.3360060305}
#'
#' @seealso \code{\link{flood_route}} for the model being conditioned.
#' @export
flood_uncertainty <- function(x, observed_depth_m,
                              n_sim = 5000,
                              n_range = c(0.02, 0.08),
                              width_range = c(10, 40),
                              obs_error = 0.1,
                              behavioural_fraction = 0.1,
                              seed = NULL) {
  is_project <- is_flood_project(x)
  route <- if (is_project) x$route else x

  if (is.null(route) || !inherits(route, "flood_route")) {
    stop("No routing result found. Run flood_route() first.", call. = FALSE)
  }
  if (missing(observed_depth_m) || !is.numeric(observed_depth_m) ||
      length(observed_depth_m) != 1L || observed_depth_m <= 0) {
    stop("`observed_depth_m` must be a single positive number.", call. = FALSE)
  }
  if (length(n_range) != 2L || length(width_range) != 2L) {
    stop("`n_range` and `width_range` must each be length-2.", call. = FALSE)
  }
  if (behavioural_fraction <= 0 || behavioural_fraction >= 1) {
    stop("`behavioural_fraction` must be in (0, 1).", call. = FALSE)
  }
  if (!is.null(seed)) set.seed(seed)

  slope <- route$settings$slope
  area_km2 <- route$settings$area_km2
  # Peak volumetric discharge that produced the routed peak
  peak_Q_cms <- max(route$routed$Q_routed)

  # Sample priors
  n_s <- stats::runif(n_sim, n_range[1], n_range[2])
  w_s <- stats::runif(n_sim, width_range[1], width_range[2])

  # Forward model: Manning normal depth at the routed peak
  pred <- manning_depth(peak_Q_cms, n_s, w_s, slope)

  # Informal Gaussian likelihood against the observation
  sigma <- obs_error * observed_depth_m
  lik <- exp(-0.5 * ((pred - observed_depth_m) / sigma)^2)

  # Behavioural set: top fraction by likelihood
  thresh <- stats::quantile(lik, 1 - behavioural_fraction, names = FALSE)
  keep <- lik >= thresh
  wts <- lik[keep] / sum(lik[keep])

  bn <- n_s[keep]; bw <- w_s[keep]; bp <- pred[keep]

  # Weighted predictive band
  ord <- order(bp)
  cum_w <- cumsum(wts[ord])
  bp_sorted <- bp[ord]
  q_at <- function(p) bp_sorted[which(cum_w >= p)[1]]
  depth_band <- c(lower = round(q_at(0.05), 3),
                  median = round(q_at(0.50), 3),
                  upper = round(q_at(0.95), 3))
  obs_in_band <- observed_depth_m >= depth_band[["lower"]] &&
    observed_depth_m <= depth_band[["upper"]]

  # Inverse estimates (weighted mean + range = honest parameter uncertainty)
  estimates <- list(
    n = c(mean = round(sum(bn * wts), 4),
          lower = round(min(bn), 4), upper = round(max(bn), 4)),
    width = c(mean = round(sum(bw * wts), 2),
              lower = round(min(bw), 2), upper = round(max(bw), 2))
  )

  equifinality <- if (length(bn) > 2) round(stats::cor(bn, bw), 3) else NA_real_

  result <- structure(
    list(
      observed_depth_m = observed_depth_m,
      n_behavioural = sum(keep),
      depth_band = depth_band,
      obs_in_band = obs_in_band,
      estimates = estimates,
      equifinality = equifinality,
      behavioural = data.frame(n = bn, width = bw, depth = bp, weight = wts)
    ),
    class = "flood_uncertainty"
  )

  if (is_project) {
    x$uncertainty <- result
    x <- log_stage(x, "uncertainty")
    return(x)
  }
  result
}

#' Print a flood uncertainty result
#'
#' @param x A \code{flood_uncertainty} object.
#' @param ... Ignored, present for S3 method consistency.
#' @return The object \code{x}, invisibly; prints a compact summary.
#' @examples
#' disc <- data.frame(date = seq(as.Date("2020-06-01"), by = "day",
#'                                length.out = 12),
#'                    Q_mm = c(0, 1, 3, 8, 18, 30, 22, 14, 8, 4, 2, 1))
#' r <- flood_route(disc, area_km2 = 300)
#' print(flood_uncertainty(r, observed_depth_m = r$peak_depth_m,
#'                         n_sim = 1000, seed = 1))
#' @export
print.flood_uncertainty <- function(x, ...) {
  cat("<flood_uncertainty> (GLUE)\n")
  cat(sprintf("  observed depth:   %.2f m\n", x$observed_depth_m))
  cat(sprintf("  behavioural sets: %d\n", x$n_behavioural))
  cat(sprintf("  90%% depth band:   [%.2f, %.2f] m (median %.2f)\n",
              x$depth_band[["lower"]], x$depth_band[["upper"]],
              x$depth_band[["median"]]))
  cat(sprintf("  observed in band: %s\n", x$obs_in_band))
  cat("  inverse estimates:\n")
  cat(sprintf("    Manning n: %.4f  [%.4f, %.4f]\n",
              x$estimates$n[["mean"]], x$estimates$n[["lower"]],
              x$estimates$n[["upper"]]))
  cat(sprintf("    width:     %.1f m  [%.1f, %.1f]\n",
              x$estimates$width[["mean"]], x$estimates$width[["lower"]],
              x$estimates$width[["upper"]]))
  if (!is.na(x$equifinality)) {
    cat(sprintf("  equifinality (n-width corr): %.2f\n", x$equifinality))
  }
  invisible(x)
}
