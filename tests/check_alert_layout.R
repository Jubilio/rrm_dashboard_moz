library(shiny)
source('R/data.R');source('R/pages.R');source('R/severity.R')
d <- apply_alert_severity(read_rrm_data('demo'))
html <- as.character(page_ui('alerts','alerts',d))
stopifnot(grepl('id="alerts-alert_id"',html,fixed=TRUE),
  lengths(regmatches(html,gregexpr('id="alerts-alert_id"',html,fixed=TRUE)))==1L,
  grepl('Origin to arrival and targeted locations',html,fixed=TRUE),grepl('<details',html,fixed=TRUE))
stopifnot(grepl('Latest alerts',html,fixed=TRUE),
          grepl('id="alerts-latest_alerts"',html,fixed=TRUE))
fixture <- data.frame(alert_id=c('older','undated','newer','same-date'),
                      alert_date=as.Date(c('2026-01-01',NA,'2026-11-01','2026-11-01')))
stopifnot(identical(latest_alert_rows(fixture)$alert_id,
                    c('newer','same-date','older','undated')),
          nrow(latest_alert_rows(fixture[FALSE,]))==0L)
testServer(page_server,args=list(key='alerts',d=d),{
  session$setInputs(alert_id='DEMO-001',community='All',trigger='All',gla='All',movement='All',dates=as.Date(c('2026-09-01','2026-09-30')))
  stopifnot(nrow(filtered())==1L,filtered()$rna_people==4700,filtered()$rna_hh==940)
  stopifnot(identical(latest_alert_rows(filtered())$alert_id,'DEMO-001'),
            !is.null(output$latest_alerts))
  routes <- paste(unlist(output$routes),collapse=' ')
  stopifnot(grepl('route-connections',routes,fixed=TRUE),grepl('Origin A',routes,fixed=TRUE),
    grepl('Arrival B',routes,fixed=TRUE),grepl('Arrival C',routes,fixed=TRUE),
    grepl('2,700',routes,fixed=TRUE),grepl('2,000',routes,fixed=TRUE),!grepl('4,700',routes,fixed=TRUE))
  session$setInputs(community='Arrival C')
  routes <- paste(unlist(output$routes),collapse=' ')
  stopifnot(filtered()$rna_people==4700,grepl('Arrival C',routes,fixed=TRUE),!grepl('Arrival B',routes,fixed=TRUE))
  session$setInputs(community='All',alert_id='DEMO-002')
  stopifnot(is.na(filtered()$rna_people),grepl('Pending',paste(unlist(output$metrics),collapse=' '),fixed=TRUE))
  session$setInputs(alert_id='All',trigger='Flood')
  stopifnot(nrow(filtered())==1L,filtered()$alert_id=='DEMO-003')
  session$setInputs(trigger='All',dates=as.Date(c('2025-01-01','2025-01-30')))
  stopifnot(nrow(filtered())==0L,!is.null(output$routes),!is.null(output$details))
})
# Community filter: route arrival text is split into communities linked to districts.
source('R/geography.R')
stopifnot(identical(route_communities('Ancuabe - Mesa: Nacueja/Nacoja; Minheuene; Nanune'),c('Nacueja/Nacoja','Minheuene','Nanune')),
  identical(route_communities('Nangade - Ntamba IDP site and host community and Muadi IDP site'),c('Ntamba IDP site','Muadi IDP site')),
  identical(route_communities('Namuno & Montepuez - Meloco town / other destinations unresolved: Reported movement toward Meloco town, Montepuez District'),'Meloco town'),
  identical(route_communities('Arrival C'),'Arrival C'),length(route_communities(NA))==0L)
rt <- data.frame(route_id=c('R1','R2'),alert_id=c('A1','A2'),
  arrival=c('Ancuabe - Mesa: Muaja; Nanune','Montepuez - Namanhumbire'))
ct <- route_community_table(rt)
stopifnot(setequal(community_choices(ct,'mz0101'),c('All','Muaja','Nanune')),
  setequal(community_choices(ct),c('All','Muaja','Nanune','Namanhumbire')),
  identical(routes_in_community(rt,ct,'Namanhumbire')$route_id,'R2'))
stopifnot(grepl('id="alerts-community"',html,fixed=TRUE),!grepl('id="alerts-arrival"',html,fixed=TRUE))
# Triggers are harmonised into categories; the source text is kept.
stopifnot(identical(trigger_category(c('Armed attacks / fear','NSAG attack / insecurity','Cholera outbreak',
  'Floods','Cyclone Freddy','Drought',NA)),
  c('Conflict/Violence','Conflict/Violence','Outbreak','Flood','Cyclone','Other',NA)))
hd <- harmonise_alert_triggers(list(alerts=data.frame(trigger=c('Armed attack','Floods'))))
stopifnot(identical(hd$alerts$trigger,c('Conflict/Violence','Flood')),
  identical(hd$alerts$trigger_detail,c('Armed attack','Floods')))
# Alert issued date: week / month / year periods replace the date range.
stopifnot(grepl('id="alerts-date_unit"',html,fixed=TRUE),grepl('id="alerts-date_period"',html,fixed=TRUE),
  !grepl('id="alerts-dates"',html,fixed=TRUE),!grepl('id="alerts-include_undated"',html,fixed=TRUE))
pd <- as.Date(c('2026-09-07','2026-09-13','2026-09-14',NA))
stopifnot(identical(date_period_key(pd,'week'),c('2026-W37','2026-W37','2026-W38',NA)),
  identical(date_period_key(pd,'month'),c('2026-09','2026-09','2026-09',NA)),
  identical(unname(date_period_choices(pd,'week')),c('All','2026-W38','2026-W37')),
  identical(names(date_period_choices(pd,'month'))[2],'Sep 2026'))
testServer(page_server,args=list(key='alerts',d=d),{
  session$setInputs(alert_id='All',community='All',trigger='All',gla='All',movement='All',
                    consortium_response_status='All',district='All',date_unit='All',date_period='All')
  n_all <- nrow(filtered())
  k <- date_period_key(d$alerts$alert_date,'month')[1]
  session$setInputs(date_unit='month',date_period=k)
  stopifnot(nrow(filtered())>0L,nrow(filtered())<=n_all,
    all(format(filtered()$alert_date,'%Y-%m')==k))
})
message('PASS: alert selector, route-specific counts/branches, community filtering with alert-wide caseloads, district-linked communities, pending verification, trigger/date filters, week/month/year periods, harmonised triggers and empty state.')
