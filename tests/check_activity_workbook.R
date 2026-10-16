source('R/data.R');source('R/pages.R');source('R/activity_workbook.R');source('R/activity_workbook_ui.R')
raw<-read_activity_snapshot();d<-prepare_activity_data(raw)
stopifnot(nrow(d$activities)==83,nrow(d$extra)==4,sum(d$activities$link_status=='Confirmed')==77,sum(d$activities$eligible)==0,sum(d$activities$review_required)==83)
stopifnot(!any(c('Reporting Contact','Reporting Contact','MoV Reference','Comments','Review Notes') %in% names(raw$activities)))
# Use one fully reconciled source record as an isolated synthetic test fixture.
base<-raw;base$activities<-base$activities[1,,drop=FALSE];base$activities$review_status<-'Validated';base$extra<-base$extra[0,,drop=FALSE]
fixture<-function(edits=list(),extras=NULL,duplicate=FALSE) {
 b<-base;for(n in names(edits))b$activities[[n]]<-as.character(edits[[n]])
 if(!is.null(extras))b$extra<-extras
 if(duplicate)b$activities<-rbind(b$activities,b$activities)
 prepare_activity_data(b)
}
superseded<-fixture(list(review_status='Superseded'));stopifnot(!superseded$activities$eligible,!superseded$activities$review_required)
z<-fixture();stopifnot(z$activities$eligible,z$activities$quantity==5,z$activities$unit=='interviews',z$activities$people_total==12,is.na(z$activities$households),z$activities$days_from_alert==4)
extra<-data.frame(record_id=rep(base$activities$record_id,2),metric=c('Households interviewed','Observations completed'),quantity=c('7','2'),source_row=c('2','3'),stringsAsFactors=FALSE)
z<-fixture(extras=extra);stopifnot(nrow(z$outputs)==3,all(z$outputs$eligible),nrow(z$activities)==1,z$activities$people_total==12)
z<-fixture(extras=transform(extra[1,,drop=FALSE],metric='KIIs completed'));stopifnot(!z$extra$eligible,sum(z$outputs$quantity[z$outputs$eligible])==5)
z<-fixture(extras=rbind(extra[1,],extra[1,]));stopifnot(!any(z$extra$eligible),z$activities$eligible)
z<-fixture(duplicate=TRUE);stopifnot(!any(z$activities$eligible))
z<-fixture(extras=transform(extra[1,,drop=FALSE],record_id='Unknown parent'));stopifnot(!z$extra$eligible,z$activities$eligible)
for(edits in list(list(quantity='-1'),list(quantity='2.5'),list(quantity=NA,households='50',hh_basis='Unique within record'),list(alert_id='Unknown'),list(link_status='Multiple alerts unresolved'),list(start_date='2026-05-01'),list(end_date='2026-05-01'),list(reporting_month='2026-06-01'),list(female_0_4=NA),list(idp_female='1'),list(pwd_f_children='50'),list(funding='Unconfirmed'),list(people_basis='Unrecognised'),list(people_scope='Estimated catchment',people_basis='Unique within record')))
 stopifnot(!fixture(edits)$activities$eligible)
z<-fixture(list(quantity='0'));stopifnot(z$activities$eligible,activity_group_sum(z$outputs,c('metric','unit'),'quantity')$quantity==0)
z<-fixture(list(metric='Cash value disbursed',quantity='1.25'));stopifnot(z$activities$eligible,z$outputs$unit=='MZN',z$outputs$quantity==1.25)
z<-fixture(list(funding='Mixed funding - unsplit'));stopifnot(z$activities$eligible,nrow(activity_group_sum(z$outputs,c('funding','metric','unit'),'quantity'))==1,any(!z$issues$blocking))
z<-fixture(list(age_sex_status='Not available',female_0_4=NA));stopifnot(z$activities$eligible,is.na(z$activities$age_people),z$activities$people_total==12)
stopifnot(identical(as.character(activity_date(c('46112','30-08-2026','2026-08','bad')))[2:4],c('2026-08-30','2026-08-01',NA_character_)))
# Empty capacity rows and empty extra-output tables must remain safe.
b<-base;b$activities<-b$activities[0,,drop=FALSE];z<-prepare_activity_data(b);stopifnot(nrow(z$activities)==0,nrow(z$outputs)==0)
# Workbook read must match the sanitised snapshot when a source path is supplied.
path<-Sys.getenv('RRM_TEST_WORKBOOK','')
if(nzchar(path)) {
 b<-read_activity_workbook(path);z<-prepare_activity_data(b)
 stopifnot(nrow(z$activities)==83,nrow(z$extra)==4,sum(z$activities$eligible)==0)
 stopifnot(!any(grepl('Auto',names(b$activities))),!any(grepl('Contact|Reference',names(b$activities))))
}
# Exercise real Shiny refresh, exports and last-good-data behaviour.
library(shiny)
tmp<-tempfile('activity_snapshot_');dir.create(tmp)
for(n in names(base))write.csv(base[[n]],file.path(tmp,paste0(n,'.csv')),row.names=FALSE,na='')
testServer(activity_workbook_server,args=list(workbook_path='',snapshot_dir=tmp),{
 session$setInputs(month='All',alert='All',district='All',partner='All',tier='All',sector='All',modality='All',funding='All',show_all=TRUE,refresh=0)
 stopifnot(nrow(data()$activities)==1,nrow(eligible())==1,nrow(displayed_records())==1,!is.null(output$metrics),!is.null(output$outputs),!is.null(output$people),!is.null(output$demographics),!is.null(output$subsets),!is.null(output$handovers),!is.null(output$timing))
 old<-loaded_at()
 b<-base$activities;b$quantity<-'0';write.csv(b,file.path(tmp,'activities.csv'),row.names=FALSE,na='')
 session$setInputs(refresh=1);stopifnot(eligible()$quantity==0,is.null(last_error()))
 unlink(file.path(tmp,'metrics.csv'));session$setInputs(refresh=2)
 stopifnot(!is.null(last_error()),eligible()$quantity==0)
 session$setInputs(partner='Absent');stopifnot(nrow(records())==0,!is.null(output$metrics),!is.null(output$outputs),!is.null(output$subsets),!is.null(output$timing))
 if(nzchar(path)) {
  session$setInputs(partner='All',upload=data.frame(name='report.xlsx',size=file.info(path)$size,type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',datapath=path))
  stopifnot(nrow(data()$activities)==83,is.null(last_error()),source_label()=='Session upload')
  broken<-tempfile(fileext='.xlsx');writeLines('invalid workbook',broken)
  session$setInputs(upload=data.frame(name='invalid.xlsx',size=file.info(broken)$size,type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',datapath=broken))
  stopifnot(nrow(data()$activities)==83,!is.null(last_error()))
  unlink(broken)
 }

})
unlink(tmp,recursive=TRUE)
message('PASS: supplied workbook, validation gate, formula-independent units/dates/reconciliation, extra-output joins, zero/missing quantities, mixed funding, empty tables, refresh and last-good-data retention.')
