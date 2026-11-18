# Internal helpers. Nothing in this file is exported.

`%||%` <- function(x, y) if (is.null(x)) y else x

# Stop with an informative message if columns are missing from a data frame.
check_columns <- function(data, cols, arg = "data") {
  cols <- cols[!is.null(cols)]
  missing <- setdiff(cols, names(data))
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "{cli::qty(length(missing))}Column{?s} not found in {.arg {arg}}: {.val {missing}}.",
      "i" = "Available columns: {.val {names(data)}}."
    ))
  }
  invisible(TRUE)
}

# Stop unless `x` inherits from at least one of `classes`.
check_class <- function(x, classes, arg = deparse(substitute(x))) {
  if (!inherits(x, classes)) {
    cli::cli_abort(
      "{.arg {arg}} must be of class {.cls {classes}}, not {.cls {class(x)[1]}}."
    )
  }
  invisible(TRUE)
}

# INLA is not on CRAN, so it lives in Suggests. Call this before any INLA code.
check_inla <- function() {
  if (!requireNamespace("INLA", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg INLA} package is required for model fitting.",
      "i" = "Install it with:",
      " " = "{.code install.packages(\"INLA\", repos = c(getOption(\"repos\"),
             INLA = \"https://inla.r-inla-download.org/R/stable\"), dep = TRUE)}"
    ))
  }
  invisible(TRUE)
}

# Open a raster lazily. Character inputs (local paths or GDAL virtual paths
# such as "/vsicurl/https://...") are opened without reading pixel values.
as_spatraster <- function(x, arg = "raster") {
  if (inherits(x, "SpatRaster")) {
    return(x)
  }
  if (is.character(x) && length(x) >= 1) {
    return(terra::rast(x))
  }
  cli::cli_abort(
    "{.arg {arg}} must be a {.cls SpatRaster} or a file path / GDAL URL."
  )
}

# Cache directory for downloads, created on first use.
cache_dir <- function(path = NULL) {
  path <- path %||% getOption("svyexpo.cache_dir") %||%
    file.path(tempdir(), "svyexpo")
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

# Read and write cached extraction tables. Parquet is used when arrow is
# installed, otherwise RDS. The format is chosen from the file extension.
cache_read <- function(file) {
  if (grepl("\\.parquet$", file, ignore.case = TRUE)) {
    if (!requireNamespace("arrow", quietly = TRUE)) {
      cli::cli_abort("Reading {.file {file}} requires the {.pkg arrow} package.")
    }
    return(as.data.frame(arrow::read_parquet(file)))
  }
  readRDS(file)
}

cache_write <- function(x, file) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  if (grepl("\\.parquet$", file, ignore.case = TRUE)) {
    if (!requireNamespace("arrow", quietly = TRUE)) {
      cli::cli_abort("Writing {.file {file}} requires the {.pkg arrow} package.")
    }
    arrow::write_parquet(x, file)
  } else {
    saveRDS(x, file)
  }
  invisible(file)
}
