## Submission summary

This is the first submission of floodflow (0.1.0), a new package.

## Test environments

* local: Windows 10, R 4.6.0 -- 0 errors | 0 warnings | 0 notes
* win-builder: R-devel and R-release

## R CMD check results

Locally, 0 errors | 0 warnings | 0 notes.

On win-builder the only NOTE is the expected "New submission".

## Notes on dependencies

All modelling engines (terra, extRemes, airGR, whitebox, tmap, leaflet,
leafsync, ranger, lmomRFA, shiny) are listed under Suggests, not
Imports. Functions that use them check availability with requireNamespace()
and fail gracefully with an informative message when a package is not
installed. Examples and tests that require an optional engine, network access
or an external binary are guarded and skipped accordingly, so the package
checks cleanly without them.

## Downloads

Functions that retrieve external data use https only, set generous timeouts,
and return informatively without error when offline. Nothing is downloaded at
install or startup.
