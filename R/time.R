# Time handling for exposure assignment ---------------------------------------
#
# Every exposure source, whatever its format, is reduced to a matrix of values
# (rows: locations or units, columns: consecutive time *periods*) plus a table
# describing the periods. A period is one day, one month, one year, or, for
# irregular layers such as 8-day composites, the span from one layer date to
# the day before the next. Exposure windows are then averaged over periods,
# weighting each period by the number of days it overlaps the window. This is
# what lets a monthly raster, a daily monitor series and an annual table all
# answer the same question: "what was the mean exposure from 270 days before
# birth to the day of birth, and how much of that window had data?"

# Coerce to Date; character input must be ISO (YYYY-MM-DD or YYYY/MM/DD) so
# that day/month order can never be guessed wrongly.
as_date_strict <- function(x, arg = "date") {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(format(x, "%Y-%m-%d", tz = "UTC")))
  if (is.factor(x)) x <- as.character(x)
  if (is.character(x)) {
    iso <- "^[0-9]{4}[-/][0-9]{1,2}[-/][0-9]{1,2}"
    present <- !is.na(x) & trimws(x) != ""
    if (any(present & !grepl(iso, trimws(x)))) {
      cli::cli_abort(c(
        "Could not read {.arg {arg}} as dates.",
        "i" = "Use ISO format (YYYY-MM-DD), or convert with {.fn as.Date} and an explicit {.arg format} first."
      ))
    }
    cut <- sub(paste0("(", sub("\\^", "", iso), ").*"), "\\1", trimws(x))
    out <- as.Date(gsub("/", "-", ifelse(present, cut, NA_character_), fixed = TRUE),
                   format = "%Y-%m-%d")
    if (any(is.na(out) & present)) {
      cli::cli_abort("Some values of {.arg {arg}} are not valid calendar dates.")
    }
    return(out)
  }
  cli::cli_abort("{.arg {arg}} must be a Date, POSIXct or ISO date string, not {.cls {class(x)[1]}}.")
}

# Does a datetime vector carry a time of day (i.e. is it sub-daily)?
has_time_of_day <- function(x) {
  if (!inherits(x, "POSIXt")) return(FALSE)
  secs <- as.numeric(format(x, "%H")) * 3600 + as.numeric(format(x, "%M")) * 60 +
    as.numeric(format(x, "%S"))
  any(secs[!is.na(secs)] != 0)
}

# Calendar month arithmetic that clamps to the end of short months
# (31 Jan + 1 month = 28/29 Feb), vectorised over `d` and `n`.
add_months <- function(d, n) {
  lt <- as.POSIXlt(d, tz = "UTC")
  total <- lt$year * 12 + lt$mon + n
  y <- 1900 + total %/% 12
  m <- total %% 12 + 1
  first <- as.Date(ISOdate(y, m, 1))
  next_first <- as.Date(ISOdate(y + (m == 12), m %% 12 + 1, 1))
  first + pmin(lt$mday, as.integer(next_first - first)) - 1
}

add_units <- function(d, n, unit) {
  switch(unit,
    days   = d + n,
    weeks  = d + 7 * n,
    months = add_months(d, n),
    years  = add_months(d, 12 * n),
    cli::cli_abort("Unknown {.arg unit} {.val {unit}}.")
  )
}

floor_step <- function(d, step) {
  switch(step,
    day   = d,
    month = as.Date(format(d, "%Y-%m-01")),
    year  = as.Date(format(d, "%Y-01-01")),
    layer = d
  )
}

# Decide whether dates are daily, monthly, annual or irregular. The median gap
# is used, so a few missing days or months do not change the answer.
infer_step <- function(dates) {
  d <- sort(unique(dates[!is.na(dates)]))
  if (length(d) < 2) {
    cli::cli_abort(c(
      "Cannot infer the time step from a single date.",
      "i" = "Set {.arg step} to {.val day}, {.val month} or {.val year}, or use {.code static = TRUE} for a raster without time."
    ))
  }
  gap <- stats::median(as.integer(diff(d)))
  if (gap == 1) "day"
  else if (gap >= 28 && gap <= 31) "month"
  else if (gap >= 365 && gap <= 366) "year"
  else "layer"
}

# Table of consecutive periods covering `dates` at the given step.
# Returns data.frame(start, end, days); `end` is inclusive.
make_periods <- function(dates, step) {
  d <- sort(unique(floor_step(dates[!is.na(dates)], step)))
  if (step == "layer") {
    gap <- if (length(d) > 1) stats::median(as.integer(diff(d))) else 1L
    start <- d
    end <- c(d[-1] - 1, d[length(d)] + gap - 1)
  } else {
    unit <- c(day = "days", month = "months", year = "years")[[step]]
    start <- switch(step,
      day = seq(min(d), max(d), by = "day"),
      month = seq(min(d), max(d), by = "month"),
      year = seq(min(d), max(d), by = "year")
    )
    end <- add_units(start, 1, unit) - 1
  }
  data.frame(start = start, end = end, days = as.integer(end - start) + 1L)
}

