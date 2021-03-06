# Wrapper functions around CausalImpact

#' broom::glance() implementation for bsts (Bayesian Structural Time Series) model,
#' which is the model used internally in CausalImpact to predict synthetic control (counterfactual).
#' @export
glance.bsts <- function(x) {
  ret <- summary(x)
  data.frame(residual_sd = ret$residual.sd,
             prediction_sd = ret$prediction.sd,
             r_square = ret$rsquare,
             # relative.gof always gives NA.
             # bsts does not seem to handle NAs in the data in post-event period from CausalImpact. seems to be a bsts bug.
             # relative_gof = ret$relative.gof,
             n_coef_min = ret$size[[1]],
             n_coef_1st_quartile = ret$size[[2]],
             n_coef_median = ret$size[[3]],
             n_coef_mean = ret$size[[4]],
             n_coef_3rd_quartile = ret$size[[5]],
             n_coef_max = ret$size[[6]])
}

#' broom::tidy() implementation for bsts model
#' @export
tidy.bsts <- function(x) {
  df <- as.data.frame(summary(x)$coefficients)
  df <- tibble::rownames_to_column(df, var="market") # not really generic, but in our usage, it is market.
  colnames(df)[colnames(df) == "mean.inc"] <- "mean_when_included"
  colnames(df)[colnames(df) == "sd.inc"] <- "sd_when_included"
  colnames(df)[colnames(df) == "inc.prob"] <- "include_prob"
  df
}

#' NSE version of do_market_impact
#' @export
do_market_impact <- function(df, time, value = NULL, market, ...) { # value = NULL is necessary to take no column for Number of Rows aggregation
  time_col <- col_name(substitute(time))
  value_col <- col_name(substitute(value))
  market_col <- col_name(substitute(market))
  do_market_impact_(df, time_col, value_col, market_col, ...)
}

