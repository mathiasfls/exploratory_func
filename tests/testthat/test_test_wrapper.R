context("tests for wrappers of tests")

test_df <- data.frame(
  cat=rep(c("cat1", "cat2"), 20),
  dim = sort(rep(paste0("dim", seq(4)), 5)),
  dim_na=c(paste0("dim", seq(10)), paste0("dim", seq(10)+3)))

test_df$list_c <- as.list(seq(20))

test_df[["with space"]] <- seq(20)

test_that("test two sample t-test with column name", {
  test_df <- data.frame(
    cat=rep(c("cat1", "cat2"), 20),
    val = rep(seq(10), 2)
  )

  result <- test_df %>%
    do_t.test(val, cat)

  expect_equal(result$mean_cat1, 5)
  expect_equal(result$mean_cat2, 6)

  # swap cat1 and cat2
  test_df <- data.frame(
    cat=rep(c("cat2", "cat1"), 20),
    val = rep(seq(10), 2)
  )

  result <- test_df %>%
    do_t.test(val, cat)

  expect_equal(result$mean_cat1, 6)
  expect_equal(result$mean_cat2, 5)
})

test_that("test two sample t-test with factor", {
  test_df <- data.frame(
    cat=factor(rep(c("cat1", "cat2"), 20), levels = c("cat1", "cat2")),
    val = rep(seq(10), 2)
  )

  result <- test_df %>%
    do_t.test(val, cat)

  expect_equal(result$mean_cat1, 5)
  expect_equal(result$mean_cat2, 6)

  # swap cat1 and cat2
  test_df <- data.frame(
    cat=factor(rep(c("cat2", "cat1"), 20), levels = c("cat2", "cat1")),
    val = rep(seq(10), 2)
  )

  result <- test_df %>%
    do_t.test(val, cat)

  expect_equal(result$mean_cat1, 6)
  expect_equal(result$mean_cat2, 5)
})

test_that("test two sample t-test with logical", {
  test_df <- data.frame(
    cat=rep(c(TRUE, FALSE), 20),
    val = rep(seq(10), 2)
  )

  result <- test_df %>%
    do_t.test(val, cat)

  expect_equal(result$mean_TRUE, 5)
  expect_equal(result$mean_FALSE, 6)

  # swap TRUE and FALSE
  test_df <- data.frame(
    cat=rep(c(FALSE, TRUE), 20),
    val = rep(seq(10), 2)
  )

  result <- test_df %>%
    do_t.test(val, cat)

  expect_equal(result$mean_FALSE, 5)
  expect_equal(result$mean_TRUE, 6)
})

test_that("test two sample t-test more than 2 levels", {
  expect_error({
    result <- test_df %>%
      dplyr::group_by(dim) %>%
      do_t.test(`with space`, dim_na)
  })
})

test_that("test two sample t-test less than 2 levels", {
  expect_error({
    result <- test_df %>%
      dplyr::group_by(dim) %>%
      do_t.test(`with space`, dim)
  })
})

test_that("test one sample t-test", {
  result <- test_df %>%
    dplyr::group_by(dim) %>%
    do_t.test("with space", mu=3)
  expect_equal(result[result[["dim"]]=="dim1", "p.value"][[1]], 1)
})

test_that("test t-test with 3 groups", {
  data <- data.frame(val = seq(12), group = rep(c(1,2,3), each = 4))
  expect_error({
    result <- data %>%
      do_t.test(val, group)
  }, "Group Column has to have 2 unique values")
})

test_that("test f-test", {
  result <- test_df %>%
    dplyr::group_by(dim) %>%
    do_var.test(`with space`, cat)
  expect_equal(ncol(result), 10)
})

test_that("test f-test with 3 groups", {
  data <- data.frame(val = seq(12), group = rep(c(1,2,3), each = 4))
  expect_error({
    result <- data %>%
      do_var.test(val, group)
  }, "Group Column has to have 2 unique values")
})

test_that("test chisq.test with one column", {
  test_df <- data.frame(
    group = rep(letters[1:2], each = 500),
    cat1 = letters[round(runif(1000)*5)+1],
    cat2 = letters[round(runif(1000)*3)+1]
  ) %>%
    dplyr::group_by(group, cat1, cat2) %>%
    dplyr::summarize(count = n()) %>%
    dplyr::group_by(group)

  ret <- test_df %>%
    do_chisq.test(count)

  expect_equal(nrow(ret), 2)

})

