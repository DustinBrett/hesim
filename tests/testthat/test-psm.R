context("psm.R unit tests")
library("flexsurv")
library("data.table")
library("pracma")
rm(list = ls())

# Simulation
strategies_dt <- data.table(strategy_id = seq(2, 4)) # testing for cases when doesn't start at 1
patients_dt <- data.table(patient_id = seq(1, 3),
                          age = c(45, 50, 60),
                          female = c(0, 0, 1))
states_dt <- data.frame(state_id =  seq(1, 3),
                        state_name = paste0("state", seq(1, 3)))
hesim_dat <- hesim_data(strategies = strategies_dt,
                        patients = patients_dt,
                        states = states_dt)
N <- 5

# Partitioned survival curves  -------------------------------------------------
# Simulation data
surv_input_data <- expand(hesim_dat, by = c("strategies", "patients"))

# Fit survival curves
surv_est_data <- psm4_exdata$survival
fits_exp <- fits_wei <- fits_weinma <- fits_spline <- fits_ggamma <- vector(mode = "list", length = 3)
names(fits_exp) <- names(fits_wei) <- names(fits_spline) <- paste0("curves", seq(1, 3))
formulas <- list("Surv(endpoint1_time, endpoint1_status) ~ age",
                 "Surv(endpoint2_time, endpoint2_status) ~ age",
                 "Surv(endpoint3_time, endpoint3_status) ~ age")
for (i in 1:3){
  fits_exp[[i]] <- flexsurv::flexsurvreg(as.formula(formulas[[i]]),
                                         data = surv_est_data,
                                        dist = "exp")
  fits_wei[[i]] <- flexsurv::flexsurvreg(as.formula(formulas[[i]]), 
                                         data = surv_est_data,
                                          dist = "weibull")
  fits_weinma[[i]] <- suppressWarnings(flexsurv::flexsurvreg(as.formula(formulas[[i]]), 
                                         data = surv_est_data,
                                         dist = hesim_survdists$weibullNMA,
                                         inits = fits_wei[[i]]$res.t[, "est"]))
  fits_spline[[i]] <- flexsurv::flexsurvspline(as.formula(formulas[[i]]), data = surv_est_data)
  fits_ggamma[[i]] <- flexsurv::flexsurvreg(as.formula(formulas[[i]]),
                                         data = surv_est_data,
                                        dist = "gengamma")
}
fits_exp <- flexsurvreg_list(fits_exp)
fits_wei <- flexsurvreg_list(fits_wei)
fits_weinma <- flexsurvreg_list(fits_weinma)
fits_spline <- flexsurvreg_list(fits_spline)
fits_ggamma <- flexsurvreg_list(fits_ggamma)

test_that("create_PsmCurves", {
  # From fitted model
  psm_curves <- create_PsmCurves(fits_wei, data = surv_input_data, n = N,
                                 bootstrap = TRUE, est_data = surv_est_data)
  expect_true(inherits(psm_curves, "PsmCurves"))
  expect_true(inherits(psm_curves$params, "params_surv_list"))
  expect_equal(as.numeric(psm_curves$input_mats$X[[1]]$scale[, "age"]), 
              surv_input_data$age)
  
  ## errors
  expect_error(create_PsmCurves(3, data = surv_input_data, n = N,
                                bootstrap = FALSE))
  expect_error(create_PsmCurves(fits_wei, data = surv_input_data, n = N,
                                 bootstrap = TRUE))
})

