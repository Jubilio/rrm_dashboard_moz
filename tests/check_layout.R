library(shiny)
old_mode <- Sys.getenv('RRM_DATA_MODE',unset=NA_character_)
Sys.unsetenv('RRM_DATA_MODE')
e <- new.env(parent=globalenv());sys.source('app.R',envir=e)
if(is.na(old_mode)) Sys.unsetenv('RRM_DATA_MODE') else Sys.setenv(RRM_DATA_MODE=old_mode)
stopifnot(e$DATA_MODE=='demo',e$d$metadata$mode=='demo')
html <- as.character(e$ui)
stopifnot(grepl('value="coverage" checked="checked"',html,fixed=TRUE),
  lengths(regmatches(html,gregexpr('id="coverage-map_province"',html,fixed=TRUE)))==1L)
testServer(e$server,{
  session$setInputs(page='coverage')
  stopifnot(output$page_subtitle=='Geographic coverage | Cabo Delgado, Mozambique',
    output$source_label=='DRAFT LAYOUT - DEMO DATA ONLY',grepl('illustrative',output$source_footer,fixed=TRUE))
  session$setInputs(page='activity')
  stopifnot(grepl('WORKBOOK SOURCE',output$source_label,fixed=TRUE),!grepl('DEMO',output$source_label,fixed=TRUE),
    grepl('Original review statuses',output$source_footer,fixed=TRUE))
})
testServer(e$page_server,args=list(key='coverage',d=e$d),{
  session$setInputs(as_of=as.Date('2026-09-30'),area='All',partner='All',role='All',map_province='All',map_district='All',map_post='All')
  x <- filtered();stopifnot(length(unique(x$partner[x$role=='Primary']))==3L,
    length(unique(x$partner[x$role=='Secondary']))==2L,length(unique(x$area[x$role!='Unknown']))==6L)
  session$setInputs(partner='Partner A')
  stopifnot(nrow(filtered())==3L,all(filtered()$partner=='Partner A'))
  session$setInputs(as_of=as.Date('2025-01-01'))
  stopifnot(nrow(filtered())==0L)
})
message('PASS: default demo layout, coverage-first navigation, single geography input, source labels, reference KPIs and coverage filters.')
