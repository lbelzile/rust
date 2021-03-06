# =========================== gpd_sums_stats ===========================

#' Generalized Pareto summary statistics
#'
#' Calculates summary statistics involved in the Generalized Pareto
#' log-likelihood.
#'
#' @param gpd_data A numeric vector containing positive values.
#' @return A list with components
#'     \item{gpd_data}{A numeric vector. The input vector with any missings
#'     removed.}
#'     \item{m}{A numeric scalar. The sample size, i.e. the number of
#'     non-missing values.}
#'     \item{xm}{A numeric scalar. The sample maximum}
#'     \item{sum_gp}{A numeric scalar. The sum of the non-missing sample
#'     values.}
#' @examples
#' \dontrun{
#' # Sample data from a GP(sigma, xi) distribution
#' gpd_data <- rgpd(m = 100, xi = 0, sigma = 1)
#' # Calculate summary statistics for use in the log-likelihood
#' ss <- gpd_sum_stats(gpd_data)
#' }
#' @seealso \code{\link{rgpd}} for simulation from a generalized Pareto
#'   distribution.
#' @export
gpd_sum_stats <- function(gpd_data) {
  ss <- list()
  nas <- is.na(gpd_data)
  if (any(nas))
    warning("Missing values have been removed from the data")
  gpd_data <- gpd_data[!nas]
  ss$gpd_data <- gpd_data
  ss$m <- length(gpd_data)                  # sample size
  ss$xm <- max(gpd_data)                    # maximum threshold excess
  ss$sum_gp <- sum(gpd_data)                # sum of threshold excesses
  return(ss)
}

# =========================== gpd_logpost ===========================

#' Generalized Pareto posterior log-density
#'
#' Calculates the generalized Pareto posterior log-density based on a particular
#' prior for the generalized Pareto parameters, a Maximal Data Information
#' (MDI) prior truncated to xi >= -1 in order to produce a posterior
#' density that is proper.
#'
#' @param pars A numeric vector containing the values of the generalized Pareto
#'   parameters sigma and xi.
#' @param ss A numeric list. Summary statistics to be passed to the generalized
#'   Pareto log-likelihood.  Calculated using \code{gpd_sum_stats}
#' @return A numeric scalar. The value of the log-likelihood.
#' @seealso \code{\link{gpd_sum_stats}} to calculate summary statistics for
#'   use in \code{gpd_loglik}.
#' @seealso \code{\link{rgpd}} for simulation from a generalized Pareto
#' @references Northrop, P. J. and Attalides, N. (2016) Posterior propriety in
#' Bayesian extreme value analyses using reference priors. Statistica Sinica,
#' 26(2), 721-743, \url{http://dx.doi.org/10.5705/ss.2014.034}.
#' @examples
#' \dontrun{
#' # Sample data from a GP(sigma, xi) distribution
#' gpd_data <- rgpd(m = 100, xi = 0, sigma = 1)
#' # Calculate summary statistics for use in the log-likelihood
#' ss <- gpd_sum_stats(gpd_data)
#' # Calculate the generalized Pareto log-posterior
#' gpd_logpost(pars = c(1, 0), ss = ss)
#' }
#' @export
gpd_logpost <- function(pars, ss) {
  loglik <- do.call(gpd_loglik, c(list(pars = pars), ss))
  logprior <- log_gpd_mdi_prior(pars = pars)
  return(loglik + logprior)
}

# =========================== rgpd ===========================

#' Generalized Pareto simulation
#'
#' Simulates a sample of size \code{m} from a generalized Pareto distribution.
#'
#' @param m A numeric scalar.  The size of sample required.
#' @param sigma A numeric scalar.  The generalized Pareto scale parameter.
#' @param xi A numeric scalar.  The generalized Pareto shape parameter.
#' @return A numeric vector.  A generalized Pareto sample of size \code{m}.
#' @examples
#' \dontrun{
#' # Sample data from a GP(sigma, xi) distribution
#' gpd_data <- rgpd(m = 100, xi = 0, sigma = 1)
#' }
#' @export
rgpd <- function (m = 1, sigma = 1, xi = 0) {
  if (min(sigma) <= 0) {
    stop("sigma must be positive")
  }
  if (length(xi) != 1) {
    stop("xi must be scalar")
  }
  if (xi==0) {
    return(sigma * stats::rexp(m))
  } else {
    return(sigma * (stats::runif(m) ^ (-xi) - 1) / xi)
  }
}

# =========================== gpd_init ===========================

