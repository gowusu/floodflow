#' Daily rainfall and temperature for Accra, Ghana (1981 to present)
#'
#' A long-term daily weather record for Accra, on which the manual's lumped
#' pipeline is built. It is real observed-and-reanalysis data retrieved from the
#' NASA POWER service with \code{sebkc::weather()} for the Odaw basin
#' (latitude 5.60 N, longitude 0.20 W), then reduced to the columns floodflow
#' consumes. It is bundled with the package so the examples and manual keep
#' working even if the online service is unavailable; drop it straight onto a
#' \code{\link{flood_project}} as the \code{rainfall} slot. See the manual for
#' how to fetch an equivalent record for your own location.
#'
#' @format A data frame with 16637 rows and 3 variables:
#' \describe{
#'   \item{date}{Date. Calendar day, \code{YYYY-mm-dd}.}
#'   \item{precip_mm}{numeric. Daily precipitation in millimetres
#'     (NASA POWER \code{PRECTOTCORR}).}
#'   \item{temp_c}{numeric. Daily mean air temperature in degrees Celsius
#'     (NASA POWER \code{T2M}); used by the Oudin potential-evapotranspiration
#'     step inside \code{\link{flood_runoff}}.}
#' }
#'
#' @return A data frame of 16637 daily records (1981-01-01 to 2026-07-20) with
#'   three columns: \code{date} (Date), \code{precip_mm} (numeric, mm) and
#'   \code{temp_c} (numeric, degrees C). It is the default worked-example
#'   rainfall record used throughout the floodflow manual.
#'
#' @source NASA POWER daily point data, \url{https://power.larc.nasa.gov},
#'   for latitude 5.60, longitude -0.20, retrieved with \code{sebkc::weather()}.
#'
#' @examples
#' fp <- flood_project("Odaw basin, Accra")
#' fp$rainfall <- accra_rainfall
#' fp <- flood_extremes(fp)
#' fp$extremes
"accra_rainfall"
