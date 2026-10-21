library(shiny)
source('R/data.R');source('R/pages.R');source('R/input_workbook.R')
fixture <- function() {
  keys <- c('coverage','alerts','routes','assessments','needs','screening','activities','transfers','metadata')
  setNames(lapply(keys,function(key) read.csv(paste0('data/demo/',key,'.csv'),colClasses='character',na.strings='',check.names=FALSE)),keys)
}
raw <- fixture()
raw$alerts$alert_date[1] <- NA_character_
raw$alerts$rna_evidence_date[1] <- NA_character_
raw$assessments$observation_sample[] <- NA_character_
raw$assessments$start_date[] <- NA_character_
raw$needs$rank[] <- NA_character_
raw$needs$hesper_serious[] <- NA_character_
raw$needs$hesper_valid[] <- '\u00a0'
raw$activities$quantity[] <- NA_character_
raw$activities$start_date[] <- NA_character_
raw$activities$delivery_status[1] <- NA_character_
raw$activities$tier[2] <- NA_character_
raw$screening$population[1] <- NA_character_
raw$screening$reviewed[1] <- NA_character_
raw$coverage$effective_from[1] <- NA_character_
raw$metadata$source_updated[1] <- NA_character_
d <- validate_rrm_tables(raw,'demo',allow_severity_inputs=FALSE,allow_incomplete=TRUE)
stopifnot(is.na(d$alerts$alert_date[1]),all(is.na(d$needs$rank)),all(is.na(d$needs$hesper_valid)),
          all(is.na(d$activities$days_from_alert)),nrow(attr(d,'validation_issues'))>0L,
          is.na(activity_totals(d$activities)$hh),is.na(activity_totals(d$activities)$days))
stopifnot(inherits(try(validate_rrm_tables(raw,'demo'),silent=TRUE),'try-error'))
unknown <- d$activities;unknown$delivery_status[] <- NA_character_
stopifnot(is.na(activity_totals(unknown)$hh))
# Integrity errors remain blocking even when incomplete cells are accepted.
bad <- function(change) inherits(try(validate_rrm_tables(change(fixture()),'demo',allow_incomplete=TRUE),silent=TRUE),'try-error')
stopifnot(bad(function(x) {x$activities$quantity[1]<-'-1';x}),
          bad(function(x) {x$alerts$alert_date[1]<-'not a date';x}),
          bad(function(x) {x$alerts$alert_id[1]<-NA;x}),
          bad(function(x) {x$alerts$alert_id[2]<-x$alerts$alert_id[1];x}),
          bad(function(x) {x$activities$alert_id[1]<-'missing';x}),
          bad(function(x) {x$needs$rank[2]<-x$needs$rank[1];x}),
          bad(function(x) {x$needs$hesper_serious[1]<-'999';x}),
          bad(function(x) {x$activities$delivery_status[1]<-'unrecognised';x}))
for(key in names(page_titles)) local({
  key<-key
  stopifnot(!is.null(page_ui(key,key,d)))
  testServer(page_server,args=list(key=key,d=d),{
    session$setInputs(as_of=as.Date('2026-09-30'),dates=as.Date(c('2026-09-01','2026-09-30')),
      assessment_id='DEMO-RNA-01',alert_id='All',area='All',partner='All',role='All',arrival='All',
      trigger='All',gla='All',movement='All',method='All',community='All',population='All',
      decision='All',tier='All',modality='All',delivery_partner='All',include_undated=TRUE)
    stopifnot(nrow(filtered())>0L,!is.null(output$metrics),!is.null(output$table))
    if(key!='coverage') stopifnot(!is.null(output$details))
    if(key=='coverage') stopifnot(!'C01' %in% filtered()$assignment_id)
    if(key=='rna') stopifnot(all(display_table()$Rank=='Not ranked'),all(display_table()[['HESPER households']]=='Unavailable'))
    if(key=='alerts') stopifnot(grepl('345',paste(as.character(output$metrics),collapse=' '),fixed=TRUE),!grepl('4,700',paste(as.character(output$metrics),collapse=' '),fixed=TRUE))
    if(key %in% c('rna','activity')) {
      session$setInputs(include_undated=FALSE)
      stopifnot(nrow(filtered())==0L)
    }
  })
})
uploaded <- 'data/RRM_Dashboard_Input_RNA_populated.xlsx'
if(file.exists(uploaded)) {
  actual <- read_dashboard_workbook(uploaded)
  stopifnot(nrow(actual$alerts)>0L,nrow(actual$assessments)>0L,nrow(attr(actual,'validation_issues'))>0L)
  for(key in names(page_titles)) local({
    key<-key
    stopifnot(!is.null(page_ui(key,key,actual)))
    testServer(page_server,args=list(key=key,d=actual),{
      session$setInputs(as_of=as.Date('2026-10-21'),dates=as.Date(c('2026-01-01','2026-12-31')),
        assessment_id=actual$assessments$assessment_id[1],alert_id='All',area='All',partner='All',role='All',
        arrival='All',trigger='All',gla='All',movement='All',method='All',community='All',population='All',
        decision='All',tier='All',modality='All',delivery_partner='All',include_undated=TRUE)
      stopifnot(!is.null(output$table),!is.null(output$metrics))
      if(key!='coverage') stopifnot(!is.null(output$details))
    })
  })
  old <- Sys.getenv('RRM_INPUT_WORKBOOK',unset=NA_character_)
  old_mode <- Sys.getenv('RRM_DATA_MODE',unset=NA_character_)
  Sys.setenv(RRM_INPUT_WORKBOOK=normalizePath(uploaded,winslash='/'))
  Sys.unsetenv('RRM_DATA_MODE')
  e <- new.env(parent=globalenv());sys.source('app.R',envir=e)
  stopifnot(nrow(e$d$alerts)==nrow(actual$alerts),inherits(e$ui,'shiny.tag.list'))
  if(is.na(old)) Sys.unsetenv('RRM_INPUT_WORKBOOK') else Sys.setenv(RRM_INPUT_WORKBOOK=old)
  if(is.na(old_mode)) Sys.unsetenv('RRM_DATA_MODE') else Sys.setenv(RRM_DATA_MODE=old_mode)
}
message('PASS: missing cells, unranked needs, unknown counts, undated filters, five page modules and integrity checks.')
