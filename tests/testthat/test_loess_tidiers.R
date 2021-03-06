# how to run this test:
# devtools::test(filter="loess_tidiers")

context("test tidiers for loess, which is missing in broom")

test_that("test glance", {
  # TODO: with columns with space, error happens.
  #mtcars2 <- mtcars %>% rename(`cy l`=cyl, `mp g`=mpg)
  #loess_model <- stats::loess(data=mtcars2, `cy l`~`mp g`)
  loess_model <- stats::loess(data=mtcars, cyl~mpg)
  res <- broom::glance(loess_model)
  expect_equal(class(res), "data.frame")
  expect_equal(class(res$n_observations), "integer")
  expect_equal(class(res$enp), "numeric")
  expect_equal(class(res$residual_std_error), "numeric")
  expect_equal(class(res$trace_of_smoother_matrix), "numeric")

  # Test augment too.
  res <- broom::augment(loess_model, newdata=mtcars, se=TRUE)
  expect_equal(class(res$.fitted[[1]]), "numeric")
  expect_equal(class(res$.se.fit[[1]]), "numeric")
})
