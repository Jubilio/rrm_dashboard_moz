# Publish the dashboard to shinyapps.io.
#
# Run in the R console with the project folder as the working directory:
#   source("scripts/deploy.R")
#
# shinyapps.io builds the app on its own servers; rsconnect only polls for progress.
# When that polling times out ("Timeout was reached [api.shinyapps.io]"), the
# deployment usually carries on and finishes. This script:
#   1. gives each connection 60 s to open instead of 10 s;
#   2. if the connection still drops, checks shinyapps.io for up to 10 minutes
#      and reports whether the app was updated, instead of redeploying.
# The app, account and server come from the deployment record in rsconnect/.

local({
  app_dir <- normalizePath('.', winslash = '/')
  if (!file.exists(file.path(app_dir, 'app.R')))
    stop('Set the working directory to the rrm_dashboard project folder first.')

  record <- rsconnect::deployments(app_dir)
  record <- record[record$name == 'rrm_dashboard', , drop = FALSE]
  if (nrow(record) != 1L)
    stop('Expected one shinyapps.io deployment record for rrm_dashboard in rsconnect/.')

  options(rsconnect.libcurl.options = list(connecttimeout = 60))

  # TRUE once shinyapps.io reports the app running and updated after `since`.
  app_updated_since <- function(since) {
    apps <- tryCatch(rsconnect::applications(record$account, record$server),
                     error = function(e) NULL)
    app <- apps[apps$name == record$name, , drop = FALSE]
    if (is.null(app) || nrow(app) != 1L) return(FALSE)
    updated <- as.POSIXct(app$updated_time, format = '%Y-%m-%dT%H:%M:%S', tz = 'UTC')
    isTRUE(app$status == 'running' && !is.na(updated) && updated >= since)
  }

  # Small margin in case the local clock runs ahead of shinyapps.io.
  started <- Sys.time() - 120

  deployed <- tryCatch({
    rsconnect::deployApp(app_dir, appName = record$name, account = record$account,
                         server = record$server, forceUpdate = TRUE)
    TRUE
  }, error = function(e) {
    message('\nLost the connection to shinyapps.io: ', conditionMessage(e))
    FALSE
  })
  if (deployed) return(invisible(TRUE))

  message('Do not redeploy yet. Checking whether shinyapps.io finished the deployment',
          ' (up to 10 minutes)...')
  for (i in seq_len(40)) {
    if (app_updated_since(started)) {
      message('Deployment finished: ', record$url)
      return(invisible(TRUE))
    }
    Sys.sleep(15)
  }
  message('Could not confirm the deployment. Open the app\'s Logs in the shinyapps.io',
          ' dashboard before deploying again: ', record$url)
  invisible(FALSE)
})
