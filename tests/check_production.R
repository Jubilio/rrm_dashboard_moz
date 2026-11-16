library(shiny)
source('R/data.R');source('R/pages.R');source('R/severity.R');source('R/household_ui.R');source('R/activity_workbook.R')
e <- new.env(parent=globalenv())
local({
  settings <- c('RRM_DATA_MODE','RRM_INPUT_WORKBOOK')
  previous <- Sys.getenv(settings,unset=NA_character_)
  on.exit(for (name in settings) {
    if (is.na(previous[[name]])) Sys.unsetenv(name)
    else do.call(Sys.setenv,setNames(list(previous[[name]]),name))
  })
  # Exercise CSV fixtures independently of the configured deployment workbook.
  Sys.setenv(RRM_DATA_MODE='operational',RRM_INPUT_WORKBOOK='')
  # Windows removes environment variables assigned an empty string.
  # Override only this app environment to select the CSV input path reliably.
  e$Sys.getenv <- function(x, unset='', ...) {
    if (identical(x,'RRM_INPUT_WORKBOOK')) '' else base::Sys.getenv(x,unset=unset,...)
  }
  sys.source('app.R',envir=e)
})
stopifnot(e$DATA_MODE=='operational',read_rrm_data()$metadata$mode=='operational',
          all(vapply(e$d[c('coverage','alerts','routes','assessments','needs','screening','activities','transfers')],nrow,integer(1))==0L))
html <- as.character(e$ui)
stopifnot(grepl('id="source_label"',html,fixed=TRUE),
          !grepl('Synthetic draft scenarios',html,fixed=TRUE),!grepl('DEMO-001',html,fixed=TRUE),
          !grepl('Household analysis — draft',html,fixed=TRUE),
          grepl('id="coverage-coverage_map"',html,fixed=TRUE),
          grepl('value="coverage" checked="checked"',html,fixed=TRUE))
actual <- prepare_activity_data(read_activity_snapshot())
stopifnot(nrow(actual$activities)==83L,nrow(actual$extra)==4L)
h <- read_history()
testServer(household_server,args=list(h=h,allow_synthetic=FALSE),{
  session$setInputs(source='synthetic',population='All',profile='all_households')
  stopifnot(!is.null(jsonlite::fromJSON(output$summary,simplifyVector=FALSE)$x))
  stopifnot(nrow(table_data())==0L,grepl('No reviewed',paste(as.character(output$status),collapse=" "),fixed=TRUE))
})
for(key in c('coverage','alerts','rna','vulnerability')) local({
  selected_key <- key
  testServer(page_server,args=list(key=selected_key,d=e$d),{
    session$setInputs(as_of=as.Date('2026-10-16'),area='All',partner='All',role='All',
      alert_id='All',arrival='All',trigger='All',gla='All',movement='All',
      method='All',community='All',population='All',decision='All',map_province='All',map_district='All',map_post='All')
    stopifnot(nrow(filtered())==0L,nrow(display_table())==0L,!is.null(output$metrics),!is.null(output$table),
      !is.null(jsonlite::fromJSON(output$table,simplifyVector=FALSE)$x))
    if(selected_key=='coverage') {
      stopifnot(map_data()$mode=='operational',length(map_data()$posts$features)==64L,
        !any(vapply(map_data()$districts$features,function(f) f$properties$assigned,logical(1))))
    }
  })
})
message('PASS: explicit production mode, real intervention snapshot, empty operational sources, synthetic UI exclusion, server-side source guard and production map.')