#' Initial estimates for Generalized Pareto parameters
#'
#' Calculates initial estimates and estimated standard errors (SEs) for the
#' generalized Pareto parameters sigma and xi based on an
#' assumed random sample from this distribution.  Also, calculates
#' initial estimates and estimated standard errors for
#' phi1 = sigma and phi2 = xi + sigma / xm.
#'
#' @param gpd_data A numeric vector containing positive sample values.
#' @param m A numeric scalar.  The sample size, i.e. the length of gpd_data.
#' @param xm A numeric scalar. The sample maximum.
#' @param sum_gp A numeric scalar. The sum of the sample values.
#' @param xi_eq_zero A logical scalar.  If TRUE assume that the shape
#'   parameter xi = 0.
#' @param init_ests A numeric vector.  Initial estimate of
#'   theta = (sigma, xi).  If supplied \code{gpd_init()} just
#'   returns the corresponding initial estimate of phi = (phi1, phi2).
#' @details The main aim is to calculate an admissible estimate of theta,
#'   i.e. one at which the log-likelihood is finite (necessary for the
#'   posterior log-density to be finite) at the estimate, and associated
#'   estimated SEs. These are converted into estimates and SEs for phi.  The
#'   latter can be used to set values of \code{min_phi} and \code{max_phi}
#'   for input to \code{find_lambda}.
#'
#'   In the default setting (\code{xi_eq_zero = FALSE} and
#'   \code{init_ests = NULL}) the methods tried are Maximum Likelihood
#'   Estimation (MLE) (Grimshaw, 1993), Probability-Weighted Moments (PWM)
#'   (Hosking and Wallis, 1987) and Linear Combinations of Ratios of Spacings
#'   (LRS) (Reiss and Thomas, 2007, page 134) in that order.
#'
#'   For xi < -1 the likelihood is unbounded, MLE may fail when xi is not
#'   greater than -0.5 and the observed Fisher information for (sigma, xi) has
#'   finite variance only if xi > -0.25.  We use the ML estimate provided that
#'   the estimate of xi returned from \code{gpd_mle} is greater than -1. We only
#'   use the SE if the MLE of xi is greater than -0.25.
#'
#'   If either the MLE or the SE are not OK then we try PWM.  We use the PWM
#'   estimate only if is admissible, and the MLE was not OK.  We use the PWM SE,
#'   but this will be \code{c(NA, NA)} is the PWM estimate of xi is > 1/2.  If
#'   the estimate is still not OK then we try LRS.  As a last resort, which
#'   will tend to occur only when xi is strongly negative, we set xi = -1 and
#'   estimate sigma conditional on this.
#' @return If \code{init_ests} is not supplied by the user, a list is returned
#'   with components
#'     \item{init}{A numeric vector. Initial estimates of sigma
#'      and xi.}
#'     \item{se}{A numeric vector. Estimated standard errors of
#'      sigma and xi.}
#'     \item{init_phi}{A numeric vector. Initial estimates of
#'      phi1 = sigma and phi2 = xi + sigma / xm,
#'      where xm is the maximum of \code{gpd_data}.}
#'     \item{se_phi}{A numeric vector. Estimated standard errors of
#'      phi1 and phi2.}
#'   If \code{init_ests} is supplied then only the numeric vector
#'   \code{init_phi} is returned.
#' @references Grimshaw, S. D. (1993) Computing Maximum Likelihood Estimates
#'   for the Generalized Pareto Distribution.  Technometrics, 35(2), 185-191.
#'   and Computing (1991) 1, 129-133. \url{http://dx.doi.org/10.1007/BF01889987}.
#' @references Hosking, J. R. M. and Wallis, J. R. (1987) Parameter and Quantile
#'   Estimation for the Generalized Pareto Distribution. Technometrics, 29(3),
#'   339-349. \url{http://dx.doi.org/10.2307/1269343}.
#' @references Reiss, R.-D., Thomas, M. (2007) Statistical Analysis of Extreme Values
#'   with Applications to Insurance, Finance, Hydrology and Other Fields.Birkhauser.
#'   \url{http://dx.doi.org/10.1007/978-3-7643-7399-3}.
#' @seealso \code{\link{gpd_sum_stats}} to calculate summary statistics for
#'   use in \code{gpd_loglik}.
#' @seealso \code{\link{rgpd}} for simulation from a generalized Pareto
#' @seealso \code{\link{find_lambda}} to produce (somewhat) automatically
#'   a list for the argument \code{lambda} of \code{ru}.
#' @examples
#' \dontrun{
#' # Sample data from a GP(sigma, xi) distribution
#' gpd_data <- rgpd(m = 100, xi = 0, sigma = 1)
#' # Calculate summary statistics for use in the log-likelihood
#' ss <- gpd_sum_stats(gpd_data)
#' # Calculate initial estimates
#' do.call(gpd_init, ss)
#' }
#' @export
gpd_init <- function(gpd_data, m, xm, sum_gp = NULL, xi_eq_zero = FALSE,
                     init_ests = NULL) {
  #
  theta_to_phi <- function(theta) c(theta[1], theta[2] + theta[1] / xm)
  #
  if (!is.null(init_ests)) {
    return(theta_to_phi(init_ests))
  }
  if (xi_eq_zero) {
    s_hat <- mean(gpd_data)
    init <- c(s_hat, 0)
    init_phi <- theta_to_phi(init)
    cov_mtx <- matrix(c(2*s_hat^2, -s_hat, -s_hat, 1), 2, 2) / m
    se <- sqrt(diag(cov_mtx))
    mat <- matrix(c(1, 0, 1 / xm, 1), 2, 2, byrow = TRUE)
    var_phi <- mat %*% cov_mtx %*% t(mat)
    se_phi <- sqrt(diag(var_phi))
    return(list(init = init, se = se, init_phi = init_phi, se_phi = se_phi))
  }
  #
  ests_ok <- ses_ok <- FALSE
  # First try MLE
  temp <- gpd_mle(gpd_data)
  init <- temp$mle
  # Check that the MLE is OK
  if (!is.na(init[1]) & init[2] > -1 & init[2] > -init[1]/xm &
      !is.infinite(temp$nllh)){
    ests_ok <- TRUE
    # Check whether or not we should use the SE
    if (init[2] > -0.25){
      cov_mtx <- solve(gpd_obs_info(init, gpd_data))
      se <- sqrt(diag(cov_mtx))
      mat <- matrix(c(1, 0, 1 / xm, 1), 2, 2, byrow = TRUE)
      var_phi <- mat %*% cov_mtx %*% t(mat)
      if (all(diag(var_phi) > 0)){
        se_phi <- sqrt(diag(var_phi))
        ses_ok <- TRUE
      }
    }
  }
  if (!ests_ok | !ses_ok){
    # Try PWM
    if (!requireNamespace("revdbayes", quietly = TRUE)) {
      stop("revdbayes needed for this function to work. Please install it.",
           call. = FALSE)
    }
    pwm <- revdbayes:::gp_pwm(gpd_data)
    se <- pwm$se
    mat <- matrix(c(1, 0, 1 / xm, 1), 2, 2, byrow = TRUE)
    var_phi <- mat %*% pwm$cov %*% t(mat)
    se_phi <- sqrt(diag(var_phi))
    # Note: se and se_phi will be NA if pwm$est[2] > 1/2
    check <- gpd_loglik(pars = pwm$est, gpd_data = gpd_data, m = m, xm = xm,
                        sum_gp = sum_gp)
    # If MLE wasn't OK and PWM estimate is OK then use PWM estimate
    if (!ests_ok & init[2] > -1 & !is.infinite(check)) {
      init <- pwm$est
      ests_ok <- TRUE
    }
  }
  # If estimate is not OK then try LRS
  if (!ests_ok){
    if (!requireNamespace("revdbayes", quietly = TRUE)) {
      stop("revdbayes needed for this function to work. Please install it.",
           call. = FALSE)
    }
    init <- revdbayes:::gp_lrs(gpd_data)
    check <- gpd_loglik(pars = init, gpd_data = gpd_data, m = m, xm = xm,
                        sum_gp = sum_gp)
    if (init[2] > -1 & !is.infinite(check)) {
      ests_ok <- TRUE
    }
  }
  # If we get here without ests_ok = TRUE then the posterior mode is
  # probably close to xi = -1.  We want to avoid xi < -1 so we set
  # xi = -1 and use the (bias-adjusted) mle of sigma conditional on xi = -1.
  if (!ests_ok) {
    init <- c(xm * (m + 1) / m, -1)
  }
  init_phi <- theta_to_phi(init)
  return(list(init = init, se = se, init_phi = init_phi, se_phi = se_phi))
}

