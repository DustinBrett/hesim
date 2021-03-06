% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/input-data.R
\name{expand.hesim_data}
\alias{expand.hesim_data}
\title{Expand hesim_data}
\usage{
\method{expand}{hesim_data}(object, by = c("strategies", "patients"))
}
\arguments{
\item{object}{An object of class \code{\link{hesim_data}}.}

\item{by}{A character vector of the names of the data tables in \code{\link{hesim_data}} to expand by.}
}
\value{
An object of class "expanded_hesim_data", which is a \code{data.table} with an "id_vars" 
attribute containing the names of the ID variables in the data table.
}
\description{
Expand the data tables from an object of class \code{\link{hesim_data}} into a data table in 
long format (one row for each combination of observations as specified with the 
ID variables from the tables specified with the \code{by} argument).
 See "Details" for an explanation of how the expansion is done.
}
\details{
This function is similar to \code{\link{expand.grid}}, but works for data frames or data tables. 
Specifically, it creates a \code{data.table} from all combinations of the supplied tables in \code{object}. 
The supplied tables are determined using the \code{by} argument. The resulting dataset is sorted by 
prioritizing ID variables as follows: (i) \code{strategy_id}, (ii) \code{line}, (iii) \code{patient_id},
(iv) the health-related ID variable (either \code{state_id} or \code{transition_id}), and
(v) the time interval (i.e., \code{time_id}).
}
\examples{
strategies <- data.frame(strategy_id = c(1, 2))
patients <- data.frame(patient_id = seq(1, 3), age = c(65, 50, 75),
                          gender = c("Female", "Female", "Male"))
states <- data.frame(state_id =  seq(1, 3),
                     state_var = c(2, 1, 9))
hesim_dat <- hesim_data(strategies = strategies,
                        patients = patients,
                        states = states)
expand(hesim_dat, by = c("strategies", "patients"))
}