test_that("test chisq.test with select argument", {
  test_df <- data.frame(
    group = rep(letters[1:2], each = 500),
    cat1 = letters[round(runif(1000)*5)+1],
    cat2 = letters[round(runif(1000)*3)+1]
  ) %>%
    dplyr::group_by(group, cat1, cat2) %>%
    dplyr::summarize(count = n()) %>%
    tidyr::spread(cat2, count) %>%
    dplyr::group_by(group)

  ret <- test_df %>%
    do_chisq.test(-cat1)

  expect_equal(nrow(ret), 2)

})

test_that("test chisq.test with p column", {
  test_df <- structure(
    list(
      clarity = c("IF", "VS1", "VS2", "VVS1", "VVS2"),
      GIA = c(6, 61, 36, 15, 33),
      HRD = c(4, 13, 15, 23, 24),
      IGI = c(34, 7, 2, 14, 21)),
    .Names = c("clarity", "GIA", "HRD", "IGI"),
    class = "data.frame",
    row.names = c(NA,-5L)) %>%
    dplyr::mutate(p = seq(5))

  ret <- test_df %>%
    do_chisq.test(GIA, p = p)
  expect_equal(nrow(ret), 1)

  p_from_outside <- seq(5)

  ret2 <- test_df %>%
    do_chisq.test(IGI, p = p_from_outside)
  expect_equal(nrow(ret), 1)

  ret3 <- test_df %>%
    do_chisq.test(IGI, p = c(1, 2, 3, 4, 5))
  expect_equal(nrow(ret), 1)

})

test_that("test exp_chisq", {
  mtcars2 <- mtcars
  mtcars2$gear[[1]] <- NA # test handling of NAs
  mtcars2$carb[[2]] <- NA
  mtcars2$cyl[[3]] <- NA
  ret <- exp_chisq(mtcars2 %>% mutate(gear=factor(gear)), gear, carb) # factor order should be kept in the model
  ret <- exp_chisq(mtcars2, gear, carb, value=cyl, fun.aggregate=sum)

  # Test model_info function.
  # Rename model column so that we test the case where the column name is not "model". There was an issue this case.
  observed <- ret %>% rename(model1=model) %>% model_info(model1, output="variables", type="observed")
  summary <- ret %>% rename(model1=model) %>% model_info(model1, output="summary")
  data <- ret %>% rename(model1=model) %>% model_info(model1, output="data")

  observed <- ret %>% tidy_rowwise(model, type="observed")
  summary <- ret %>% glance_rowwise(model)
  residuals <- ret %>% tidy_rowwise(model, type="residuals")
  expect_true(all(c("Chi-Square","Degree of Freedom","P Value","Effect Size (Cohen's w)",
                    "Power", "Probability of Type 2 Error","Number of Rows") %in% colnames(summary)
  ))
  prob_dist <- ret %>% tidy_rowwise(model, type="prob_dist")
})

test_that("test exp_chisq with power", {
  model_df <- exp_chisq(mtcars %>% mutate(gear=factor(gear)), gear, carb, power = 0.8) # factor order should be kept in the model
  ret <- model_df %>% glance_rowwise(model)
  model_df <- exp_chisq(mtcars, gear, carb, value=cyl, power = 0.8)
  ret <- model_df %>% glance_rowwise(model)
  expect_true(all(c("Chi-Square","Degree of Freedom","P Value","Effect Size (Cohen's w)",
                     "Target Power","Target Probability of Type 2 Error","Current Sample Size","Required Sample Size") %in% colnames(ret)
  ))
})

test_that("test exp_chisq with grouping functions", {
  model_df <- exp_chisq(mtcars, disp, drat, func1="asintby10", func2="asint", value=mpg)
  ret <- model_df %>% glance_rowwise(model)
  expect_true(all(c("Chi-Square","Degree of Freedom","P Value","Effect Size (Cohen's w)","Power",
                 "Probability of Type 2 Error","Number of Rows") %in% colnames(ret)
  ))
})

test_that("test exp_chisq with logical", {
  model_df <- exp_chisq(mtcars %>% mutate(gear=gear>3, carb=carb>3), gear, carb) # logical type should be kept in the model
  ret <- model_df %>% tidy_rowwise(model, type="residuals")
  expect_equal(class(ret$gear), "logical")
  expect_equal(class(ret$carb), "logical")
})

test_that("test exp_chisq with numeric", {
  model_df <- exp_chisq(mtcars , gear, carb) # numeric type should be kept in the model
  ret <- model_df %>% tidy_rowwise(model, type="residuals")
  expect_equal(class(ret$gear), "numeric")
  expect_equal(class(ret$carb), "numeric")
})

