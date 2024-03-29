####################### BEGIN Auxiliary functions #######################

### START QL_loss_function
QL_loss_function <- function(pred, gt){pred/gt - log(pred/gt) - 1}
### END QL_loss_function

### START dbw
dbw <- function(X
                ,dbw_indices
                ,shock_time_vec
                ,scale = FALSE
                ,center = FALSE
                ,sum_to_1 = 1
                ,bounded_below_by = 0
                ,bounded_above_by = 1
                ,normchoice = c('l1', 'l2')[2]
                ,penalty_normchoice = c('l1', 'l2')[1]
                ,penalty_lambda = 0
) { # https://github.com/DEck13/synthetic_prediction/blob/master/prevalence_testing/numerical_studies/COP.R
  # X is a list of covariates for the time series
  # X[[1]] should be the covariate of the time series to predict
  # X[[k]] for k = 2,...,n+1 are covariates for donors

  # T^* is a vector of shock-effects time points
  # shock effect point must be > 2

  print('Now we print the length of the list X')
  print(X)

  # number of time series for pool
  n <- length(X) - 1

  # COVARIATE FOR TIME SERIES UNDER STUDY AT shock_time_vec
  X1 <- X[[1]][shock_time_vec[1], dbw_indices, drop = FALSE] # we get only 1 row

  #We notify user if p > n, i.e. if linear system is overdetermined
  p <- length(dbw_indices)

  if (p > n){print('p > n, i.e. system is overdetermined from an unconstrained point-of-view.')}

  # LOOP for grab shock_time_vec covariate vector for each donor
  X0 <- c()
  for (i in 1:n) {
    X0[[i]] <- X[[i+1]][shock_time_vec[i+1]
                        , dbw_indices
                        , drop = FALSE] #get 1 row from each donor
  }

  #################################
  #begin if statement
  if (scale == TRUE) {
    print('User has chosen to scale covariates.')

    dat <- rbind(as.data.frame(X1), as.data.frame(do.call('rbind', X0))) # do.call is for cluster computing?
    print('Pre-scaling')
    print(dat)

    dat <- apply(dat, 2, function(x) scale(x, center = TRUE, scale = TRUE))
    print('Post-scaling')
    print(dat)

    ## We output details of SVD of matrix X1
    dat.svd <- svd(dat)
    sing_vals <- dat.svd$d / sum(dat.svd$d)
    print('These are the singular value percentages for the donor pool X data:')
    print(paste(100 * sing_vals, "%", sep = ""))

    X1 <- dat[1, dbw_indices
              , drop = FALSE]

    X0 <- c()

    for (i in 1:n) {
      X0[[i]] <- dat[i+1, dbw_indices, drop = FALSE] #we are repopulating X0[[i]] with scaled+centered data
    } #end loop
  } #end if statement
  #################################


  # objective function
  weightedX0 <- function(W) {
    # W is a vector of weight of the same length of X0
    n <- length(W)
    p <- ncol(X1)
    XW <- matrix(0, nrow = 1, ncol = p)
    for (i in 1:n) {
      XW <- XW + W[i] * X0[[i]]
    } #end of loop

    #normchoice
    if (normchoice == 'l1') {
      norm <- as.numeric(norm(matrix(X1 - XW), type = "1"))
    }
    else {
      norm <- as.numeric(crossprod(matrix(X1 - XW)))
    }

    #now add penalty
    if (penalty_normchoice == 'l1' & penalty_lambda > 0) {
      norm <- norm + penalty_lambda * norm(as.matrix(W), type = "1")
    }
    else if (penalty_normchoice == 'l2' & penalty_lambda > 0) {
      norm <- norm + penalty_lambda * as.numeric(crossprod(matrix(W)))
    }
    else {norm <- norm}

    return(norm)
  } #end objective function

  # optimization and return statement

  # I have added features
  # 1) The option to remove the sum-to-1 constraint
  # 2) The option to change the lower bound to -1 or NA
  # 3) option to change the upper bound to NA'
  # 4) option to choose l1 or l2 norm as distance function

  #Thus I need if statements to implement these...

  # conditional for sum to 1
  if (is.na(sum_to_1) == FALSE) {eq_constraint <- function(W) sum(W) - 1}
  else{eq_constraint = NULL}

  # conditional for bounding below
  if (is.na(bounded_below_by) == FALSE)
  {
    lower_bound = rep(bounded_below_by, n)
  }
  else if (is.na(bounded_below_by) == TRUE)  {
    lower_bound = NULL
  }

  #conditional for bounding above
  if (is.na(bounded_above_by) == FALSE)
  {
    upper_bound = rep(1, n)
  }
  else if (is.na(bounded_above_by) == TRUE)  {
    upper_bound = NULL
  }

  object_to_return <- Rsolnp::solnp(par = rep(1/n, n),
                            fun = weightedX0,
                            eqfun = eq_constraint,
                            eqB = 0,
                            LB = lower_bound, UB = upper_bound,
                            control = list(trace = 1
                                           , 1.0e-12
                                           , tol = 1e-27
                                           , outer.iter = 1000000000
                                           , inner.iter = 10000000))

  if (object_to_return$convergence == 0){convergence <- 'convergence'}
  else {convergence <- 'failed_convergence'}

  pair_to_return <- list(object_to_return$pars, convergence)

  names(pair_to_return) <- c('opt_params', 'convergence')

  return(pair_to_return)

} #END dbw function
### END dbw

