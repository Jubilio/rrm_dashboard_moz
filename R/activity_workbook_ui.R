activity_workbook_ui <- function(id) {
 ns<-shiny::NS(id)
 shiny::tagList(
  shiny::div(class='page-heading',shiny::div(shiny::span(class='eyebrow','STANDARDISED WORKBOOK'),shiny::h2('Activity reporting')),
    shiny::downloadButton(ns('export'),'Export displayed records')),
  shiny::div(class='panel',shiny::h3('Data source'),shiny::uiOutput(ns('source_status')),
    shiny::div(class='filters',shiny::fileInput(ns('upload'),'Load a standardised workbook (.xlsx)',accept='.xlsx'),
      shiny::actionButton(ns('clear_upload'),'Use configured source'),shiny::actionButton(ns('refresh'),'Refresh now')),
    shiny::p(class='muted','A configured workbook is checked automatically every 10 seconds. Uploads are session-specific. Only an explicit allowlist of reporting fields is used; reporting contacts and private references are excluded.')),
  shiny::uiOutput(ns('load_error')),
  shiny::div(class='filters',
    shiny::selectInput(ns('month'),'Reporting month','All'),shiny::selectInput(ns('alert'),'Alert ID','All'),
    shiny::selectInput(ns('district'),'Response district','All'),shiny::selectInput(ns('community'),'Reported community','All'),shiny::selectInput(ns('partner'),'Implementing agency','All'),
    shiny::selectInput(ns('tier'),'Tier','All'),shiny::selectInput(ns('sector'),'Sector','All'),
    shiny::selectInput(ns('modality'),'Modality','All'),shiny::selectInput(ns('funding'),'Funding scope','All'),
    shiny::actionButton(ns('reset'),'Reset filters',class='btn-reset')),
  shiny::uiOutput(ns('metrics')),
  shiny::div(class='method-strip','Results use Validated records with Confirmed alert links and reconciled inputs. Blank is not zero. All reported HH reach is gross; repeat assistance can overlap. Outputs are grouped by metric AND unit. People, estimated catchments, household counts, kits, services and currency are never added together.'),
  shiny::tabsetPanel(
    shiny::tabPanel('Intervention map',
      shiny::div(class='panel',shiny::h3('Reported intervention locations'),
        shiny::radioButtons(ns('map_scope'),'Map record scope',choices=c('All reported records'='all','Validated results only'='validated'),selected='all',inline=TRUE),
        shiny::uiOutput(ns('location_status')),rrm_map_output(ns('location_map')),
        shiny::div(class='map-legend',
          shiny::span(shiny::span(class='map-swatch',style='background:#EE5859;'),'Location with validated records'),
          shiny::span(shiny::span(class='map-swatch',style='background:#D2CBB8;'),'Reported location - pending / excluded records only')),
        shiny::p(class='muted','Points are geographic name matches, not independent verification of delivery. Marker counts describe activity records, never unique beneficiaries. Combined locations, conflicting administrative labels and ambiguous names require review; no reach or output quantities are allocated to points.')),
      shiny::div(class='panel',shiny::h3('Community matching and unresolved locations'),
        shiny::downloadButton(ns('location_export'),'Export geographic matching CSV'),DT::DTOutput(ns('location_review')),
        shiny::p(class='muted','Candidate names are review suggestions only. Similar spellings and multiple possible points are never assigned automatically.'))),
    shiny::tabPanel('Validated outputs',shiny::div(class='panel',shiny::h3('Outputs by tier, funding, metric and unit'),DT::DTOutput(ns('outputs')))),
    shiny::tabPanel('Reach and demographics',
      shiny::div(class='panel',shiny::h3('Household reach by counting basis'),DT::DTOutput(ns('households'))),
      shiny::div(class='panel',shiny::h3('Reported people by scope and counting basis'),DT::DTOutput(ns('people'))),
      shiny::div(class='panel',shiny::h3('Complete reported age/sex breakdowns — gross counts'),DT::DTOutput(ns('demographics')),
        shiny::p(class='muted','Age bands retain the source 0–59 months, 5–17 years, 18–49 years and 50+ years. Disability and population-status figures are subsets, not additional reach.')),
      shiny::div(class='panel',shiny::h3('Population and disability subsets · do not add to total reach'),DT::DTOutput(ns('subsets')))),
    shiny::tabPanel('Timing, handovers and evidence',
      shiny::div(class='panel',shiny::h3('First validated activity by selected alert and tier · all reported months'),DT::DTOutput(ns('timing')),
        shiny::p(class='muted','Timing uses the workbook Alerts shared date, not shock or arrival dates. It includes assessment and coordination activities if validated; it is not automatically first delivery of assistance.')),
      shiny::div(class='panel',shiny::h3('Transfers and evidence use'),DT::DTOutput(ns('handovers')))),
    shiny::tabPanel('Records and review',shiny::div(class='panel',shiny::h3('Imported activity records'),
      shiny::checkboxInput(ns('show_all'),'Include pending and excluded records for review',TRUE),DT::DTOutput(ns('records')),
      shiny::p(class='muted','Blank source review statuses are shown as Pending review. The dashboard does not mark records Validated. Combined locations and mixed funding remain unsplit.')),
      shiny::div(class='panel',shiny::h3('Recomputed data-quality checks'),DT::DTOutput(ns('issues')))),
    shiny::tabPanel('Counting definitions',shiny::div(class='panel',DT::DTOutput(ns('definitions'))))))
}
activity_workbook_server <- function(id,workbook_path='',snapshot_dir='data/activity_snapshot') shiny::moduleServer(id,function(input,output,session) {
 settlement_error<-NULL
 settlements<-tryCatch(read_settlement_points(),error=function(e){settlement_error<<-conditionMessage(e);NULL})
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
  paths<-if(nzchar(file)) file else file.path(snapshot_dir,paste0(c('activities','extra','alerts','metrics','metadata'),'.csv'))
  info<-file.info(paths)
  stamp<-paste(source,paste(info$size,as.numeric(info$mtime),collapse='|'),input$refresh,collapse='|')
  if(identical(shiny::isolate(signature()),stamp)) return()
  signature(stamp)
  tryCatch({
   if(nzchar(file)&&!file.exists(file)) stop('Configured workbook is unavailable. Correct its location or load another workbook.')
   raw<-if(nzchar(file)) read_activity_workbook(file) else read_activity_snapshot(snapshot_dir)
   parsed<-prepare_activity_data(raw)
   current(parsed);last_error(NULL);source_label(source);loaded_at(format(Sys.time(),'%Y-%m-%d %H:%M:%S %Z'))
  },error=function(e){last_error(conditionMessage(e))})
 })
 data<-shiny::reactive({shiny::req(current(),cancelOutput=TRUE);current()})
 filter_fields<-c(month='reporting_month',alert='alert_id',district='district',community='community',partner='implementing_agency',tier='tier',sector='sector',modality='modality',funding='funding')
 shiny::observeEvent(current(),{
  a<-data()$activities
  for(id in names(filter_fields)) {
   values<-a[[filter_fields[[id]]]]
   values<-if(id=='month') format(values,'%Y-%m') else as.character(values)
   choices<-c('All',sort(unique(values[!is.na(values)])))
   selected<-shiny::isolate(input[[id]])
   if(is.null(selected)||!selected %in% choices)selected<-'All'
   shiny::updateSelectInput(session,id,choices=choices,selected=selected)
  }
 },ignoreNULL=TRUE)
 shiny::observeEvent(input$reset,{for(id in names(filter_fields))shiny::updateSelectInput(session,id,selected='All')})
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
 eligible<-shiny::reactive({x<-records();x[x$eligible,,drop=FALSE]})
 outputs<-shiny::reactive({x<-apply_filters(data()$outputs);x[x$eligible,,drop=FALSE]})
 result_table<-function(x) {
  titles<-c(record_id='Record ID',alert_id='Alert ID',tier='Tier',funding='Funding scope',metric='Output metric',quantity='Quantity',unit='Unit',n_records='Records',n_known='Records with a reported quantity',households='Households reported',hh_basis='Household counting basis',people_scope='People reach scope',people_basis='People counting basis',people_total='Reported people',age_sex_group='Age / sex group',subset='Population subset',age_people='Complete age/sex total',status_people='Complete population-status total',eligible='Included in validated results',eligibility_note='Review outcome',previous_agency='Previous implementing agency',first_validated_start='First validated start',days_from_alert='Days from alert shared date',source_row='Source row')
  names(x)<-vapply(names(x),function(n) if(n %in% names(titles)) titles[[n]] else tools::toTitleCase(gsub('_',' ',n,fixed=TRUE)),character(1))
  DT::datatable(x,rownames=FALSE,escape=TRUE,options=list(scrollX=TRUE,pageLength=8,language=list(emptyTable='No records available for this selection.')))
 }
 output$source_status<-shiny::renderUI({d<-current();shiny::tagList(shiny::p(shiny::strong(source_label())),
  shiny::p(class='muted',paste('Last successful refresh:',if(is.null(loaded_at())) 'Not loaded' else loaded_at())),
  if(!is.null(d)) shiny::p(class='muted',paste('Source updated:',d$metadata$source_updated[1])))})
 output$load_error<-shiny::renderUI({e<-last_error();if(is.null(e))return(NULL)
  shiny::div(class='empty',shiny::h4('Source refresh failed'),shiny::p(e),shiny::p(if(is.null(current())) 'No dataset is available.' else 'The last successfully loaded dataset remains visible; its refresh timestamp is unchanged.'))})
 location_source<-shiny::reactive({a<-records();if(identical(input$map_scope,'validated'))a<-a[a$eligible,,drop=FALSE];a})
 location_links<-shiny::reactive(match_intervention_locations(location_source(),settlements))
 output$location_map<-render_rrm_map(intervention_map_payload(location_source(),location_links(),settlements,location_layers))
 output$location_status<-shiny::renderUI({
  a<-location_links();mapped<-sum(a$match_status=='Matched');places<-length(unique(a$point_id[!is.na(a$point_id)]))
  shiny::tagList(
    if(!is.null(settlement_error))shiny::p(class='map-notice',paste('Settlement source unavailable:',settlement_error)),
    shiny::p(paste(mapped,'of',nrow(a),'records geographically matched to',places,'distinct points;',nrow(a)-mapped,'records require geographic review.')),
    shiny::p(class='muted',if(identical(input$map_scope,'validated'))'Only records included in validated results are mapped.' else 'Includes pending and excluded records. Geographic matching does not change source review status.'))
 })
 output$location_review<-DT::renderDT(result_table(location_links()))
 output$location_export<-shiny::downloadHandler(filename=function()paste0('rrm_community_matching_',Sys.Date(),'.csv'),
   content=function(file)write.csv(location_links(),file,row.names=FALSE,na='',fileEncoding='UTF-8'))
 output$metrics<-shiny::renderUI({
  x<-records();a<-eligible();o<-outputs();hh<-if(!nrow(a)) NA_real_ else known_sum(a$households)
  assisted<-o[o$metric=='Households assisted'&o$unit=='households',,drop=FALSE]
  q<-if(nrow(assisted)) known_sum(assisted$quantity) else NA_real_
  shiny::tagList(kpi_row(kpi('Imported records',nrow(x),'Current filter selection'),kpi('Validated and reconciled',nrow(a),'Confirmed alert links only'),
    kpi('Awaiting review / correction',sum(x$review_required),'Blank review status remains pending'),kpi('Confirmed alert links',sum(!is.na(x$link_status)&x$link_status=='Confirmed'),'Before review and reconciliation')),
    kpi_row(kpi('Gross reported HH reach',fmt(hh),'All reported bases; see basis breakdown'),kpi('HH assistance outputs',fmt(q),'Households assisted metric; separate from reach'),
      kpi('Known output quantities',sum(!is.na(o$quantity)),'Across separate metrics; quantities are not summed'),kpi('Unknown HH reach records',sum(is.na(a$households)),'Among validated selected records')))
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
 output$handovers<-DT::renderDT({
  a<-eligible();cols<-c('record_id','alert_id','implementing_agency','previous_agency','handover_date','handover_reason','delay_reason','evidence_source','evidence_use')
  result_table(a[,cols,drop=FALSE])
 })
 displayed_records<-shiny::reactive({a<-records();if(!isTRUE(input$show_all)) a<-a[a$eligible,,drop=FALSE]
  a[,c('record_id','alert_id','link_status','reporting_month','start_date','end_date','district','community','location_coverage','tier','sector','activity','modality','implementing_agency','funding','metric','quantity','unit','households','hh_basis','people_total','age_people','status_people','people_scope','people_basis','review_status','eligible','eligibility_note'),drop=FALSE]})
 output$records<-DT::renderDT(result_table(displayed_records()))
 output$issues<-DT::renderDT({q<-data()$issues;q<-q[q$record_id %in% records()$record_id,,drop=FALSE];result_table(q)})
 output$definitions<-DT::renderDT(result_table(data()$metrics[,c('metric','unit','definition'),drop=FALSE]))
 output$export<-shiny::downloadHandler(filename=function() paste0('rrm_activity_',if(isTRUE(input$show_all)) 'review' else 'validated','_',Sys.Date(),'.csv'),content=function(file)write.csv(displayed_records(),file,row.names=FALSE,na=''))
})
