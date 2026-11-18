Sys.setlocale('LC_ALL','English_United States.utf8')
source('R/data.R');source('R/pages.R');source('R/activity_workbook.R')
raw<-read_activity_snapshot()
stopifnot(all(prepare_activity_data(raw)$activities$response_status=='Not reported'))
raw$alerts$response_status<-rep(' ongoing ',nrow(raw$alerts))
d<-prepare_activity_data(raw)
stopifnot(all(d$activities$response_status[d$activities$link_status=='Confirmed' & !is.na(d$activities$link_status)]=='Ongoing'))
p<-read_settlement_points();a<-d$activities
links<-match_intervention_locations(a,p)
ix<-which(links$match_status=='Matched')[1]
a<-a[rep(ix,2),,drop=FALSE];a$record_id<-c('test-1','test-2')
links<-match_intervention_locations(a,p)
status<-function(values) {
 a$response_status<-values
 intervention_map_payload(a,links,p)$markers$features[[1]]$properties
}
stopifnot(status(c('Ongoing','Ongoing'))$response_status=='Ongoing',
 status(c('Closed','Closed'))$response_status=='Closed',
 status(c('Ongoing','Closed'))$response_status=='Mixed',
 status(c('Ongoing','Not reported'))$response_status=='Mixed',
 status(c(NA,NA))$response_status=='Not reported',
 status(c('Ongoing','Closed'))$ongoing_records==1L,
 status(c('Ongoing','Closed'))$closed_records==1L)
message('PASS: optional response status, backwards compatibility and co-located status aggregation.')
