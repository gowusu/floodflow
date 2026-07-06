# Internal generalized extreme value engine

A small, dependency-free implementation of the generalized extreme value
(GEV) distribution used as the default engine for
[`flood_extremes`](https://gowusu.github.io/floodflow/reference/flood_extremes.md).
It provides the density-based negative log-likelihood,
maximum-likelihood fitting for stationary and non-stationary (trending
location) models, and return-level calculation. When the extRemes
package is available and requested, `flood_extremes` uses it instead;
this engine guarantees the package works without it.

## Details

The parameterisation follows Coles (2001): location \\\mu\\, scale
\\\sigma \> 0\\ and shape \\\xi\\, with the Gumbel limit taken as \\\xi
\to 0\\.
