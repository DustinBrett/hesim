% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rand.R
\name{rpwexp}
\alias{rpwexp}
\title{Random generation for piecewise exponential distribution}
\usage{
rpwexp(n, rate = 1, time = 0)
}
\arguments{
\item{n}{Number of random observations to draw.}

\item{rate}{A matrix of rates where rows correspond to observations 
and columns correspond to rates during specified time intervals.}

\item{time}{A vector equal to the number of columns in \code{rate} giving the
times at which the rate changes}
}
\value{
A vector of random samples from the piecewise exponential distribution. The length of the sample is 
determined by n. The numerical arguments other than n are recycled so that the number of samples is 
equal to n.
}
\description{
Draw random samples from an exponential distribution with piecewise rates.
 \code{rpwexp} is vectorized and written in C++ for speed.
}
\examples{
rate <- c(.6, 1.2, 1.3)
n <- 100000
ratemat <- matrix(rep(rate, n/2), nrow = n, 
                  ncol = 3, byrow = TRUE)
t <- c(0, 10, 15) 
ptm <- proc.time()
samp <- rpwexp(n, ratemat, t)
proc.time() - ptm
summary(samp)
}
