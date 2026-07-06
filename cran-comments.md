## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release, so there is one NOTE for "New submission".

## Test environments

* local: R 4.x
* GitHub Actions: windows-latest (release), macOS-latest (release),
  ubuntu-latest (release, devel, oldrel-1)
* win-builder: R-devel

## Notes on dependencies

All modelling engines (terra, extRemes, airGR, whitebox, tmap, leaflet,
leafsync, ranger, lmomRFA, epwshiftr, shiny) are listed under Suggests, not
Imports. Functions that use them check availability with
requireNamespace() and fail gracefully with an informative message when a
package is not installed. Examples and tests that require an optional engine,
network access or an external binary are guarded and skipped accordingly, so
the package checks cleanly without them.

## Downloads

Functions that retrieve external data use https only, set generous timeouts,
and return informatively without error when offline. Nothing is downloaded at
install or startup.