### START GARCH plot_maker_garch
plot_maker_garch <- function(fitted_vol
                            ,shock_time_labels = NULL
                            ,shock_time_vec #mk
                            ,shock_length_vec
                            ,unadjusted_pred
                            ,w_hat
                            ,omega_star_hat
                            ,omega_star_hat_vec
                            ,adjusted_pred
                            ,arithmetic_mean_based_pred
                            ,ground_truth_vec){

  if (is.character(shock_time_labels) == FALSE | is.null(shock_time_labels) == TRUE){
    shock_time_labels <- 1:length(shock_time_vec)
  }

  par(mfrow = c(1,3), mar=c(15,6,4,2))

  barplot_colors <- RColorBrewer::brewer.pal(length(w_hat),'Set3')

  print('Barplot colors no problem.')

  #PLOT ON THE LEFT:

  # Plot donor weights
  barplot(w_hat
          , main = 'Donor Pool Weights'
          , names.arg = shock_time_labels[-1]
          , cex.names=1.3
          , cex.main=1.5
          , las=2
          , col = barplot_colors
          )

  #PLOT IN THE MIDDLE

  #Plot FE estimates
    barplot(omega_star_hat_vec
          , main = 'Donor-Pool-Supplied \n FE Estimates'
          , names.arg = shock_time_labels[-1]
          , cex.names=1.3
          , cex.main=1.5
          , las=2
          , col = barplot_colors)

  title(ylab = expression(sigma^2), line = 3.05, cex.lab = 1.99) # Add y-axis text

  #Plot target series and prediction

  thing_to_get_max_of <- c(as.numeric(fitted_vol)
                        , unadjusted_pred
                        , adjusted_pred
                        , ground_truth_vec
                        , arithmetic_mean_based_pred
                        )

  max_for_y_lim <- max(thing_to_get_max_of)

  #PLOT ON THE RIGHT:
  plot.ts(fitted_vol[1:shock_time_vec[1]], #mk
       main = 'Post-Shock Volatility Forecast', #mk can improve this title
       cex.main=1.5,
       ylab = '',
       xlab = "Trading Days",
       xlim = c(0, shock_time_vec[1] + 5), #mk
       ylim = c(min(0, fitted_vol),  max_for_y_lim))

  title(ylab = expression(sigma^2), line = 2.05, cex.lab = 1.99) # Add y-axis text

  print('Vol TS no problem.')

  # Here is the color scheme we will use
  colors_for_adjusted_pred <- c('red'
                              , "green"
                              , "purple"
                              , 'blue'
                              )

  # Let's add the plain old GARCH prediction
  points(y = unadjusted_pred
         ,x = (shock_time_vec[1]+1):(shock_time_vec[1]+shock_length_vec[1])
         ,col = colors_for_adjusted_pred[1]
         ,cex = 1.5
         ,pch = 15)

  print('Unadjusted prediction no problem.')

  # Now plot the adjusted predictions
  points(y = adjusted_pred
         ,x = (shock_time_vec[1]+1):(shock_time_vec[1]+shock_length_vec[1])
         ,col = colors_for_adjusted_pred[2]
         ,cex = 1.5
         ,pch = 23)

  print('Adjusted prediction no problem.')

  # Now plot the arithmetic mean-based predictions
  points(y = arithmetic_mean_based_pred
         ,x = (shock_time_vec[1]+1):(shock_time_vec[1]+shock_length_vec[1])
         ,col = colors_for_adjusted_pred[3]
         ,cex = 1.5
         ,pch = 23)


  # Now plot Ground Truth tk
  if (is.null(ground_truth_vec) == FALSE)
    {
    points(y = ground_truth_vec
           ,x = (shock_time_vec[1]+1):(shock_time_vec[1]+shock_length_vec[1])
           ,col = colors_for_adjusted_pred[4]
           ,cex = 1.5
           ,pch = 22)
  }

  labels_for_legend <- c('GARCH (unadjusted)'
                        , 'Adjusted'
                        , 'Arithmetic Mean'
                        , 'Ground Truth'
                        )

  legend(x = "topleft",  # Coordinates (x also accepts keywords) #mk
         legend = labels_for_legend,
         1:length(labels_for_legend), # Vector with the name of each group
         colors_for_adjusted_pred,   # Creates boxes in the legend with the specified colors
         title = 'Prediction Method',      # Legend title,
         cex = .9)

}
### END plot_maker_garch

