library(shiny)
source('R/data.R'); source('R/pages.R'); source('R/activity_workbook.R')
source('R/activity_workbook_ui.R'); source('R/light_rna.R')
d <- read_rrm_data('demo')
round <- d$assessments[1,,drop=FALSE]
round$assessment_id <- 'DEMO-RNA-03'
round$start_date <- as.Date('2026-09-30')
round$end_date <- as.Date('2026-10-02')
round$coverage_note <- 'Sites: Arrival B; Arrival C. Posto: Demo post.'
d$assessments <- rbind(d$assessments,round)
d$assessments$start_date[d$assessments$alert_id=='DEMO-003'] <- as.Date(NA)
markup <- as.character(light_rna_ui('rna',d))
stopifnot(!grepl('include_undated|Data pending|Method type|kii_sample',markup))
testServer(light_rna_server,args=list(d=d,open_alert=function() NULL,response_available=function() character()),{
  html <- function(value) if (is.null(value)) '' else value$html
  stopifnot(!nzchar(html(output$rounds)),!nzchar(html(output$findings)))
  session$setInputs(gla=d$alerts$gla[1],community='Arrival C',period_unit='month',period='2026-10')
  stopifnot(identical(filtered()$assessment_id,'DEMO-RNA-03'),is.null(selected_round()))
  session$setInputs(select_round='DEMO-RNA-03')
  stopifnot(grepl('30 Sep – 2 Oct 2026',html(output$findings),fixed=TRUE))
  session$setInputs(gla='All',community='All',period='All',alert='DEMO-001')
  stopifnot(identical(selected_round(),'DEMO-RNA-03'),nrow(filtered())==2L)
  session$setInputs(alert='DEMO-003')
  stopifnot(is.null(selected_round()),grepl('Date unavailable',html(output$rounds),fixed=TRUE))
  session$setInputs(select_round='DEMO-RNA-02')
  stopifnot(!grepl('Latest assessment for this alert',html(output$findings),fixed=TRUE))
  session$setInputs(alert='DEMO-002')
  stopifnot(grepl('No Light RNA assessment recorded',html(output$rounds),fixed=TRUE))
  session$setInputs(reset=1,alert='')
  stopifnot(!nzchar(html(output$rounds)),!nzchar(html(output$findings)))
})

raw <- read_activity_snapshot()
fixture <- raw$activities[1,,drop=FALSE]
fixture$record_id <- 'MULTI-001'
fixture$activity <- 'Voucher Distribution'
fixture$community <- 'Alpha; Beta'
fixture$location_coverage <- 'Combined locations'
fixture$metric <- 'Households assisted'
fixture$quantity <- '18'
fixture$delivery_status <- 'Completed'
fixture$review_status <- 'Pending review'
raw$activities <- fixture
raw$extra <- raw$extra[FALSE,,drop=FALSE]
directory <- tempfile()
dir.create(directory)
for (name in names(raw)) write.csv(raw[[name]],file.path(directory,paste0(name,'.csv')),row.names=FALSE,na='')
testServer(activity_workbook_server,args=list(snapshot_dir=directory),{
  session$setInputs(community='Alpha',scope='delivery',response_view='list')
  stopifnot(nrow(response_records())==1L,sum(response_records()$quantity)==18,
            grepl('Alpha; Beta',output$responses$html,fixed=TRUE),
            grepl('Completed',output$responses$html,fixed=TRUE),
            grepl('Pending review',output$responses$html,fixed=TRUE),
            grepl('No validated totals available',output$response_totals$html,fixed=TRUE))
  session$setInputs(response_view='map',community='Beta')
  stopifnot(identical(response_records()$record_id,'MULTI-001'))
  session$setInputs(community='Other')
  stopifnot(grepl('No activities match these filters.',output$response_empty$html,fixed=TRUE))
  session$setInputs(alert='missing-alert')
  stopifnot(grepl('No response activities recorded for this alert.',output$response_empty$html,fixed=TRUE))
})
unlink(directory,recursive=TRUE)
message('PASS: Light RNA round discovery, period overlap, undated rounds and reported response record scope.')
