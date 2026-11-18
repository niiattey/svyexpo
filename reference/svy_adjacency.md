# Build the spatial neighbourhood graph for areal models

Creates a contiguity graph with
[`spdep::poly2nb()`](https://r-spatial.github.io/spdep/reference/poly2nb.html),
connects islands (areas with no neighbours) to their nearest area, and
returns a sparse adjacency matrix ready for INLA together with a fixed
area index.

## Usage

``` r
svy_adjacency(
  boundaries,
  area_col = "area_id",
  queen = TRUE,
  connect_islands = TRUE,
  snap = NULL
)
```

## Arguments

- boundaries:

  An `sf` polygon object.

- area_col:

  Area identifier column. Must be unique.

- queen:

  Use queen contiguity (shared vertex) rather than rook (shared edge).

- connect_islands:

  Link each island to its nearest area.

- snap:

  Distance tolerance passed to
  [`spdep::poly2nb()`](https://r-spatial.github.io/spdep/reference/poly2nb.html),
  in the units of the boundary CRS. Small values fix slivers between
  neighbouring polygons that do not quite touch.

## Value

An object of class `svy_graph`: a list with

- `adj`: sparse binary adjacency matrix (`Matrix::dgCMatrix`)

- `nb`: the `spdep` neighbour list

- `index`: data frame mapping `area_col` to integer `area_idx`

- `n_components`: number of connected components

- `islands_linked`: area ids that were connected to a neighbour

## Details

The area index matters: INLA identifies areas by integer position in the
graph, so data must be indexed with the same ordering.
[`svy_fit_bym2()`](https://niiattey.github.io/svyexpo/reference/svy_fit_bym2.md)
handles this using the `index` table returned here.

Disconnected groups of several areas (for example an archipelago region)
are left as separate components. BYM2 with `scale.model = TRUE` scales
each component separately, which is the recommended treatment
(Freni-Sterrantino et al., 2018, Spatial and Spatio-temporal
Epidemiology 26:25-34).
