library(shiny)
source('R/data.R'); source('R/pages.R'); source('R/activity_workbook.R')

d <- read_rrm_data('demo')
d$metadata$mode <- 'operational'
a <- d$activities
context <- data.frame(record_id=a$event_id, alert_id=a$alert_id,
  district=a$area, activity=a$modality, implementing_agency=a$delivery_partner,
  tier=a$tier, start_date=as.character(a$start_date), quantity=as.character(a$quantity),
  community=paste('Community',seq_len(nrow(a))))
enriched <- add_activity_communities(d,context)
stopifnot(identical(enriched$activities[names(a)],a),
          identical(enriched$activities$community,context$community),
          identical(activity_totals(a),activity_totals(enriched$activities)))
# Ambiguous IDs, changed event details and missing source rows cannot supply context.
changed <- context
changed$quantity[2] <- '99999'
changed$record_id[3] <- 'Other event'
changed$community[4] <- NA_character_
changed <- rbind(changed,changed[1,])
guarded <- add_activity_communities(d,changed)
stopifnot(all(is.na(guarded$activities$community[1:4])),
          guarded$activities$community[5]==context$community[5],
          identical(guarded$activities[names(a)],a))
stopifnot(all(is.na(add_activity_communities(read_rrm_data('demo'),context)$activities$community)),
          all(is.na(add_activity_communities(d)$activities$community)))
empty <- d; empty$activities <- a[FALSE,]
stopifnot(nrow(add_activity_communities(empty,context)$activities)==0L)
existing <- enriched
stopifnot(identical(add_activity_communities(existing,changed),existing))
testServer(page_server,args=list(key='activity',d=enriched),{
  session$setInputs(alert_id='All',area='All',tier='All',modality='All',delivery_partner='All')
  stopifnot(identical(display_table()$community,context$community),
            identical(filtered()[names(a)],a))
  widget <- jsonlite::fromJSON(output$table,simplifyVector=FALSE)
  stopifnot(grepl('<th>Community',widget$x$container,fixed=TRUE))
  session$setInputs(area='Absent')
  stopifnot(nrow(display_table())==0L,!is.null(output$table))
})
message('PASS: corroborated community context, ambiguous/mismatched source guards, unchanged records and totals, community table and empty state.')
