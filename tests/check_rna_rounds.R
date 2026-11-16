library(shiny)
source('R/data.R');source('R/pages.R')
d <- read_rrm_data('demo')
# Distinct methods exercise method filtering independently of the round filter.
d$assessments$method[2] <- 'KII only'
html <- as.character(page_ui('rna','rna',d))
stopifnot(grepl('value="All" selected>All assessments',html,fixed=TRUE))
updates <- list()
mock_session <- MockShinySession$new()
mock_session$sendInputMessage <- function(inputId,message) {updates[[inputId]] <<- message}
testServer(page_server,args=list(key='rna',d=d),session=mock_session,{
  session$setInputs(assessment_id='All',alert_id='All',area='All',method='All',
    dates=as.Date(c('2026-09-01','2026-09-30')),include_undated=TRUE)
  stopifnot(nrow(filtered())==2L,nrow(display_table())==nrow(d$needs),
    setequal(display_table()[['Assessment round']],d$assessments$assessment_id))
  stopifnot(all(display_table()[['Alert ID']]==d$assessments$alert_id[
    match(display_table()[['Assessment round']],d$assessments$assessment_id)]))
  metrics <- paste(as.character(output$metrics),collapse=' ')
  stopifnot(grepl('Assessment rounds',metrics,fixed=TRUE),
    grepl('Do not sum potentially overlapping samples',metrics,fixed=TRUE),!is.null(output$table))
  session$setInputs(alert_id='DEMO-001')
  stopifnot(nrow(filtered())==1L,nrow(display_table())==3L,
    !'Assessment round' %in% names(display_table()),
    grepl('Selected assessment',paste(as.character(output$metrics),collapse=' '),fixed=TRUE))
  session$setInputs(alert_id='All',area='Arrival F')
  stopifnot(identical(filtered()$assessment_id,'DEMO-RNA-02'))
  session$setInputs(area='All',method='KII only')
  stopifnot(identical(filtered()$assessment_id,'DEMO-RNA-02'))
  session$setInputs(method='All',dates=as.Date(c('2026-09-01','2026-09-10')))
  stopifnot(identical(filtered()$assessment_id,'DEMO-RNA-01'))
  session$setInputs(assessment_id='DEMO-RNA-02')
  stopifnot(nrow(filtered())==0L,nrow(display_table())==0L,
    grepl('No matching records',paste(as.character(output$metrics),collapse=' '),fixed=TRUE))
  session$setInputs(dates=as.Date(c('2026-09-01','2026-09-30')))
  stopifnot(identical(filtered()$assessment_id,'DEMO-RNA-02'))
  session$setInputs(reset=1)
  stopifnot(identical(unname(updates$assessment_id$value),'All'))
  # testServer records client updates but does not apply them as a browser does.
  session$setInputs(assessment_id='All',area='All',alert_id='All',method='All')
  stopifnot(nrow(filtered())==2L)
})
d$assessments$start_date[2] <- as.Date(NA)
testServer(page_server,args=list(key='rna',d=d),{
  session$setInputs(assessment_id='All',alert_id='All',area='All',method='All',
    dates=as.Date(c('2026-09-01','2026-09-30')),include_undated=TRUE)
  stopifnot(nrow(filtered())==2L)
  session$setInputs(include_undated=FALSE)
  stopifnot(identical(filtered()$assessment_id,'DEMO-RNA-01'))
})
message('PASS: All assessments, round provenance, combined filters, single/multiple rounds and empty states.')
