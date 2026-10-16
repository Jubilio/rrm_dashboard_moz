library(shiny)
source('R/data.R');source('R/pages.R');source('R/activity_workbook.R');source('R/activity_workbook_ui.R')
a<-prepare_activity_data(read_activity_snapshot())$activities
p<-read_settlement_points();m<-match_intervention_locations(a,p)
stopifnot(nrow(p)==1804L,sum(p$admin_conflict)==6L,nrow(m)==83L,
          identical(m$record_id,a$record_id),identical(m$review_status,a$review_status),sum(m$match_status=='Matched')==38L,
          length(unique(na.omit(m$point_id)))==7L,
          sum(m$match_status=='Combined locations - review')==24L,
          sum(m$match_status=='Ambiguous settlement')==4L,
          sum(m$match_status=='Administrative-post mismatch')==6L,
          !any(a$eligible),!any(m$eligible),all(is.na(m$longitude[m$match_status!='Matched'])))
# Controlled fixtures isolate administrative homonyms, duplicate source points and false spelling links.
x<-a[1,,drop=FALSE];one<-p[match(m$point_id[1],p$point_id),,drop=FALSE]
link<-function(activity,points=one)match_intervention_locations(activity,points)
stopifnot(link(x)$match_status=='Matched')
two<-rbind(one,one);two$point_id[2]<-'duplicate';stopifnot(link(x,two)$match_status=='Matched')
two$longitude[2]<-two$longitude[2]+0.1
stopifnot(link(x,two)$match_status=='Ambiguous settlement',is.na(link(x,two)$point_id))
two$district_pcode[2]<-'mz0101';stopifnot(link(x,two)$match_status=='Matched')
x$community<-'Muanon';stopifnot(link(x)$match_status=='Not found',is.na(link(x)$longitude))
x<-a[1,,drop=FALSE];x$province<-'Nampula';stopifnot(link(x)$match_status=='Province/district mismatch')
x<-a[1,,drop=FALSE];x$admin_post<-'Hucula';stopifnot(link(x)$match_status=='Administrative-post mismatch')
x<-a[1,,drop=FALSE];x$admin_post<-'Unresolved spelling';stopifnot(link(x)$match_status=='Matched',link(x)$match_method=='Exact community + district')
x<-a[1,,drop=FALSE];x$location_coverage<-'Combined locations';stopifnot(link(x)$match_status=='Combined locations - review')
x<-a[1,,drop=FALSE];x$community<-'Muanona/Olaminane';stopifnot(link(x)$match_status=='Combined locations - review')
x<-a[1,,drop=FALSE];x$pcode<-'Tier 1';stopifnot(link(x)$match_status=='Matched',grepl('not used',link(x)$match_note))
conflict<-one;conflict$admin_conflict<-TRUE;stopifnot(link(x,conflict)$match_status=='Settlement administrative conflict')
stopifnot(all(match_intervention_locations(a,NULL)$match_status=='Gazetteer unavailable'))
map<-intervention_map_payload(a,m,p)
stopifnot(length(map$markers$features)==7L,
          sum(vapply(map$markers$features,function(f)f$properties$record_count,integer(1)))==38L,
          all(vapply(map$markers$features,function(f)f$properties$validated_records==0L,logical(1))),
          !any(c('quantity','households','people_total') %in% names(map$markers$features[[1]]$properties)))
z<-a[FALSE,];empty<-intervention_map_payload(z,match_intervention_locations(z,p),p)
stopifnot(length(empty$markers$features)==0L)
testServer(activity_workbook_server,args=list(workbook_path=''),{
  session$setInputs(month='All',alert='All',district='All',partner='All',tier='All',sector='All',modality='All',funding='All',show_all=TRUE,map_scope='all')
  stopifnot(sum(location_links()$match_status=='Matched')==38L,
            !is.null(jsonlite::fromJSON(output$location_review,simplifyVector=FALSE)$x),!is.null(output$location_map))
  before<-nrow(records());session$setInputs(map_scope='validated')
  stopifnot(nrow(location_source())==0L,nrow(records())==before,nrow(location_links())==0L,
            !is.null(jsonlite::fromJSON(output$location_review,simplifyVector=FALSE)$x))
  session$setInputs(map_scope='all',district='Namuno')
  stopifnot(sum(location_links()$match_status=='Matched')==14L,nrow(location_links())==18L)
  session$setInputs(community='Muanona');stopifnot(nrow(location_links())==14L)
  session$setInputs(community='All',district='Absent');stopifnot(nrow(location_links())==0L,!is.null(output$location_map))
})
message('PASS: supplied settlement names, administrative disambiguation, fuzzy/combined/conflict exclusions, no quantity allocation, review gates and filtered Shiny map.')