test_that("PsmCurves", {
  times <- c(1, 2, 3)
  
  # Sampling
  ## Weibull
  psm_curves <- create_PsmCurves(fits_wei, data = surv_input_data, n = N,
                                 bootstrap = TRUE,
                                 est_data = surv_est_data)
  expect_true(inherits(psm_curves$survival(t = times), "data.table"))
  
  ## Splines
  psm_curves <- create_PsmCurves(fits_spline, data = surv_input_data, n = N,
                                bootstrap = FALSE)
  expect_equal(max(psm_curves$survival(t = times)$sample), N)
  
  # Comparison of summary of survival curves
  compare_surv_summary <- function(fits, data, fun_name = c("survival", "hazard",
                                                            "cumhazard", "rmst",
                                                            "quantile")){
    fun_name <- match.arg(fun_name)
    psm_curves <- create_PsmCurves(fits, data = data,
                                   point_estimate = TRUE,
                                   bootstrap = FALSE)
    
    hesim_out <- psm_curves[[fun_name]](t = times)
    fun_name2 <- if (fun_name == "cumhazard"){
      "cumhaz"
    } else{
      fun_name
    }
    flexsurv_out <- summary(fits[[1]], newdata = data.frame(age = data[1, age]),
                           t = times, type = fun_name2, tidy = TRUE, ci = FALSE)
    expect_equal(hesim_out[curve == 1, fun_name, with = FALSE][[1]], 
                 flexsurv_out[, "est"], tolerance = .001, scale = 1)
  }
  tmp_data = surv_input_data
  tmp_data <- tmp_data[1, ]
  
  compare_surv_summary(fits_wei, tmp_data, "survival")
  compare_surv_summary(fits_spline, tmp_data, "survival")
  compare_surv_summary(fits_weinma, tmp_data, "survival")
  compare_surv_summary(fits_ggamma, tmp_data, "survival")
  
  compare_surv_summary(fits_wei, tmp_data, "hazard")
  compare_surv_summary(fits_spline, tmp_data, "hazard")
  compare_surv_summary(fits_weinma, tmp_data, "hazard")
  compare_surv_summary(fits_ggamma, tmp_data, "hazard")
  
  
  compare_surv_summary(fits_wei, tmp_data, "cumhazard")
  compare_surv_summary(fits_spline, tmp_data, "cumhazard")
  compare_surv_summary(fits_weinma, tmp_data, "cumhazard")
  compare_surv_summary(fits_ggamma, tmp_data, "cumhazard")
  
  compare_surv_summary(fits_wei, tmp_data, "rmst")
  compare_surv_summary(fits_spline, tmp_data, "rmst")
  compare_surv_summary(fits_weinma, tmp_data, "rmst")
  
  # Quantiles
  psm_curves <- create_PsmCurves(fits_exp, data = surv_input_data, n = N,
                                 bootstrap = TRUE, est_data = surv_est_data)
  X <- psm_curves$input_mats$X$curves1$rate[1, , drop = FALSE]
  beta <- psm_curves$params$curves1$coefs$rate[1, , drop = FALSE]
  rate_hat <- X %*% t(beta)
  
  quantiles_out <- psm_curves$quantile(.5)
  expect_equal(qexp(.5, exp(rate_hat)), quantiles_out$quantile[1])
})

# Partitioned survival model  --------------------------------------------------
set.seed(101)
times <- c(0, 2, 5, 8)

# Survival models
psm_curves <- create_PsmCurves(fits_wei, data = surv_input_data, n = N,
                               bootstrap = FALSE)

# Utility model
psm_X <- create_input_mats(formula_list(mu = formula(~1)), 
                                     expand(hesim_dat, 
                                     by = c("strategies", "patients", "states")),
                                     id_vars = c("strategy_id", "patient_id", "state_id"))
psm_utility <- StateVals$new(input_mats = psm_X,
                             params = params_lm(coef = runif(N, .6, .8)))


# Cost model(s)
fit_costs_medical <- stats::lm(costs ~ female + state_name, 
                               data = psm4_exdata$costs$medical)
cost_input_data <- expand(hesim_dat, by = c("strategies", "patients", "states"))
psm_costs_medical <- create_StateVals(fit_costs_medical, data = cost_input_data, n = N)
psm_costs_medical2 <- create_StateVals(fit_costs_medical, data = cost_input_data, n = N + 1)

# Combine
psm <- Psm$new(survival_models = psm_curves,
               utility_model = psm_utility,
               cost_models = list(medical = psm_costs_medical))
expect_error(psm$sim_survival(t = c(2, 5)))
psm$sim_survival(t = times)

# State probabilities
test_that("Psm$stateprobs", {
  dt_by_grp <- function(x, by_var, value_var){
    df <- split(x, by = by_var)
    dt <- data.table(data.frame(lapply(df, function (x) x[[value_var]])))
  }
  
  surv_dt <- dt_by_grp(psm$survival_, by_var = "curve", value_var = "survival")
  surv_dt[, cross1 := ifelse(X1 > X2, 1, 0)]
  surv_dt[, cross2 := ifelse(X2 > X3, 1, 0)]
  n_crossings <- sum(surv_dt$cross1) + sum(surv_dt$cross2)
  if (n_crossings > 0){
    expect_warning(psm$sim_stateprobs()$stateprobs_)
  } else{
    psm$sim_stateprobs()$stateprobs_
  }
  
  stateprobs_dt <- dt_by_grp(psm$stateprobs_, by_var = "state_id",
                              value_var = "prob")

  expect_equal(surv_dt$X1, stateprobs_dt$X1)
  expect_equal(pmax(0, surv_dt$X2 - surv_dt$X1), stateprobs_dt$X2)
  expect_equal(pmax(0, surv_dt$X3 - surv_dt$X2), stateprobs_dt$X3)
  expect_equal(1 - surv_dt$X3, stateprobs_dt$X4)
})

# Costs and QALYs
R_los <- function(psm, type, type_num, dr = .03, 
                  state_id = 1, sample = 1, strategy_id = 2,
                  patient_id = 1){
  if (type == "costs_"){
    model <- psm$cost_models[[type_num]]
  } else{
    model <- psm$utility_model
  }
  dat <- model$input_mats
  statevals <- dat$X$mu %*% t(model$params$coefs)
  obs <- which(dat$state_id == state_id & dat$strategy_id == strategy_id &
                 dat$patient_id == patient_id)
  stateval <- statevals[obs, sample]
  
  env <- environment()
  stateprobs <- psm$stateprobs_[state_id == env$state_id &
                                sample == env$sample &
                                strategy_id == env$strategy_id &
                                patient_id == env$patient_id]
  times <- stateprobs$t
  yvals <- exp(-dr * times) * stateval * stateprobs$prob
  return(pracma::trapz(x = times, y = yvals))
}

