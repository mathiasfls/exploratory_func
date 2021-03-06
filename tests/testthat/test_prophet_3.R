context("test prophet functions - Extra Regressor with Number-of-Rows target")

test_that("do_prophet with extra regressor without target column (Number of Rows)", {
  ts <- seq.Date(as.Date("2010-01-01"), as.Date("2012-01-01"), by="day")
  raw_data <- data.frame(timestamp=ts, count=round(runif(length(ts))/0.1)+1) #TODO: +1 to remove possibility of 0 rows is necessary to stabilize test. Looks into it.
  ts2 <- seq.Date(as.Date("2010-01-01"), as.Date("2012-01-11"), by="day")
  regressor_data <- data.frame(timestamp=ts2, regressor=runif(length(ts2)))
  combined_data <- raw_data %>% full_join(regressor_data, by=c("timestamp"="timestamp"))
  combined_data <- combined_data %>% mutate(count=if_else(is.na(count),1,count))
  uncounted_data <- combined_data %>% tidyr::uncount(count)
  ret <- uncounted_data %>%
    do_prophet(timestamp, NULL, 10, time_unit = "day", regressors = c(regressor_mean="regressor"), funs.aggregate.regressors = c(mean), na_fill_type="value", na_fill_value=0, regressors_na_fill_type="value", regressors_na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), as.Date("2012-01-11")) 
  # verify the last date in the data
  expect_equal(ret$timestamp[[length(ret$timestamp)]], as.Date("2012-01-11"))
})

test_that("do_prophet with extra regressor without target column (Number of Rows) with test mode", {
  ts <- seq.Date(as.Date("2010-01-01"), as.Date("2012-01-11"), by="day")
  raw_data <- data.frame(timestamp=ts, count=round(runif(length(ts))/0.1)+1)
  ts2 <- seq.Date(as.Date("2010-01-01"), as.Date("2012-01-11"), by="day")
  regressor_data <- data.frame(timestamp=ts2, regressor=runif(length(ts2)))
  combined_data <- raw_data %>% full_join(regressor_data, by=c("timestamp"="timestamp"))
  combined_data <- combined_data %>% mutate(count=if_else(is.na(count),1,count))
  uncounted_data <- combined_data %>% tidyr::uncount(count)
  ret <- uncounted_data %>%
    do_prophet(timestamp, NULL, 10, time_unit = "day", regressors = c("regressor"), funs.aggregate.regressors = c(mean), test_mode = TRUE, na_fill_type="value", na_fill_value=0, regressors_na_fill_type="value", regressors_na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), as.Date("2012-01-11")) 
  # verify the end of training data.
  expect_equal(last((ret %>% filter(!is_test_data))$timestamp), as.Date("2012-01-01")) 
  # verify the last date in the data
  expect_equal(ret$timestamp[[length(ret$timestamp)]], as.Date("2012-01-11"))
})

test_that("do_prophet with extra regressor with NAs without target column (Number of Rows) with test mode", {
  set.seed(1)
  ts <- rep(seq.Date(as.Date("2010-01-01"), as.Date("2012-01-11"), by="day"), 3) # make multiple rows for each day to test aggregation.
  raw_data <- data.frame(timestamp=ts, count=round(runif(length(ts))/0.1)+1)
  ts2 <- rep(seq.Date(as.Date("2010-01-01"), as.Date("2012-01-11"), by="day"), 3) # make multiple rows for each day to test aggregation.
  regressor_data <- data.frame(timestamp=ts2, regressor=rnorm(length(ts2)))
  regressor_data <- regressor_data %>% mutate(regressor=if_else(regressor < 0, NA_real_, regressor)) # inject NAs in regressor to test na.rm on aggregate function.
  combined_data <- raw_data %>% full_join(regressor_data, by=c("timestamp"="timestamp"))
  combined_data <- combined_data %>% mutate(count=if_else(is.na(count),1,count))
  uncounted_data <- combined_data %>% tidyr::uncount(count)
  ret <- uncounted_data %>%
    do_prophet(timestamp, NULL, 10, time_unit = "day", regressors = c("regressor"), funs.aggregate.regressors = c(mean), test_mode = TRUE, na_fill_type="value", na_fill_value=0, regressors_na_fill_type="value", regressors_na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), as.Date("2012-01-11")) 
  # verify the end of training data.
  expect_equal(last((ret %>% filter(!is_test_data))$timestamp), as.Date("2012-01-01")) 
  # verify the last date in the data
  expect_equal(ret$timestamp[[length(ret$timestamp)]], as.Date("2012-01-11"))
})

