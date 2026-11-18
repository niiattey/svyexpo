# Module 4: Spatial structure -------------------------------------------------

#' Build the spatial neighbourhood graph for areal models
#'
#' Creates a contiguity graph with [spdep::poly2nb()], connects islands
#' (areas with no neighbours) to their nearest area, and returns a sparse
#' adjacency matrix ready for INLA together with a fixed area index.
#'
#' The area index matters: INLA identifies areas by integer position in the
#' graph, so data must be indexed with the same ordering. [svy_fit_bym2()]
#' handles this using the `index` table returned here.
#'
#' Disconnected groups of several areas (for example an archipelago region)
#' are left as separate components. BYM2 with `scale.model = TRUE` scales each
#' component separately, which is the recommended treatment (Freni-Sterrantino
#' et al., 2018, Spatial and Spatio-temporal Epidemiology 26:25-34).
#'
#' @param boundaries An `sf` polygon object.
#' @param area_col Area identifier column. Must be unique.
#' @param queen Use queen contiguity (shared vertex) rather than rook (shared
#'   edge).
#' @param connect_islands Link each island to its nearest area.
#' @param snap Distance tolerance passed to [spdep::poly2nb()], in the units
#'   of the boundary CRS. Small values fix slivers between neighbouring
#'   polygons that do not quite touch.
#'
#' @return An object of class `svy_graph`: a list with
#'   * `adj`: sparse binary adjacency matrix (`Matrix::dgCMatrix`)
#'   * `nb`: the `spdep` neighbour list
#'   * `index`: data frame mapping `area_col` to integer `area_idx`
#'   * `n_components`: number of connected components
#'   * `islands_linked`: area ids that were connected to a neighbour
#' @export
svy_adjacency <- function(boundaries, area_col = "area_id", queen = TRUE,
                          connect_islands = TRUE, snap = NULL) {
  check_class(boundaries, "sf")
  check_columns(boundaries, area_col, arg = "boundaries")
  ids <- as.character(boundaries[[area_col]])
  if (anyDuplicated(ids)) {
    cli::cli_abort(c(
      "{.arg area_col} values must be unique.",
      "i" = "Dissolve multi-part areas first, e.g. with {.fn sf::st_union} by group."
    ))
  }

  nb_args <- list(boundaries, queen = queen, row.names = ids)
  if (!is.null(snap)) nb_args$snap <- snap
  nb <- suppressWarnings(do.call(spdep::poly2nb, nb_args))

  islands <- which(spdep::card(nb) == 0L)
  linked <- character(0)
  if (length(islands) > 0 && connect_islands && length(ids) > 1) {
    nb <- link_islands(nb, boundaries, islands)
    linked <- ids[islands]
    cli::cli_inform("Linked {length(islands)} island{?s} to the nearest area: {.val {linked}}.")
  } else if (length(islands) > 0) {
    cli::cli_warn("{length(islands)} area{?s} have no neighbours.")
  }

  n_comp <- spdep::n.comp.nb(nb)$nc
  if (n_comp > 1) {
    cli::cli_inform("The graph has {n_comp} disconnected components; BYM2 scaling handles each separately.")
  }

  structure(
    list(
      adj = nb_to_sparse(nb),
      nb = nb,
      index = stats::setNames(
        data.frame(ids, seq_along(ids), stringsAsFactors = FALSE),
        c(area_col, "area_idx")
      ),
      n_components = n_comp,
      islands_linked = linked
    ),
    class = "svy_graph"
  )
}

#' @export
print.svy_graph <- function(x, ...) {
  n <- nrow(x$index)
  card <- spdep::card(x$nb)
  cli::cli_text("{.cls svy_graph}: {n} area{?s}, {sum(card) / 2} neighbour pair{?s}")
  cli::cli_text("Neighbours per area: min {min(card)}, median {stats::median(card)}, max {max(card)}")
  cli::cli_text("Connected components: {x$n_components}")
  if (length(x$islands_linked)) {
    cli::cli_text("Islands linked: {.val {x$islands_linked}}")
  }
  invisible(x)
}

# Connect each island to its nearest polygon (symmetrically).
link_islands <- function(nb, boundaries, islands) {
  for (i in islands) {
    d <- as.numeric(sf::st_distance(boundaries[i, ], boundaries))
    d[i] <- Inf
    j <- which.min(d)
    nb[[i]] <- sort(unique(c(setdiff(nb[[i]], 0L), j)))
    nb[[j]] <- sort(unique(c(setdiff(nb[[j]], 0L), i)))
  }
  nb[] <- lapply(nb, as.integer)
  nb
}

# Binary sparse adjacency matrix from an nb object.
nb_to_sparse <- function(nb) {
  n <- length(nb)
  i <- rep(seq_len(n), spdep::card(nb))
  j <- unlist(lapply(nb, function(x) x[x != 0L]))
  Matrix::sparseMatrix(
    i = i, j = j, x = 1, dims = c(n, n),
    dimnames = list(attr(nb, "region.id"), attr(nb, "region.id"))
  )
}
