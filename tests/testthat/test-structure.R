grid_polys <- function(n = 3) {
  g <- sf::st_make_grid(
    sf::st_as_sfc(sf::st_bbox(c(xmin = 0, xmax = n, ymin = 0, ymax = n))),
    n = c(n, n)
  )
  sf::st_sf(area_id = sprintf("A%d", seq_along(g)), geometry = g)
}

test_that("queen adjacency on a 3 x 3 grid has the expected neighbour counts", {
  g <- svy_adjacency(grid_polys(3))
  expect_s3_class(g, "svy_graph")
  expect_equal(unname(spdep::card(g$nb)), c(3, 5, 3, 5, 8, 5, 3, 5, 3))
  expect_true(Matrix::isSymmetric(g$adj))
  expect_equal(g$index$area_idx, 1:9)
  expect_equal(g$n_components, 1)
})

test_that("rook adjacency drops diagonal neighbours", {
  g <- svy_adjacency(grid_polys(3), queen = FALSE)
  expect_equal(spdep::card(g$nb)[5], 4)
})

test_that("islands are linked to their nearest area", {
  polys <- grid_polys(2)
  island <- sf::st_sf(
    area_id = "ISL",
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(5, 0), c(6, 0), c(6, 1), c(5, 1), c(5, 0)
    ))))
  )
  polys <- rbind(polys, island)
  expect_message(g <- svy_adjacency(polys), "island")
  expect_equal(g$islands_linked, "ISL")
  expect_equal(g$n_components, 1)
  expect_true(all(spdep::card(g$nb) > 0))
  expect_true(Matrix::isSymmetric(g$adj))
})

test_that("duplicate area ids are rejected", {
  polys <- grid_polys(2)
  polys$area_id[2] <- polys$area_id[1]
  expect_error(svy_adjacency(polys), "unique")
})
