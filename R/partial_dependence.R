# Calculates "Actual" data to plot with partial dependence from model.
# 1. Bin data into 20 bins alongside with the variable (x) to take partial dependende.
# 2. Calculate mean of x and y for each bin. We will plot it with partial dependence to show how the model's prediction compares with raw data.
calc_partial_binning_data <- function(df, target_col, var_cols) {
  if (is.factor(df[[target_col]]) && all(levels(df[[target_col]]) %in% c("TRUE","FALSE"))) {
    # If it is a factor with levels of only TRUE or FALSE, here we assume it is a value converted from logical.
    df <- df %>% dplyr::mutate(!!rlang::sym(target_col) := !!rlang::sym(target_col) == "TRUE") # Convert it to logical so that we can count TRUE as 1 and FALSE as 0.
  }
  else if (!is.numeric(df[[target_col]]) && !is.logical(df[[target_col]])) {
    # Other non-numeric, non-logical values are other types of classifications. For them we do not show data from binning.
    return(NULL)
  }

  ret <- data.frame()
  for (var_col in var_cols) {
    if (is.factor(df[[var_col]])) { # In case of factor, just plot means of training data for each category.
      grouped <- df %>% dplyr::group_by(!!rlang::sym(var_col))
      if (!is.logical(df[[target_col]])) { # When not logical (when numeric), calculate regular confidence interval.
        summarized <- grouped %>% dplyr::summarize(Actual=mean(!!rlang::sym(target_col), na.rm=TRUE), error=confint_radius(!!rlang::sym(target_col)), bin_sample_size=n())
      }
      else { # When logical, calculate confidence interval of population proportion.
        summarized <- grouped %>% dplyr::summarize(Actual=mean(!!rlang::sym(target_col), na.rm=TRUE), error=prop_confint_radius(!!rlang::sym(target_col)), bin_sample_size=n())
      }
      actual_ret <- summarized %>% dplyr::mutate(conf_low=Actual-error, conf_high=Actual+error)
      actual_ret <- actual_ret %>% dplyr::select(-error)
      ret <- ret %>% dplyr::bind_rows(actual_ret)
    }
    else if (is.numeric(df[[var_col]])) { # Because of proprocessing we do, all columns should be either factor or numeric by now.
      # Equal width cut: We found this gives more understandable plot compared to equal frequency cut.
      grouped <- df %>% dplyr::mutate(.temp.bin.column=cut(!!rlang::sym(var_col), breaks=20)) %>% dplyr::group_by(.temp.bin.column)
      # Equal frequency cut version:
      # actual_ret <- df %>% dplyr::mutate(.temp.bin.column=ggplot2::cut_number(!!rlang::sym(var_col), 20)) %>% dplyr::group_by(.temp.bin.column)
      if (!is.logical(df[[target_col]])) { # When not logical (when numeric), calculate regular confidence interval.
        summarized <- grouped %>% dplyr::summarize(Actual=mean(!!rlang::sym(target_col), na.rm=TRUE), error=confint_radius(!!rlang::sym(target_col)), !!rlang::sym(var_col):=mean(!!rlang::sym(var_col), na.rm=TRUE), bin_sample_size=n())
      }
      else { # When logical, calculate confidence interval of population proportion.
        summarized <- grouped %>% dplyr::summarize(Actual=mean(!!rlang::sym(target_col), na.rm=TRUE), error=prop_confint_radius(!!rlang::sym(target_col)), !!rlang::sym(var_col):=mean(!!rlang::sym(var_col), na.rm=TRUE), bin_sample_size=n())
      }
      actual_ret <- summarized %>% dplyr::mutate(conf_low=Actual-error, conf_high=Actual+error)
      actual_ret <- actual_ret %>% dplyr::select(-.temp.bin.column, -error)
      ret <- ret %>% dplyr::bind_rows(actual_ret)
    }
  }
  ret
}