### START plot_maker_synthprediction
plot_maker_synthprediction <- function(Y
                                     ,shock_time_labels = NULL
                                     ,shock_time_vec #mk
                                     ,shock_length_vec
                                     ,unadjusted_pred
                                     ,w_hat
                                     ,omega_star_hat
                                     ,omega_star_hat_vec
                                     ,adjusted_pred
                                     ,display_ground_truth = FALSE){


  if (is.character(shock_time_labels) == FALSE | is.null(shock_time_labels) == TRUE){
    shock_time_labels <- 1:length(shock_time_vec)
  }

  n <- length(Y) - 1

  #First print donor series
  par(mfrow = c(round(sqrt(n)),ceiling(sqrt(n))))

  for (i in 2:(n+1)){
    plot.ts(Y[[i]][1:shock_time_vec[i]]
            ,xlab = 'Trading Days'
            ,ylab = 'Differenced Logarithm'
            ,main = paste('Donor ', i,': ', shock_time_labels[i], sep = '')
            ,xlim = c(0, shock_time_vec[i] + 5)
            ,ylim = c(min(Y[[i]]),  max(Y[[i]]))
            )

    if (display_ground_truth == TRUE){

      lines(y = Y[[i]][shock_time_vec[i]:(shock_time_vec[i] + shock_length_vec[i])]
            ,x = shock_time_vec[i]:(shock_time_vec[i] + shock_length_vec[i])
            ,col = 'purple'
            ,cex = 1.1
            ,lty = 3)

      points(y = Y[[i]][(shock_time_vec[i]+1):(shock_time_vec[i] + shock_length_vec[i])]
             ,x = (shock_time_vec[i]+1):(shock_time_vec[i] + shock_length_vec[i])
             # ,col = 'red'
             ,cex = 1.1
             ,pch = 24)

    }
  }

  #Now print time series under study
  par(mfrow = c(1,3), mar=c(15,6,4,2))

  barplot_colors <- RColorBrewer::brewer.pal(length(w_hat),'Set3')

  #PLOT ON THE LEFT:
  #Plot donor weights
  barplot(w_hat
          , main = 'Donor Pool Weights'
          , names.arg = shock_time_labels[-1]
          , cex.names=.95
          , las=2
          , col = barplot_colors)

  #PLOT IN THE MIDDLE

  #Plot FE estimates
  barplot(omega_star_hat_vec
          , main = 'Donor-Pool-Supplied \n FE Estimates'
          , names.arg = shock_time_labels[-1]
          , cex.names=.95
          , las=2
          , col = barplot_colors)

  #Plot target series and prediction

  thing_to_get_max_of <- c(as.numeric(Y[[1]]), unadjusted_pred, adjusted_pred)

  max_for_y_lim <- max(thing_to_get_max_of)

  #PLOT ON THE RIGHT:
  plot.ts(Y[[1]][1:shock_time_vec[1]], #mk
          main = 'Post-shock Forecasts',
          ylab = '',
          xlab = "Trading Days",
          xlim = c(0, shock_time_vec[1] + 5), #mk
          ylim = c(min(0, Y[[1]]),  max_for_y_lim))

  title(ylab = 'Log-return', line = 2.05, cex.lab = 1.99) # Add y-axis text

  # Here is the color scheme we will use
  colors_for_adjusted_pred <- c('red', "green",'purple')

  # Let's add the plain old GARCH prediction
  points(y = unadjusted_pred
         ,x = (shock_time_vec[1]+1):(shock_time_vec[1]+shock_length_vec[1])
         ,col = colors_for_adjusted_pred[1]
         ,cex = .9
         ,pch = 15)

  # Now plot the adjusted predictions
  points(y = adjusted_pred
         ,x = (shock_time_vec[1]+1):(shock_time_vec[1]+shock_length_vec[1])
         ,col = colors_for_adjusted_pred[2]
         ,cex = 1.1
         ,pch = 23)

  if (display_ground_truth == TRUE){

    lines(y = Y[[1]][shock_time_vec[1]:(shock_time_vec[1] + shock_length_vec[1])]
          ,x = shock_time_vec[1]:(shock_time_vec[1] + shock_length_vec[1])
          ,col = colors_for_adjusted_pred[3]
          ,cex = 1.1
          ,lty = 3)

    points(y = Y[[1]][(shock_time_vec[1]+1):(shock_time_vec[1] + shock_length_vec[1])]
          ,x = (shock_time_vec[1]+1):(shock_time_vec[1] + shock_length_vec[1])
          ,col = colors_for_adjusted_pred[3]
          ,cex = 1.1
          ,pch = 24)

  }

  labels_for_legend <- c('ARIMA (unadjusted)', 'Adjusted Prediction', 'Actual')

  legend(x = "topleft",  # Coordinates (x also accepts keywords) #mk
         legend = labels_for_legend,
         1:length(labels_for_legend), # Vector with the name of each group
         colors_for_adjusted_pred,   # Creates boxes in the legend with the specified colors
         title = 'Prediction Method',      # Legend title,
         cex = .9)

}
### END plot_maker_synthprediction