test_that("do_prophet with extra regressor with NAs, with na_count functions on target and regressor with test mode", {
  set.seed(1)
  ts <- rep(seq.Date(as.Date("2010-01-01"), as.Date("2012-01-11"), by="day"), 3) # make multiple rows for each day to test aggregation.
  raw_data <- data.frame(timestamp=ts, val=round(rnorm(length(ts)))+1)
  raw_data <- raw_data %>% mutate(val=if_else(val < 0, NA_real_, val)) # inject NAs in target to test na_count aggregate function.
  ts2 <- rep(seq.Date(as.Date("2010-01-01"), as.Date("2012-01-11"), by="day"), 3) # make multiple rows for each day to test aggregation.
  regressor_data <- data.frame(timestamp=ts2, regressor=rnorm(length(ts2)))
  regressor_data <- regressor_data %>% mutate(regressor=if_else(regressor < 0, NA_real_, regressor)) # inject NAs in regressor to test na.rm on aggregate function.
  combined_data <- raw_data %>% full_join(regressor_data, by=c("timestamp"="timestamp"))
  ret <- combined_data %>%
    do_prophet(timestamp, val, 10, time_unit = "day", fun.aggregate=na_count, regressors = c("regressor"), funs.aggregate.regressors = c(na_count), test_mode = TRUE, na_fill_type="value", na_fill_value=0, regressors_na_fill_type="value", regressors_na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), as.Date("2012-01-11")) 
  # verify the end of training data.
  expect_equal(last((ret %>% filter(!is_test_data))$timestamp), as.Date("2012-01-01")) 
  # verify the last date in the data
  expect_equal(ret$timestamp[[length(ret$timestamp)]], as.Date("2012-01-11"))
})

test_that("do_prophet with extra regressor with NAs for entirety of some dates without target column (Number of Rows) with test mode", {
  set.seed(1)
  ts <- rep(seq.Date(as.Date("2010-01-01"), as.Date("2012-01-11"), by="day"), 3) # make multiple rows for each day to test aggregation.
  raw_data <- data.frame(timestamp=ts, count=round(runif(length(ts))/0.1)+1)
  ts2 <- rep(seq.Date(as.Date("2010-01-01"), as.Date("2012-01-11"), by="day"), 3) # make multiple rows for each day to test aggregation.
  regressor_data <- data.frame(timestamp=ts2, regressor=rnorm(length(ts2)))
  regressor_data <- regressor_data %>% mutate(regressor=if_else(timestamp %in% c(as.Date("2011-01-01"), as.Date("2012-01-10")), NA_real_, regressor)) # inject NAs in regressor for an entire day to test post aggregation NA filtering, as opposed to na.rm on aggregate function.
  combined_data <- raw_data %>% full_join(regressor_data, by=c("timestamp"="timestamp"))
  combined_data <- combined_data %>% mutate(count=if_else(is.na(count),1,count))
  uncounted_data <- combined_data %>% tidyr::uncount(count)
  ret <- uncounted_data %>%
    do_prophet(timestamp, NULL, 10, time_unit = "day", regressors = c("regressor"), funs.aggregate.regressors = c(mean), test_mode = TRUE, na_fill_type="value", na_fill_value=0, regressors_na_fill_type="value", regressors_na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), as.Date("2012-01-11")) 
  # verify the end of training data.
  expect_equal(last((ret %>% filter(!is_test_data))$timestamp), as.Date("2012-01-01")) 
  # verify the last date in the data
  expect_equal(ret$timestamp[[length(ret$timestamp)]], as.Date("2012-01-11"))
})

