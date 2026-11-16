library(shiny)
source('R/data.R');source('R/pages.R');source('R/severity.R');source('R/activity_workbook.R')
d <- read_rrm_data('demo')
values <- alert_summary_values(d$alerts,d$activities)
stopifnot(values$total_alerts==3L,values$households==180,
          is.na(values$activated_alerts),is.na(values$non_activated_alerts))
a <- d$alerts[d$alerts$alert_id=='DEMO-001',,drop=FALSE]
a$consortium_response_status <- 'Yes'
stopifnot(alert_summary_values(rbind(a,a),d$activities)$total_alerts==1L,
          is.na(alert_summary_values(a,d$activities)$activated_alerts))
events <- d$activities
events$quantity[events$event_id=='A01'] <- NA_real_
stopifnot(is.na(alert_summary_values(a,events)$households))
events$quantity[events$event_id %in% c('A01','A04')] <- 0
stopifnot(alert_summary_values(a,events)$households==0)
stopifnot(is.na(alert_summary_values(d$alerts[d$alerts$alert_id=='DEMO-003',],d$activities)$households),
          is.na(alert_summary_values(a)$households))
reporting <- data.frame(alert_id=c('DEMO-001','DEMO-001','DEMO-001','DEMO-002'),
  eligible=c(TRUE,FALSE,TRUE,TRUE),link_status='Confirmed',
  metric=c('Households assisted','Households assisted','Households interviewed','Households assisted'),
  unit='households',hh_basis='Unique within record',households=c(10,999,100,30))
stopifnot(alert_summary_values(a,reporting,TRUE)$households==10)
reporting$link_status[1] <- 'Multiple alerts unresolved'
stopifnot(is.na(alert_summary_values(a,reporting,TRUE)$households))
reporting$link_status[1] <- 'Confirmed';reporting$households[1] <- NA_real_
stopifnot(is.na(alert_summary_values(a,reporting,TRUE)$households))
empty <- alert_summary_values(a[FALSE,],d$activities)
stopifnot(empty$total_alerts==0L,is.na(empty$households))
html <- as.character(alert_summary_ui(values))
stopifnot(grepl('Activated alerts</div>\n',html,fixed=TRUE),
          !grepl('Unavailable|Not reported|>NA<',html),
          grepl('Gross reported household reach',html,fixed=TRUE))
testServer(page_server,args=list(key='alerts',d=d),{
  session$setInputs(alert_id='All')
  stopifnot(grepl('Total alerts',paste(as.character(output$alert_summary),collapse=' '),fixed=TRUE))
  session$setInputs(alert_id='DEMO-003')
  stopifnot(alert_summary_values(filtered(),d$activities)$total_alerts==1L,
            is.na(alert_summary_values(filtered(),d$activities)$households))
})
h <- read_history(); activity <- prepare_activity_data(read_activity_snapshot())
testServer(history_server,args=list(h=h,d=d,activity=activity),{
  session$setInputs(as_of=as.Date('2026-11-06'),alert='All',district='All',organisation='All')
  stopifnot(alert_summary_values(registry(),activity$activities,TRUE)$total_alerts==18L,
            is.na(alert_summary_values(registry(),activity$activities,TRUE)$households),
            !is.null(output$alert_summary))
})
message('PASS: distinct alerts, blank activation, exact links, correct assistance units/status, no assessment reach, no partial totals, explicit zero and filtered summary in both views.')
