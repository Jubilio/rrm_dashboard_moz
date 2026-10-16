severity_labels <- c('Low','Moderate','High','Critical')
level_number <- function(x) {
  if(!length(x)||is.na(x)) return(NA_integer_)
  hit <- regmatches(x,regexpr('^[1-4]|(?<=Level )[1-4]',x,perl=TRUE))
  if(length(hit)&&nzchar(hit)) as.integer(hit) else match(x,severity_labels)
}
severity_result <- function(conditions=NA_integer_,protection=NA_integer_,verified_hh=NA_real_,override_verified=FALSE) {
  v <- c(conditions,protection)
  if(any(!is.na(v)&(!v %in% 1:4))) stop('Domain ratings must be 1–4 or missing.')
  if(!is.na(verified_hh)&&(!is.finite(verified_hh)||verified_hh<0||verified_hh!=floor(verified_hh))) stop('Verified HH must be a non-negative integer.')
  override <- isTRUE(override_verified)&&!is.na(verified_hh)&&verified_hh>=900
  n <- sum(!is.na(v));observed <- if(n) max(v,na.rm=TRUE) else NA_integer_
  score <- if(override) 4L else observed
  list(level=score,severity=if(is.na(score)) 'Unclassified' else severity_labels[score],
       override=override,completeness=if(n==2) 'Complete' else if(n==1) 'Partial' else 'Unknown',
       basis=if(override) 'Verified ≥900 HH override' else if(n) 'Highest supported domain' else 'No classified domain evidence')
}
# RNA patches contain only genuine new evidence. Missing patch values retain baseline values.
update_stage <- function(baseline,patch) {
  for(name in names(patch)) if(length(patch[[name]])&&!is.na(patch[[name]])&&nzchar(as.character(patch[[name]]))) baseline[[name]] <- patch[[name]]
  baseline
}
alert_status <- function(alert_date,rna_done,as_of=Sys.Date(),closed=FALSE) {
  age <- as.integer(as.Date(as_of)-as.Date(alert_date))
  if(any(age<0,na.rm=TRUE)) stop('Status as-of date precedes an alert date.')
  ifelse(closed,'Closed (formally confirmed)',ifelse(age>80,'Pending closure',ifelse(rna_done=='Yes','Ongoing alert','Open - RNA pending')))
}
read_history <- function(base='data/reference') {
  read <- function(file) read.csv(file.path(base,file),colClasses='character',na.strings='',check.names=FALSE,fileEncoding='UTF-8')
  a <- read('alert_registry.csv'); e <- read('severity_evidence.csv')
  a$registry_quality <- vapply(seq_len(nrow(a)),function(i) {
    flags<-character(0)
    if(a$rna_done[i]=='Yes'&&is.na(a$rna_date[i])) flags<-c(flags,'RNA marked complete but date missing')
    if(a$rna_done[i]=='Yes'&&is.na(a$recorded_latest_severity[i])) flags<-c(flags,'Latest/RNA severity missing in registry')
    paste(flags,collapse='; ')
  },character(1))
  # Never infer verified numeric caseloads from free-text estimates.
  e$conditions_level <- vapply(e$conditions_rating,level_number,integer(1))
  e$protection_level <- vapply(e$protection_rating,level_number,integer(1))
  e$domain_recalculation <- vapply(seq_len(nrow(e)),function(i) severity_result(e$conditions_level[i],e$protection_level[i])$severity,character(1))
  e$source_override_asserted <- !is.na(e$recorded_override)&grepl('^Yes',e$recorded_override)
  e$source_rule_recalculation <- ifelse(e$source_override_asserted,'Critical',e$domain_recalculation)
  e$calculation_agrees <- e$source_rule_recalculation==e$recorded_severity
  e$verification_note <- ifelse(e$source_override_asserted,'Workbook asserts override; underlying verified numeric registration is not supplied.','Possible/unknown overrides are not activated.')
  list(registry=a,evidence=e,
       rules=read('household_rules.csv'),decisions=read('pending_decisions.csv'))
}
history_ui <- function(id,h) {
 ns <- shiny::NS(id)
 shiny::tagList(shiny::div(class='page-heading',shiny::div(shiny::span(class='eyebrow','SUPPLIED WORKBOOK · HISTORICAL REVIEW'),shiny::h2('Alert severity registry'))),
  shiny::div(class='method-strip','Source classifications are preserved. Recalculations use the workbook domain ratings and explicit source override assertions, not an independently verified household register. Estimated caseload text is never treated as a verified count.'),
  shiny::div(class='filters',shiny::dateInput(ns('as_of'),'Status as of',Sys.Date()),
   shiny::selectInput(ns('district'),'Arrival district',all_choices(h$registry$arrival_district)),
   shiny::selectInput(ns('organisation'),'Reporting organisation',all_choices(h$registry$organisation)),
   shiny::selectInput(ns('alert'),'Alert ID',all_choices(h$registry$alert_id)),
   shiny::downloadButton(ns('export'),'Export registry')),
  shiny::uiOutput(ns('metrics')),
  shiny::div(class='panel',shiny::h3('Registry · one row per alert'),DT::DTOutput(ns('registry'))),
  shiny::div(class='panel',shiny::h3('Stage-specific evidence · original source rows retained'),DT::DTOutput(ns('evidence'))),
  shiny::div(class='panel',shiny::h3('Source quality issues requiring review'),DT::DTOutput(ns('issues'))),
  shiny::div(class='panel',shiny::h3('Severity calculator · manual verified inputs'),
    shiny::p('Use reviewed domain ratings. Unknown information is not Low. No numeric confidence score is invented.'),
    shiny::div(class='filters',shiny::selectInput(ns('conditions'),'Current humanitarian conditions',c('Unknown'='',setNames(1:4,severity_labels))),
      shiny::selectInput(ns('protection'),'Current protection / ongoing threat',c('Unknown'='',setNames(1:4,severity_labels))),
      shiny::numericInput(ns('verified_hh'),'Alert-linked households',NA,min=0,step=1),shiny::checkboxInput(ns('verified'),'Count independently verified for this alert',FALSE)),
    shiny::uiOutput(ns('calculation'))))
}
history_server <- function(id,h) shiny::moduleServer(id,function(input,output,session) {
 registry <- shiny::reactive({
  a <- h$registry
  a <- filter_equal(a,'arrival_district',input$district);a <- filter_equal(a,'organisation',input$organisation);a <- filter_equal(a,'alert_id',input$alert)
  shiny::req(input$as_of)
  a$days_open <- as.integer(as.Date(input$as_of)-as.Date(a$alert_date))
  a$provisional_status <- rep('Not yet issued as of selection',nrow(a))
  # Evaluate each historical status against the selected date, never a global adjusted date.
  eligible <- a$days_open>=0
  a$provisional_status[eligible] <- alert_status(a$alert_date[eligible],a$rna_done[eligible],input$as_of)
  a$source_change <- ifelse(a$rna_done=='Yes',paste(a$recorded_alert_severity,'→',ifelse(is.na(a$recorded_latest_severity),'Not recorded',a$recorded_latest_severity)),'No RNA; alert classification retained')
  a
 })
 evidence <- shiny::reactive({
  ids <- registry()$alert_id
  all_scope <- all(vapply(list(input$district,input$organisation,input$alert),function(v) is.null(v)||identical(v,'All'),logical(1)))
  if(all_scope) h$evidence else h$evidence[h$evidence$linked_alert_id %in% ids | h$evidence$source_alert_id %in% ids,,drop=FALSE]
 })
 output$metrics <- shiny::renderUI({a<-registry();kpi_row(kpi('Alerts',nrow(a),'Distinct registry IDs'),kpi('RNA completed',sum(a$rna_done=='Yes'),'Registry completion flag'),kpi('Pending closure',sum(a$provisional_status=='Pending closure'),'>80 days; formal confirmation required'),kpi('Latest recorded Critical',sum(a$recorded_latest_severity=='Critical',na.rm=TRUE),'May include retained alert ratings'))})
 output$registry <- DT::renderDT(DT::datatable(registry(),rownames=FALSE,escape=TRUE,options=list(scrollX=TRUE,pageLength=8)))
 output$evidence <- DT::renderDT(DT::datatable(evidence()[c('record_key','source_alert_id','linked_alert_id','link_status','stage','stage_date','conditions_rating','protection_rating','recorded_override','domain_recalculation','source_rule_recalculation','recorded_severity','calculation_agrees','completeness','confidence','caseload_text','verification_note','rationale','source_file')],rownames=FALSE,escape=TRUE,options=list(scrollX=TRUE,pageLength=6)))
 output$issues <- DT::renderDT({e<-evidence();i<-is.na(e$confidence)|grepl('review required',e$link_status)|!e$calculation_agrees|e$source_override_asserted
   DT::datatable(e[i,c('record_key','source_alert_id','linked_alert_id','link_status','confidence','verification_note','completeness')],rownames=FALSE,escape=TRUE,options=list(scrollX=TRUE,pageLength=5))})
 output$calculation <- shiny::renderUI({
  num<-function(x) if(is.null(x)||!length(x)||is.na(x)||identical(x,'')) NA_real_ else as.numeric(x)
  s<-severity_result(num(input$conditions),num(input$protection),num(input$verified_hh),input$verified)
  kpi_row(kpi('Calculated severity',s$severity,s$basis),kpi('Domain completeness',s$completeness,'Geographic coverage and confidence still require review'))
 })
 output$export<-shiny::downloadHandler(filename=function() paste0('rrm_historical_registry_',Sys.Date(),'.csv'),content=function(file) write.csv(registry(),file,row.names=FALSE,na=''))
})
apply_alert_severity <- function(d,path=file.path('data',d$metadata$mode,'severity_inputs.csv')) {
 if(!file.exists(path)) {d$severity_calculations<-data.frame();return(d)}
 z<-read.csv(path,colClasses='character',na.strings='',check.names=FALSE)
 required<-c('alert_id','stage','conditions_level','protection_level','verified_hh','hh_verified','evidence_date','confidence','geographic_caveat')
 if(!identical(names(z),required)) stop('severity_inputs.csv must match the supplied template.')
 if(anyDuplicated(z[c('alert_id','stage')])) stop('Duplicate alert/stage severity input.')
 if(!all(z$alert_id %in% d$alerts$alert_id)||!all(z$stage %in% c('Alert','RNA'))) stop('Unknown alert or stage in severity inputs.')
 if(anyNA(z$hh_verified)||!all(z$hh_verified %in% c('TRUE','FALSE'))) stop('hh_verified must explicitly be TRUE or FALSE.')
 calculations<-list()
 for(id in unique(z$alert_id)) {
  state<-list(conditions=NA_real_,protection=NA_real_,verified_hh=NA_real_,verified=FALSE)
  for(stage in c('Alert','RNA')) {
   y<-z[z$alert_id==id&z$stage==stage,,drop=FALSE]
   if(!nrow(y)) next
   num<-function(v) if(is.na(v)) NA_real_ else {n<-suppressWarnings(as.numeric(v));if(is.na(n)) stop('Invalid numeric severity input.');n}
   baseline<-state
   state<-update_stage(state,list(conditions=num(y$conditions_level),protection=num(y$protection_level)))
   if(!is.na(y$verified_hh)) {state$verified_hh<-num(y$verified_hh);state$verified<-y$hh_verified=='TRUE'}
   # A false verification flag without a replacement count withdraws the old attestation.
   else if(y$hh_verified=='FALSE') state$verified<-FALSE
   date<-as.Date(y$evidence_date,format='%Y-%m-%d')
   if(is.na(date)||format(date,'%Y-%m-%d')!=y$evidence_date) stop('Stage severity requires a valid evidence date.')
   ix<-match(id,d$alerts$alert_id);prefix<-if(stage=='Alert') 'alert_' else 'rna_'
   if(date<d$alerts$alert_date[ix]) stop('Severity evidence precedes alert date.')
   reported<-d$alerts[[paste0(prefix,'hh')]][ix]
   if(isTRUE(state$verified)&&!is.na(state$verified_hh)&&!is.na(reported)&&reported!=state$verified_hh) stop('Verified HH differs from the matching alert-stage caseload. Reconcile the source tables.')
   s<-severity_result(state$conditions,state$protection,state$verified_hh,state$verified)
   d$alerts[[paste0(prefix,'severity')]][ix]<-if(s$severity=='Unclassified') NA_character_ else s$severity
   d$alerts[[paste0(prefix,'evidence_date')]][ix]<-date
   calculations[[length(calculations)+1]]<-data.frame(alert_id=id,stage=stage,conditions_level=state$conditions,protection_level=state$protection,
      severity=s$severity,override=s$override,domain_completeness=s$completeness,confidence=if(is.na(y$confidence)) 'Not reported' else y$confidence,
      geographic_caveat=y$geographic_caveat,confidence_review=if(s$completeness!='Complete'||!is.na(y$geographic_caveat)) 'Review confidence and geographic applicability' else 'Review source confidence',conditions_provenance=if(is.na(num(y$conditions_level))&&stage=='RNA'&&!is.na(baseline$conditions)) 'Retained from Alert' else 'Current stage',
      protection_provenance=if(is.na(num(y$protection_level))&&stage=='RNA'&&!is.na(baseline$protection)) 'Retained from Alert' else 'Current stage',
      evidence_date=as.character(date),rule_version='Supplied simplified MOZ-RRM framework 2026',stringsAsFactors=FALSE)
  }
 }
 d$severity_calculations<-if(length(calculations)) do.call(rbind,calculations) else data.frame()
 d
}
