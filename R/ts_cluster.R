#' Time series clustering by dtwclust.
#' @export
exp_ts_cluster <- function(df, time, value, category, time_unit = "day", fun.aggregate = sum, na_fill_type = "previous", na_fill_value = 0, max_category_na_ratio = 0.5,
                           variables = NULL, funs.aggregate.variables = NULL,
                           centers = 3L, with_centroids = FALSE, distance = "sdtw", centroid = "sdtw_cent",
                           seed = 1,
                           output = "data") {
  if(!is.null(seed)) {
    set.seed(seed)
  }

  time_col <- tidyselect::vars_select(names(df), !! rlang::enquo(time))
  value_col <- if (missing(value)) {
    # Using empty string instead of NULL, because using NULL here would cause error from UQ(rlang::sym(value_col)),
    # which seems to be evaluated as soon as the parent function is called, which is before if-condition for it to be not NULL is evaluated.
    # (rlang::sym("") does not seem to throw error unlike rlang::sym(NULL).)
    ""
  }
  else {
    tidyselect::vars_select(names(df), !! rlang::enquo(value))
  }
  # Handle the case where NULL was specified for value argument. We handle this case this way because is.null(value) throws error when value actuall has value.
  if (length(value_col) == 0) {
    value_col = ""
  }
  category_col <- tidyselect::vars_select(names(df), !! rlang::enquo(category))

  # Copied from do_prophet.
  if (time_unit == "min") {
    time_unit <- "minute"
  }
  else if (time_unit == "sec") {
    time_unit <- "second"
  }

  # remove rows with NA time
  df <- df[!is.na(df[[time_col]]), ]

  # Compose arguments to pass to dplyr::summarise.
  summarise_args <- list() # default empty list
  if (!is.null(variables) && !is.null(funs.aggregate.variables)) {
    summarise_args <- purrr::map2(funs.aggregate.variables, variables, function(func, cname) {
      # For common functions that require na.rm=TRUE to handle NA, add it.
      if (is_na_rm_func(func)) {
        quo(UQ(func)(UQ(rlang::sym(cname)), na.rm=TRUE))
      }
      else {
        quo(UQ(func)(UQ(rlang::sym(cname))))
      }
    })

    # Set final output column names.
    if (!is.null(names(variables))) {
      names(summarise_args) <- names(variables)
    }
    else {
      names(summarise_args) <- variables
    }
  }

  model_df <- df %>% nest_by() %>% ungroup() %>%
    mutate(model = purrr::map(data, function(df) {
      # Floor date. The code is copied form do_prophet.
      df[[time_col]] <- if (time_unit %in% c("day", "week", "month", "quarter", "year")) {
        # Take care of issue that happened in anomaly detection here for prophet too.
        # In this case, convert (possibly) from POSIXct to Date first.
        # If we did this without converting POSIXct to Date, floor_date works, but later at complete stage,
        # data on day-light-saving days would be skipped, since the times seq.POSIXt gives and floor_date does not match.
        # We give the time column's timezone to as.Date, so that the POSIXct to Date conversion is done
        # based on that timezone.
        lubridate::floor_date(as.Date(df[[time_col]], tz = lubridate::tz(df[[time_col]])), unit = time_unit)
      } else {
        lubridate::floor_date(df[[time_col]], unit = time_unit)
      }
      renamed_df <- if (value_col != "") {
        df %>% dplyr::rename(
            time = UQ(rlang::sym(time_col)),
            value = UQ(rlang::sym(value_col)),
            category = UQ(rlang::sym(category_col))
          )
      }
      else {
        df %>% dplyr::rename(
            time = UQ(rlang::sym(time_col)),
            category = UQ(rlang::sym(category_col))
          )
      }

      # Summarize
      grouped_df <- renamed_df %>% dplyr::group_by(category, time)
      if (value_col == "") {
        df <- grouped_df %>% 
          dplyr::summarise(value = n(), !!!summarise_args)
      }
      else if (is_na_rm_func(fun.aggregate)) {
        df <- grouped_df %>% 
          dplyr::summarise(value = fun.aggregate(value, na.rm=TRUE), !!!summarise_args)
      }
      else {
        df <- grouped_df %>% 
          dplyr::summarise(value = fun.aggregate(value), !!!summarise_args)
      }
      df <- df %>% dplyr::ungroup()
      df_summarised <- df
      df <- df %>% dplyr::select(time, value, category)
      # Pivot wider
      df <- df %>% tidyr::pivot_wider(names_from="category", values_from="value")
      # Complete the time column.
      df <- df %>% complete_date("time", time_unit = time_unit)
      # Drop columns (represents category) that has more NAs than max_category_na_ratio, considering them to have not enough data.
      df <- df %>% dplyr::select_if(function(x){sum(is.na(x))/length(x) < max_category_na_ratio})
      if (length(colnames(df)) <= centers) {
        stop("EXP-ANA-2 :: [] :: There is not enough data left after removing high NA ratio data.")
      }
      # Fill NAs in time series
      df <- df %>% dplyr::mutate(across(-time, ~fill_ts_na(.x, time, type = na_fill_type, val = na_fill_value)))
      time_values <- df$time
      df <- df %>% dplyr::select(-time)
      model <- dtwclust::tsclust(t(as.matrix(df)), k = centers, distance = distance, centroid = centroid)
      attr(model, "time_col") <- time_col
      attr(model, "value_col") <- value_col
      attr(model, "category_col") <- category_col
      attr(model, "time_values") <- time_values
      # Pass original data, so that the output has other variables too.
      if (!is.null(variables) && !is.null(funs.aggregate.variables)) {
        attr(model, "aggregated_data") <- df_summarised
      }
      model
    }))
  model_df <- model_df %>% rowwise()
  if (output == "data") {
    model_df %>% tidy_rowwise(model, with_centroids = with_centroids)
  }
  else { # output == "model"
    model_df
  }
}

