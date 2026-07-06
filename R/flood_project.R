#' Create a flood project object
#'
#' Constructs the container object that carries data and results through every
#' stage of the \pkg{floodflow} pipeline. A \code{flood_project} is a named list
#' with a fixed set of slots; pipeline functions read from and write to these
#' slots, so a single object accumulates the DEM, rainfall record, fitted
#' extreme-value model, routed discharge, water depth and derived maps as it
#' passes through the workflow.
#'
#' The constructor deliberately performs no geospatial work and has no heavy
#' dependencies, so it can be created and inspected without \pkg{terra} or any
#' modelling engine installed. Slots that are not yet populated are held as
#' \code{NULL}.
#'
#' @param name Character scalar naming the project or study basin, used in
#'   printing and map titles. Defaults to \code{"flood_project"}.
#' @param crs Optional character scalar giving the target coordinate reference
#'   system as an EPSG string (for example \code{"EPSG:32630"} for UTM zone 30N,
#'   appropriate for Accra). Stored for later stages; not applied here.
#' @param meta Optional named list of user metadata to attach to the project
#'   (for example data provenance notes). Defaults to an empty list.
#'
#' @return An object of class \code{flood_project}: a named list with slots
#'   \code{name}, \code{crs}, \code{meta}, \code{dem}, \code{rainfall},
#'   \code{extremes}, \code{scenario}, \code{roughness}, \code{runoff},
#'   \code{route}, \code{hydraulics}, \code{uncertainty}, \code{vulnerability}
#'   and \code{log}. All data slots are \code{NULL} until populated by later
#'   pipeline functions. The \code{log} slot is a character vector recording the
#'   stages that have been run.
#'
#' @examples
#' fp <- flood_project(name = "Odaw basin")
#' fp
#' is_flood_project(fp)
#'
#' @seealso \code{\link{is_flood_project}} to test the class.
#' @export
flood_project <- function(name = "flood_project", crs = NULL, meta = list()) {
  if (!is.character(name) || length(name) != 1L) {
    stop("`name` must be a single character string.", call. = FALSE)
  }
  if (!is.null(crs) && (!is.character(crs) || length(crs) != 1L)) {
    stop("`crs` must be NULL or a single character string, e.g. \"EPSG:32630\".",
         call. = FALSE)
  }
  if (!is.list(meta)) {
    stop("`meta` must be a list.", call. = FALSE)
  }

  obj <- list(
    name          = name,
    crs           = crs,
    meta          = meta,
    dem           = NULL,   # terrain raster (populated by flood_data)
    rainfall      = NULL,   # rainfall record (data.frame: date, precip_mm)
    extremes      = NULL,   # fitted GEV models + return levels
    scenario      = NULL,   # climate-adjusted design event
    roughness     = NULL,   # Manning's n field or scalar
    runoff        = NULL,   # simulated discharge series
    route         = NULL,   # routed discharge + water depth
    hydraulics    = NULL,   # velocity, time-of-concentration, travel time
    uncertainty   = NULL,   # GLUE / Bayesian ensemble results
    vulnerability = NULL,   # hazard x exposure x vulnerability risk
    log           = character(0)
  )
  class(obj) <- "flood_project"
  obj
}

#' Test whether an object is a flood project
#'
#' @param x An object to test.
#'
#' @return A single logical value: \code{TRUE} if \code{x} inherits from class
#'   \code{flood_project}, otherwise \code{FALSE}.
#'
#' @examples
#' is_flood_project(flood_project())
#' is_flood_project(list())
#'
#' @export
is_flood_project <- function(x) {
  inherits(x, "flood_project")
}

#' Record a completed pipeline stage on a flood project
#'
#' Internal helper that appends a stage label to the project log and is used by
#' pipeline functions to track progress. Not exported.
#'
#' @param x A \code{flood_project} object.
#' @param stage Character scalar naming the stage just completed.
#'
#' @return The \code{flood_project} object with \code{stage} appended to its
#'   \code{log} slot.
#'
#' @noRd
log_stage <- function(x, stage) {
  x$log <- c(x$log, stage)
  x
}

#' Print a flood project
#'
#' @param x A \code{flood_project} object.
#' @param ... Ignored, present for S3 method consistency.
#'
#' @return The \code{flood_project} object \code{x}, returned invisibly. Called
#'   for the side effect of printing a compact summary to the console.
#'
#' @examples
#' print(flood_project(name = "Odaw basin"))
#'
#' @export
print.flood_project <- function(x, ...) {
  cat("<flood_project>\n")
  cat("  name: ", x$name, "\n", sep = "")
  cat("  crs:  ", if (is.null(x$crs)) "<unset>" else x$crs, "\n", sep = "")

  data_slots <- c("dem", "rainfall", "extremes", "scenario", "roughness",
                  "runoff", "route", "hydraulics", "uncertainty",
                  "vulnerability")
  filled <- data_slots[!vapply(x[data_slots], is.null, logical(1))]
  cat("  populated: ",
      if (length(filled)) paste(filled, collapse = ", ") else "<none yet>",
      "\n", sep = "")

  if (length(x$log)) {
    cat("  stages run: ", paste(x$log, collapse = " -> "), "\n", sep = "")
  }
  invisible(x)
}

#' Summarise a flood project
#'
#' @param object A \code{flood_project} object.
#' @param ... Ignored, present for S3 method consistency.
#'
#' @return A \code{data.frame} with one row per pipeline slot and columns
#'   \code{slot} and \code{status} (either \code{"populated"} or \code{"empty"}),
#'   returned invisibly after printing.
#'
#' @examples
#' summary(flood_project(name = "Odaw basin"))
#'
#' @export
summary.flood_project <- function(object, ...) {
  data_slots <- c("dem", "rainfall", "extremes", "scenario", "roughness",
                  "runoff", "route", "hydraulics", "uncertainty",
                  "vulnerability")
  status <- ifelse(
    vapply(object[data_slots], is.null, logical(1)),
    "empty", "populated"
  )
  out <- data.frame(
    slot = data_slots,
    status = unname(status),
    stringsAsFactors = FALSE
  )
  cat("Summary of <flood_project> '", object$name, "'\n", sep = "")
  print(out, row.names = FALSE)
  invisible(out)
}
