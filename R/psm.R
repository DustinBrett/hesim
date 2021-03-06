# PsmCurves --------------------------------------------------------------------

#' Create \code{PsmCurves} object
#' 
#' \code{create_PsmCurves} is a function for creating an object of class
#' \code{\link{PsmCurves}}.
#' @param object Fitted survival models.
#' @param data An object of class "expanded_hesim_data" returned by 
#' \code{\link{expand.hesim_data}}. Must be expanded by the data tables "strategies" and
#' "patients". 
#' @param n Number of random observations of the parameters to draw.
#' @param point_estimate If \code{TRUE}, then the point estimates are returned and and no samples are drawn.
#' @param bootstrap If TRUE, then \code{n} bootstrap replications are drawn by refitting the survival
#'  models in \code{object} on resamples of the sample data; if FALSE, then the parameters for each survival
#'  model are independently draw from multivariate normal distributions.  
#' @param est_data A \code{data.table} or \code{data.frame} of estimation data 
#' used to fit survival models during bootstrap replications.
#' @param ... Further arguments passed to or from other methods. Currently unused. 
#' @return Returns an \code{\link{R6Class}} object of class \code{\link{PsmCurves}}.
#' @seealso \code{\link{PsmCurves}}
#' @export
create_PsmCurves <- function(object, ...){
  UseMethod("create_PsmCurves", object)
} 
 
#' @export
#' @rdname create_PsmCurves
create_PsmCurves.flexsurvreg_list <- function(object, data, n = 1000, point_estimate = FALSE,
                                              bootstrap = FALSE, est_data = NULL, ...){
  if (bootstrap == TRUE & is.null(est_data)){
    stop("If 'boostrap' == TRUE, then 'est_data' cannot be NULL")
  }
  psfit <- partsurvfit(object, est_data)
  input_mats <- create_input_mats(psfit, data, id_vars = c("strategy_id", "patient_id"))
  params <- create_params(psfit, n = n, point_estimate = point_estimate, bootstrap = bootstrap)
  return(PsmCurves$new(input_mats = input_mats, params = params))
}

#' @export
#' @rdname create_PsmCurves
create_PsmCurves.params_surv_list <- function(object, data, ...){
  input_mats <- create_input_mats(object, data)
  return(PsmCurves$new(input_mats = input_mats, params = object))
}


# Manual documentation in PsmCurves.Rd
#' @export
PsmCurves <- R6::R6Class("PsmCurves",
  private = list(
    summary = function(x, type = c("hazard", "cumhazard", "survival", 
                                   "rmst", "quantile"), 
                       dr = 0){
      self$check()
      type <- match.arg(type)
      res <- data.table(C_psm_curves_summary(self, x, type, dr))
      res[, curve := curve + 1]
      res[, sample := sample + 1]
      if (type %in% c("hazard", "cumhazard", "survival", "rmst")){
        setnames(res, "x", "t")
      } else if (type == "quantile"){
        setnames(res, "x", "p")
      }
      if (type == "hazard") setnames(res, "value", "hazard")
      if (type == "cumhazard") setnames(res, "value", "cumhazard")
      if (type == "survival") setnames(res, "value", "survival")
      if (type == "rmst") setnames(res, "value", "rmst")
      if (type == "quantile") setnames(res, "value", "quantile")
      return(res[])
    }
  ),                            
                              
  public = list(
    input_mats = NULL,
    params = NULL,

    initialize = function(input_mats, params) {
      self$input_mats <- input_mats
      self$params <- params
    },
    
    hazard = function(t){
      return(private$summary(x = t, type = "hazard"))
    },
    
    cumhazard = function(t){
      return(private$summary(x = t, type = "cumhazard"))
    },
    
    survival = function(t){
      return(private$summary(x = t, type = "survival"))
    },
    
    rmst = function(t, dr = 0){
      return(private$summary(x = t, type = "rmst", dr = dr))
    },
    
    quantile = function(p){
      return(private$summary(x = p, type = "quantile"))
    },
    
    check = function(){
      if(!inherits(self$input_mats, "input_mats")){
        stop("'input_mats' must be an object of class 'input_mats'",
            call. = FALSE)
      }
      if(!inherits(self$params, c("params_surv_list", 
                                  "joined_params_surv_list"))){
        stop("Class of 'params' is not supported. See documentation.",
             call. = FALSE)
      }
    }
  )
)

