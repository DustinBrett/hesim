context("input_data unit tests")
library("flexsurv")
library("data.table")
rm(list = ls())

strategies_dt <- data.table(strategy_id = c(1, 2))
patients_dt <- data.table(patient_id = seq(1, 3), 
                          age = c(45, 47, 60),
                          female = c(1, 0, 0),
                          group = factor(c("Good", "Medium", "Poor")))
lines_dt <- create_lines_dt(list(c(1, 2, 5), c(1, 2)))
states_dt <- data.frame(state_id =  seq(1, 3),
                        state_name = factor(paste0("state", seq(1, 3))))
trans_dt <- data.frame(transition_id = seq(1, 4),
                       from = c(1, 1, 2, 2),
                       to = c(2, 3, 1, 3))
times_dt <- data.frame(time_start = c(0, 4, 9))
hesim_dat <- hesim_data(strategies = strategies_dt,
                        patients = patients_dt,
                        lines = lines_dt,
                        states = states_dt,
                        transitions = trans_dt,
                        times = times_dt)

# create_lines_dt --------------------------------------------------------------
test_that("create_lines_dt", {
  lines_dt <- create_lines_dt(list(c(1, 2, 5), c(1, 2)))
  
  expect_true(inherits(lines_dt, "data.table"))
  expect_equal(lines_dt$treatment_id[3], 5)
  expect_equal(lines_dt$line, 
               c(seq(1, 3), seq(1, 2)))
  
  # explicit strategy ids
  lines_dt <- create_lines_dt(list(c(1, 2, 5), c(1, 2)),
                              strategy_ids = c(3, 5))
  expect_equal(lines_dt$strategy_id, c(3, 3, 3, 5, 5))
  
  # errors
  expect_error(create_lines_dt(list(c("tx1", "tx2"),
                                  c("tx1"))))
})

# create_trans_dt --------------------------------------------------------------
test_that("create_trans_dt", {
  tmat <- rbind(c(NA, 1, 2),
                c(NA, NA, 3),
                c(NA, NA, NA))
  trans_dt <- create_trans_dt(tmat)
  
  expect_true(inherits(trans_dt, "data.table"))
  expect_equal(trans_dt$transition_id, 
               c(1, 2, 3))
  expect_equal(trans_dt$from, 
               c(1, 1, 2))
  expect_equal(trans_dt$to, 
               c(2, 3, 3))
  
  # Row and column names
  rownames(tmat) <- c("No BOS", "BOS", "Death")
  trans_dt <- create_trans_dt(tmat)
  expect_equal(trans_dt$from_name, NULL)
  
  colnames(tmat) <- rownames(tmat)
  trans_dt <- create_trans_dt(tmat)
  expect_equal(trans_dt$from_name, rownames(tmat)[c(1, 1, 2)])
  expect_equal(trans_dt$to_name, colnames(tmat)[c(2, 3, 3)])
})