test_that("test exp_chisq with integer", {
  model_df <- exp_chisq(mtcars %>% mutate(gear=as.integer(gear), carb=as.integer(carb)), gear, carb) # integer type should be kept in the model
  ret <- model_df %>% tidy_rowwise(model, type="residuals")
  expect_equal(class(ret$gear), "integer")
  expect_equal(class(ret$carb), "integer")
})

test_that("test exp_chisq with group_by", {
  ret <- mtcars %>% group_by(vs) %>% exp_chisq(gear, carb, value=cyl)
  observed <- ret %>% tidy_rowwise(model, type="observed")
  expect_true("vs" %in% colnames(observed))
  summary <- ret %>% glance_rowwise(model)
  expect_true("vs" %in% colnames(summary))
  residuals <- ret %>% tidy_rowwise(model, type="residuals")
  expect_true("vs" %in% colnames(residuals))
})

test_that("test exp_chisq with group_by with single class category in one of the groups", {
  ret <- mtcars %>% filter(vs!=1 | gear==4) %>% group_by(vs) %>% exp_chisq(gear, carb, value=cyl)
  observed <- ret %>% tidy_rowwise(model, type="observed")
  summary <- ret %>% glance_rowwise(model)
  expect_equal(nrow(summary), 1) # summary for only one group should be shown.
  residuals <- ret %>% tidy_rowwise(model, type="residuals")
})

test_that("test exp_ttest", {
  mtcars2 <- mtcars
  mtcars2$am[[1]] <- NA # test NA filtering
  model_df <- exp_ttest(mtcars2, mpg, am, test_sig_level=0.05)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  expect_true("Number of Rows" %in% colnames(ret))
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  ret <- model_df %>% tidy_rowwise(model, type="prob_dist")
})

test_that("test exp_ttest with logical explanatory variable", {
  mtcars2 <- mtcars
  mtcars2$am[[1]] <- NA # test NA filtering
  mtcars2 <- mtcars2 %>% dplyr::mutate(am=as.logical(am))
  model_df <- exp_ttest(mtcars2, mpg, am)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  expect_gt(ret$Difference, 0) # Checking the direction of Difference is correct.
  expect_true("Number of Rows" %in% colnames(ret))
  model_df %>% tidy_rowwise(model, type="data_summary")
})

test_that("test exp_ttest with var.equal = TRUE", {
  mtcars2 <- mtcars
  mtcars2$am[[1]] <- NA # test NA filtering
  model_df <- exp_ttest(mtcars2, mpg, am, var.equal = TRUE)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("am","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",
                 "Minimum","Maximum"))
})

test_that("test exp_ttest with alternative = greater", {
  mtcars2 <- mtcars
  mtcars2$am[[1]] <- NA # test NA filtering
  model_df <- exp_ttest(mtcars2, mpg, am, alternative = "greater")
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  colnames(ret)
  expect_equal(colnames(ret),
               c("am","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",
                 "Minimum","Maximum"))
})

test_that("test exp_ttest with paired = TRUE", {
  # Make sample size equal between groups for paired t-test.
  mtcars2 <- mtcars %>% group_by(am) %>% slice_sample(n=6) %>% ungroup()
  model_df <- exp_ttest(mtcars2, mpg, am, paired = TRUE)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("am","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",
                 "Minimum","Maximum"))
  ret
})

test_that("test exp_ttest with power", {
  mtcars2 <- mtcars
  mtcars2$am[[1]] <- NA # test NA filtering
  model_df <- exp_ttest(mtcars2, mpg, am, beta = 0.2)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  expect_equal(colnames(ret),
               c("t Value","P Value","Degree of Freedom","Difference",
                 "Conf High","Conf Low","Effect Size (Cohen's d)","Target Power",
                 "Target Probability of Type 2 Error","Current Sample Size (Each Group)","Required Sample Size (Each Group)","Number of Rows",
                 "Number of Rows for 0","Number of Rows for 1"))
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("am","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",
                 "Minimum","Maximum"))
})

test_that("test exp_ttest with power with paired = TRUE", {
  # Make sample size equal between groups for paired t-test.
  mtcars2 <- mtcars %>% group_by(am) %>% slice_sample(n=6) %>% ungroup()
  model_df <- exp_ttest(mtcars2, mpg, am, paired = TRUE, power = 0.8)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("am","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",
                 "Minimum","Maximum"))
  ret
})


test_that("test exp_ttest with diff_to_detect", {
  mtcars2 <- mtcars
  mtcars2$am[[1]] <- NA # test NA filtering
  model_df <- exp_ttest(mtcars2, mpg, am, diff_to_detect = 0.5, power = 0.8)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("am","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",
                 "Minimum","Maximum"))
  ret
})