# Validate and normalise the `windows` argument. Each window is c(start, end),
# offsets from the anchor date in `unit`, with both ends inclusive.
normalise_windows <- function(windows) {
  if (is.numeric(windows) && length(windows) == 2) windows <- list(window = windows)
  if (!is.list(windows) || length(windows) == 0) {
    cli::cli_abort(c(
      "{.arg windows} must be a named list of {.code c(start, end)} pairs.",
      "i" = "Example: {.code list(prenatal = c(-270, -1), postnatal = c(0, 364))}"
    ))
  }
  if (is.null(names(windows)) || any(names(windows) == "")) {
    names(windows) <- ifelse(
      is.null(names(windows)) | names(windows) == "",
      paste0("w", seq_along(windows)), names(windows)
    )
  }
  ok <- vapply(windows, function(w) is.numeric(w) && length(w) == 2 && !anyNA(w) && w[1] <= w[2],
               logical(1))
  if (!all(ok)) {
    cli::cli_abort(c(
      "Each window must be two numbers {.code c(start, end)} with start <= end.",
      "x" = "Problem with: {.val {names(windows)[!ok]}}."
    ))
  }
  if (anyDuplicated(names(windows))) cli::cli_abort("Window names must be unique.")
  windows
}

#' Ready-made exposure windows
#'
#' Returns a named list of windows that can be passed to [svy_expose()].
#' Offsets are relative to the anchor date (normally the date of birth).
#'
#' @param preset One of:
#'   * `"prenatal_postnatal"`: `prenatal` = 270 days before birth to the day
#'     before; `postnatal` = birth to 364 days after (first year of life).
#'   * `"trimesters"`: three prenatal trimesters of about 90 days each.
#'   * `"first_1000_days"`: conception (270 days before birth) to 730 days
#'     after birth.
#'   * `"lifetime_to_date"`: 0 to 5 years before the anchor date; use with an
#'     interview date as the anchor.
#'
#' @return A named list of `c(start, end)` pairs in **days**. Pass
#'   `window_unit = "days"` (the default) to [svy_expose()].
#' @examples
#' svy_windows("trimesters")
#' @export
svy_windows <- function(preset = c("prenatal_postnatal", "trimesters",
                                   "first_1000_days", "lifetime_to_date")) {
  preset <- match.arg(preset)
  switch(preset,
    prenatal_postnatal = list(prenatal = c(-270, -1), postnatal = c(0, 364)),
    trimesters = list(trimester1 = c(-270, -181), trimester2 = c(-180, -91),
                      trimester3 = c(-90, -1)),
    first_1000_days = list(first_1000_days = c(-270, 729)),
    lifetime_to_date = list(last_5_years = c(-1826, 0))
  )
}

# Mean exposure over each person's windows, weighting periods by the number of
# days they overlap the window, together with the share of window days that
# had data.
#   V       numeric matrix, rows = locations, columns = periods
#   periods data.frame(start, end, days) from make_periods()
#   row     row of V for each person
#   from,to Lists of Date vectors (inclusive window ends), one list element
#           per window, each with one date per person
# Returns a list (one element per window) of list(value, coverage).
window_mean <- function(V, periods, row, from, to) {
  n <- length(row)
  st <- as.numeric(periods$start)
  en <- as.numeric(periods$end)
  dy <- periods$days
  nper <- length(st)

  valid <- !is.na(V)
  V0 <- V
  V0[!valid] <- 0
  # Running totals along time, padded with a leading zero column, so the
  # contribution of any run of whole periods is a single subtraction.
  cV <- cbind(0, t(apply(sweep(V0, 2, dy, "*"), 1, cumsum)))
  cD <- cbind(0, t(apply(sweep(valid * 1, 2, dy, "*"), 1, cumsum)))

  lapply(seq_along(from), function(w) {
    a <- as.numeric(from[[w]])
    b <- as.numeric(to[[w]])
    value <- rep(NA_real_, n)
    coverage <- rep(NA_real_, n)
    for (k in seq_len(n)) {
      if (is.na(row[k]) || is.na(a[k]) || is.na(b[k])) next
      i <- row[k]
      ia <- findInterval(a[k], st)
      ib <- findInterval(b[k], st)
      num <- 0
      den <- 0
      # Edge periods may overlap the window only partly.
      for (p in unique(c(ia, ib))) {
        if (p < 1 || p > nper) next
        ov <- min(en[p], b[k]) - max(st[p], a[k]) + 1
        if (ov > 0 && valid[i, p]) {
          num <- num + ov * V[i, p]
          den <- den + ov
        }
      }
      # Periods strictly between the edges lie wholly inside the window.
      if (ib - ia >= 2) {
        lo <- ia + 1
        hi <- ib - 1
        num <- num + cV[i, hi + 1] - cV[i, lo]
        den <- den + cD[i, hi + 1] - cD[i, lo]
      }
      coverage[k] <- den / (b[k] - a[k] + 1)
      if (den > 0) value[k] <- num / den
    }
    list(value = value, coverage = coverage)
  })
}
