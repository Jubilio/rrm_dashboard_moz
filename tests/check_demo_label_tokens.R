source('R/data.R');source('R/alert_locations.R')
keys <- c('coverage','alerts','routes','assessments','needs','screening','activities','transfers','metadata')
raw <- setNames(lapply(keys,function(key) {
  x <- read.csv(paste0('data/demo/',key,'.csv'),colClasses='character',na.strings='',check.names=FALSE)
  for(col in names(x)) x[[col]] <- gsub('DEMO','REAL',x[[col]],ignore.case=TRUE)
  x
}),keys)
raw$metadata$mode <- 'operational'
raw$alerts$rationale[1] <- 'RNA demonstrates serious needs. Severe deprivation was demonstrated.'
d <- validate_rrm_tables(raw,'operational',allow_severity_inputs=FALSE)
stopifnot(identical(d$alerts$rationale[1],raw$alerts$rationale[1]))
for(label in c('DEMO','demo','DEMO-v1','DEMO-001','DEMO_RNA_01','Source: Demo data')) {
  bad <- raw;bad$metadata$source_version <- label
  stopifnot(inherits(try(validate_rrm_tables(bad,'operational'),silent=TRUE),'try-error'))
}
loc <- data.frame(route_id='R1',endpoint='origin',location_name='Democratic village',
  longitude='40',latitude='-12',coordinate_source='Field observation demonstrates location',coordinate_status='Confirmed')
stopifnot(nrow(validate_alert_locations(loc,'operational'))==1L)
loc$coordinate_source <- 'DEMO-v1'
stopifnot(inherits(try(validate_alert_locations(loc,'operational'),silent=TRUE),'try-error'))
message('PASS: ordinary words remain intact; explicit demo labels and tokens are rejected in operational data and coordinates.')