los_compare <- function(psm, type = c("costs_", "qalys_"), 
                        type_num = NULL, dr,
                        state_id = 1, sample = 1, strategy_id = 1,
                  patient_id = 1){
  type <- match.arg(type)
  env <- environment()
  hesim_los_dt <- psm[[type]][state_id == env$state_id &
                                  sample == env$sample &
                                  strategy_id == env$strategy_id &
                                  patient_id == env$patient_id &
                                  dr == env$dr]
  R_los <- R_los(psm, type = type, type_num = type_num, dr = dr, 
                 state_id = state_id, sample = sample,
                 strategy_id = strategy_id, patient_id = patient_id)
  expect_equal(hesim_los_dt[[gsub("_", "", type)]], R_los)
}

test_that("Psm$costs", {
  psm$sim_stateprobs()$stateprobs_
  psm$sim_costs(dr = c(0, .03))
  
  los_compare(psm, type = "costs_", type_num = 1, dr = 0, strategy_id = 2)
  los_compare(psm, type = "costs_", type_num = 1, dr = .03, strategy_id = 3)
  
  # Error messages
  psm2 <- Psm$new(survival_models = psm_curves,
                  utility_model = psm_utility,
                  cost_models = list(medical = psm_costs_medical2))
  psm2$sim_survival(t = times)
  expect_error(psm2$sim_costs(dr = c(0, .03)))
  psm2$sim_stateprobs()
  expect_error(psm2$sim_costs(dr = 0))
  
  ## Incorrect number of survival models
  fits_wei2 <- flexsurvreg_list(fits_wei[1:2])
  psm_curves2 <- create_PsmCurves(fits_wei2, 
                               data = surv_input_data, n = N,
                               bootstrap = TRUE, est_data = surv_est_data)
  psm2 <- Psm$new(survival_models = psm_curves2,
                  utility_model = psm_utility,
                  cost_models = list(medical = psm_costs_medical))
  psm2$sim_survival(t = times)
  psm2$sim_stateprobs()
  expect_error(psm2$sim_costs())
  
  ## Time varying costs are not currently supported
  drugcost_tbl = data.frame(strategy_id = strategies_dt$strategy_id,
                            time_start = c(0, 0, 0, 2, 2, 2),
                            est = c(1000, 1500, 2000, 3000, 4000, 5000)
                            )
  drugcost_tbl <- stateval_tbl(drugcost_tbl, dist = "fixed", hesim_data = hesim_dat)
  psm_drugcost <- create_StateVals(drugcost_tbl, n = N)
  psm2$cost_models <- list(medical = psm2$cost_models$medical, drug = psm_drugcost)
  expect_error(psm2$sim_costs())
  
  ## Incorrect types
  psm2 <- Psm$new(survival_models = NULL)
  expect_error(psm2$sim_survival(t = times))
})

test_that("Psm$qalys", {
  # Time constant
  psm$sim_stateprobs()$stateprobs_
  psm$sim_qalys(dr = c(0, .05))
  
  los_compare(psm, type = "qalys_", dr = 0, strategy_id = 2)
  los_compare(psm, type = "qalys_", dr = .05, patient_id = 2,
              strategy_id = 3)
  
  # Time varying
  utility_tbl2 <- data.frame(state_id = states_dt$state_id,
                             time_start = c(0, 0, 0, 2, 2, 2),
                             est = c(.90, .85, .80, .75, .65, .55))
  utility_tbl2 <- stateval_tbl(utility_tbl2, dist = "fixed", hesim_data = hesim_dat)
  psm_utility2 <- create_StateVals(utility_tbl2, n = N)
  psm$utility_model <- psm_utility2
  expect_error(psm$sim_qalys())
})

test_that("Psm - from parameter object", {
  # PsmCurves
  params_wei <- create_params(fits_wei)
  tmp_input_data <- surv_input_data
  tmp_input_data$shape <- 1
  tmp_input_data$scale <- 1
  psm_curves <- create_PsmCurves(params_wei, data = tmp_input_data)
  expect_true(inherits(psm_curves$hazard(t = c(1, 2, 3)),
                      "data.table"))
  
  # Psm
  psm <- Psm$new(survival_models = psm_curves)
  psm$sim_survival(t = c(0, 1, 2, 3))
  expect_true(inherits(psm$survival_,
                      "data.table")) 
  psm$sim_stateprobs()
  expect_true(inherits(psm$stateprobs_,
                      "data.table")) 
})