test_that("test exp_ttest with diff_to_detect and common_sd", {
  mtcars2 <- mtcars
  mtcars2$am[[1]] <- NA # test NA filtering
  model_df <- exp_ttest(mtcars2, mpg, am, diff_to_detect = 0.5, common_sd = 1.5, power = 0.8)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("am","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",
                 "Minimum","Maximum"))
})


test_that("test exp_ttest with asint grouping", {
  mtcars2 <- mtcars
  mtcars2$am[[1]] <- NA # test NA filtering
  model_df <- exp_ttest(mtcars2, mpg, am, func2 = "asint")
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("am","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",
                 "Minimum","Maximum"))
})

test_that("test exp_ttest with group_by", {
  model_df <- mtcars %>% group_by(vs) %>% exp_ttest(mpg, am)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("vs","am","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",
                 "Minimum","Maximum"))
  ret
})

test_that("test exp_ttest with outlier filter", {
  model_df <- mtcars %>% group_by(vs) %>% exp_ttest(mpg, am, outlier_filter_type="percentile", outlier_filter_threshold=0.9)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("vs","am","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",
                 "Minimum","Maximum"))
})

test_that("test exp_anova", {
  model_df <- exp_anova(mtcars, mpg, am)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  ret <- model_df %>% tidy_rowwise(model, type="prob_dist")
  model_df <- exp_anova(mtcars, mpg, gear)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("gear","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",   
                 "Minimum","Maximum"))
  ret <- model_df %>% tidy_rowwise(model, type="prob_dist")
})

test_that("test exp_anova with outlier filter", {
  model_df <- exp_anova(mtcars, mpg, am, outlier_filter_type="percentile", outlier_filter_threshold=0.9)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  model_df <- exp_anova(mtcars, mpg, gear, outlier_filter_type="percentile", outlier_filter_threshold=0.9)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("gear","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",   
                 "Minimum","Maximum"))
})

test_that("test exp_anova with required power", {
  model_df <- exp_anova(mtcars, mpg, am, power=0.8)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  model_df <- exp_anova(mtcars, mpg, gear, power=0.8)
  ret <- model_df %>% tidy_rowwise(model, type="model")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("gear","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",   
                 "Minimum","Maximum"))
})

test_that("test exp_anova with grouping functions", {
  model_df <- exp_anova(mtcars, mpg, disp, func2="asintby10")
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("disp","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean","Std Deviation",   
                 "Minimum","Maximum"))
})


test_that("test exp_anova with group_by", {
  model_df <- mtcars %>% group_by(vs) %>% exp_anova(mpg, am)
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  model_df <- mtcars %>% group_by(vs) %>% exp_anova(mpg, gear)
  ret <- model_df %>% tidy_rowwise(model, type="data_summary")
  expect_equal(colnames(ret),
               c("vs","gear","Number of Rows","Mean","Conf Low","Conf High","Std Error of Mean",
                 "Std Deviation","Minimum","Maximum"))
})

test_that("test exp_normality", {
  df <- mtcars %>% mutate(dummy=c(NA, rep(1,n()-1))) # test for column with always same value, except for NA.
  ret <- df %>% exp_normality(mpg, gear, dummy, n_sample=20, n_sample_qq=30)
  qq <- ret %>% tidy_rowwise(model, type="qq")
  model_summary <- ret %>% tidy_rowwise(model, type="model_summary", signif_level=0.1)
  expect_equal(colnames(model_summary),
               c("Column","W Statistic","P Value","Sample Size","Normal Distribution"))
})

test_that("test exp_normality with group", {
  df <- mtcars %>% mutate(dummy=c(NA, rep(1,n()-1))) %>% # test for column with always same value, except for NA.
    group_by(am)
  ret <- df %>% exp_normality(mpg, gear, dummy, n_sample=20, n_sample_qq=30)
  qq <- ret %>% tidy_rowwise(model, type="qq")
  expect_true("am" %in% colnames(qq))
  model_summary <- ret %>% tidy_rowwise(model, type="model_summary", signif_level=0.1)
  expect_true("am" %in% colnames(model_summary))
})

test_that("test exp_normality with column with almost always same value", {
  # test for column with almost always same value, except for NA, to test column prefiltering logic to avoid error.
  df <- mtcars %>% mutate(dummy=c(NA, 0, rep(1,n()-2)))
  ret <- df %>% exp_normality(mpg, gear, dummy, n_sample=6, n_sample_qq=30)
  qq <- ret %>% tidy_rowwise(model, type="qq")
  model_summary <- ret %>% tidy_rowwise(model, type="model_summary", signif_level=0.1)
  expect_equal(colnames(model_summary),
               c("Column","W Statistic","P Value","Sample Size","Normal Distribution"))
})