test_that("do_prophet with extra regressor without target column (Number of Rows) with time unit of month", {
  ts <- seq.Date(as.Date("2010-01-01"), as.Date("2012-01-01"), by="month")
  raw_data <- data.frame(timestamp=ts, count=round(runif(length(ts))/0.1)+1)
  ts2 <- seq.Date(as.Date("2010-01-01"), as.Date("2012-04-01"), by="month")
  regressor_data <- data.frame(timestamp=ts2, regressor=runif(length(ts2)))
  combined_data <- raw_data %>% full_join(regressor_data, by=c("timestamp"="timestamp"))
  combined_data <- combined_data %>% mutate(count=if_else(is.na(count),1,count))
  uncounted_data <- combined_data %>% tidyr::uncount(count)
  ret <- uncounted_data %>%
    do_prophet(timestamp, NULL, 3, time_unit = "month", regressors = c("regressor"), funs.aggregate.regressors = c(mean), na_fill_type="value", na_fill_value=0, regressors_na_fill_type="value", regressors_na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), as.Date("2012-04-01")) 
  # verify the last date in the data
  expect_equal(ret$timestamp[[length(ret$timestamp)]], as.Date("2012-04-01"))
})

test_that("do_prophet with extra regressor without target column (Number of Rows) with time unit of year", {
  ts <- seq.Date(as.Date("2010-01-01"), as.Date("2020-01-01"), by="year")
  raw_data <- data.frame(timestamp=ts, count=round(runif(length(ts))/0.1)+1)
  ts2 <- seq.Date(as.Date("2010-01-01"), as.Date("2023-01-01"), by="year")
  regressor_data <- data.frame(timestamp=ts2, regressor=runif(length(ts2)))
  combined_data <- raw_data %>% full_join(regressor_data, by=c("timestamp"="timestamp"))
  combined_data <- combined_data %>% mutate(count=if_else(is.na(count),1,count))
  uncounted_data <- combined_data %>% tidyr::uncount(count)
  ret <- uncounted_data %>%
    do_prophet(timestamp, NULL, 3, time_unit = "year", regressors = c("regressor"), funs.aggregate.regressors = c(mean), na_fill_type="value", na_fill_value=0, regressors_na_fill_type="value", regressors_na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), as.Date("2023-01-01")) 
  # verify the last date in the data
  expect_equal(ret$timestamp[[length(ret$timestamp)]], as.Date("2023-01-01"))
})

test_that("do_prophet with extra regressor without target column (Number of Rows) with time unit of quarter", {
  ts <- seq.Date(as.Date("2010-01-01"), as.Date("2020-01-01"), by="quarter")
  raw_data <- data.frame(timestamp=ts, count=round(runif(length(ts))/0.1)+1)
  ts2 <- seq.Date(as.Date("2010-01-01"), as.Date("2020-10-01"), by="quarter")
  regressor_data <- data.frame(timestamp=ts2, regressor=runif(length(ts2)))
  combined_data <- raw_data %>% full_join(regressor_data, by=c("timestamp"="timestamp"))
  combined_data <- combined_data %>% mutate(count=if_else(is.na(count),1,count))
  uncounted_data <- combined_data %>% tidyr::uncount(count)
  ret <- uncounted_data %>%
    do_prophet(timestamp, NULL, 3, time_unit = "quarter", regressors = c("regressor"), funs.aggregate.regressors = c(mean), na_fill_type="value", na_fill_value=0, regressors_na_fill_type="value", regressors_na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), as.Date("2020-10-01")) 
  # verify the last date in the data
  expect_equal(ret$timestamp[[length(ret$timestamp)]], as.Date("2020-10-01"))
})

test_that("do_prophet with extra regressor without target column (Number of Rows) with time unit of hour", {
  ts <- lubridate::with_tz(seq.POSIXt(as.POSIXct("2010-01-01 00:00:00"), as.POSIXct("2010-01-02 00:00:00"), by="hour"), tz="America/Los_Angeles")
  raw_data <- data.frame(timestamp=ts, count=round(runif(length(ts))/0.1)+1)
  ts2 <- lubridate::with_tz(seq.POSIXt(as.POSIXct("2010-01-01 00:00:00"), as.POSIXct("2010-01-02 03:00:00"), by="hour"), tz="America/Los_Angeles")
  regressor_data <- data.frame(timestamp=ts2, regressor=runif(length(ts2)))
  combined_data <- raw_data %>% full_join(regressor_data, by=c("timestamp"="timestamp"))
  combined_data <- combined_data %>% mutate(count=if_else(is.na(count),1,count))
  uncounted_data <- combined_data %>% tidyr::uncount(count)
  ret <- uncounted_data %>%
    do_prophet(timestamp, NULL, 3, time_unit = "hour", regressors = c("regressor"), funs.aggregate.regressors = c(mean), na_fill_type="value", na_fill_value=0, regressors_na_fill_type="value", regressors_na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(lubridate::with_tz(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), tz="America/Los_Angeles"), lubridate::with_tz(as.POSIXct("2010-01-02 03:00:00"), tz="America/Los_Angeles")) 
  # verify the last date in the data
  expect_equal(lubridate::with_tz(ret$timestamp[[length(ret$timestamp)]], tz="America/Los_Angeles"), lubridate::with_tz(as.POSIXct("2010-01-02 03:00:00"), tz="America/Los_Angeles"))
})

