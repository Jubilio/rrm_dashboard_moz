library(shiny)
source('R/data.R');source('R/pages.R');source('R/input_workbook.R')
path <- 'data/examples/RRM_Dashboard_Input_Example.xlsx'
d <- read_dashboard_workbook(path)
csv <- read_rrm_data('demo')
for(key in names(csv))stopifnot(isTRUE(all.equal(d[[key]],csv[[key]],check.attributes=FALSE)))
stopifnot(d$metadata$mode=='demo',!is.null(attr(d,'input_workbook')),
  inherits(d$coverage$effective_from,'Date'),as.character(d$coverage$effective_from[1])=='2026-01-01')
p <- alert_map_payload(d$routes[d$routes$alert_id=='DEMO-001',],d$route_locations,'demo')
stopifnot(length(p$markers$features)==3L,length(p$connections$features)==2L)
stopifnot(inherits(try(read_dashboard_workbook(path,mode='operational'),silent=TRUE),'try-error'),
  inherits(try(read_dashboard_workbook('missing-file.xlsx'),silent=TRUE),'try-error'))
# The real reporting workbook is not accepted as consolidated input.
if(file.exists('../upload/MOZ_RRM_Activity_Reporting_Standardised_.xlsx'))stopifnot(inherits(try(read_dashboard_workbook('../upload/MOZ_RRM_Activity_Reporting_Standardised_.xlsx'),silent=TRUE),'try-error'))
old <- Sys.getenv('RRM_INPUT_WORKBOOK',unset=NA_character_)
Sys.setenv(RRM_INPUT_WORKBOOK=normalizePath(path,winslash='/'))
e <- new.env(parent=globalenv());sys.source('app.R',envir=e)
stopifnot(e$DATA_MODE=='demo',nrow(e$d$activities)==5L,!is.null(attr(e$d,'input_workbook')))
Sys.setenv(RRM_INPUT_WORKBOOK='missing-file.xlsx')
stopifnot(inherits(try(load_dashboard_input('missing-file.xlsx'),silent=TRUE),'try-error'))
if(is.na(old)) Sys.unsetenv('RRM_INPUT_WORKBOOK') else Sys.setenv(RRM_INPUT_WORKBOOK=old)
for(key in c('coverage','alerts','rna','vulnerability','activity'))local({
 selected_key<-key
 testServer(page_server,args=list(key=selected_key,d=d),{
  session$setInputs(as_of=as.Date('2026-09-30'),dates=as.Date(c('2026-09-01','2026-09-30')),assessment_id='DEMO-RNA-01',
   alert_id=if(selected_key=='coverage') 'All' else 'DEMO-001',area='All',community='All',population='All',decision='All',
   arrival='All',trigger='All',gla='All',movement='All',partner='All',role='All',tier='All',modality='All',delivery_partner='All')
  stopifnot(nrow(filtered())>0L,!is.null(output$table),!is.null(output$metrics))
  if(selected_key=='alerts')stopifnot(length(output$alert_map$markers$features)==3L)
  if(selected_key=='activity')stopifnot(activity_totals(filtered())$hh==180)
 })
})
message('PASS: consolidated XLSX equals CSV fixtures, Excel dates, five pages, alert coordinates, mode isolation, wrong/missing source rejection and app startup.')
