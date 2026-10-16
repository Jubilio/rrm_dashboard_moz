library(shiny)
source('R/data.R'); source('R/pages.R'); d <- read_rrm_data('demo')
for (key in names(page_titles)) {
  local({
    key <- key
    testServer(page_server,args=list(key=key,d=d), {
      session$setInputs(as_of=as.Date('2026-09-30'),dates=as.Date(c('2026-09-01','2026-09-30')),
        assessment_id='DEMO-RNA-01',alert_id=if(key=='coverage') 'All' else 'DEMO-001',
        area='All',partner='All',role='All',arrival='All',trigger='All',gla='All',movement='All',
        method='All',community='All',population='All',decision='All',tier='All',modality='All',delivery_partner='All')
      stopifnot(nrow(filtered())>0,nrow(display_table())>0)
      stopifnot(!is.null(output$metrics),!is.null(output$table))
      if(key=='activity') stopifnot(activity_totals(filtered())$hh==180)
      if(key=='rna') stopifnot(length(unique(filtered()$assessment_id))==1,nrow(display_table())==3)
      if(key=='alerts') {session$setInputs(arrival='Arrival C');stopifnot(nrow(filtered())==1,filtered()$rna_hh==940)}
      if(key=='vulnerability') {
        session$setInputs(alert_id='DEMO-002')
        stopifnot(!grepl('Repeated displacement',paste(as.character(output$details),collapse=' '),fixed=TRUE))
        stopifnot(!'profile_summary' %in% names(display_table()))
      }
      if(key=='coverage') session$setInputs(area='Absent') else session$setInputs(alert_id='Absent')
      stopifnot(nrow(filtered())==0,nrow(display_table())==0)
      stopifnot(grepl('No matching records',paste(as.character(output$metrics),collapse=' '),fixed=TRUE))
    })
  })
}
message('PASS: five Shiny modules, filters, single-round RNA, alert-wide totals, aggregate privacy and empty states.')
