# Standardised RRM reporting workbook adapter. Never uses cached Excel formulas.
activity_fields <- c(record_id='Record ID',alert_id='Alert ID',link_status='Alert Link Status',reporting_month='Reporting Month',start_date='Activity Start',end_date='Activity End',lead_agency='Lead Agency',implementing_agency='Implementing Agency',province='Province',district='District',admin_post='Administrative Post',community='Community',pcode='Admin 4 Pcode',location_coverage='Location Coverage',tier='Tier',sector='Sector',activity='Activity',modality='Modality',metric='Primary Output Metric',quantity='Primary Output Quantity',households='Households Reached',hh_basis='Household Count Basis',people_scope='People Reach Scope',people_basis='People Count Basis',age_sex_status='Age Sex Breakdown Status',female_0_4='Female 0-59m',female_5_17='Female 5-17 y',female_18_49='Female 18-49 y',female_50_plus='Female 50+ y',male_0_4='Male 0-59m',male_5_17='Male 5-17 y',male_18_49='Male 18-49 y',male_50_plus='Male 50+ y',reported_people='Reported People Total',pwd_f_children='PWD Female Children',pwd_m_children='PWD Male Children',pwd_f_adults='PWD Female Adults',pwd_m_adults='PWD Male Adults',idp_female='IDP Female',idp_male='IDP Male',host_female='Host Female',host_male='Host Male',returnee_female='Returnee Female',returnee_male='Returnee Male',population_status='Population Status Breakdown',funding='Funding Scope',delay_reason='Delay Reason',previous_agency='Previous Implementing Agency',handover_date='Handover Date',handover_reason='Handover Reason',evidence_source='Evidence Source',evidence_use='How Evidence Informed Response',review_status='Review Status')
extra_fields <- c(record_id='Record ID',metric='Additional Output Metric',quantity='Quantity')
alert_fields <- c(alert_id='Alert ID',alert_date='Alert Shared Date',lead_agency='Lead Agency',arrival_district='Arrival District')
metric_fields <- c(metric='Output Metric',unit='Unit',definition='Counting Definition')
activity_trim <- function(x) {x<-trimws(as.character(x));x[is.na(x)|!nzchar(x)]<-NA_character_;x}
activity_select <- function(x,mapping,sheet) {
 missing<-setdiff(unname(mapping),names(x));if(length(missing)) stop(sheet,': missing columns: ',paste(missing,collapse=', '))
 x<-as.data.frame(x[,unname(mapping),drop=FALSE],stringsAsFactors=FALSE);names(x)<-names(mapping)
 for(n in names(x)) x[[n]]<-activity_trim(x[[n]])
 x$source_row<-seq_len(nrow(x))+1L
 x
}
activity_date <- function(x) {
 x<-activity_trim(x);out<-rep(as.Date(NA),length(x))
 for(i in seq_along(x)) {
  v<-x[i];if(is.na(v)) next
  if(grepl('^[0-9]+(\\.0+)?$',v)&&as.numeric(v)>10000) out[i]<-as.Date(as.numeric(v),origin='1899-12-30')
  else if(grepl('^\\d{4}-\\d{2}$',v)) out[i]<-as.Date(paste0(v,'-01'))
  else if(grepl('^\\d{4}-\\d{2}-\\d{2}( 00:00:00)?$',v)) out[i]<-suppressWarnings(as.Date(substr(v,1,10),format='%Y-%m-%d'))
  else if(grepl('^\\d{2}-\\d{2}-\\d{4}$',v)) out[i]<-suppressWarnings(as.Date(v,format='%d-%m-%Y'))
 }
 out
}
workbook_table_range <- function(path,name) {
 entries<-utils::unzip(path,list=TRUE)$Name
 entries<-entries[grepl('^xl/tables/[^/]+\\.xml$',entries)]
 matches<-character(0)
 for(entry in entries) {
  con<-unz(path,entry,open='rb');text<-rawToChar(readBin(con,what='raw',n=10000000L));close(con)
  if(grepl(paste0('name="',name,'"'),text,fixed=TRUE)) {
   m<-regmatches(text,regexpr(' ref="[^"]+"',text))
   if(length(m)&&nzchar(m)) matches<-c(matches,sub('^ ref="([^"]+)"$','\\1',m))
  }
 }
 if(length(matches)!=1) stop('Expected one Excel table named ',name,'.')
 matches
}
read_activity_workbook <- function(path) {
 if(!requireNamespace('readxl',quietly=TRUE)) stop('Install readxl using install_packages.R to import Excel workbooks.')
 sheet<-function(label,table) {
  range<-workbook_table_range(path,table)
  as.data.frame(readxl::read_excel(path,sheet=label,range=range,col_types='text',.name_repair='minimal',progress=FALSE),stringsAsFactors=FALSE)
 }
 raw<-list(activities=activity_select(sheet('Activity Entry','RRMInterventions'),activity_fields,'Activity Entry'),
  extra=activity_select(sheet('Extra Outputs','RRMExtraOutputs'),extra_fields,'Extra Outputs'),
  alerts=activity_select(sheet('Alerts','RRMAlerts'),alert_fields,'Alerts'),
  metrics=activity_select(sheet('Lists','ReferenceLists'),metric_fields,'Lists'))
 raw$activities<-raw$activities[!is.na(raw$activities$record_id),,drop=FALSE]
 raw$extra<-raw$extra[!is.na(raw$extra$record_id),,drop=FALSE]
 raw$alerts<-raw$alerts[!is.na(raw$alerts$alert_id),,drop=FALSE]
 raw$metrics<-raw$metrics[!is.na(raw$metrics$metric),,drop=FALSE]
 raw$metadata<-data.frame(source='Standardised reporting workbook',source_updated=format(file.info(path)$mtime,tz='UTC',usetz=TRUE),stringsAsFactors=FALSE)
 raw
}
read_activity_snapshot <- function(directory='data/activity_snapshot') {
 names<-c('activities','extra','alerts','metrics','metadata')
 setNames(lapply(names,function(n) {
  p<-file.path(directory,paste0(n,'.csv'));if(!file.exists(p)) stop('Missing activity snapshot ',n)
  read.csv(p,colClasses='character',na.strings='',check.names=FALSE,fileEncoding='UTF-8')
 }),names)
}
prepare_activity_data <- function(raw) {
 a<-raw$activities;e<-raw$extra;l<-raw$alerts;m<-raw$metrics
 for(n in names(a))a[[n]]<-activity_trim(a[[n]])
 for(n in names(e))e[[n]]<-activity_trim(e[[n]])
 if(anyDuplicated(m$metric)||anyNA(m$unit)) stop('Output metric dictionary must have unique metrics and known units.')
 required<-names(activity_fields)
 if(!all(required %in% names(a))||!all(names(extra_fields) %in% names(e))||!all(names(alert_fields) %in% names(l))) stop('Activity snapshot schema does not match the adapter.')
 # Snapshots also follow an exact allowlist; extra columns can never be published by UI/export.
 a<-a[,c(required,'source_row'),drop=FALSE];e<-e[,c(names(extra_fields),'source_row'),drop=FALSE];l<-l[,c(names(alert_fields),'source_row'),drop=FALSE];m<-m[,c(names(metric_fields),'source_row'),drop=FALSE]
 a<-a[!is.na(a$record_id),,drop=FALSE];e<-e[!is.na(e$record_id),,drop=FALSE]
 issues<-list()
 add<-function(id,row,issue,blocking=TRUE,sheet='Activity Entry') {
  issues[[length(issues)+1L]]<<-data.frame(record_id=id,source_sheet=sheet,source_row=as.integer(row),blocking=blocking,issue=issue,stringsAsFactors=FALSE)
 }
 numeric_value<-function(v,integer=TRUE) {
  n<-suppressWarnings(as.numeric(v))
  n[is.na(n)|!is.finite(n)|n<0|(integer&n!=floor(n))]<-NA_real_;n
 }
 a$unit<-m$unit[match(a$metric,m$metric)]
 a$review_status_original<-a$review_status
 a$review_status[is.na(a$review_status)]<-'Pending review'
 for(n in c('reporting_month','start_date','end_date','handover_date')) a[[n]]<-activity_date(a[[n]])
 l$alert_date<-activity_date(l$alert_date)
 a$alert_date<-l$alert_date[match(a$alert_id,l$alert_id)]
 a$days_from_alert<-as.integer(a$start_date-a$alert_date)
 duplicate_ids<-unique(a$record_id[duplicated(a$record_id)|duplicated(a$record_id,fromLast=TRUE)])
 duplicate_alerts<-unique(l$alert_id[duplicated(l$alert_id)|duplicated(l$alert_id,fromLast=TRUE)])
 counts<-c('households','reported_people','female_0_4','female_5_17','female_18_49','female_50_plus','male_0_4','male_5_17','male_18_49','male_50_plus','pwd_f_children','pwd_m_children','pwd_f_adults','pwd_m_adults','idp_female','idp_male','host_female','host_male','returnee_female','returnee_male')
 for(n in c('quantity',counts)) {
  original<-a[[n]]
  a[[n]]<-numeric_value(original,integer=if(n=='quantity') FALSE else TRUE)
  bad<-which(!is.na(original)&is.na(a[[n]]))
  for(i in bad)add(a$record_id[i],a$source_row[i],paste(n,'must be a non-negative',if(n=='quantity') 'number' else 'integer'))
 }
 age<-c('female_0_4','female_5_17','female_18_49','female_50_plus','male_0_4','male_5_17','male_18_49','male_50_plus')
 status<-c('idp_female','idp_male','host_female','host_male','returnee_female','returnee_male')
 complete_sum<-function(columns,status_column) {
  values<-as.matrix(a[,columns,drop=FALSE]);total<-rowSums(values,na.rm=FALSE)
  total[is.na(a[[status_column]])|a[[status_column]]!='Complete']<-NA_real_;total
 }
 a$age_people<-complete_sum(age,'age_sex_status');a$status_people<-complete_sum(status,'population_status')
 a$female_total<-complete_sum(age[1:4],'age_sex_status');a$male_total<-complete_sum(age[5:8],'age_sex_status')
 a$children_total<-complete_sum(age[c(1,2,5,6)],'age_sex_status');a$adults_total<-complete_sum(age[c(3,4,7,8)],'age_sex_status')
 # Reported total and demographic total are alternatives, never additive.
 a$people_total<-ifelse(!is.na(a$reported_people),a$reported_people,a$age_people)
 for(i in seq_len(nrow(a))) {
  z<-a[i,,drop=FALSE]; flag<-function(message,blocking=TRUE)add(z$record_id,z$source_row,message,blocking)
  missing<-function(n) is.na(z[[n]])||!nzchar(as.character(z[[n]]))
  if(z$record_id %in% duplicate_ids)flag('Duplicate Record ID; all copies excluded')
  if(missing('alert_id')||!z$alert_id %in% l$alert_id||z$alert_id %in% duplicate_alerts)flag('Alert ID missing, unknown or duplicated in Alerts')
  if(missing('link_status')||z$link_status!='Confirmed')flag('Alert link is not confirmed')
  if(missing('review_status')||!z$review_status %in% c('Pending review','Needs correction','Validated','Superseded'))flag('Unrecognised review status')
  if(missing('start_date')||missing('end_date'))flag('Confirm activity start/end dates')
  else if(z$end_date<z$start_date)flag('Activity end precedes start')
  if(missing('reporting_month')||format(z$reporting_month,'%d')!='01')flag('Reporting Month must be the first day of a valid month')
  else if(!missing('start_date')&&!missing('end_date')&&(format(z$start_date,'%Y-%m')!=format(z$reporting_month,'%Y-%m')||format(z$end_date,'%Y-%m')!=format(z$reporting_month,'%Y-%m')))flag('Activity period crosses reporting month; split incremental periods')
  for(n in c('implementing_agency','tier','activity','modality','sector','district'))if(missing(n))flag(paste('Missing',n))
  if(!missing('tier')&&!z$tier %in% c('Tier 1','Tier 2','Not applicable'))flag('Unrecognised tier')
  choices<-list(hh_basis=c('Unique within record','Estimated','Unknown','Not applicable'),people_basis=c('Unique within record','Repeat contacts','Estimated','Unknown'),people_scope=c('Members of assisted households','Direct service users','Participants','Service contacts','Estimated catchment','Assessment respondents','Staff or coordination participants','Unconfirmed'),age_sex_status=c('Complete','Partial','Not available','Not applicable'),population_status=c('Complete','Partial','Not available','Not applicable'),funding=c('ECHO','CDCS','Mixed funding - unsplit','Other','Unconfirmed'))
  for(n in names(choices))if(!missing(n)&&!z[[n]] %in% choices[[n]])flag(paste('Unrecognised',n))
  if(!missing('people_scope')&&z$people_scope=='Estimated catchment'&&(missing('people_basis')||z$people_basis!='Estimated'))flag('Estimated catchment must retain Estimated counting basis')

  if(missing('metric')||missing('unit'))flag('Primary metric missing or absent from Lists')
  if(missing('quantity'))flag('Primary output quantity missing; never infer from people or households')
  else if(!missing('unit')&&!z$unit %in% c('MZN','litres')&&z$quantity!=floor(z$quantity))flag('Output count must be a whole number')
  if(!is.na(z$days_from_alert)&&z$days_from_alert<0)flag('Activity starts before alert shared date')
  if(!missing('age_sex_status')&&z$age_sex_status=='Complete'&&is.na(z$age_people))flag('Age/sex breakdown marked Complete but eight valid counts not supplied')
  if(!missing('population_status')&&z$population_status=='Complete'&&is.na(z$status_people))flag('Population breakdown marked Complete but six valid counts not supplied')
  if(!is.na(z$reported_people)&&!is.na(z$age_people)&&z$reported_people!=z$age_people)flag('Reported people differ from age/sex total')
  if(!is.na(z$age_people)&&!is.na(z$status_people)&&z$age_people!=z$status_people)flag('Population-status total differs from age/sex total')
  if(!is.na(z$reported_people)&&!is.na(z$status_people)&&z$reported_people!=z$status_people)flag('Population-status total differs from reported people')
  pf<-sum(unlist(z[c('pwd_f_children','pwd_f_adults')]),na.rm=TRUE);pm<-sum(unlist(z[c('pwd_m_children','pwd_m_adults')]),na.rm=TRUE)
  if(!is.na(z$people_total)&&pf+pm>z$people_total)flag('Known PWD subset exceeds reported people')
  if(!is.na(z$people_total)&&sum(unlist(z[status]),na.rm=TRUE)>z$people_total)flag('Known population-status subset exceeds reported people')
  if((!is.na(z$female_total)&&pf>z$female_total)||(!is.na(z$male_total)&&pm>z$male_total))flag('PWD subset exceeds sex total')
  if(!is.na(z$people_total)&&(missing('people_basis')||z$people_basis=='Unknown'||missing('people_scope')||z$people_scope=='Unconfirmed'))flag('Confirm people counting basis and reach scope')
  if(!is.na(z$households)&&(missing('hh_basis')||z$hh_basis=='Unknown'))flag('Confirm household counting basis')
  if(missing('funding')||z$funding=='Unconfirmed')flag('Confirm funding scope')
  if(!missing('funding')&&z$funding=='Mixed funding - unsplit')flag('Mixed funding retained as one unsplit scope; never copied to each funder',FALSE)
  if(!missing('location_coverage')&&z$location_coverage=='Combined locations')flag('Combined locations retained; no geographic allocation inferred',FALSE)
  if(!missing('previous_agency')&&is.na(z$handover_date))flag('Previous agency recorded but handover date is missing',FALSE)
 }
 issue_frame<-function() if(length(issues)) do.call(rbind,issues) else data.frame(record_id=character(),source_sheet=character(),source_row=integer(),blocking=logical(),issue=character())
 q<-issue_frame();blocked<-unique(q$record_id[q$blocking])
 a$eligible<-a$review_status=='Validated'&!is.na(a$link_status)&a$link_status=='Confirmed'&!a$record_id %in% blocked
 a$review_required<-a$review_status!='Superseded'&(a$review_status!='Validated'|a$record_id %in% blocked)
 a$eligibility_note<-ifelse(a$eligible,'Validated, confirmed and reconciled',ifelse(a$review_status=='Superseded','Superseded — excluded',ifelse(a$review_status!='Validated','Awaiting partner review','Validation requires correction')))
 # Extra outputs inherit authoritative parent fields. No one-to-many join multiplies reach.
 parent_index<-match(e$record_id,a$record_id)
 e$unit<-m$unit[match(e$metric,m$metric)]
 original<-e$quantity;e$quantity<-numeric_value(e$quantity,FALSE)
 e$eligible<-rep(FALSE,nrow(e))
 duplicate_extra<-duplicated(e[c('record_id','metric')])|duplicated(e[c('record_id','metric')],fromLast=TRUE)
 for(i in seq_len(nrow(e))) {
  ix<-parent_index[i];bad<-FALSE
  flag<-function(message){add(e$record_id[i],e$source_row[i],message,TRUE,'Extra Outputs');bad<<-TRUE}
  if(is.na(ix)||e$record_id[i] %in% duplicate_ids)flag('Extra output has no unique parent record')
  if(is.na(e$metric[i])||is.na(e$unit[i]))flag('Extra output metric missing or absent from Lists')
  if(is.na(e$quantity[i]))flag('Extra output quantity missing or invalid')
  else if(!is.na(e$unit[i])&&!e$unit[i] %in% c('MZN','litres')&&e$quantity[i]!=floor(e$quantity[i]))flag('Extra output count must be a whole number')
  if(duplicate_extra[i])flag('Duplicate additional metric for parent; resolve before summing')
  if(!is.na(ix)&&!is.na(e$metric[i])&&!is.na(a$metric[ix])&&e$metric[i]==a$metric[ix])flag('Additional metric repeats primary metric; excluded to prevent double counting')
  e$eligible[i]<-!bad&&!is.na(ix)&&isTRUE(a$eligible[ix])
 }
 inherit<-c('alert_id','tier','reporting_month','start_date','end_date','district','community','implementing_agency','lead_agency','sector','activity','modality','funding')
 for(n in inherit)e[[n]]<-a[[n]][parent_index]
 a$source_sheet<-rep('Activity Entry',nrow(a));e$source_sheet<-rep('Extra Outputs',nrow(e))
 output_columns<-c('record_id','alert_id','tier','reporting_month','start_date','end_date','district','community','implementing_agency','lead_agency','sector','activity','modality','funding','metric','quantity','unit','eligible','source_sheet','source_row')
 outputs<-rbind(a[,output_columns,drop=FALSE],e[,output_columns,drop=FALSE])
 list(activities=a,extra=e,outputs=outputs,alerts=l,metrics=m,issues=issue_frame(),metadata=raw$metadata)
}
activity_group_sum <- function(x,groups,value) {
 if(!nrow(x)) {out<-as.data.frame(setNames(rep(list(character()),length(groups)),groups));out[[value]]<-numeric();return(out)}
 x<-x[,c(groups,value),drop=FALSE];for(n in groups)x[[n]][is.na(x[[n]])]<-'Not reported'
 ids<-vapply(seq_len(nrow(x)),function(i) paste(vapply(groups,function(n) paste0(nchar(x[[n]][i]),':',x[[n]][i]),character(1)),collapse='|'),character(1))
 rows<-lapply(split(seq_len(nrow(x)),ids),function(ix){r<-x[ix[1],groups,drop=FALSE];v<-x[[value]][ix];r[[value]]<-if(all(is.na(v))) NA_real_ else sum(v,na.rm=TRUE);r$n_records<-length(ix);r$n_known<-sum(!is.na(v));r})
 do.call(rbind,rows)
}