# =========================== log_gpd_mdi_prior ===========================

log_gpd_mdi_prior <- function(pars) {
  # Generalized Pareto MDI prior log-density
  #
  # Calculates the log-density of a Maximal Data Information (MDI) prior
  # for generalized Pareto parameters.  The prior density is truncated,
  # (to xi >= -1), to produce a posterior density that is proper.
  #
  # Args:
  #   pars : A numeric vector containing the values of the generalized Pareto
  #          parameters sigma and xi.
  #
  # Returns:
  #   A numeric scalar. The value of the prior log-density.
  #
  if (pars[1] <= 0 | pars[2] < -1) {
    return(-Inf)
  }
  return(-log(pars[1]) - pars[2] - 1)
}

# =========================== gpd_loglik ===========================

gpd_loglik <- function(pars, gpd_data, m, xm, sum_gp) {
  # Generalized Pareto log-likelihood
  #
  # Calculates the log-likelihood for a random sample from a Generalized Pareto.
  #
  # Args:
  #   pars     : A numeric vector containing the values of the generalized
  #              Pareto parameters sigma and xi.
  #   gpd_data : A numeric vector containing positive sample values.
  #   m        : A numeric scalar.  The sample size: the length of gpd_data.
  #   xm       : A numeric scalar. The sample maximum.
  #   sum_gp   : The sum of the sample values.
  #
  # Returns:
  #   A numeric scalar. The value of the log-likelihood.
  #
  if (pars[1] <= 0 | pars[2] <= -pars[1] / xm)
    return(-Inf)
  sdat <- gpd_data / pars[1]
  zz <- 1 + pars[2] * sdat
  if (abs(pars[2]) > 1e-6) {
    val <- -m * log(pars[1]) - (1 + 1 / pars[2]) * sum(log(zz))
  } else {
    i <- 1:4
    g_fun <- function(x) {
      t1 <- x ^ i
      t2 <- (i * x - i - 1)
      sum((-1) ^ i * t1 * t2 * pars[2] ^ i / i / (i + 1))
    }
    val <- -m * log(pars[1]) - sum_gp / pars[1] - sum(sapply(sdat, g_fun))
  }
  return(val)
}