####################### END Auxiliary functions #######################

### START SynthVolForecast
SynthVolForecast <- function(Y_series_list
                             ,covariates_series_list
                             ,shock_time_vec
                             ,shock_length_vec
                             ,k=1
                             ,dbw_scale = TRUE
                             ,dbw_center = TRUE
                             ,dbw_indices = NULL
                             ,covariate_indices = NULL
                             ,geometric_sets = NULL #tk
                             ,days_before_shocktime_vec = NULL #tk I may want to remove this
                             ,garch_order = NULL
                             ,common_series_assumption = FALSE
                             ,plots = TRUE
                             ,shock_time_labels = NULL
                             ,ground_truth_vec = NULL
){
  ### BEGIN Doc string
  #tk
  ### END Doc string

  ### BEGIN Populate defaults
  n <- length(Y_series_list) - 1

  if (is.null(garch_order) == TRUE) {garch_order <- c(1,1,1)}

  if (is.null(dbw_indices) == TRUE) {dbw_indices <- 1:ncol(covariates_series_list[[1]])}

  ### END Populate defaults

  ## BEGIN Check that inputs are all comformable/acceptable
  n <- length(Y_series_list) - 1 #tk
  ## END Check that inputs are all comformable/acceptable

  integer_shock_time_vec <- c() #mk
  integer_shock_time_vec_for_convex_hull_based_optimization <- c() #mk

  ## BEGIN Check whether shock_time_vec is int/date

  for (i in 1:(n+1)){

    if (is.character(shock_time_vec[i]) == TRUE){
      print('The shock time vector entry is a character.')
      integer_shock_time_vec[i] <- which(index(Y[[i]]) == shock_time_vec[i]) #mk
      integer_shock_time_vec_for_convex_hull_based_optimization[i] <- which(index(covariates_series_list[[i]]) == shock_time_vec[i]) #mk
    }
    else{
      print('The shock time vector entry is NOT a character.')
      integer_shock_time_vec[i] <- shock_time_vec[i]
      integer_shock_time_vec_for_convex_hull_based_optimization[i] <- shock_time_vec[i]
    }

  }

  ## END Check whether shock_time_vec is int/date

  ## BEGIN calculate weight vector
  dbw_output <- dbw(covariates_series_list, #tk
               dbw_indices,
               integer_shock_time_vec_for_convex_hull_based_optimization,
               scale = dbw_scale,
               center = dbw_center,
               sum_to_1 = TRUE, #tk
               bounded_below_by = 0, #tk
               bounded_above_by = 1, #tk
               # normchoice = normchoice, #tk
               # penalty_normchoice = penalty_normchoice,
               # penalty_lambda = penalty_lambda
               )

  w_hat <- dbw_output[[1]]

  ## END calculate weight vector

  ## BEGIN estimate fixed effects in donors
  omega_star_hat_vec <- c()

  if (common_series_assumption == TRUE){
    print('tk TODO')

    #step 1: create dummy vector with n+1 shocks
    #NOTA BENE: n different fixed effects, or
    # 1 fixed effect estimated at n shocks?
      vec_of_zeros <- rep(0, integer_shock_time_vec[i])
      vec_of_ones <- rep(1, shock_length_vec[i])
      post_shock_indicator <- c(vec_of_zeros, vec_of_ones)
      last_shock_point <- integer_shock_time_vec[i] + shock_length_vec[i]

    #step 2: fit model


  }

  else{

    for (i in 2:(n+1)){

      # Make indicator variable w/ a 1 at only T*+1, T*+2,...,T*+shock_length_vec[i]
      vec_of_zeros <- rep(0, integer_shock_time_vec[i])
      vec_of_ones <- rep(1, shock_length_vec[i])
      post_shock_indicator <- c(vec_of_zeros, vec_of_ones)
      last_shock_point <- integer_shock_time_vec[i] + shock_length_vec[i]

      #subset X_i
      if (is.null(covariate_indices) == TRUE) {
        X_i_penultimate <- cbind(Y_series_list[[i]][1:last_shock_point] #tk
                                 , post_shock_indicator)
        X_i_final <- X_i_penultimate[,2]
      }
      else {
        X_i_subset <- covariates_series_list[[i]][1:last_shock_point,covariate_indices]
        X_i_with_indicator <- cbind(X_i_subset, post_shock_indicator)
        X_i_final <- X_i_with_indicator
      }

      fitted_garch <- garchx::garchx(Y_series_list[[i]][1:last_shock_point] #tk
                     , order = garch_order
                     , xreg = X_i_final
                     , backcast.values = NULL
                     , control = list(eval.max = 100000
                     , iter.max = 1500000
                     , rel.tol = 1e-8))

      cat('\n===============================================================\n')
      print(paste('Outputting GARCH estimates for donor series number ', i,'.', sep = ''))
      print(fitted_garch)
      print(paste('Outputting AIC for donor series number ', i,'.', sep = ''))
      print(AIC(fitted_garch))
      cat('\n===============================================================\n')

      coef_test <- lmtest::coeftest(fitted_garch)
      extracted_fixed_effect <- coef_test[dim(lmtest::coeftest(fitted_garch))[1], 1]
      omega_star_hat_vec <- c(omega_star_hat_vec, extracted_fixed_effect)

    } ## END loop for computing fixed effects

  }

  ## END estimate fixed effects in donors

  ## BEGIN compute linear combination of fixed effects
  omega_star_hat <- w_hat %*% omega_star_hat_vec
  ## END compute linear combination of fixed effects

  ## BEGIN fit GARCH to target series

  if (is.null(covariate_indices) == TRUE){

    fitted_garch <- garchx::garchx(Y_series_list[[1]][1:integer_shock_time_vec[1]]
                           , order = garch_order
                           , xreg = NULL
                           , backcast.values = NULL
                           , control = list(eval.max = 100000
                                            , iter.max = 1500000
                                            , rel.tol = 1e-8))

    cat('\n===============================================================\n')
    print('Outputting the fitted GARCH for time series under study.')
    print(fitted_garch)
    print('Outputting AIC for time series under study.')
    print(AIC(fitted_garch))
    cat('\n===============================================================\n')

    unadjusted_pred <- predict(fitted_garch, n.ahead = shock_length_vec[1])
  }
  else{
    ## BEGIN fit GARCH to target series
    fitted_garch <- garchx::garchx(Y_series_list[[1]][1:integer_shock_time_vec[1]]
                           , order = garch_order
                           , xreg = covariates_series_list[[1]][1:integer_shock_time_vec[1],covariate_indices]
                           , backcast.values = NULL
                           , control = list(eval.max = 100000
                                            , iter.max = 1500000
                                            , rel.tol = 1e-8))

    cat('\n===============================================================\n')
    print('Outputting the fitted GARCH for the time series under study.')
    print(fitted_garch)
    cat('\n===============================================================\n')

    #Note: for forecasting, we use last-observed X value
    X_to_use_in_forecast <- covariates_series_list[[1]][integer_shock_time_vec[1],covariate_indices]

    X_replicated_for_forecast_length <- matrix(rep(X_to_use_in_forecast, k)
                                               , nrow = shock_length_vec[1]
                                               , byrow = TRUE)

    forecast_period <- (integer_shock_time_vec[1]+1):(integer_shock_time_vec[1]+shock_length_vec[1])
    mat_X_for_forecast <- cbind(Y_series_list[[1]][forecast_period]
                           , X_replicated_for_forecast_length)

    unadjusted_pred <- predict(fitted_garch
                               , n.ahead = shock_length_vec[1]
                               , newxreg = mat_X_for_forecast[,-1])
  }

  print('Now we get the adjusted predictions.')
  adjusted_pred <- unadjusted_pred + rep(omega_star_hat, k)

  arithmetic_mean_based_pred <- rep(mean(omega_star_hat_vec), k) + unadjusted_pred

  if (is.null(ground_truth_vec) == TRUE){
    QL_loss_unadjusted_pred <- NA
    QL_loss_adjusted_pred <- NA
  }
  else {
    QL_loss_unadjusted_pred <- sum(QL_loss_function(unadjusted_pred, ground_truth_vec))
    QL_loss_adjusted_pred <- sum(QL_loss_function(adjusted_pred, ground_truth_vec))
  }


  list_of_linear_combinations <- list(w_hat)
  list_of_forecasts <- list(unadjusted_pred, adjusted_pred)
  names(list_of_forecasts) <- c('unadjusted_pred', 'adjusted_pred')

  output_list <- list(list_of_linear_combinations
                      , list_of_forecasts)

  names(output_list) <- c('linear_combinations', 'predictions')

  ## tk OUTPUT
  cat('--------------------------------------------------------------\n',
      '-------------------SynthVolForecast Results-------------------','\n',
      '--------------------------------------------------------------\n',
      'Donors:', n, '\n',  '\n',
      'Shock times:', shock_time_vec, '\n', '\n',
      'Lengths of shock times:', shock_length_vec, '\n', '\n',
      'Optimization Success:', dbw_output[[2]], '\n', '\n',
      'Convex combination:',w_hat,'\n', '\n',
      'Shock estimates:', omega_star_hat_vec, '\n', '\n',
      'Aggregate estimated shock effect:', omega_star_hat, '\n', '\n',
      'Unadjusted Forecast:', unadjusted_pred,'\n', '\n',
      'Adjusted Forecast:', adjusted_pred,'\n', '\n',
      'Arithmetic-Mean-Based Forecast:',arithmetic_mean_based_pred,'\n','\n',
      'Ground Truth (estimated by realized volatility):', ground_truth_vec,'\n', '\n',
      'QL Loss of unadjusted:', QL_loss_unadjusted_pred,'\n', '\n',
      'QL Loss of adjusted:', QL_loss_adjusted_pred,'\n', '\n'
  )

  ## PLOTS

  if (plots == TRUE){
    cat('\n User has opted to produce plots.','\n')
    plot_maker_garch(fitted(fitted_garch)
               ,shock_time_labels
               ,integer_shock_time_vec
               ,shock_length_vec
               ,unadjusted_pred
               ,w_hat
               ,omega_star_hat
               ,omega_star_hat_vec
               ,adjusted_pred
               ,arithmetic_mean_based_pred
               ,ground_truth_vec = NULL)
                  }

  return(output_list)

} ### END SynthVolForecast