# hesim data -------------------------------------------------------------------
test_that("hesim_data", {

  # strategy by patient
  hesim_dat2 <- hesim_data(strategies = strategies_dt,
                          patients = patients_dt)
  
  expect_true(inherits(hesim_dat2, "hesim_data"))
  expect_equal(hesim_dat2$state, NULL)
  expect_equal(hesim_dat2$patients, patients_dt)
  
  # strategy by patient by state
  hesim_dat2 <- hesim_data(strategies = strategies_dt,
                            patients = patients_dt, 
                            states = states_dt)
  expect_equal(hesim_dat2$states, states_dt)
  
  # Expand
  expanded_dt <- expand(hesim_dat, by = c("strategies"))
  expect_equal(expanded_dt, data.table(strategies_dt), check.attributes = FALSE)
  expect_equal(attributes(expanded_dt)$id_vars, "strategy_id")
  
  expanded_dt <- expand(hesim_dat, by = c("strategies", "patients"))
  expanded_dt2 <- expand(hesim_dat, by = c("patients", "strategies"))
  expect_equal(nrow(expanded_dt), 
               nrow(strategies_dt) * nrow(patients_dt))
  expect_equal(expanded_dt, expanded_dt2)
  expect_equal(attributes(expanded_dt)$id_vars, attributes(expanded_dt2)$id_vars)
  expect_equal(attributes(expanded_dt)$id_vars, c("strategy_id", "patient_id"))
  
  expanded_dt <- expand(hesim_dat, by = c("strategies", "patients", "times"))
  expect_equal(nrow(expanded_dt), 
               nrow(strategies_dt) * nrow(patients_dt) * nrow(times_dt))
  
  
  
  # errors
  expect_error(expand(hesim_dat, by = c("strategies", "patients", 
                                                  "states", "transitions")))
  expect_error(expand(hesim_dat, by = c("strategies", "patients", 
                                                  "states", "wrong_table")))
  hesim_dat2 <- hesim_dat[c("strategies", "patients")]
  class(hesim_dat2) <-"hesim_data"
  expect_error(expand(hesim_dat2, by = c("strategies", "patients", 
                                                  "states")))
  
  # Attributes are preserved with subsetting
  ## with data table
  dat <- expand(hesim_dat)
  expect_equal(attributes(dat[1])$id_vars, c("strategy_id", "patient_id"))
  expect_equal(dat[1:2, age], hesim_dat$patients$age[1:2], check.attributes = FALSE)
  tmp <- dat[1:2, .(age, female)]
  expect_equal(nrow(tmp), 2)
  expect_equal(colnames(tmp), c("age", "female"))
  expect_equal(attributes(tmp)$id_vars, c("strategy_id", "patient_id"))
  
  ## with data frame
  setattr(dat, "class", c("expanded_hesim_data", "data.frame"))
  expect_equal(attributes(dat[1, ])$id_vars, c("strategy_id", "patient_id"))
  tmp <- dat[, c("age", "female")]
  expect_equal(nrow(tmp), nrow(dat))
  expect_equal(colnames(tmp), c("age", "female"))
  expect_equal(attributes(tmp)$id_vars, c("strategy_id", "patient_id"))
})

# input_mats class -------------------------------------------------------------
# By treatment strategy and patient
dat <- expand(hesim_dat)
X <- input_mats(X = list(mu = model.matrix(~ age, dat)),
                strategy_id = dat$strategy_id,
                n_strategies = length(unique(dat$strategy_id)),
                patient_id = dat$patient_id,
                n_patients = length(unique(dat$patient_id)))

## X must be a list
expect_error(input_mats(X = model.matrix(~ age, dat),
                       strategy_id = dat$strategy_id,
                       n_strategies = length(unique(dat$strategy_id)),
                       patient_id = dat$patient_id,
                       n_patients = length(unique(dat$patient_id))))

## X must be a list of matrices
expect_error(input_mats(X = list(model.matrix(~ age, dat), 2),
                        strategy_id = dat$strategy_id,
                        n_strategies = length(unique(dat$strategy_id)),
                        patient_id = dat$patient_id,
                        n_patients = length(unique(dat$patient_id))))

## Number of rows in X is inconsistent with strategy_id 
expect_error(input_mats(X = list(model.matrix(~ age, dat)),
                        strategy_id = dat$strategy_id[-1],
                        n_strategies = length(unique(dat$strategy_id)),
                        patient_id = dat$patient_id,
                        n_patients = length(unique(dat$patient_id))))

## Size of patient_id is incorrect
expect_error(input_mats(X = list(model.matrix(~ age, dat)),
                        strategy_id = dat$strategy_id,
                        n_strategies = length(unique(dat$strategy_id)),
                        patient_id = sort(dat$patient_id),
                        n_patients = length(unique(dat$strategy_id))))

## n_patients is incorrect v1
expect_error(input_mats(X = list(model.matrix(~ age, dat)),
                        strategy_id = dat$strategy_id,
                        n_strategies = length(unique(dat$strategy_id)),
                        patient_id = dat$strategy_id,
                        n_patients = length(unique(dat$strategy_id))))

## n_patients is incorrect v2
expect_error(input_mats(X = list(model.matrix(~ age, dat)),
                        strategy_id = dat$strategy_id,
                        n_strategies = length(unique(dat$strategy_id)),
                        patient_id = dat$patient_id,
                        n_patients = 1))

## patient_id is not sorted correctly
expect_error(input_mats(X = list(model.matrix(~ age, dat)),
                        strategy_id = dat$strategy_id,
                        n_strategies = length(unique(dat$strategy_id)),
                        patient_id = sort(dat$patient_id),
                        n_patients = length(unique(dat$patient_id))))