# =========================== gpd_mle ===========================

gpd_mle <- function(gpd_data) {
  # Maximum likelihood estimation for the generalized Pareto distribution
  #
  # Performs maximum likelihood estimation for the generalized Pareto
  # distribution.  Uses the function \code{gpdmle} associated with
  # Grimshaw (1993), which returns MLEs of sigma and k = - \xi.
  #
  # Grimshaw, S. D. (1993) Computing Maximum Likelihood Estimates
  #   for the Generalized Pareto Distribution.  Technometrics, 35(2), 185-191.
  #   and Computing (1991) 1, 129-133. http://dx.doi.org/10.1007/BF01889987.
  #
  # Args:
  #   gpd_data : A numeric vector containing positive values, assumed to be a
  #             random sample from a generalized Pareto distribution.
  #
  # Returns:
  #   A list with components
  #     mle  : A numeric vector.  MLEs of GP parameters sigma and xi.
  #     nllh : A numeric scalar.  The negated log-likelihood at the MLE.
  #
  # Call Grimshaw (1993) function, note: k is -xi, a is sigma
#  pjn <- grimshaw_gpdmle(gpd_data)
  temp <- list()
  # Use revdbayes function if revdbayes is available, otherwise use fallback
  if (requireNamespace("revdbayes", quietly = TRUE)) {
    pjn <- revdbayes:::grimshaw_gp_mle(gpd_data)
    temp$mle <- c(pjn$a, -pjn$k)  # mle for (sigma,xi)
  } else {
    temp <- fallback_gp_mle(init = c(mean(gpd_data), 0), gpd_data = gpd_data,
                            m = length(gpd_data), xm = max(gpd_data),
                            sum_gp = sum(gpd_data))
  }
  sc <- rep(temp$mle[1], length(gpd_data))
  xi <- temp$mle[2]
  temp$nllh <- sum(log(sc)) + sum(log(1 + xi * gpd_data / sc) * (1 / xi + 1))
  return(temp)
}

# =========================== fallback_gp_mle ===========================

fallback_gp_mle <- function(init, ...){
  x <- stats::optim(init, gpd_loglik, ..., control = list(fnscale = -1),
                    hessian = FALSE)
  temp <- list()
  temp$mle <- x$par
  temp$nllh <- -x$value
  return(temp)
}

# =========================== gpd_obs_info ===========================

gpd_obs_info <- function(gpd_pars, y) {
  # Observed information for the generalized Pareto distribution
  #
  # Calculates the observed information matrix for a random sample \code{y}
  # from the generalized Pareto distribution, i.e. the negated Hessian matrix of
  # the generalized Pareto log-likelihood, evaluated at \code{gpd_pars}.
  #
  # Args:
  #   gpd_pars : A numeric vector. Parameters sigma and xi of the
  #   generalized Pareto distribution.
  #   y       : A numeric vector. A sample of positive data values.
  #
  # Returns:
  #   A 2 by 2 numeric matrix.  The observed information matrix.
  #
  s <- gpd_pars[1]
  x <- gpd_pars[2]
  i <- matrix(NA, 2, 2)
  i[1,1] <- -sum((1 - (1 + x) * y * (2 * s + x * y) / (s + x * y) ^ 2) / s ^ 2)
  i[1,2] <- i[2,1] <- -sum(y * (1 - y / s) / (1 + x * y / s) ^ 2 / s ^ 2)
  i[2,2] <- sum(2 * log(1 + x * y / s) / x ^ 3 - 2 * y / (s + x * y) / x ^ 2 -
                  (1 + 1 / x) * y ^ 2 / (s + x * y) ^ 2)
  return(i)
}