test_that("do_prophet with extra regressor without target column (Number of Rows) with time unit of second", {
  ts <- lubridate::with_tz(seq.POSIXt(as.POSIXct("2010-01-01 00:00:00"), as.POSIXct("2010-01-01 00:00:50"), by="sec"), tz="America/Los_Angeles")
  raw_data <- data.frame(timestamp=ts, count=round(runif(length(ts))/0.1)+1)
  ts2 <- lubridate::with_tz(seq.POSIXt(as.POSIXct("2010-01-01 00:00:00"), as.POSIXct("2010-01-01 00:00:53"), by="sec"), tz="America/Los_Angeles")
  regressor_data <- data.frame(timestamp=ts2, regressor=runif(length(ts2)))
  combined_data <- raw_data %>% full_join(regressor_data, by=c("timestamp"="timestamp"))
  combined_data <- combined_data %>% mutate(count=if_else(is.na(count),1,count))
  uncounted_data <- combined_data %>% tidyr::uncount(count)
  ret <- uncounted_data %>%
    do_prophet(timestamp, NULL, 3, time_unit = "second", regressors = c("regressor"), funs.aggregate.regressors = c(mean), na_fill_type="value", na_fill_value=0, regressors_na_fill_type="value", regressors_na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(lubridate::with_tz(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), tz="America/Los_Angeles"), lubridate::with_tz(as.POSIXct("2010-01-01 00:00:53"), tz="America/Los_Angeles")) 
  # verify the last date in the data
  expect_equal(lubridate::with_tz(ret$timestamp[[length(ret$timestamp)]], tz="America/Los_Angeles"), lubridate::with_tz(as.POSIXct("2010-01-01 00:00:53"), tz="America/Los_Angeles"))
})

test_that("do_prophet with holiday column without target column (Number of Rows)", {
  ts <- seq.Date(as.Date("2010-01-01"), as.Date("2012-01-01"), by="day")
  raw_data <- data.frame(timestamp=ts, count=round(runif(length(ts))/0.1)+1) #TODO: +1 to remove possibility of 0 rows is necessary to stabilize test. Looks into it.
  ts2 <- seq.Date(as.Date("2010-01-01"), as.Date("2012-01-11"), by="day")

  regressor_data <- data.frame(timestamp=ts2, regressor=runif(length(ts2)), holiday=if_else(runif(length(ts2)) > 0.90,"holiday",NA_character_)) %>%
    mutate(holiday=as.character(holiday)) %>%
    rename(`holi day`=holiday)

  combined_data <- raw_data %>% full_join(regressor_data, by=c("timestamp"="timestamp"))
  combined_data <- combined_data %>% mutate(count=if_else(is.na(count),1,count))
  uncounted_data <- combined_data %>% tidyr::uncount(count)

  # With Holiday column, but without regressors.
  ret <- uncounted_data %>%
    do_prophet(timestamp, NULL, 10, time_unit = "day", holiday=`holi day`, na_fill_type="value", na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), as.Date("2012-01-11")) 
  # verify the last date in the data
  expect_equal(ret$timestamp[[length(ret$timestamp)]], as.Date("2012-01-11"))

  # With Holiday column and regressors.
  ret <- uncounted_data %>%
    do_prophet(timestamp, NULL, 10, time_unit = "day", holiday=`holi day`, regressors = c(regressor_mean="regressor"), funs.aggregate.regressors = c(mean), na_fill_type="value", na_fill_value=0, regressors_na_fill_type="value", regressors_na_fill_value=0)
  # verify the last date with forecasted_value
  expect_equal(last((ret %>% filter(!is.na(forecasted_value)))$timestamp), as.Date("2012-01-11")) 
  # verify the last date in the data
  expect_equal(ret$timestamp[[length(ret$timestamp)]], as.Date("2012-01-11"))
})
