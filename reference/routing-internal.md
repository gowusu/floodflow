# Internal routing engine

Shared numerical routines for
[`flood_route`](https://gowusu.github.io/floodflow/reference/flood_route.md).
Water depth is obtained everywhere from Manning's equation for a wide
channel; hydrograph routing uses the Muskingum-Cunge family, whose grid
diffusion is varied to represent the different levels of the routing
ladder. Muskingum-Cunge is numerically stable and physically based,
which is why it underlies every method here rather than a hand-rolled
explicit Saint-Venant solver.
