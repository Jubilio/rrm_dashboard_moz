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
testServer(activity_workbook_server,{
 session$setInputs(demo_examples=FALSE,show_all=TRUE)
 original<-data()$activities
 session$setInputs(demo_examples=TRUE)
 stopifnot(nrow(eligible())==2L,grepl('^DEMONSTRATION',source_label()),
  all(grepl('^DEMO-',displayed_records()$record_id)),
  !is.null(output$households),!is.null(output$people),!is.null(output$demographics),
  !is.null(output$subsets),!is.null(output$timing),!is.null(output$handovers))
 session$setInputs(tier='Tier 2')
 # Timing retains every tier for the selected alert across all reported months.
 stopifnot(nrow(eligible())==1L,eligible()$households==10,nrow(timing_data())==2L)
 session$setInputs(tier='All',demo_examples=FALSE)
 stopifnot(identical(data()$activities,original),!grepl('^DEMONSTRATION',source_label()))
})
message('PASS: fictional examples reconcile, populate results, filter and restore the operational source.')
