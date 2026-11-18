library(shiny)
source('R/data.R');source('R/pages.R');source('R/activity_workbook.R');source('R/activity_workbook_ui.R')
measure <- 'Direct service users / Unique within record'
a <- data.frame(record_id=letters[1:6],district=c('Balama','Balama','Nangade','Balama','Balama','Unknown'),
  province='Cabo Delgado',eligible=c(TRUE,TRUE,TRUE,FALSE,TRUE,TRUE),
  people_total=c(100,300,0,999,900,1000),
  people_scope=c(rep('Direct service users',4),'Participants','Direct service users'),
  people_basis='Unique within record')
values <- function(p) setNames(vapply(p$reach$features,function(f) f$properties$people,numeric(1)),
  vapply(p$reach$features,function(f) f$properties$district,character(1)))
p <- district_reach_payload(a,measure)
stopifnot(values(p)[['Balama']]==400,values(p)[['Nangade']]==0,p$reach_unresolved==1L)
a$people_total[2]<-NA_real_
p<-district_reach_payload(a,measure)
stopifnot(!'Balama' %in% names(values(p)),p$reach_missing==1L)
a$people_total[2]<-300;a$province[1]<-'Nampula'
stopifnot(values(district_reach_payload(a,measure))[['Balama']]==300)
a$people_scope<-'Estimated catchment';a$people_basis<-'Estimated'
stopifnot(length(district_reach_payload(a,'Estimated catchment / Estimated')$reach$features)==0L)
stopifnot(length(district_reach_payload(a[0,],measure)$reach$features)==0L)
# Configured live workbook: verify actual district totals and reactive filters.
path<-Sys.getenv('RRM_DISTRICT_REACH_WORKBOOK','')
if(nzchar(path)) testServer(activity_workbook_server,args=list(workbook_path=path),{
 session$setInputs(map_view='reach',reach_measure=measure,month='All',alert='All',district='All',
  community='All',partner='All',tier='All',sector='All',modality='All',funding='All')
 totals<-values(reach_map())
 stopifnot(totals[['Balama']]==502,totals[['Nangade']]==21,!is.null(output$location_map))
 session$setInputs(district='Balama');stopifnot(length(values(reach_map()))==1L)
 session$setInputs(district='All',reach_measure='Participants / Unique within record')
 stopifnot(values(reach_map())[['Montepuez']]==176)
 session$setInputs(partner='Absent');stopifnot(length(reach_map()$reach$features)==0L,
  grepl('No validated reach',paste(as.character(output$location_status),collapse=' '),fixed=TRUE))
})
message('PASS: district gross reach, scope separation, review gate, missing versus zero, administrative conflicts and filters.')
