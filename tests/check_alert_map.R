library(shiny)
source('R/data.R');source('R/pages.R')
d <- read_rrm_data('demo');locations <- read_alert_locations('demo');layers <- read_map_layers()
routes <- d$routes[d$routes$alert_id=='DEMO-001',]
x <- alert_endpoint_links(routes,locations,'demo')
p <- alert_map_payload(routes,locations,'demo',layers)
stopifnot(nrow(x)==4L,all(x$mapped),length(p$markers$features)==3L,length(p$connections$features)==2L,
  p$mapped_endpoints==4L,p$kind=='alert_routes',p$mode=='demo',
  !any(vapply(p$districts$features,function(f)f$properties$assigned,logical(1))))
origin <- Filter(function(f)f$properties$endpoint=='origin',p$markers$features)[[1]]
stopifnot(grepl('R01',origin$properties$details,fixed=TRUE),grepl('R02',origin$properties$details,fixed=TRUE),
  p$connections$features[[1]]$properties$people==2700,p$connections$features[[2]]$properties$people==2000)
missing <- locations[!locations$route_id=='R02'|locations$endpoint!='arrival',]
p <- alert_map_payload(routes,missing,'demo',layers)
stopifnot(p$mapped_endpoints==3L,length(p$connections$features)==1L)
wrong <- locations;wrong$location_name[1] <- 'Different place'
stopifnot(!alert_endpoint_links(routes,wrong,'demo')$mapped[1])
actual <- locations;actual$coordinate_status <- 'Confirmed'
stopifnot(all(alert_endpoint_links(routes,actual,'operational')$mapped))
actual$coordinate_status[1] <- 'Pending'
p <- alert_map_payload(routes,actual,'operational',layers)
stopifnot(p$mapped_endpoints==3L,length(p$connections$features)==1L)
actual$coordinate_source[2] <- NA_character_
stopifnot(!alert_endpoint_links(routes,actual,'operational')$mapped[2])
empty <- read_alert_locations('operational')
stopifnot(!any(alert_endpoint_links(routes,empty,'operational')$mapped),
  length(alert_map_payload(routes[FALSE,],empty,'operational',layers)$markers$features)==0L)
tmp <- tempfile();dir.create(tmp);dir.create(file.path(tmp,'data'));dir.create(file.path(tmp,'data','operational'))
stopifnot(!any(alert_endpoint_links(routes,read_alert_locations('operational',tmp),'operational')$mapped))
write.csv(locations,file.path(tmp,'data','operational','route_locations.csv'),row.names=FALSE,na='')
stopifnot(inherits(try(read_alert_locations('operational',tmp),silent=TRUE),'try-error'))
locations$coordinate_status <- 'Confirmed';locations$coordinate_source <- 'Reviewed test fixture'
locations$longitude[1] <- 181
write.csv(locations,file.path(tmp,'data','operational','route_locations.csv'),row.names=FALSE,na='')
stopifnot(inherits(try(read_alert_locations('operational',tmp),silent=TRUE),'try-error'))
unlink(tmp,recursive=TRUE)
html <- as.character(page_ui('alerts','alerts',d))
stopifnot(grepl('id="alerts-alert_map"',html,fixed=TRUE),grepl('Origin and arrival coordinate review',html,fixed=TRUE))
testServer(page_server,args=list(key='alerts',d=d),{
  session$setInputs(alert_id='DEMO-001',arrival='All',trigger='All',gla='All',movement='All',dates=as.Date(c('2026-09-01','2026-09-30')))
  stopifnot(length(output$alert_map$markers$features)==3L,length(output$alert_map$connections$features)==2L,filtered()$rna_people==4700)
  session$setInputs(arrival='Arrival C')
  stopifnot(length(output$alert_map$markers$features)==2L,length(output$alert_map$connections$features)==1L,filtered()$rna_people==4700)
})
message('PASS: alert endpoint map, shared origins, route-specific counts, confirmed coordinate gate, missing/name/provenance handling, demo isolation, coordinate bounds and arrival filters.')
