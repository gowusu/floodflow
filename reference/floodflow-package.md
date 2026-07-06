# floodflow: map-first climate-informed flood assessment

floodflow chains rainfall extreme value analysis, rainfall-runoff
simulation, terrain-based flow routing and water-depth estimation into a
single reproducible pipeline built around the
[`flood_project`](https://gowusu.github.io/floodflow/reference/flood_project.md)
object. A test for changing rainfall extremes is built in, and flood
scenarios can be generated for present-day or climate-adjusted design
events.

## Details

The package core is pure R with no heavy dependencies. Modelling engines
(terra, extRemes, airGR, whitebox and others) are listed under
`Suggests` and wrapped rather than reimplemented; each is loaded only
when the relevant stage is run, and functions fail gracefully with an
informative message when an engine is not installed.

## Pipeline stages

The workflow proceeds through a fixed sequence of functions, each
populating one slot of the `flood_project`: data ingestion, extreme
value analysis, climate scenario generation, roughness assignment,
runoff simulation, flow routing, hydraulic derivation, uncertainty
analysis, vulnerability overlay and mapping.

## See also

Useful links:

- <https://github.com/gowusu/floodflow>

- Report bugs at <https://github.com/gowusu/floodflow/issues>

## Author

**Maintainer**: George Owusu <owusugeorge@ug.edu.gh>

Authors:

- George Owusu <owusugeorge@ug.edu.gh>
