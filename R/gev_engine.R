#' Internal generalized extreme value engine
#'
#' A small, dependency-free implementation of the generalized extreme value
#' (GEV) distribution used as the default engine for \code{\link{flood_extremes}}.
#' It provides the density-based negative log-likelihood, maximum-likelihood
#' fitting for stationary and non-stationary (trending location) models, and
#' return-level calculation. When the \pkg{extRemes} package is available and
#' requested, \code{flood_extremes} uses it instead; this engine guarantees the
#' package works without it.
#'
#' The parameterisation follows Coles (2001): location \eqn{\mu}, scale
#' \eqn{\sigma > 0} and shape \eqn{\xi}, with the Gumbel limit taken as
#' \eqn{\xi \to 0}.
#'
#' @name gev-internal
#' @keywords internal
NULL

#' GEV return level
#'
#' @param mu,sigma,shape GEV parameters.
#' @param period Numeric vector of return periods in years.
#' @return Numeric vector of return levels, one per \code{period}.
#' @noRd
gev_return_level <- function(mu, sigma, shape, period) {
  p <- 1 - 1 / period
  if (abs(shape) < 1e-6) {
    mu - sigma * log(-log(p))
  } else {
    mu + (sigma / shape) * ((-log(p))^(-shape) - 1)
  }
}

#' GEV negative log-likelihood (stationary)
#' @noRd
gev_nll_stationary <- function(par, x) {
  mu <- par[1]; sigma <- par[2]; shape <- par[3]
  if (sigma <= 0) return(1e10)
  z <- (x - mu) / sigma
  if (abs(shape) < 1e-6) {
    ll <- -log(sigma) - z - exp(-z)
  } else {
    t <- 1 + shape * z
    if (any(t <= 0)) return(1e10)
    ll <- -log(sigma) - (1 / shape + 1) * log(t) - t^(-1 / shape)
  }
  -sum(ll)
}

#' GEV negative log-likelihood (location trends linearly with time)
#' @noRd
gev_nll_trend <- function(par, x, tt) {
  mu0 <- par[1]; mu1 <- par[2]; sigma <- par[3]; shape <- par[4]
  if (sigma <= 0) return(1e10)
  mu <- mu0 + mu1 * tt
  z <- (x - mu) / sigma
  if (abs(shape) < 1e-6) {
    ll <- -log(sigma) - z - exp(-z)
  } else {
    t <- 1 + shape * z
    if (any(t <= 0)) return(1e10)
    ll <- -log(sigma) - (1 / shape + 1) * log(t) - t^(-1 / shape)
  }
  -sum(ll)
}

#' Fit stationary GEV by maximum likelihood
#' @return list(par = c(mu, sigma, shape), nll = value, convergence = int)
#' @noRd
fit_gev_stationary <- function(x) {
  start <- c(mean(x), stats::sd(x), 0.1)
  fit <- stats::optim(start, gev_nll_stationary, x = x,
                      method = "Nelder-Mead",
                      control = list(maxit = 3000, reltol = 1e-10))
  list(par = stats::setNames(fit$par, c("mu", "sigma", "shape")),
       nll = fit$value, convergence = fit$convergence)
}

#' Fit non-stationary GEV (trending location) by maximum likelihood
#' @return list(par = c(mu0, mu1, sigma, shape), nll = value, convergence = int)
#' @noRd
fit_gev_trend <- function(x, tt) {
  start <- c(mean(x), 0, stats::sd(x), 0.1)
  fit <- stats::optim(start, gev_nll_trend, x = x, tt = tt,
                      method = "Nelder-Mead",
                      control = list(maxit = 3000, reltol = 1e-10))
  list(par = stats::setNames(fit$par, c("mu0", "mu1", "sigma", "shape")),
       nll = fit$value, convergence = fit$convergence)
}