# By treatment strategy, line, and patient
dat <- expand(hesim_dat, by = c("strategies", "patients", "lines"))
n_lines <- hesim_dat$lines[, .N, by = "strategy_id"]
X <- input_mats(X = list(model.matrix(~ age, dat)),
                strategy_id = dat$strategy_id,
                n_strategies = length(unique(dat$strategy_id)),
                patient_id = dat$patient_id,
                n_patients = length(unique(dat$patient_id)),
                line = dat$line,
                n_lines = n_lines)

## n_lines is incorrect v1
n_lines[, N := N + 1]
expect_error(input_mats(X = list(model.matrix(~ age, dat)),
                        strategy_id = dat$strategy_id,
                        n_strategies = length(unique(dat$strategy_id)),
                        patient_id = dat$patient_id,
                        n_patients = length(unique(dat$patient_id)),
                        line = dat$line,
                        n_lines = n_lines))

## n_lines is incorrect v2
n_lines[, N := N - 1]
expect_error(input_mats(X = list(model.matrix(~ age, dat)),
                        strategy_id = dat$strategy_id,
                        n_strategies = length(unique(dat$strategy_id)),
                        patient_id = dat$patient_id,
                        n_patients = length(unique(dat$patient_id)),
                        line = dat$line,
                        n_lines = n_lines + 1))

## line is not sorted correctly
expect_error(input_mats(X = list(model.matrix(~ age, dat)),
                        strategy_id = dat$strategy_id,
                        n_strategies = length(unique(dat$strategy_id)),
                        patient_id = dat$patient_id,
                        n_patients = length(unique(dat$patient_id)),
                        line = sort(dat$line),
                        n_lines = n_lines))

# create_input_mats with formula objects ---------------------------------------
test_that("create_input_mats.formula_list", {
  dat <- expand(hesim_dat)
  f_list <- formula_list(list(f1 = formula(~ age), f2 = formula(~ 1)))
  expect_equal(class(f_list), "formula_list")
  input_mats <- create_input_mats(f_list, dat)
  
  expect_equal(length(input_mats$X), length(f_list))
  expect_equal(names(input_mats$X), names(f_list))
  expect_equal(as.numeric(input_mats$X$f1[, "age"]), dat$age)
  expect_equal(ncol(input_mats$X$f1), 2)
  expect_equal(ncol(input_mats$X$f2), 1)
})

# create_input_mats with lm objects or params_lm objects -----------------------
dat <- expand(hesim_dat, by = c("strategies", "patients", "states"))
fit1 <- stats::lm(costs ~ female + state_name, data = psm4_exdata$costs$medical)

test_that("create_input_mats.lm", {
  input_mats1 <- create_input_mats(fit1, dat)
  expect_equal(ncol(input_mats1$X$mu), 4)
  expect_equal(as.numeric(input_mats1$X$mu[, "female"]), dat$female)
  
  # Works with data.frame
  dat_df = copy(dat)
  setattr(dat_df, "class", c("expanded_hesim_data", "data.frame"))
  input_mats2 <- create_input_mats(fit1, dat_df)
  expect_equal(input_mats1, input_mats2)
  
  # Error if not data.table or data.frame
  setattr(dat_df, "class", "expanded_hesim_data")
  expect_error(create_input_mats(fit1, dat_df))
})

test_that("create_input_mats.lm_list", {
  fit2 <- stats::lm(costs ~ 1, data = psm4_exdata$costs$medical)
  fit_list <- hesim:::lm_list(fit1 = fit1, fit2 = fit2)
  input_mats <- create_input_mats(fit_list, dat)
  
  expect_equal(ncol(input_mats$X$fit1$mu), 4)
  expect_equal(ncol(input_mats$X$fit2$mu), 1)
  expect_equal(as.numeric(input_mats$X$fit1$mu[, "female"]), dat$female)
})

test_that("create_input_mats.params_lm", {
  coef <- as.matrix(data.frame(intercept = c(.2, .3), age = c(.02, .05)))
  params <- params_lm(coef = coef)
  data <- data.table(intercept = c(1, 1), age = c(55, 65),
                     patient_id = c(1, 2), strategy_id = c(1, 1))
  setattr(data, "id_vars", c("patient_id", "strategy_id"))
  setattr(data, "class", c("expanded_hesim_data", "data.table", "data.frame"))
  input_mats <- create_input_mats(params, data)
  expect_equal(input_mats$X$mu[, "intercept"], c(1, 1))
  expect_equal(input_mats$patient_id, c(1, 2))
})

