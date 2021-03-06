#' Incremental treatment effect
#'
#' Computes incremental effect for all treatment strategies 
#' on outcome variables from a probabilistic sensitivity analysis relative to a comparator.
#'
#' @param x A \code{data.frame} or \code{data.table} containing simulation output with  
#' information on outcome variables for each randomly sampled parameter set from
#' a PSA. Each row should denote a randomly sampled parameter set
#' and treatment strategy.
#' @param comparator The comparator strategy. If the strategy column is a character
#' variable, then must be a character; if the strategy column is an integer variable,
#' then must be an integer.
#' @param sample Character name of column denoting a randomly sampled parameter set.
#' @param strategy Character name of column denoting treatment strategy.
#' @param grp Character name of column denoting subgroup. If \code{NULL}, then
#' it is assumed that there is only one group.
#' @param outcomes Name of columns to compute incremental changes for.
#' @return A \code{data.table} containing the differences in the values of each variable 
#' specified in outcomes between each treatment strategy and the 
#' comparator. 
#'
#' @examples 
#'# simulation output
#'n_samples <- 100
#'sim <- data.frame(sample = rep(seq(n_samples), 4),
#'              c = c(rlnorm(n_samples, 5, .1), rlnorm(n_samples, 5, .1),
#'                     rlnorm(n_samples, 11, .1), rlnorm(n_samples, 11, .1)),
#'              e = c(rnorm(n_samples, 8, .2), rnorm(n_samples, 8.5, .1),
#'                    rnorm(n_samples, 11, .6), rnorm(n_samples, 11.5, .6)),
#'              strategy = rep(paste0("Strategy ", seq(1, 2)),
#'                            each = n_samples * 2),
#'              grp = rep(rep(c("Group 1", "Group 2"),
#'                            each = n_samples), 2)
#')
#'# calculate incremental effect of Strategy 2 relative to Strategy 1 by group
#' ie <- incr_effect(sim, comparator = "Strategy 1", sample = "sample",
#'                         strategy = "strategy", grp = "grp", outcomes = c("c", "e"))
#' head(ie)
#' @export
incr_effect <- function(x, comparator, sample, strategy, grp = NULL, outcomes){
  x <- data.table(x)
  if (!comparator %in% unique(x[[strategy]])){
    stop("Chosen comparator strategy not in x")
  }
  if (is.null(grp)){
    grp = "grp"
    if (!"grp" %in% colnames(x)){
      x[, (grp) := 1] 
    }
  }
  indx_comparator <- which(x[[strategy]] == comparator)
  indx_treat <- which(x[[strategy]] != comparator)
  x_comparator <- x[indx_comparator]
  x_treat <- x[indx_treat]
  n_strategies <- length(unique(x_treat[[strategy]]))
  n_samples <- length(unique(x_treat[[sample]]))
  n_grps <- length(unique(x_treat[[grp]]))
  setorderv(x_treat, c(strategy, sample))
  setorderv(x_comparator, c(strategy, sample))

  # estimation
  return(calc_incr_effect(x_treat, x_comparator, sample, strategy, grp, outcomes, 
                          n_samples, n_strategies, n_grps))
}

# incremental change calculation
calc_incr_effect <- function(x_treat, x_comparator, sample, strategy, grp, outcomes,
                             n_samples, n_strategies, n_grps){
  outcomes_mat <- matrix(NA, nrow = nrow(x_treat), ncol = length(outcomes))
  colnames(outcomes_mat) <- paste0("i", outcomes)
  for (i in 1:length(outcomes)){
    outcomes_mat[, i] <- C_incr_effect(x_treat[[outcomes[i]]],
                                      x_comparator[[outcomes[i]]],
                                      n_samples, n_strategies, n_grps)
  }
  dt <- data.table(x_treat[[sample]], x_treat[[strategy]], x_treat[[grp]], outcomes_mat)
  setnames(dt, c(sample, strategy, grp, paste0("i", outcomes)))
}

#' Survival quantiles
#' 
#' Compute quantiles from survival curves.
#' @param x A \code{data.table} or \code{data.frame}.
#' @param probs A numeric vector of probabilities with values in \code{[0,1]}.
#' @param t A character scalar of the name of the time column.
#' @param surv_cols A character vector of the names of columns containing 
#' survival curves.
#' @param by A character vector of the names of columns to group by.
#' @return A \code{data.table} of quantiles of each survival curve in 
#' \code{surv_cols} by each group in \code{by}.
#' @examples 
#' library("data.table")
#' t <- seq(0, 10, by = .01)
#' surv1 <- seq(1, .3, length.out = length(t))
#' surv2 <- seq(1, .2, length.out = length(t))
#' strategies <- c("Strategy 1", "Strategy 2")
#' surv <- data.table(strategy = rep(strategies, each = length(t)),
#'                    t = rep(t, 2), 
#'                    surv = c(surv1, surv2))
#' surv_quantile(surv, probs = c(.4, .5), t = "t",
#'               surv_cols = "surv", by = "strategy")
#' @export
surv_quantile <- function (x, probs = .5, t, surv_cols, by) {
  x <- data.table(x)
  
  res <- vector(mode = "list", length = length(probs))
  for (i in 1:length(probs)){
    if (probs[i] > 1 | probs[i] < 0){
      stop("'prob' must be in the interval [0,1]",
          call. = FALSE)
    }  
    
    for (j in 1:length(surv_cols)){
      rows <- x[, .I[which(get(surv_cols[j]) <=  1 - probs[i])[1]], 
                     by = by]$V1
      obs1_rows <- x[, .I[1], by = by]$V1
      na_rows <- which(is.na(rows))
      rows[is.na(rows)] <- obs1_rows[na_rows]
      quantile_name <- paste0("quantile_", surv_cols[j])
      if (j == 1){
        res[[i]] <- x[rows, c(by, t), with = FALSE]
        res[[i]][, ("prob") := probs[i]]
        setnames(res[[i]], t, quantile_name)
        setcolorder(res[[i]], c(by, "prob"))
      } else{
        res[[i]][, (quantile_name) := x[rows, t, with = FALSE]]
      }
      if (length(na_rows) > 0) {
        res[[i]][na_rows, (quantile_name) := NA]
      } 
    } # End loop over surv_cols
  } # End loop over probs
  res <- rbindlist(res)
  return(res)
}


