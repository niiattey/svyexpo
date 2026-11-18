# Small simulated dataset shared across tests.
sim_small <- function() svy_simulate(n_side = 3, clusters_per_area = 2,
                                     records_per_cluster = 3, seed = 42)
