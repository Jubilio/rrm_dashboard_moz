source('R/activity_workbook.R')
d<-prepare_activity_data(read_activity_snapshot('data/activity_demo'))
a<-d$activities
stopifnot(nrow(a)==2L,all(a$eligible),!any(d$issues$blocking),
 identical(as.numeric(a$people_total),c(100,50)),all(a$age_people==a$status_people),
 all(a$days_from_alert==c(4,11)),a$previous_agency[2]==a$implementing_agency[1],
 a$handover_date[2]>=a$end_date[1],a$handover_date[2]<=a$start_date[2],
 all(!is.na(a$evidence_source)),all(!is.na(a$evidence_use)))
invisible(parse('R/activity_workbook_ui.R'))
message('PASS: demo counts, dates, handover and evidence reconcile; UI syntax is valid.')
source('R/data.R');source('R/pages.R');source('R/activity_workbook_ui.R')
library(shiny)
stopifnot(!grepl('demo_examples',as.character(activity_workbook_ui('test')),fixed=TRUE))
testServer(activity_workbook_server,{
 session$setInputs(demo_examples=FALSE,show_all=TRUE)
 original<-data()$activities
 session$setInputs(demo_examples=TRUE)
 stopifnot(identical(data()$activities,original),source_label()=='Supplied workbook snapshot',
  !is.null(output$households),!is.null(output$people),!is.null(output$demographics),
  !is.null(output$subsets),!is.null(output$timing),!is.null(output$handovers))
 session$setInputs(demo_examples=FALSE)
 stopifnot(identical(data()$activities,original),!grepl('^DEMONSTRATION',source_label()))
})
message('PASS: fictional example control removed; legacy input cannot replace the reporting source.')