### START SynthPrediction
SynthPrediction <- function(Y_series_list
                             ,covariates_series_list
                             ,shock_time_vec
                             ,shock_length_vec
                             ,k = 1
                             ,dbw_scale = TRUE
                             ,dbw_center = TRUE
                             ,dbw_indices = NULL
                             ,covariate_indices = NULL
                             ,geometric_sets = NULL #tk
                             ,days_before_shocktime_vec = NULL #tk I may want to remove this
                             ,arima_order = NULL
                             ,user_ic_choice = c('aicc','aic','bic')[1]
                             ,plots = TRUE
                             ,display_ground_truth_choice = FALSE
){
  ### BEGIN Doc string
  #tk
  ### END Doc string

  ### BEGIN Populate defaults
  n <- length(Y_series_list) - 1

  if (is.null(arima_order) == TRUE) {
    arima_order <- c(1,1,1)
  }

  if (is.null(dbw_indices) == TRUE) {
    dbw_indices <- 1:ncol(covariates_series_list[[1]]) #tk
  }

  ### END Populate defaults

  ## BEGIN Check that inputs are all comformable/acceptable
  n <- length(Y_series_list) - 1 #tk
  ## END Check that inputs are all comformable/acceptable

  integer_shock_time_vec <- c() #mk
  integer_shock_time_vec_for_convex_hull_based_optimization <- c() #mk

  ## BEGIN Check whether shock_time_vec is int/date

  for (i in 1:(n+1)){

    if (is.character(shock_time_vec[i]) == TRUE){
      print('The shock time vector entry is a character.')
      integer_shock_time_vec[i] <- which(index(Y[[i]]) == shock_time_vec[i]) #mk
      integer_shock_time_vec_for_convex_hull_based_optimization[i] <- which(index(covariates_series_list[[i]]) == shock_time_vec[i]) #mk
    }
    else{
      print('The shock time vector entry is NOT a character.')
      integer_shock_time_vec[i] <- shock_time_vec[i]
      integer_shock_time_vec_for_convex_hull_based_optimization[i] <- shock_time_vec[i]
    }

  }

  ## END Check whether shock_time_vec is int/date

  ## BEGIN estimate fixed effects in donors
  omega_star_hat_vec <- c()

  order_of_arima <- list()

  for (i in 2:(n+1)){

    # Make indicator variable w/ a 1 at only T*+1, T*+2,...,T*+shock_length_vec[i]
    vec_of_zeros <- rep(0, integer_shock_time_vec[i])
    vec_of_ones <- rep(1, shock_length_vec[i])
    post_shock_indicator <- c(vec_of_zeros, vec_of_ones)
    last_shock_point <- integer_shock_time_vec[i] + shock_length_vec[i]

    #subset X_i
    if (is.null(covariate_indices) == TRUE) {
      X_i_penultimate <- cbind(Y_series_list[[i]][1:last_shock_point]
                               , post_shock_indicator)
      X_i_final <- X_i_penultimate[,2]
    }
    else {
      X_i_subset <- covariates_series_list[[i]][1:last_shock_point,covariate_indices]
      X_i_with_indicator <- cbind(X_i_subset, post_shock_indicator)
      X_i_final <- X_i_with_indicator
    }

    print('Now fitting the donor ARIMA models')

    arima <- forecast::auto.arima(Y_series_list[[i]][1:last_shock_point]
                        ,xreg=X_i_final
                        ,ic = user_ic_choice)

    print(arima)

    order_of_arima[[i]] <- arima$arma #tk

    coef_test <- lmtest::coeftest(arima)
    extracted_fixed_effect <- coef_test[nrow(coef_test),1]
    omega_star_hat_vec <- c(omega_star_hat_vec, extracted_fixed_effect)

  } ## END loop for computing fixed effects

  ## END estimate fixed effects in donors

  ## BEGIN compute linear combination of fixed effects
  dbw_output <- dbw(covariates_series_list, #tk
                   dbw_indices,
                   integer_shock_time_vec,
                   scale = TRUE,
                   center = TRUE,
                   sum_to_1 = TRUE, #tk
                   bounded_below_by = 0, #tk
                   bounded_above_by = 1, #tk
                   # normchoice = normchoice, #tk
                   # penalty_normchoice = penalty_normchoice,
                   # penalty_lambda = penalty_lambda
  )

  w_hat <- dbw_output[[1]]

  omega_star_hat <- as.numeric(w_hat %*% omega_star_hat_vec)
  ## END compute linear combination of fixed effects

  ## BEGIN fit GARCH to target series

  if (is.null(covariate_indices) == TRUE){

    arima <- forecast::auto.arima(Y_series_list[[1]][1:integer_shock_time_vec[1]]
                        ,xreg = NULL
                        ,ic = user_ic_choice)

    unadjusted_pred <- predict(arima, n.ahead = shock_length_vec[1])

  }
  else{
    ## BEGIN fit GARCH to target series

    X_lagged <- lag.xts(covariates_series_list[[1]][1:integer_shock_time_vec[1],covariate_indices])

    arima <- forecast::auto.arima(Y_series_list[[1]][1:integer_shock_time_vec[1]]
                        ,xreg = X_lagged
                        ,ic = user_ic_choice)

    print(arima)

    #Note: for forecasting, we use last-observed X value
    X_to_use_in_forecast <- covariates_series_list[[1]][integer_shock_time_vec[1],covariate_indices]

    X_replicated_for_forecast_length <- matrix(rep(X_to_use_in_forecast, k)
                                               , nrow = shock_length_vec[1]
                                               , byrow = TRUE)

    forecast_period <- (integer_shock_time_vec[1]+1):(integer_shock_time_vec[1]+shock_length_vec[1])
    mat_X_for_forecast <- cbind(Y_series_list[[1]][forecast_period]
                                , X_replicated_for_forecast_length)

    unadjusted_pred <- predict(arima
                               , n.ahead = shock_length_vec[1]
                               , newxreg = mat_X_for_forecast[,-1])
  }

  ##We take care of housekeeping
  #tk
  order_of_arima[[1]] <- arima$arma

  print('now we print dataframe with orders...')
  order_matrix <- matrix(unlist(order_of_arima), byrow = TRUE, nrow = length(order_of_arima))

  print(order_matrix)

  if( length(unique(order_matrix[,2])) > 1 ) {
    message <- paste('NOT all series are I(', order_matrix[,2], ')')
    warning(message)
  }

  ##

  adjusted_pred <- unadjusted_pred$pred + omega_star_hat

  list_of_linear_combinations <- list(w_hat)
  list_of_forecasts <- list(unadjusted_pred, adjusted_pred)
  names(list_of_forecasts) <- c('unadjusted_pred', 'adjusted_pred')

  output_list <- list(list_of_linear_combinations
                      , list_of_forecasts)

  names(output_list) <- c('linear_combinations', 'predictions')

  ## tk OUTPUT
  cat('SynthPrediction Details','\n',
      '-------------------------------------------------------------\n',
      'Donors:', n, '\n',
      'Shock times:', shock_time_vec, '\n',
      'Lengths of shock times:', shock_length_vec, '\n',
      'Optimization Success:', dbw_output[[2]], '\n', '\n',
      'Convex combination',w_hat,'\n',
      'Shock estimates provided by donors:', omega_star_hat_vec, '\n',
      'Aggregate estimated shock effect:', omega_star_hat, '\n',
      'Actual change in stock price at T* + 1:', Y_series_list[[1]][integer_shock_time_vec[1]+1],'\n',
      'Unadjusted forecasted change in stock price at T*+1:', unadjusted_pred$pred,'\n',
      'MSE unadjusted:', (as.numeric(Y_series_list[[1]][integer_shock_time_vec[1]+1])-unadjusted_pred$pred)**2,'\n',
      'Adjusted forecasted change in stock price at T*+1:', adjusted_pred,'\n',
      'MSE adjusted:', (as.numeric(Y_series_list[[1]][integer_shock_time_vec[1]+1])-adjusted_pred)**2,'\n'

  )

  ## PLOTS

  if (plots == TRUE){

    cat('User has opted to produce plots.','\n')

    plot_maker_synthprediction(Y_series_list
               ,shock_time_vec
               ,integer_shock_time_vec
               ,shock_length_vec
               ,unadjusted_pred$pred
               ,w_hat
               ,omega_star_hat
               ,omega_star_hat_vec
               ,adjusted_pred
               ,display_ground_truth = display_ground_truth_choice

               )
  }

  return(output_list)

} ### END SynthPrediction
