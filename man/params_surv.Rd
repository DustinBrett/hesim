% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/params.R
\name{params_surv}
\alias{params_surv}
\title{Parameters of a survival model}
\usage{
params_surv(coefs, dist, aux = NULL)
}
\arguments{
\item{coefs}{A list of length equal to the number of parameters in the 
survival distribution. Each element of the list is a matrix of samples from 
the posterior distribution of the regression coefficients used to predict
a given parameter.}

\item{dist}{Character vector denoting the parametric distribution. See "Details".}

\item{aux}{Auxillary arguments used with splines or fractional polynomials. See "Details".}
}
\value{
An object of class "params_surv", which is a list containing \code{coefs},
\code{dist}, and \code{n_samples}. \code{n_samples} is equal to the number of rows
in each element of \code{coefs}, which must be the same. The list may also contain \code{aux} if
a spline or fractional polynomial model is fit.
}
\description{
Create a list containing the parameters of a single fitted parametric survival model.
}
\details{
The types of distributions that can be specified are: 
\itemize{
\item{\code{exponential} or \code{exp}}{ Exponential distribution. \code{coef}
must contain the \code{rate} parameter on the log scale and the same parameterization as in 
\code{\link[stats]{Exponential}}.}.
\item{\code{weibull} or \code{weibull.quiet}}{ Weibull distribution. The first 
element of \code{coef} is the \code{shape} parameter (on the log scale) and the second
element is the \code{scale} parameter (also on the log scale). The parameterization is
that same as in \code{\link[stats]{Weibull}}.}
\item{\code{gamma}}{ Gamma distribution. The first 
element of \code{coef} is the \code{shape} parameter (on the log scale) and the second
element is the \code{rate} parameter (also on the log scale). The parameterization is
that same as in \code{\link[stats]{GammaDist}}.}
\item{\code{lnorm}}{ Lognormal distribution. The first 
element of \code{coef} is the \code{meanlog} parameter (i.e., the mean on the log scale) and the second
element is the \code{sdlog} parameter (i.e., the standard deviation on the log scale). The parameterization is
that same as in \code{\link[stats]{Lognormal}}.}
\item{\code{gompertz}}{ Gompertz distribution. The first 
element of \code{coef} is the \code{shape} parameter and the second
element is the \code{rate} parameter (on the log scale). The parameterization is
that same as in \code{\link[flexsurv]{Gompertz}}.}
\item{\code{llogis}}{ Log-logistic distribution. The first 
element of \code{coef} is the \code{shape} parameter (on the log scale) and the second
element is the \code{scale} parameter (also on the log scale). The parameterization is
that same as in \code{\link[flexsurv]{Llogis}}.}
\item{\code{gengamma}}{ Generalized gamma distribution. The first 
element of \code{coef} is the location parameter \code{mu}, the second
element is the scale parameter \code{sigma} (on the log scale), and the
third element is the shape parameter \code{Q}. The parameterization is
that same as in \code{\link[flexsurv]{GenGamma}}.}
\item{\code{survspline}}{ Survival splines. Each element of \code{coef} is a parameter of the
spline model (i.e. \code{gamma_0}, \code{gamma_1}, \eqn{\ldots}) with length equal
to the number of knots (including the boundary knots). See below for details on the
auxillary arguments. The parameterization is that same as in \code{\link[flexsurv]{Survspline}}.}
\item{\code{fracpoly}}{ Fractional polynomials. Each element of \code{coef} is a parameter of the
fractional polynomial model (i.e. \code{gamma_0}, \code{gamma_1}, \eqn{\ldots}) with length equal
to the number of powers minus 1. See below for details on the auxillary arguments 
(i.e., \code{powers}).}
}

Auxillary arguments for spline models should be specified as a list containing the elements:
\describe{
\item{\code{knots}}{ A numeric vector of knots.}
\item{\code{scale}}{ A character vector of length 1 denoting the survival outcome to be modeled
as a spline function. Options are "log_cumhazard", for the log cummulative hazard; 
"log_hazard" for the log hazard rate; "log_cumodds" for the log cummulative odds;
and "inv_normal" for the inverse normal distribution function.}
\item{\code{timescale}}{If "log" (the default), then survival is modeled as a spline function
of log time; if "identity", then it is modeled as a spline function of time.}
}

Auxillary arguments for fractional polynomial models should be specified as a list containing the elements:
\describe{
\item{\code{powers}}{ A vector of the powers of the fractional polynomial with each element
 chosen from the following set: -2. -1, -0.5, 0, 0.5, 1, 2, 3.}
}
}
\examples{
library("flexsurv")
fit <- flexsurvreg(Surv(futime, fustat) ~ 1, data = ovarian, dist = "weibull")
params <- params_surv(coefs = list(shape = fit$res.t["shape", "est", drop = FALSE],
                                   scale = fit$res.t["scale", "est", drop = FALSE]),
                     dist = fit$dlist$name)
print(params)
}