#' Extracts results from the model as a data frame.
#' The output is original long-format set of time series with Cluster column.
#' @export
tidy.PartitionalTSClusters <- function(x, with_centroids = TRUE) {
  res <- tibble::as_tibble(x@datalist)
  res <- res %>% dplyr::mutate(time=!!attr(x,"time_values"))
  cluster_map <- x@cluster
  cluster_map_names <- names(x@datalist)

  if (with_centroids) {
    for (i in 1:(x@k)) {
      res <- res %>% dplyr::mutate(!!rlang::sym(paste0("centroid",i)):=x@centroids[[i]])
      cluster_map <- c(cluster_map, i)
      cluster_map_names <- c(cluster_map_names, paste0("centroid",i))
    }
  }

  names(cluster_map) <- cluster_map_names

  res <- res %>% tidyr::pivot_longer(cols = -time)
  if (!is.null(attr(x, "aggregated_data"))) {
    aggregated_data <- attr(x, "aggregated_data")
    aggregated_data <- aggregated_data %>% dplyr::select(-value) # Drop value column from aggregated_data since res already has it.
    res <- res %>% dplyr::left_join(aggregated_data, by=c("time"="time", "name"="category"))
  }
  res <- res %>% dplyr::mutate(Cluster = cluster_map[name])
  value_col <- attr(x, "value_col")
  if (value_col == "") {
    res <- res %>% dplyr::rename(!!rlang::sym(attr(x,"time_col")):=time,
                                 Number_of_Rows=value,
                                 !!rlang::sym(attr(x,"category_col")):=name)
  }
  else {
    res <- res %>% dplyr::rename(!!rlang::sym(attr(x,"time_col")):=time,
                                 !!rlang::sym(value_col):=value,
                                 !!rlang::sym(attr(x,"category_col")):=name)
  }
  res
}
