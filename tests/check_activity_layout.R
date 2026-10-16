library(shiny)
source('R/data.R');source('R/pages.R')
d <- read_rrm_data('demo')
html <- as.character(page_ui('activity','activity',d))
stopifnot(grepl('id="activity-area"',html,fixed=TRUE),grepl('Delay and response timing',html,fixed=TRUE),
  grepl('Transfer of response responsibilities',html,fixed=TRUE))
testServer(page_server,args=list(key='activity',d=d),{
  session$setInputs(alert_id='DEMO-001',area='All',tier='All',modality='All',delivery_partner='All',dates=as.Date(c('2026-09-01','2026-09-30')))
  t <- activity_totals(filtered())
  stopifnot(nrow(filtered())==4L,t$hh==180,t$kits==120,t$consultations==86,t$days==4,
    output$table_title=='Interventions linked to DEMO-001')
  table <- jsonlite::fromJSON(output$table,simplifyVector=FALSE)
  stopifnot(grepl('<th>Scope',table$x$container,fixed=TRUE),grepl('<th>Partner',table$x$container,fixed=TRUE),
    'measure_type' %in% names(display_table()),'donor' %in% names(display_table()))
  stopifnot(grepl('Shelter follow-up',paste(unlist(output$transfer_summary),collapse=' '),fixed=TRUE),
    grepl('Partner-reported access constraints',paste(unlist(output$details),collapse=' '),fixed=TRUE))
  session$setInputs(tier='Tier 2')
  stopifnot(nrow(filtered())==1L,activity_totals(filtered())$hh==60,activity_totals(filtered())$days==18)
  # Transfers remain alert/geography scoped, independently of the selected intervention dates.
  session$setInputs(tier='All',dates=as.Date(c('2026-09-05','2026-09-05')))
  stopifnot(nrow(filtered())==2L,grepl('20 Sep 2026',paste(unlist(output$transfer_summary),collapse=' '),fixed=TRUE))
  session$setInputs(delivery_partner='Partner B',dates=as.Date(c('2026-09-01','2026-09-30')))
  stopifnot(nrow(filtered())==1L,activity_totals(filtered())$consultations==86)
  session$setInputs(area='Unknown')
  stopifnot(nrow(filtered())==0L,!is.null(jsonlite::fromJSON(output$table,simplifyVector=FALSE)$x),
    grepl('No responsibility transfers',paste(unlist(output$transfer_summary),collapse=' '),fixed=TRUE))
})
message('PASS: activity overview layout, distinct metric units, friendly table with full audit exports, filters, timing, independent transfers and empty widgets.')