#' Calculate impact of an event in timeseries data.
#' @param df - Data frame
#' @param time_col - Column that has time data
#' @param value_col - Column that has value data
#' @param market_col - Column that has id/name of market
#' @param target_market - The market of interest
#' @param time_unit - "day", "week", "month", "quarter", or "year"
#' @param fun.aggregate - Function to aggregate values.
#' @param event_time - The point of time when the event of interest happened.
#' @param output_type - Type of output data frame:
#'                      "series" - time series (default)
#'                      "model_stats" - model fit summary from broom::glance() on the bsts model.
#'                      "model_coef" - model coefficients from broom::tidy() on the bsts model.
#'                      "predictor_market_candidates" - candidates of predictor market and their ranking based on distance and correlation.
#'                      "model" - model data frame with the bsts model. (Not use in Exploratory UI for now.)
#' @param na_fill_type - Type of NA fill:
#'                       "spline" - Spline interpolation.
#'                       "interpolate" - Linear interpolation.
#'                       "previous" - Fill with last previous non-NA value.
#'                       "value" - Fill with the value of na_fill_value.
#'                       NULL - Skip NA fill. Use this only when you know there is no NA.
#' @param na_fill_value - Value to fill NA when na_fill_type is "value"
#' @param distance_weight - Weight of distance (vs. correlation) for calculating ranking of candidate control markets.
#' @param alpha - Tail-area probability of posterior interval (a concept that is similar to confidence interval.)
#' @param niter - Number of MCMC Samples.
#' @param standardize.data - Whether to standardize data.
#' @param prior.level.sd - Prior Standard Deviation of Random Walk
#' @param nseasons - Period of Seasonal Trend. e.g. 7, for weekly trend.
#' @param season.duration - Used with nseasons. How many unit time one season consists of. e.g. 24, when unit time is hour.
#' @param dynamic.regression - Whether to include time-varying regression coefficients.
#' @param ... - extra values to be passed to CausalImpact::CausalImpact.
do_market_impact_ <- function(df, time_col, value_col, market_col, target_market = NULL, max_predictors = 5,
                              time_unit = "day", fun.aggregate = sum,
                              event_time = NULL, output_type = "series",
                              na_fill_type = "value", na_fill_value = 0,
                              distance_weight = 1,
                              niter = NULL, standardize.data = NULL, prior.level.sd = NULL, nseasons = NULL, season.duration = NULL, dynamic.regression = NULL, ...) {
  validate_empty_data(df)

  y_colname <- target_market
  grouped_col <- grouped_by(df)

  # column name validation
  if(!time_col %in% colnames(df)){
    stop(paste0(time_col, " is not in column names"))
  }

  if(time_col %in% grouped_col){
    stop(paste0(time_col, " is grouped. Please ungroup it."))
  }

  if (!class(df[[time_col]]) %in% c("Date", "POSIXct")) {
    stop(paste0(time_col, " must be Date or POSIXct."))
  }

  if (!(is.null(event_time) || class(event_time) == "character" || class(df[[time_col]]) == class(event_time))) {
    stop(paste0("event_time must be character or the same class as ", time_col, "."))
  }

  do_causal_impact_each <- function(df) {
    # aggregate data with day
    aggregated_data <-
    if (!is.null(value_col)){
      data.frame(
        time = lubridate::floor_date(df[[time_col]], unit = time_unit),
        value = df[[value_col]],
        market = df[[market_col]]
      ) %>%
        dplyr::filter(!is.na(value)) %>% # remove NA so that we do not pass NA to aggregate function.
        dplyr::group_by(time, market) %>%
        dplyr::summarise(y = fun.aggregate(value)) %>%
        dplyr::ungroup() # ungroup for time
    } else {
      data.frame(
        time = lubridate::floor_date(df[[time_col]], unit = time_unit),
        market = df[[market_col]]
      ) %>%
        dplyr::group_by(time, market) %>%
        dplyr::summarise(y = n()) %>%
        dplyr::ungroup() # ungroup for time
    }
    # no need to complete(). spread should have the same effect as complate().
    # aggregated_data <- aggregated_data %>% complete(time, market)
    df <- aggregated_data %>% tidyr::spread(market, y)

    # keep time_col column, since we will drop it in the next step,
    # but will need it to compose zoo object.
    time_points_vec <- df[["time"]]

    # drop time_col.
    input_df <- df[, colnames(df) != "time"]

    # bring y column at the beginning of the input_df, so that CausalImpact understand this is the column to predict.
    input_df <- move_col(input_df, target_market, 1)

    df_zoo <- zoo::zoo(input_df, time_points_vec)
    # fill NAs in the input.
    # since CausalImpact does not allow irregular time series,
    # filtering rows would not work.
    if (na_fill_type == "spline") {
      df_zoo <- zoo::na.spline(df_zoo)
    }
    else if (na_fill_type == "interpolate") {
      df_zoo <- zoo::na.approx(df_zoo)
    }
    else if (na_fill_type == "previous") {
      df_zoo <- zoo::na.locf(df_zoo)
    }
    # TODO: Getting this error with some input with na.StructTS().
    #       Error in rowSums(tsSmooth(StructTS(y))[, -2]) : 'x' must be an array of at least two dimensions
    #
    # else if (na_fill_type == "StructTS") {
    #   df_zoo <- zoo::na.StructTS(df_zoo)
    # }
    else if (na_fill_type == "value") {
      df_zoo <- zoo::na.fill(df_zoo, na_fill_value)
    }
    else if (is.null(na_fill_type)) {
      # skip when it is NULL. this is for the case caller is confident that
      # there is no NA and want to skip overhead of checking for NA.
    }
    else {
      stop(paste0(na_fill_type, " is not a valid na_fill_type option."))
    }

    zoo_mm <- best_matches_from_zoo(
      zoo_data = df_zoo,
      target_value = target_market,
      warping_limit = 1, # warping limit=1
      dtw_emphasis = distance_weight, # how much to rely on dtw for pre-screening
      matches = max_predictors, # number of best matches to return
      end_match_period = event_time,
      parallel = FALSE
    )
    if (output_type == "predictor_market_candidates") {
      return(zoo_mm$BestMatches)
    }

    df_zoo = df_zoo[, colnames(df_zoo) %in%  c(target_market, head(zoo_mm$BestMatches$market, max_predictors))]
    orig_colnames = colnames(df_zoo)
    # rename column names too "y", "x1", "x2", ... since CausalImpact throws error when column names starts with number,
    # or in some other cases too.
    temp_colnames = c("y", paste0("x", as.character(1:(length(orig_colnames) - 1))))
    # create mapping so that we can convert coefficient names back in model_coef output type.
    colnames_map <- stats::setNames(orig_colnames, temp_colnames)
    colnames(df_zoo) <- temp_colnames

    # compose list for model.args argument of CausalImpact.
    model_args <- list()
    if (!is.null(niter)) {
      model_args$niter = niter
    }
    if (!is.null(standardize.data)) {
      model_args$standardize.data = standardize.data
    }
    if (!is.null(prior.level.sd)) {
      model_args$prior.level.sd = prior.level.sd
    }
    if (!is.null(nseasons)) {
      model_args$nseasons = nseasons
    }
    if (!is.null(season.duration)) {
      model_args$season.duration = season.duration
    }
    if (!is.null(dynamic.regression)) {
      model_args$dynamic.regression = dynamic.regression
    }

    if (!is.null(event_time)) { # if event_time is specified, create pre.period/post.period automatically.
      if (class(event_time) == "character") { # translate character event_time into Date or POSIXct.
        if (class(df[["time"]]) == "Date") {
          event_time <- as.Date(event_time)
        }
        else {
          event_time <- as.POSIXct(event_time)
        }
      }
      pre_period <- c(min(time_points_vec), event_time - 1) # -1 works as -1 day on Date and -1 sec on POSIXct.
      post_period <- c(event_time, max(time_points_vec))

      # call CausalImpact::CausalImpact, which is the heart of this analysis.
      impact <- CausalImpact::CausalImpact(df_zoo, pre.period = pre_period, post.period = post_period, model.args = model_args, ...)
    }
    else {
      # pre.period, post.period must be in the ... in this case.
      impact <- CausalImpact::CausalImpact(df_zoo, model.args = model_args, ...)
    }

    # $series has the result of prediction. for now ignore the rest such as $model.
    if (output_type == "series") {
      ret_df <- data.frame(time = df$time,
                           actual = df[[target_market]],
                           expected = impact$series$point.pred,
                           expected_high = impact$series$point.pred.upper,
                           expected_low = impact$series$point.pred.lower,
                           impact = impact$series$point.effect,
                           impact_high = impact$series$point.effect.upper,
                           impact_low = impact$series$point.effect.lower,
                           cumulative_impact = impact$series$cum.effect,
                           cumulative_impact_high = impact$series$cum.effect.upper,
                           cumulative_impact_low = impact$series$cum.effect.lower,
                           # to make this work with NA, this has to be ifelse, not if_else.
                           actual_at_event_time = ifelse(df$time == event_time, df[[target_market]], NA))
      ret_df
    }
    else if (output_type == "model_stats") {
      broom::glance(impact$model$bsts.model)
    }
    else if (output_type == "model_coef") {
      ret_df <- broom::tidy(impact$model$bsts.model)
      # map values of market back to original names.
      # if there is no match, use the name as is. this if for "(intercept)" row from broom::tidy().
      ret_df <- ret_df %>% mutate(market = ifelse(!is.na(colnames_map[market]), colnames_map[market], market))
      ret_df
    }
    else { # output_type should be "model"
      # following would cause error : cannot coerce class ""bsts"" to a data.frame
      # ret <- data.frame(model = list(impact$model$bsts.model))
      # working it around like following.
      ret <- data.frame(model = 1)
      ret$model = list(impact$model$bsts.model)
      ret
    }
  }

  # Calculation is executed in each group.
  # Storing the result in this tmp_col and
  # unnesting the result.
  # If the original data frame is grouped by "tmp",
  # overwriting it should be avoided,
  # so avoid_conflict is used here.
  tmp_col <- avoid_conflict(grouped_col, "tmp")
  ret <- df %>%
    dplyr::do_(.dots=setNames(list(~do_causal_impact_each(.)), tmp_col)) %>%
    dplyr::ungroup() %>%
    tidyr::unnest(!!rlang::sym(tmp_col))

  # grouping should be kept
  if(length(grouped_col) != 0){
    ret <- dplyr::group_by(ret, !!!rlang::syms(grouped_col))
  }
  ret
}