# create_input_mats with flexsurvreg or params_surv objects --------------------
test_that("create_input_mats.flexsurv", {
  dat <- expand(hesim_dat)
  fit <- flexsurv::flexsurvreg(Surv(recyrs, censrec) ~ group, data = bc,
                              anc = list(sigma = ~ group), 
                              dist = "gengamma") 
  input_mats <- create_input_mats(fit, dat)
  
  expect_equal(input_mats$strategy_id, dat$strategy_id)
  expect_equal(input_mats$state_id, dat$state_id)
  expect_equal(input_mats$patient_id, dat$patient_id)
  expect_equal(class(input_mats$X), "list")
  expect_equal(class(input_mats$X[[1]]), "matrix")
  expect_equal(length(input_mats$X), 3)
  expect_equal(ncol(input_mats$X$mu), 3)
  expect_equal(ncol(input_mats$X$sigma), 3)
  expect_equal(ncol(input_mats$X$Q), 1)
})

fit1_wei <- flexsurv::flexsurvreg(formula = Surv(futime, fustat) ~ 1, 
                                  data = ovarian, dist = "weibull")
fit1_exp <- flexsurv::flexsurvreg(formula = Surv(futime, fustat) ~ 1, 
                                  data = ovarian, dist = "exp")
flexsurvreg_list1 <- flexsurvreg_list(wei = fit1_wei, exp = fit1_exp)
dat <- expand(hesim_dat)

test_that("create_input_mats.flexsurv_list", {
  input_mats <- create_input_mats(flexsurvreg_list1, dat)  
  
  expect_equal(class(input_mats$X$wei$shape), "matrix")
})

fit2_wei <- flexsurv::flexsurvreg(formula = Surv(futime, fustat) ~ 1 + age, 
                                  data = ovarian, 
                                  dist = "weibull")
fit2_exp <- flexsurv::flexsurvreg(formula = Surv(futime, fustat) ~ 1 + age, 
                                  data = ovarian, 
                                  dist = "exp")
flexsurvreg_list2 <- flexsurvreg_list(wei = fit2_wei, exp = fit2_exp)
joined_flexsurvreg_list <- joined_flexsurvreg_list(mod1 = flexsurvreg_list1,
                                                   mod2 = flexsurvreg_list2,
                                                   times = list(2, 5))

test_that("create_input_mats.joined_flexsurv_list", {
  input_mats <- create_input_mats(joined_flexsurvreg_list, dat)  
  
  expect_equal(input_mats$state_id, dat$state_id)
  expect_equal(class(input_mats$X[[1]]$wei$shape), "matrix")
})

test_that("create_input_mats.params_surv", {
  # params_surv
  coef_wei <- list(scale = as.matrix(data.frame(intercept = c(.2, .3), 
                                            age = c(.02, .05))),
               shape = as.matrix(data.frame(intercept = c(.2, .3))))
  params_wei <- params_surv(coef = coef_wei,
                        dist = "weibull") 
  data <- data.table(intercept = c(1, 1), age = c(55, 65),
                     patient_id = c(1, 2), strategy_id = c(1, 1))
  setattr(data, "id_vars", c("patient_id", "strategy_id"))
  setattr(data, "class", c("expanded_hesim_data", "data.table", "data.frame"))  
  input_mats <- create_input_mats(params_wei, data)
  expect_equal(input_mats$X$shape[, "intercept"], c(1, 1))
  expect_equal(input_mats$X$scale[, "age"], data$age)
  expect_equal(input_mats$strategy_id, data$strategy_id)
  
  # params_surv_list
  coef_exp <- list(rate = as.matrix(data.frame(intercept = c(.2, .3), 
                                            age = c(.02, .05))))
  params_exp <- params_surv(coef = coef_exp,
                                dist = "exp") 
  params <- params_surv_list(wei = params_wei, exp = params_exp)
  input_mats <- create_input_mats(params, data) 
  expect_equal(input_mats$X$wei$scale[, "age"], data$age)
  expect_equal(input_mats$X$exp$rate[, "age"], data$age)
  expect_equal(input_mats$strategy_id, data$strategy_id)
})

