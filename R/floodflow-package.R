#' floodflow: map-first climate-informed flood assessment
#'
#' \pkg{floodflow} chains rainfall extreme value analysis, rainfall-runoff
#' simulation, terrain-based flow routing and water-depth estimation into a
#' single reproducible pipeline built around the \code{\link{flood_project}}
#' object. A test for changing rainfall extremes is built in, and flood
#' scenarios can be generated for present-day or climate-adjusted design events.
#'
#' The package core is pure R with no heavy dependencies. Modelling engines
#' (\pkg{terra}, \pkg{extRemes}, \pkg{airGR}, \pkg{whitebox} and others) are
#' listed under \code{Suggests} and wrapped rather than reimplemented; each is
#' loaded only when the relevant stage is run, and functions fail gracefully
#' with an informative message when an engine is not installed.
#'
#' @section Pipeline stages:
#' The workflow proceeds through a fixed sequence of functions, each populating
#' one slot of the \code{flood_project}: data ingestion, extreme value
#' analysis, climate scenario generation, roughness assignment, runoff
#' simulation, flow routing, hydraulic derivation, uncertainty analysis,
#' vulnerability overlay and mapping.
#'
#' @keywords internal
"_PACKAGE"

#' Require an optional engine package
#'
#' Internal helper implementing the \code{Suggests} guard pattern. Pipeline
#' functions call this before using an optional engine so that, when the engine
#' is not installed, the user gets a clear instruction rather than an opaque
#' error. Keeping the check in one place makes the behaviour consistent across
#' every stage.
#'
#' @param pkg Character scalar naming the required package.
#' @param stage Character scalar naming the pipeline stage requesting it, used
#'   to make the message specific.
#'
#' @return Invisibly \code{TRUE} if the package is available; otherwise throws
#'   an error with installation guidance. Never returns \code{FALSE}.
#'
#' @noRd
require_engine <- function(pkg, stage) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      sprintf(
        "The '%s' stage needs the '%s' package, which is not installed.\n  Install it with: install.packages(\"%s\")",
        stage, pkg, pkg
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Test whether an optional engine is available
#'
#' Internal predicate used mainly in examples and tests to decide whether an
#' engine-dependent code path can run. Unlike \code{require_engine}, this does
#' not error.
#'
#' @param pkg Character scalar naming the package.
#'
#' @return A single logical value.
#'
#' @noRd
has_engine <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}
