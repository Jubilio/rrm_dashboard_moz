library(shiny)
e <- new.env(parent=globalenv())
local({
  settings <- c('RRM_DATA_MODE','RRM_INPUT_WORKBOOK')
  previous <- Sys.getenv(settings,unset=NA_character_)
  on.exit(for (name in settings) {
    if (is.na(previous[[name]])) Sys.unsetenv(name)
    else do.call(Sys.setenv,setNames(list(previous[[name]]),name))
  })
  # Exercise CSV fixtures independently of the configured deployment workbook.
  Sys.setenv(RRM_DATA_MODE='demo',RRM_INPUT_WORKBOOK='')
  # Windows removes environment variables assigned an empty string.
  # Override only this app environment to select the CSV input path reliably.
  e$Sys.getenv <- function(x, unset='', ...) {
    if (identical(x,'RRM_INPUT_WORKBOOK')) '' else base::Sys.getenv(x,unset=unset,...)
  }
  sys.source('app.R',envir=e)
})
stopifnot(e$DATA_MODE=='demo',e$d$metadata$mode=='demo')
html <- as.character(e$ui)
stopifnot(grepl('value="coverage" checked="checked"',html,fixed=TRUE),
  !grepl('id="coverage-map_province"',html,fixed=TRUE),
  grepl('id="alerts-alert_summary"',html,fixed=TRUE),
  grepl(paste0('tables.js?v=', unname(tools::md5sum('www/tables.js'))),
        htmltools::renderTags(e$ui)$head, fixed=TRUE),
  !grepl('id="alerts_view"|Historical severity review',html))
coverage_html <- as.character(e$page_ui('coverage','coverage',e$d))
stopifnot(grepl('id="coverage-coverage_map"',coverage_html,fixed=TRUE),
  !grepl('Partner and area responsibilities',coverage_html,fixed=TRUE),
  grepl('coverage-intro-text',coverage_html,fixed=TRUE),
  !grepl('id="coverage-metrics"',coverage_html,fixed=TRUE),
  !grepl('id="coverage-partner"',coverage_html,fixed=TRUE),
  !grepl('Map view and sources',coverage_html,fixed=TRUE),
  !grepl('Coverage uses effective assignment dates',coverage_html,fixed=TRUE))
testServer(e$server,{
  session$setInputs(page='coverage')
  stopifnot(output$page_subtitle=='RNA Intro | Cabo Delgado, Mozambique',
    output$source_label=='DRAFT LAYOUT - DEMO DATA ONLY',grepl('illustrative',output$source_footer,fixed=TRUE))
  session$setInputs(page='activity',activity_view='workbook')
  stopifnot(grepl('WORKBOOK SOURCE',output$source_label,fixed=TRUE),!grepl('DEMO',output$source_label,fixed=TRUE),
    grepl('Original review statuses',output$source_footer,fixed=TRUE))
  session$setInputs(activity_view='overview')
  stopifnot(grepl('WORKBOOK SOURCE',output$source_label,fixed=TRUE))
})
testServer(e$page_server,args=list(key='coverage',d=e$d),{
  session$setInputs(as_of=as.Date('2026-09-30'),area='All',partner='All',role='All',map_province='All',map_district='All',map_post='All')
  x <- filtered();stopifnot(length(unique(x$partner[x$role=='Primary']))==3L,
    length(unique(x$partner[x$role=='Secondary']))==2L,length(unique(x$area[x$role!='Unknown']))==6L)
  session$setInputs(partner='Partner A')
  stopifnot(nrow(filtered())==3L,all(filtered()$partner=='Partner A'))
  session$setInputs(as_of=as.Date('2025-01-01'))
  stopifnot(nrow(filtered())==0L)
})
# The intro page has no filter inputs; coverage defaults to the source date.
testServer(e$page_server,args=list(key='coverage',d=e$d),{
  stopifnot(nrow(filtered())>0L)
})
message('PASS: default demo layout, coverage-first navigation, single geography input, source labels, reference KPIs and RNA Intro layout.')
# Vulnerability screening has no "Include records without a date" checkbox; undated records stay included.
local({
  v <- new.env(parent = globalenv())
  for (f in c('R/data.R', 'R/pages.R', 'R/severity.R')) sys.source(f, envir = v)
  dv <- v$read_rrm_data('demo')
  page_ui <- v$page_ui; page_server <- v$page_server
  html <- as.character(page_ui('vulnerability', 'vulnerability', dv))
  stopifnot(!grepl('id="vulnerability-include_undated"', html, fixed = TRUE),
            !grepl('Include records without a date', html, fixed = TRUE))
  shiny::testServer(page_server, args = list(key = 'vulnerability', d = dv), {
    x <- dv$screening
    session$setInputs(dates = as.Date(c('1900-01-01', '1900-01-02')))
    stopifnot(nrow(filtered()) == sum(is.na(x$decision_date)))
  })
  message('PASS: Vulnerability screening keeps undated records without a checkbox.')
})