# Psm --------------------------------------------------------------------------
# Manual documentation in Psm.Rd
#' @export
Psm <- R6::R6Class("Psm",
  private = list(
    
    sim_wlos = function(dr, type){
      if(is.null(self$stateprobs_)){
        stop("You must first simulate health state probabilities using '$sim_stateprobs'.",
             call. = FALSE)
      }
      
      # Time varying state values are not currently supported
      if (type == "qalys"){
        if (!is.null(self$utility_model$input_mats$time_intervals)){
          stop("Time varying utilities are not currently supported with PSMs.")
        }
      } else{
          for (i in 1:length(self$cost_models)){
            if (!is.null(self$cost_models[[i]]$input_mats$time_intervals)){
              stop("Time varying costs are not currently supported with PSMs.")
            } 
          }
      }
      
      statvalmods <- switch(type,
                           costs = self$cost_models,
                           qalys = list(self$utility_model))
      
      statvalmods_name <- switch(type,
                                costs = "cost_models",
                                qalys = "utility_model")
      
      # Check number of samples
      expected_samples <- max(self$stateprobs_$sample)
      for (i in 1:length(statvalmods)){
        if (statvalmods[[i]]$params$n_samples != expected_samples){
          msg <- paste0("Number of samples in '", statvalmods_name, "' must equal to ",
                        " the number of samples in 'survival_models', which is ",
                         expected_samples)
          stop(msg, call. = FALSE)
        }
      }
      
      # Check number of states
      for (i in 1:length(statvalmods)){
        if(self$n_states != statvalmods[[i]]$input_mats$n_states + 1){
          msg <- paste0("The number of survival models must equal the number of states in '",
                        statvalmods_name, "' - 1.")
          stop(msg, call. = FALSE)
        }
      } # loop over models
      
      stateprobs <- self$stateprobs_[state_id != self$n_states] 
      
      if (type == "costs"){
        if (is.null(names(self$cost_models))){
          categories <- paste0("Type ", seq(1, length(self$cost_models)))
        } else{
            categories <- names(self$cost_models)
        } # end if/else names for cost models
      } else{
        categories <- "qalys"
      } # end if/else costs vs. qalys

      res <- data.table(C_psm_sim_wlos(self, stateprobs, dr, type, categories))
      res[, sample := sample + 1]
      return(res[])
    } # end sim_wlos()
  ), # end private
                        
  public = list(
    survival_models = NULL,
    utility_model = NULL,
    cost_models = NULL,
    n_states = NULL,
    t_ = NULL,
    survival_ = NULL,
    stateprobs_ = NULL,
    qalys_ = NULL,
    costs_ = NULL,

    initialize = function(survival_models, utility_model = NULL, cost_models = NULL) {
      self$survival_models <- survival_models
      self$cost_models = cost_models
      self$utility_model = utility_model
      self$n_states <- length(self$survival_models$params) + 1
    },
    
    sim_survival = function(t){
      if (t[1] !=0){
        stop("The first element of 't' must be 0.", call. = FALSE)
      }
      if(!inherits(self$survival_models, "PsmCurves")){
        stop("'survival_models' must be of class 'PsmCurves'.")
      }
      self$survival_models$check()
      self$survival_ <- self$survival_models$survival(t)
      self$t_ <- t
      self$stateprobs_ <- NULL
      invisible(self)
    },
    
    sim_stateprobs = function(){
      if(is.null(self$survival_)){
        stop("You must first simulate survival curves using '$sim_survival'.",
            call. = FALSE)
      }
      res <- C_psm_sim_stateprobs(self$survival_,
                                  n_samples = self$survival_models$params[[1]]$n_samples,
                                  n_strategies = self$survival_models$input_mats$n_strategies,
                                  n_patients = self$survival_models$input_mats$n_patients,
                                  n_states = self$n_states,
                                  n_times = length(self$t_))
      prop_cross <- res$n_crossings/nrow(res$stateprobs)
      if (prop_cross > 0){
        warning(paste0("Survival curves crossed ", round(prop_cross * 100, 2), 
                       " percent of the time."),
                call. = FALSE)
      }
      stateprobs <- data.table(res$stateprobs)
      stateprobs[, state_id := state_id + 1]
      stateprobs[, sample := sample + 1]
      self$stateprobs_ <- stateprobs[]
      invisible(self)
    },
    
    sim_qalys = function(dr = .03){
      self$utility_model$check()
      qalys <- private$sim_wlos(dr, type = "qalys")
      setnames(qalys, "value", "qalys")
      self$qalys_ <- qalys
      invisible(self)
    },
    
    sim_costs = function(dr = .03){
      if(!is.list(self$cost_models)){
        stop("'cost_models' must be a list", call. = FALSE)
      }
      for (i in 1:length(self$cost_models)){
        self$cost_models[[i]]$check()
      }
      costs <- private$sim_wlos(dr, type = "costs")
      setnames(costs, "value", "costs")
      self$costs_ <- costs
      invisible(self)
    }
  )
)