# Common utility function called for tidy with type "partial_dependence".
# Used for ranger, rpart, lm, and glm.
# TODO: Almost there, but make it completely model agnostic.
handle_partial_dependence <- function(x) {
  if (is.null(x$partial_dependence)) {
    return(data.frame()) # Skip by returning empty data.frame.
  }
  # return partial dependence
  ret <- x$partial_dependence
  var_cols <- attr(x$partial_dependence, "vars")
  target_col <- attr(x$partial_dependence, "target")
  # We used to do the following, probably for better formatting of numbers, but this had side-effect of
  # turning close numbers into a same number, when differences among numbers are small compared to their
  # absolute values. It happened with Date data turned into numeric.
  # Now we are turning the numbers into factors as is.
  # Number of unique values should be small (20) here since the grid we specify with edarf is c(20,20).
  #
  # for (var_col in var_cols) {
  #   if (is.numeric(ret[[var_col]])) {
  #     ret[[var_col]] <- signif(ret[[var_col]], digits=4) # limit digits before we turn it into a factor.
  #   }
  # }

  # For lm/glm, show plot of means of binned training data alongside with the partial dependence as "Actual" plot.
  # Partial dependence is labeled as the "Predicted" plot to make comparison.
  if ("glm" %in% class(x) || "lm" %in% class(x)) {
    if (!is.null(x$data)) {  # For glm case.
      df <- x$data
    }
    else { # For lm case
      df <- x$model
    }
    actual_ret <- calc_partial_binning_data(df, target_col, var_cols)
    ret <- actual_ret %>% dplyr::bind_rows(ret) # So that PDP is drawn over the binning, the bind_row order needs to be this way.
    ret <- ret %>% dplyr::rename(Predicted=!!rlang::sym(target_col)) # Rename target column to Predicted to make comparison with Actual.
  }
  else if (!is.null(x$partial_binning)) { # For ranger/rpart, we calculate binning data at model building. Maybe we should do the same for glm/lm.
    actual_ret <- x$partial_binning
    ret <- actual_ret %>% dplyr::bind_rows(ret) # So that PDP is drawn over the binning, the bind_row order needs to be this way.
    if (!is.null(ret[[target_col]])) {
      ret <- ret %>% dplyr::rename(Predicted=!!rlang::sym(target_col)) # Rename target column to Predicted to make comparison with Actual.
    }
    else if (!is.null(ret$`TRUE`)) { # Column with name that matches target_col is not there, but TRUE column is there. This must be a binary classification case.
      ret <- ret %>% dplyr::rename(Predicted=`TRUE`) # Rename target column to Predicted to make comparison with Actual.
      if (!is.null(ret$`FALSE`)) {
        ret <- ret %>% dplyr::select(-`FALSE`) # Drop FALSE column, which we will not use.
      }
    }
  }

  ret <- ret %>% tidyr::gather_("x_name", "x_value", var_cols, na.rm = TRUE, convert = FALSE)
  # sometimes x_value comes as numeric and not character, and it was causing error from bind_rows internally done
  # in tidy().
  ret <- ret %>% dplyr::mutate(x_value = as.character(x_value))
  # convert must be FALSE for y to make sure y_name is always character. otherwise bind_rows internally done
  # in tidy() to bind outputs from different groups errors out because y_value can be, for example, mixture of logical and character.
  if ("conf_high" %in% colnames(ret)) { # if the data is with confidence interval.
    ret <- ret %>% tidyr::gather("y_name", "y_value", -x_name, -x_value, -conf_high, -conf_low, -bin_sample_size, na.rm = TRUE, convert = FALSE)
  }
  else {
    ret <- ret %>% tidyr::gather("y_name", "y_value", -x_name, -x_value, na.rm = TRUE, convert = FALSE)
  }
  ret <- ret %>% dplyr::mutate(x_name = forcats::fct_relevel(x_name, x$imp_vars)) # set factor level order so that charts appear in order of importance.
  # set order to ret and turn it back to character, so that the order is kept when groups are bound.
  # if it were kept as factor, when groups are bound, only the factor order from the first group would be respected.
  ret <- ret %>% dplyr::arrange(x_name) %>% dplyr::mutate(x_name = as.character(x_name))

  # Set original factor level back so that legend order is correct on the chart.
  # In case of logical, c("TRUE","FALSE") is stored in orig_level, so that we can
  # use it here either way.
  # glm (binomial family) is exception here, since we only show probability of being TRUE,
  # and instead show mean of binned actual data.
  if ("glm" %in% class(x) || !is.null(x$partial_binning)) { # Or part is for ranger/rpart. They might not have partial_binning, because of being multiclass or published on server from older release.
    ret <- ret %>%  dplyr::mutate(y_name = factor(y_name, levels=c("Actual", "Predicted", "conf_low", "conf_high")))
  }
  else if (!is.null(x$orig_levels)) {
    ret <- ret %>%  dplyr::mutate(y_name = factor(y_name, levels=x$orig_levels))
  }

  # create mapping from column name (x_name) to facet chart type based on whether the column is numeric.
  chart_type_map <-c()
  x_type_map <-c()
  df <- NULL
  if ("ranger" %in% class(x)) {
    df <- x$df
  }
  else if (!is.null(x$data)) {  # For glm case.
    df <- x$data
  }
  else if ("lm" %in% class(x)) { # For lm case
    df <- x$model
  }
  else { # rpart, xgboost
    # use partial_dependence itself for determining chart_type. Maybe this works for other models too?
    df <- x$partial_dependence
  }
  for(col in colnames(df)) {
    if (is.numeric(df[[col]])) {
      x_type <- "numeric"
      chart_type <- "line"
    }
    # Since we turn logical into factor in preprocess_regression_data_after_sample(), detect them accordingly.
    else if (is.factor(df[[col]]) && all(levels(df[[col]]) %in% c("TRUE", "FALSE", "(Missing)"))) {
      x_type <- "logical"
      chart_type <- "scatter"
    }
    else {
      x_type <- "character" # Since we turn charactors into factor in preprocessing (fct_lump) and cannot distinguish the original type at this point, for now, we treat both factors and characters as "characters" here.
      chart_type <- "scatter"
    }
    x_type_map <- c(x_type_map, x_type)
    chart_type_map <- c(chart_type_map, chart_type)
  }
  names(x_type_map) <- colnames(df)
  names(chart_type_map) <- colnames(df)

  ret <- ret %>%  dplyr::mutate(chart_type = chart_type_map[x_name])
  ret <- ret %>%  dplyr::mutate(x_type = x_type_map[x_name])

  # Sort the rows for scatter plots for categorical predictor variables, by Predicted values.
  nested <- ret %>% dplyr::group_by(x_name) %>% tidyr::nest(.temp.data=c(-x_name)) #TODO: avoid possibility of column name conflict between .temp.data and group_by columns.
  nested <- nested %>% dplyr::mutate(.temp.data = purrr::map(.temp.data, function(df){
    # We do the sorting only for scatter chart with Predicted values. This eliminates line charts or multiclass classifications.
    if (df$x_type[[1]]=="character" && "Predicted" %in% unique(df$y_name)) {
      # Set x_value factor level order first for the sorting at the next step.
      df <- df %>% dplyr::mutate(x_value = forcats::fct_reorder2(x_value, y_name, y_value, function(name, value) {
        if ("Predicted" %in% name) {
          first(value[name=="Predicted"])
        }
        else { # This should not happen but giving reasonable default just in case.
          first(value)
        }
      }))
      df <- df %>% dplyr::arrange(x_value)
      df %>% dplyr::mutate(x_value = as.character(x_value)) # After sorting, change it back to character, so that it does not mess up the chart.
    }
    else if (df$x_type[[1]]=="logical" && "Predicted" %in% unique(df$y_name)) {
      # Set factor label order for sorting. There may be unused level, but should not matter since we change it back to character after sort.
      df <- df %>% dplyr::mutate(x_value = factor(x_value, levels=c("TRUE","FALSE","(Missing)")))
      df <- df %>% dplyr::arrange(x_value)
      df %>% dplyr::mutate(x_value = as.character(x_value)) # After sorting, change it back to character, so that it does not mess up the chart.
    }
    else {
      df
    }
  }))
  ret <- nested %>% tidyr::unnest(cols=.temp.data) %>% dplyr::ungroup()

  if (("lm" %in% class(x)) || ("glm" %in% class(x))) { # For linear regression, join coefficient and P value for numeric predictors.
    ret2 <- broom:::tidy.glm(x) # Use tidy.glm() even for lm, since tidy.lm raises error if class other than "lm" is added.
    # Coefficient/P value info is joined only for predicted numeric variables. 
    ret <- ret %>% dplyr::mutate(key=case_when(y_name=='Actual'~NA_character_,chart_type=='line'~x_name, TRUE~NA_character_)) %>% dplyr::left_join(ret2, by = c(key="term"))
    ret <- ret %>% dplyr::select(-key)
  }

  ret <- ret %>% dplyr::mutate(x_name = x$terms_mapping[x_name]) # map variable names to original.
  ret
}
