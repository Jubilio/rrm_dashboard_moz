library(shiny)
source('R/data.R');source('R/pages.R');source('R/severity.R');source('R/activity_workbook.R')
d <- read_rrm_data('demo')
values <- alert_summary_values(d$alerts,d$activities)
stopifnot(identical(values,list(total_alerts=3L,tier_1=2L,tier_2=1L,completed=2L)))
a <- d$alerts[d$alerts$alert_id=='DEMO-001',,drop=FALSE]
stopifnot(identical(alert_summary_values(rbind(a,a),d$activities),
                    list(total_alerts=1L,tier_1=1L,tier_2=1L,completed=1L)))
events <- d$activities
events$delivery_status[events$event_id=='A01'] <- 'Ongoing'
stopifnot(alert_summary_values(a,events)$completed==0L,
          alert_summary_values(a,events)$tier_1==1L,
          alert_summary_values(a)$completed==0L)
events$delivery_status[events$event_id=='A01'] <- NA_character_
stopifnot(alert_summary_values(a,events)$completed==0L)
reporting <- data.frame(alert_id=c('DEMO-001','DEMO-001','DEMO-001','DEMO-002'),
  eligible=c(TRUE,FALSE,TRUE,TRUE),link_status='Confirmed',
  metric=c('Households assisted','Households assisted','Households interviewed','Households assisted'),
  unit='households',hh_basis='Unique within record',households=c(10,999,100,30))
stopifnot(alert_summary_values(a,reporting,TRUE)$households==10)
reporting$link_status[1] <- 'Multiple alerts unresolved'
stopifnot(is.na(alert_summary_values(a,reporting,TRUE)$households))
reporting$link_status[1] <- 'Confirmed';reporting$households[1] <- NA_real_
stopifnot(is.na(alert_summary_values(a,reporting,TRUE)$households))
reporting$households[1] <- 0
stopifnot(alert_summary_values(a,reporting,TRUE)$households==0)
empty <- alert_summary_values(a[FALSE,],d$activities)
stopifnot(all(unlist(empty)==0L))
html <- as.character(alert_summary_ui(values))
stopifnot(grepl('Tier 1.*Tier 2.*All recorded activities completed',html),
          grepl('Tier counts can overlap.',html,fixed=TRUE),
          !grepl('Activated alerts|Gross.*reach',html))
page <- as.character(page_ui('alerts','alerts',d))
stopifnot(regexpr('id="alerts-alert_summary"',page,fixed=TRUE) > regexpr('id="alerts-reset"',page,fixed=TRUE),
          regexpr('id="alerts-alert_summary"',page,fixed=TRUE) < regexpr('id="alerts-alert_map"',page,fixed=TRUE))
testServer(page_server,args=list(key='alerts',d=d),{
  session$setInputs(alert_id='All')
  stopifnot(grepl('Total alerts',paste(as.character(output$alert_summary),collapse=' '),fixed=TRUE))
  session$setInputs(alert_id='DEMO-003')
  stopifnot(identical(alert_summary_values(filtered(),d$activities),
                      list(total_alerts=1L,tier_1=1L,tier_2=0L,completed=1L)))
})
h <- read_history(); activity <- prepare_activity_data(read_activity_snapshot())
testServer(history_server,args=list(h=h,d=d,activity=activity),{
  session$setInputs(as_of=as.Date('2026-11-06'),alert='All',district='All',organisation='All')
  stopifnot(alert_summary_values(registry(),activity$activities,TRUE)$total_alerts==18L,
            is.na(alert_summary_values(registry(),activity$activities,TRUE)$households),
            grepl('Gross validated household reach',output$alert_summary$html,fixed=TRUE))
})
message('PASS: filtered tier and completion counts, summary placement, and historical household reach.')
