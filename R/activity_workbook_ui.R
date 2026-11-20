# Excel export used by the Activity reporting buttons. Always delivers a .xlsx file:
# if building the table fails, the file holds the error and the user sees a notification,
# instead of the browser saving Shiny's error page under the button id with no extension.
rrm_xlsx_download <- function(stem, data, sheet='Records') shiny::downloadHandler(
  filename=function() paste0(stem,'_',format(Sys.Date()),'.xlsx'),
  contentType='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  content=function(file) {
    x <- tryCatch(as.data.frame(data()), error=function(e) {
      shiny::showNotification(paste('Export failed:',conditionMessage(e)),type='error',duration=NULL)
      data.frame(export_error=conditionMessage(e))
    })
    x[] <- lapply(x, function(col) if (is.list(col))
      vapply(col, function(v) paste(stats::na.omit(unlist(v)), collapse='; '), character(1)) else col)
    writexl::write_xlsx(stats::setNames(list(x), sheet), file)
  })

source('R/table_labels.R', local=TRUE)
source('R/response_reporting.R', local=TRUE)
# Process-wide caches so each new browser session does not re-read and re-parse
# the activity sources (several seconds that delayed every page's first render).
activity_parse_cache <- new.env()
activity_source_stamp <- function(file, source, snapshot_dir, refresh = NULL) {
  paths <- if (nzchar(file)) file else
    file.path(snapshot_dir, paste0(c('activities', 'extra', 'alerts', 'metrics', 'metadata'), '.csv'))
  info <- file.info(paths)
  paste(source, paste(info$size, as.numeric(info$mtime), collapse = '|'), refresh, collapse = '|')
}
# Called once at app start: parse the configured activity source before the first visitor.
warm_activity_cache <- function(workbook_path = '', snapshot_dir = 'data/activity_snapshot') {
  source <- if (nzchar(workbook_path)) 'Configured workbook' else 'Supplied workbook snapshot'
  stamp <- activity_source_stamp(workbook_path, source, snapshot_dir)
  if (exists(stamp, envir = activity_parse_cache, inherits = FALSE)) return(invisible())
  if (nzchar(workbook_path) && !file.exists(workbook_path)) return(invisible())
  raw <- if (nzchar(workbook_path)) read_activity_workbook(workbook_path) else read_activity_snapshot(snapshot_dir)
  assign(stamp, prepare_activity_data(raw), envir = activity_parse_cache)
  invisible()
}
cached_settlement_points <- local({
  value <- NULL
  function() {
    if (is.null(value)) value <<- read_settlement_points()
    value
  }
})
activity_workbook_server <- function(id,workbook_path='',snapshot_dir='data/activity_snapshot',
                                     core=NULL,open_alert=function() NULL) shiny::moduleServer(id,function(input,output,session) {
 settlement_error<-NULL
 settlements<-tryCatch(cached_settlement_points(),error=function(e){settlement_error<<-conditionMessage(e);NULL})
 location_layers<-read_map_layers()
 current<-shiny::reactiveVal(NULL);last_error<-shiny::reactiveVal(NULL);source_label<-shiny::reactiveVal('Not loaded');loaded_at<-shiny::reactiveVal(NULL)
 use_upload<-shiny::reactiveVal(TRUE)
 signature<-shiny::reactiveVal(NULL)
 shiny::observeEvent(input$upload,{use_upload(TRUE)},ignoreInit=TRUE)
 shiny::observeEvent(input$clear_upload,{use_upload(FALSE);signature(NULL)})
 shiny::observe({
  shiny::invalidateLater(10000,session);input$refresh
  file<-if(isTRUE(use_upload())&&!is.null(input$upload)) input$upload$datapath else workbook_path
  uploaded<-isTRUE(use_upload())&&!is.null(input$upload)
  source<-if(nzchar(file)) if(uploaded) 'Session upload' else 'Configured workbook' else 'Supplied workbook snapshot'
  stamp<-activity_source_stamp(file,source,snapshot_dir,input$refresh)
  if(identical(shiny::isolate(signature()),stamp)) return()
  signature(stamp)
  tryCatch({
   if(nzchar(file)&&!file.exists(file)) stop('Configured workbook is unavailable. Correct its location or load another workbook.')
   # Parsed sources are shared across sessions until the file changes; uploads are always re-read.
   parsed<-if(!uploaded&&exists(stamp,envir=activity_parse_cache,inherits=FALSE)) get(stamp,envir=activity_parse_cache) else {
    raw<-if(nzchar(file)) read_activity_workbook(file) else read_activity_snapshot(snapshot_dir)
    p<-prepare_activity_data(raw)
    if(!uploaded) assign(stamp,p,envir=activity_parse_cache)
    p
   }
   current(parsed);last_error(NULL);source_label(source);loaded_at(format(Sys.time(),'%Y-%m-%d %H:%M:%S %Z'))
  },error=function(e){last_error(conditionMessage(e))})
 })
 data<-shiny::reactive({shiny::req(current(),cancelOutput=TRUE);current()})
 reported <- shiny::reactive({
  a <- data()$activities
  response_status_records(a, if (!is.null(core) && core$metadata$mode != 'demo') core$activities else NULL)
 })
 filter_fields<-c(month='reporting_month',alert='alert_id',district='district',community='community',partner='implementing_agency',tier='tier',sector='sector',modality='modality',funding='funding')
 response_fields <- c(alert='alert_id',district='district',community='community',period='start_date',
   partner='implementing_agency',tier='tier',sector='sector',modality='modality',delivery_status='delivery_status')
 alert_choices <- shiny::reactive({
   ids <- sort(unique(c(reported()$alert_id,core$alerts$alert_id)))
   c('All alerts'='All',setNames(ids,ids))
 })
 shiny::observeEvent(current(),{
  a<-reported()
  for(id in setdiff(c(names(response_fields),'month'),'community')) {
   if (id=='alert') {
    selected <- shiny::isolate(input$alert)
    choices <- alert_choices()
    shiny::updateSelectizeInput(session,id,choices=choices,server=TRUE,
      selected=if (length(selected) && selected %in% choices) selected else 'All')
    next
   }
   values<-a[[if(id=='month') 'reporting_month' else response_fields[[id]]]]
   values<-if(id %in% c('month','period')) format(values,'%Y-%m') else as.character(values)
   reported_values <- sort(unique(values[!is.na(values)]))
   labels <- if (id %in% c('month','period') && length(reported_values))
     format(as.Date(paste0(reported_values,'-01')),'%b %Y') else reported_values
   all_label <- switch(id,district='All districts',period='All dates',month='All reporting months','All')
   choices<-c(setNames('All',all_label),setNames(reported_values,labels))
   selected<-shiny::isolate(input[[id]])
   if(is.null(selected)||!selected %in% choices)selected<-'All'
   shiny::updateSelectInput(session,id,choices=choices,selected=selected)
  }
 },ignoreNULL=TRUE)
 shiny::observe({
  a <- reported()
  if (length(input$district) && input$district!='All') a <- a[a$district %in% input$district,,drop=FALSE]
  values <- sort(unique(unlist(lapply(a$community,response_communities))))
  choices <- c('All communities'='All',setNames(values,values))
  selected <- shiny::isolate(input$community)
  shiny::updateSelectInput(session,'community',choices=choices,
    selected=if (length(selected) && selected %in% choices) selected else 'All')
 })
 reset_response <- function() for(id in setdiff(names(response_fields),'alert'))
  shiny::updateSelectInput(session,id,selected='All')
 shiny::observeEvent(input$reset,{
  reset_response()
  shiny::updateSelectizeInput(session,'alert',selected='All')
 })
 shiny::observeEvent(open_alert(),{
  id <- open_alert()
  shiny::req(is.character(id),length(id)==1L,id %in% alert_choices(),id!='All')
  reset_response()
  shiny::updateSelectizeInput(session,'alert',choices=alert_choices(),selected=id,server=TRUE)
  shiny::updateTabsetPanel(session,'workspace',selected='response')
  shiny::updateRadioButtons(session,'response_view',selected='list')
  shiny::updateRadioButtons(session,'scope',selected='delivery')
 })
 unique_reported <- shiny::reactive({
  a <- reported()
  a[!duplicated(a$record_id) & !duplicated(a$record_id,fromLast=TRUE),,drop=FALSE]
 })
 response_records <- shiny::reactive({
  x <- unique_reported()
  if (!identical(input$scope,'all')) x <- response_delivery_records(x)
  for (id in names(response_fields)) {
   value <- input[[id]]
   if (!length(value) || value == 'All') next
   column <- x[[response_fields[[id]]]]
   matches <- if (id=='community')
     vapply(column,function(place) value %in% response_communities(place),logical(1))
   else if (id=='period') format(column,'%Y-%m') %in% value
   else column %in% value
   x <- x[matches,,drop=FALSE]
  }
  x[order(-as.numeric(x$start_date),x$record_id,na.last=TRUE),,drop=FALSE]
 })
 apply_filters<-function(x,exclude_month=FALSE) {
  for(id in names(filter_fields)) {
   if(exclude_month&&id=='month')next
   v<-input[[id]];col<-filter_fields[[id]]
   if(is.null(v)||v=='All')next
   values<-if(id=='month') format(x[[col]],'%Y-%m') else as.character(x[[col]])
   x<-x[!is.na(values)&values==v,,drop=FALSE]
  }
  x
 }
 records<-shiny::reactive(apply_filters(data()$activities))
 delay_records<-shiny::reactive({
  a<-records()
  a<-a[,c('record_id','alert_id','implementing_agency','activity','start_date','end_date',
           'days_from_alert','delay_reason','review_status','link_status'),drop=FALSE]
  a$delay_reason[is.na(a$delay_reason)]<-''
  a
 })
 eligible<-shiny::reactive({x<-records();x[x$eligible,,drop=FALSE]})
 outputs<-shiny::reactive({x<-apply_filters(data()$outputs);x[x$eligible,,drop=FALSE]})
 result_table<-function(x) {
  titles<-c(record_id='Record ID',alert_id='Alert ID',tier='Tier',funding='Funding scope',metric='Output metric',quantity='Quantity',unit='Unit',n_records='Records',n_known='Records with a reported quantity',households='Households reported',hh_basis='Household counting basis',people_scope='People reach scope',people_basis='People counting basis',people_total='Reported people',age_sex_group='Age / sex group',subset='Population subset',age_people='Complete age/sex total',status_people='Complete population-status total',eligible='Included in validated results',eligibility_note='Review outcome',previous_agency='Previous implementing agency',first_validated_start='First validated start',days_from_alert='Days from alert shared date',source_row='Source row')
  names(x)<-vapply(names(x),function(n) if(n %in% names(titles)) titles[[n]] else tools::toTitleCase(gsub('_',' ',n,fixed=TRUE)),character(1))
  rrm_datatable(width='100%',x,rownames=FALSE,escape=TRUE,options=list(scrollX=TRUE,pageLength=8,language=list(emptyTable='No records available for this selection.')))
 }
 output$source_status<-shiny::renderUI({d<-current();shiny::div(shiny::h3(source_label()),
  shiny::p(class='rrm-footnote',paste('Last successful refresh \u00b7',if(is.null(loaded_at())) 'Not loaded' else loaded_at(),
    if(!is.null(d) && !is.na(d$metadata$source_updated[1])) paste('\u00b7 Source updated',d$metadata$source_updated[1]) else '')))})
 output$load_error<-shiny::renderUI({e<-last_error();if(is.null(e))return(NULL)
  shiny::div(class='empty',shiny::h4('Source refresh failed'),shiny::p(e),shiny::p(if(is.null(current())) 'No dataset is available.' else 'The last successfully loaded dataset remains visible; its refresh timestamp is unchanged.'))})
 location_source<-shiny::reactive(response_records())
 location_links<-shiny::reactive(match_intervention_locations(location_source(),settlements))
 shiny::observeEvent(current(),{
  a<-data()$activities
  a<-a[which(a$people_scope %in% c('Direct service users','Participants','Members of assisted households') & a$people_basis=='Unique within record'),,drop=FALSE]
  values<-sort(unique(paste(a$people_scope[!is.na(a$people_scope)&!is.na(a$people_basis)],a$people_basis[!is.na(a$people_scope)&!is.na(a$people_basis)],sep=' / ')))
  selected<-shiny::isolate(input$reach_measure)
  preferred<-'Direct service users / Unique within record'
  if(is.null(selected)||!selected %in% values) selected<-if(preferred %in% values) preferred else if(length(values)) values[1] else character()
  shiny::updateSelectInput(session,'reach_measure',choices=values,selected=selected)
 },ignoreNULL=TRUE)
 reach_map<-shiny::reactive(district_reach_payload(records(),
   if(is.null(input$reach_measure)) 'Direct service users / Unique within record' else input$reach_measure,location_layers))
 output$location_map<-render_rrm_map({
  if(identical(input$map_view,'reach')) reach_map() else
    intervention_map_payload(location_source(),location_links(),settlements,location_layers)
 })
 output$location_status<-shiny::renderUI({
  if(identical(input$map_view,'reach')) {
   p<-reach_map()
   return(shiny::tagList(
    shiny::p(if(length(p$reach$features)) paste(length(p$reach$features),'district(s) with validated gross reach.') else 'No validated reach is available for this selection.'),
    if(p$reach_unresolved>0L) shiny::p(class='muted',paste(p$reach_unresolved,'record(s) excluded: district unresolved.')),
    if(p$reach_missing>0L) shiny::p(class='muted',paste(p$reach_missing,'district(s) have incomplete reach totals.'))))
  }
  a<-location_links();mapped<-sum(a$match_status=='Matched');places<-length(unique(a$point_id[!is.na(a$point_id)]))
  shiny::tagList(
    if(!is.null(settlement_error))shiny::p(class='map-notice',paste('Settlement source unavailable:',settlement_error)),
    shiny::div(class='rrm-map-status',
      shiny::p(paste(mapped,'of',nrow(a),'records mapped to',places,if(places==1)'location.' else 'locations.')),
      shiny::p(class='rrm-footnote',if(identical(input$map_scope,'validated'))'Scope: validated records' else 'Scope: all reported records, including pending review')))
 })
 output$location_review<-DT::renderDT(result_table(review_links()))
 output$linked_alert <- shiny::renderUI({
  id <- input$alert
  if (!length(id) || id == 'All') return(NULL)
  date <- core$alerts$alert_date[match(id,core$alerts$alert_id)]
  if (!length(date) || is.na(date)) date <- data()$alerts$alert_date[match(id,data()$alerts$alert_id)]
  shiny::div(class='panel rrm-linked-alert rrm-activity-alert',
    shiny::div(shiny::strong(paste(c('Linked alert',if(length(date) && !is.na(date)) rrm_day(date)),collapse=' \u00b7 ')),
      shiny::p(id)),
    if (id %in% core$alerts$alert_id) shiny::div(class='rrm-section-actions',
      shiny::tagAppendAttributes(alert_navigation_button('open_alert_record',id,'View alert details'),class='rrm-btn-outline'),
      shiny::tagAppendAttributes(alert_navigation_button('open_light_rna',id,'View Light RNA'),class='rrm-btn-outline')))
 })
 response_available <- shiny::reactive({
  if (is.null(current())) return(NULL)
  unique(response_delivery_records(unique_reported())$alert_id)
 })
 output$responses <- shiny::renderUI({
  a <- response_records()
  if (nrow(a)) response_list(a,session$ns('response-'))
 })
 output$scope_line <- shiny::renderUI({
  all <- identical(input$scope,'all')
  n <- nrow(response_records())
  shiny::div(class='rrm-scope-line',
   shiny::p(class='rrm-footnote',paste(if(all)'All reported activities' else 'Delivery activities','\u00b7',n,if(n==1)'record' else 'records')),
   shiny::actionLink(session$ns('scope_toggle'),
     shiny::tagList(if(all)'Delivery activities only' else 'All activities',shiny::span(class='rrm-arrow',`aria-hidden`='true','\u2192'))))
 })
 shiny::observeEvent(input$scope_toggle,
  shiny::updateRadioButtons(session,'scope',selected=if(identical(input$scope,'all'))'delivery' else 'all'))
 output$response_empty <- shiny::renderUI({
  if (nrow(response_records())) return(NULL)
  alert <- input$alert
  has_records <- if (identical(input$scope,'all')) unique_reported()$alert_id else response_available()
  shiny::div(class='panel',shiny::p(if (length(alert) && alert!='All' && !alert %in% has_records)
    'No response activities recorded for this alert.' else 'No activities match these filters.'))
 })
 output$response_export <- rrm_xlsx_download('rrm_filtered_activities', function()
   response_records()[c('record_id','alert_id','district','admin_post','community','location_coverage',
     'activity','tier','implementing_agency','start_date','metric','quantity','unit','delivery_status',
     'review_status','funding','delay_reason','link_status','delivery_status_source','source_sheet','source_row')], 'Activities')
 output$response_totals <- shiny::renderUI({
  a <- response_records()
  x <- data()$outputs
  x <- x[x$eligible & x$record_id %in% a$record_id & !is.na(x$quantity),,drop=FALSE]
  if (!nrow(x)) return(shiny::p(class='rrm-footnote','No validated totals available.'))
  totals <- aggregate(quantity~metric+unit,x,sum)
  shiny::tags$ul(class='rrm-validated-totals',lapply(seq_len(nrow(totals)),function(i) {
   row <- totals[i,]
   shiny::tags$li(paste0(row$metric,': ',fmt(row$quantity),' ',row$unit,
     if (row$unit=='households' && row$metric=='Households assisted') ' (gross; may include repeat households)' else ''))
  }))
 })
 output$first_delivery <- shiny::renderUI({
  id <- input$alert
  if (!length(id) || id=='All') return(NULL)
  issue <- core$alerts$alert_date[match(id,core$alerts$alert_id)]
  if (!length(issue) || is.na(issue)) return(NULL)
  a <- response_delivery_records(response_records())
  dates <- a$start_date[a$eligible & a$delivery_status %in% c('Completed','Ongoing') & !is.na(a$start_date)]
  dates <- dates[dates>=issue]
  if (length(dates)) shiny::p(paste('First confirmed delivery:',as.integer(min(dates)-issue),'calendar days from alert issue.'))
 })
 output$response_timeline <- DT::renderDT(result_table(
  response_records()[,c('record_id','activity','start_date','end_date','delivery_status','review_status','delay_reason'),drop=FALSE]))
 review_records <- shiny::reactive({
  a <- reported()
  if (length(input$month) && input$month!='All') a <- a[format(a$reporting_month,'%Y-%m') %in% input$month,,drop=FALSE]
  a
 })
 review_links <- shiny::reactive(match_intervention_locations(review_records(),settlements))
 output$review_queue <- shiny::renderUI(response_review_table(
  review_records(),review_links(),which(review_records()$review_required),session$ns('pending-')))
 output$geographic_queue <- shiny::renderUI(response_review_table(
  review_records(),review_links(),seq_len(nrow(review_records())),session$ns('geo-')))
 output$location_export<-rrm_xlsx_download('rrm_community_matching',review_links,'Geographic matching')
 output$metrics<-shiny::renderUI({
  x<-review_records()
  card<-function(label,value,title=NULL) shiny::div(class='rrm-kpi',title=title,shiny::p(class='rrm-kpi-label',label),shiny::p(class='rrm-kpi-value',fmt(value)))
  shiny::div(class='rrm-kpi-row',card('Imported records',nrow(x),'Reporting month selection'),
    card('Awaiting review or correction',sum(x$review_required)),
    card('Validated and reconciled',sum(x$eligible),'Confirmed alert links only'),
    card('Confirmed alert links',sum(x$link_status %in% 'Confirmed')))
 })
 output$outputs<-DT::renderDT(result_table(activity_group_sum(outputs(),c('tier','funding','metric','unit'),'quantity')))
 output$households<-DT::renderDT(result_table(activity_group_sum(eligible(),c('tier','funding','hh_basis'),'households')))
 output$people<-DT::renderDT(result_table(activity_group_sum(eligible(),c('tier','funding','people_scope','people_basis'),'people_total')))
 output$demographics<-DT::renderDT({
  a<-eligible();a<-a[!is.na(a$age_people),,drop=FALSE]
  columns<-c('female_0_4','female_5_17','female_18_49','female_50_plus','male_0_4','male_5_17','male_18_49','male_50_plus')
  y<-lapply(columns,function(n){v<-a[,c('tier','funding','people_scope','people_basis',n),drop=FALSE];names(v)[ncol(v)]<-'quantity';v$age_sex_group<-rep(c(female_0_4='Female 0–59 months',female_5_17='Female 5–17 years',female_18_49='Female 18–49 years',female_50_plus='Female 50+ years',male_0_4='Male 0–59 months',male_5_17='Male 5–17 years',male_18_49='Male 18–49 years',male_50_plus='Male 50+ years')[[n]],nrow(v));v})
  y<-do.call(rbind,y)
  result_table(activity_group_sum(y,c('tier','funding','people_scope','people_basis','age_sex_group'),'quantity'))
 })
 timing_data<-shiny::reactive({
  ids<-unique(records()$alert_id);a<-data()$activities;a<-a[a$eligible&a$alert_id %in% ids,,drop=FALSE]
  if(!nrow(a)) return(data.frame(alert_id=character(),tier=character(),first_validated_start=character(),days_from_alert=integer()))
  keys<-paste(a$alert_id,a$tier,sep='|')
  do.call(rbind,lapply(split(seq_len(nrow(a)),keys),function(ix){z<-a[ix,,drop=FALSE];first<-min(z$start_date);data.frame(alert_id=z$alert_id[1],tier=z$tier[1],first_validated_start=as.character(first),days_from_alert=as.integer(first-z$alert_date[1]))}))
 })
 output$subsets<-DT::renderDT({
  a<-eligible();columns<-c('idp_female','idp_male','host_female','host_male','returnee_female','returnee_male','pwd_f_children','pwd_m_children','pwd_f_adults','pwd_m_adults')
  rows<-lapply(columns,function(n){v<-a[,c('tier','funding','people_scope','people_basis',n),drop=FALSE];names(v)[ncol(v)]<-'quantity';v$subset<-rep(n,nrow(v));v})
  result_table(activity_group_sum(do.call(rbind,rows),c('tier','funding','people_scope','people_basis','subset'),'quantity'))
 })
 output$timing<-DT::renderDT(result_table(timing_data()))
 output$delays<-DT::renderDT(result_table(delay_records()))
 output$handovers<-DT::renderDT({
  a<-response_records();a<-a[a$eligible,,drop=FALSE]
  cols<-c('record_id','alert_id','implementing_agency','previous_agency','handover_date','handover_reason','delay_reason','evidence_source','evidence_use')
  result_table(a[,cols,drop=FALSE])
 })
 displayed_records<-shiny::reactive({a<-records();if(!isTRUE(input$show_all)) a<-a[a$eligible,,drop=FALSE]
  a[,c('record_id','alert_id','link_status','reporting_month','start_date','end_date','delay_reason','district','community','location_coverage','tier','sector','activity','modality','implementing_agency','funding','metric','quantity','unit','households','hh_basis','people_total','age_people','status_people','people_scope','people_basis','review_status','eligible','eligibility_note'),drop=FALSE]})
 output$records<-DT::renderDT(result_table(displayed_records()))
 output$issues<-DT::renderDT({q<-data()$issues;q<-q[q$record_id %in% review_records()$record_id,,drop=FALSE];result_table(q)})
 output$definitions<-DT::renderDT(result_table(data()$metrics[,c('metric','unit','definition'),drop=FALSE]))
 output$export<-rrm_xlsx_download('rrm_activity_review',function() {
    a <- review_records()
    a[a$review_required,c('record_id','alert_id','community','link_status','review_status','eligibility_note','source_sheet','source_row')]
   },'Review records')
 response_available
})
