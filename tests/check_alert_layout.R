library(shiny)
source('R/data.R');source('R/pages.R');source('R/severity.R')
d <- apply_alert_severity(read_rrm_data('demo'))
html <- as.character(page_ui('alerts','alerts',d))
stopifnot(grepl('id="alerts-alert_id"',html,fixed=TRUE),
  lengths(regmatches(html,gregexpr('id="alerts-alert_id"',html,fixed=TRUE)))==1L,
  grepl('Origin to arrival and targeted locations',html,fixed=TRUE),grepl('<details',html,fixed=TRUE))
testServer(page_server,args=list(key='alerts',d=d),{
  session$setInputs(alert_id='DEMO-001',arrival='All',trigger='All',gla='All',movement='All',dates=as.Date(c('2026-09-01','2026-09-30')))
  stopifnot(nrow(filtered())==1L,filtered()$rna_people==4700,filtered()$rna_hh==940)
  routes <- paste(unlist(output$routes),collapse=' ')
  stopifnot(grepl('route-connections',routes,fixed=TRUE),grepl('Origin A',routes,fixed=TRUE),
    grepl('Arrival B',routes,fixed=TRUE),grepl('Arrival C',routes,fixed=TRUE),
    grepl('2,700',routes,fixed=TRUE),grepl('2,000',routes,fixed=TRUE),!grepl('4,700',routes,fixed=TRUE))
  session$setInputs(arrival='Arrival C')
  routes <- paste(unlist(output$routes),collapse=' ')
  stopifnot(filtered()$rna_people==4700,grepl('Arrival C',routes,fixed=TRUE),!grepl('Arrival B',routes,fixed=TRUE))
  session$setInputs(arrival='All',alert_id='DEMO-002')
  stopifnot(is.na(filtered()$rna_people),grepl('Pending',paste(unlist(output$metrics),collapse=' '),fixed=TRUE))
  session$setInputs(alert_id='All',trigger='Flood')
  stopifnot(nrow(filtered())==1L,filtered()$alert_id=='DEMO-003')
  session$setInputs(trigger='All',dates=as.Date(c('2025-01-01','2025-01-30')))
  stopifnot(nrow(filtered())==0L,!is.null(output$routes),!is.null(output$details))
})
message('PASS: alert selector, route-specific counts/branches, arrival filtering with alert-wide caseloads, pending verification, trigger/date filters and empty state.')
