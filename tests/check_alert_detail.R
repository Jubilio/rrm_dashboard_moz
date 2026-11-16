library(shiny)
source('R/data.R'); source('R/pages.R'); source('R/severity.R')
source('R/activity_workbook.R')
d <- read_rrm_data('demo')
widget <- latest_alert_table(d$alerts,'alerts-open_alert_detail')
stopifnot(grepl('View details',widget$x$data$Details[1],fixed=TRUE),
          grepl('data-input="alerts-open_alert_detail"',widget$x$data$Details[1],fixed=TRUE),
          grepl(latest_alert_rows(d$alerts)$alert_id[1],widget$x$data$Details[1],fixed=TRUE))
detail <- alert_detail_data('DEMO-001',d)
stopifnot(nrow(detail$core)==1L,detail$core$alert_hh==610,
          all(detail$assessments$alert_id=='DEMO-001'),
          all(detail$needs$assessment_id %in% detail$assessments$assessment_id),
          all(detail$assistance$alert_id=='DEMO-001'))
stopifnot(alert_detail_cell(NA_real_)=='',alert_detail_cell(0)=='0',
          alert_detail_cell(as.Date('2026-09-01'))=='2026-09-01')
empty <- alert_detail_data('does-not-exist',d)
stopifnot(all(vapply(empty,nrow,integer(1))==0L))
html <- as.character(alert_detail_ui('does-not-exist',empty))
stopifnot(!grepl('Not reported|Not available|>NA<',html),
          grepl('<td></td>',html,fixed=TRUE))
safe <- as.character(alert_detail_table(data.frame(value='<script>'),c(value='Value')))
stopifnot(!grepl('<script>',safe,fixed=TRUE),grepl('&lt;script&gt;',safe,fixed=TRUE))

h <- read_history()
activity <- prepare_activity_data(read_activity_snapshot())
for (id in h$registry$alert_id) {
  detail <- alert_detail_data(id,d,h,activity)
  stopifnot(all(detail$evidence$source_alert_id==id),
            all(detail$evidence$linked_alert_id==id),
            !any(grepl('review required|unresolved',detail$evidence$link_status)),
            all(detail$reported_assistance$alert_id==id),
            all(detail$reported_assistance$eligible),
            all(detail$reported_assistance$link_status=='Confirmed'))
  stopifnot(length(as.character(alert_detail_ui(id,detail)))==1L)
}
# A proposed ID match and an unvalidated activity must never leak into a detail.
fake_h <- list(evidence=data.frame(source_alert_id=c('wrong','DEMO-001'),
  linked_alert_id='DEMO-001',link_status=c('review required','ID and metadata consistent')))
fake_activity <- list(activities=data.frame(alert_id='DEMO-001',
  link_status=c('Confirmed','Confirmed','Multiple alerts unresolved'),eligible=c(TRUE,FALSE,TRUE)))
detail <- alert_detail_data('DEMO-001',d,fake_h,fake_activity)
stopifnot(nrow(detail$evidence)==1L,nrow(detail$reported_assistance)==1L)
testServer(page_server,args=list(key='alerts',d=d),{
  session$setInputs(alert_id='All')
  session$setInputs(open_alert_detail='DEMO-001')
  session$setInputs(latest_alerts_rows_selected=1L)
  stopifnot(!is.null(output$latest_alerts))
  session$setInputs(latest_alerts_rows_selected=integer())
})
testServer(history_server,args=list(h=h,d=d,activity=activity),{
  session$setInputs(as_of=as.Date('2026-11-06'),district='All',organisation='All',alert='All')
  session$setInputs(open_alert_detail=h$registry$alert_id[1])
  session$setInputs(latest_alerts_rows_selected=1L)
  stopifnot(!is.null(output$latest_alerts))
})
message('PASS: exact alert links, no unresolved matches or unvalidated assistance, blank missing values, preserved zeros, safe HTML and detail selection in both views.')
