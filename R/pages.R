source('R/geography.R',local=TRUE)
page_titles <- c(coverage='Geographic coverage',alerts='Alerts',rna='Light RNA',vulnerability='Vulnerability screening',activity='Activity reporting')
all_choices <- function(x) c('All', sort(unique(x[!is.na(x)])))
filter_spec <- function(key, d) {
  switch(key,
    coverage=list(list('area','Area',d$coverage$area),list('partner','Partner',d$coverage$partner),list('role','GLA role',d$coverage$role)),
    alerts=list(list('arrival','Arrival geography',d$routes$arrival),list('alert_id','Alert ID',d$alerts$alert_id),list('trigger','Trigger',d$alerts$trigger),list('gla','GLA',d$alerts$gla),list('movement','Movement',d$alerts$movement)),
    rna=list(list('area','Assessed geography',d$assessments$area),list('alert_id','Alert ID',d$assessments$alert_id),list('method','Method',d$assessments$method),list('assessment_id','Assessment round',d$assessments$assessment_id)),
    vulnerability=list(list('community','Community',d$screening$community),list('alert_id','Alert ID',d$screening$alert_id),list('population','Population',d$screening$population),list('decision','Decision',d$screening$decision)),
    activity=list(list('area','Response geography',d$activities$area),list('alert_id','Alert ID',d$activities$alert_id),list('tier','Tier',d$activities$tier),list('modality','Modality',d$activities$modality),list('delivery_partner','Delivery partner',d$activities$delivery_partner)))
}
page_ui <- function(id, key, d) {
  ns <- NS(id); specs <- filter_spec(key,d)
  if(key=='coverage') specs <- specs[c(2,3,1)]
  date_col <- switch(key,alerts='alert_date',rna='start_date',vulnerability='decision_date',activity='start_date')
  source <- switch(key,coverage=d$coverage,alerts=d$alerts,rna=d$assessments,vulnerability=d$screening,activity=d$activities)
  dates <- if(key != 'coverage') source[[date_col]] else d$metadata$source_updated
  bounds <- if(length(dates) && any(!is.na(dates))) range(dates,na.rm=TRUE) else c(Sys.Date(),Sys.Date())
  div(class=paste('dashboard-page',paste0('page-',key)),
    if(key!='coverage') div(class='page-heading',div(span(class='eyebrow','RAPID RESPONSE MECHANISM'),h2(page_titles[[key]])),
        downloadButton(ns('download'),'Export filtered CSV',class='btn-export')),
    if(d$metadata$mode=='operational' && !nrow(source)) div(class='method-strip',paste('No operational',switch(key,coverage='responsibility assignments',alerts='core alert records',rna='assessment records',vulnerability='screening decisions',activity='core activity records'),'have been supplied for this page.')),
    div(class='filters',
      if(key=='coverage') tagList(
        selectInput(ns('map_province'),'Geography',choices=c('All verified areas'='All','Cabo Delgado'='mz01','Nampula'='mz07'),selectize=FALSE),
        dateInput(ns('as_of'),'Coverage as of',value=d$metadata$source_updated,format='dd M yyyy'))
      else dateRangeInput(ns('dates'),switch(key, alerts='Alert issued date',rna='RNA start date',vulnerability='Tier 2 decision date',activity='Intervention start date'),start=bounds[1],end=bounds[2],format='dd M yyyy'),
      lapply(specs,function(s) {
        choices <- if(s[[1]]=='assessment_id') sort(unique(s[[3]])) else all_choices(s[[3]])
        if(key=='coverage') {
          names(choices) <- choices
          names(choices)[1] <- switch(s[[1]],partner='All partners',role='Primary / secondary',area='All areas')
        }
        selected <- if(s[[1]]=='alert_id' && key %in% c('alerts','activity','vulnerability') && 'DEMO-001' %in% choices) 'DEMO-001' else choices[1]
        selectInput(ns(s[[1]]),s[[2]],choices=choices,selected=selected,selectize=FALSE)
      }),actionButton(ns('reset'),'Reset filters',class='btn-reset')),
    uiOutput(ns('metrics')),
    if(key=='coverage') div(class='two-col',div(class='panel',h3('Assigned GLA coverage'),rrm_map_output(ns('coverage_map')),uiOutput(ns('map_slot'))),
      div(class='panel',h3('Partner and area responsibilities'),DT::DTOutput(ns('table')),
        p(class='responsibility-note','Assignments are coverage responsibilities, not evidence that a response took place.')))
    else if(key=='alerts') tagList(div(class='two-col',div(class='panel',h3('Origin to arrival and targeted locations'),uiOutput(ns('routes'))),
      div(class='panel',h3('Alert summary and severity evidence'),uiOutput(ns('details')))),
      div(class='panel',h3('Stage-specific alert evidence'),DT::DTOutput(ns('table'))),
      div(class='panel',h3('Calculated domain ratings and evidence provenance'),DT::DTOutput(ns('severity_calc'))))
    else if(key=='rna') div(class='two-col',div(class='panel',h3('Top needs · separate evidence streams'),DT::DTOutput(ns('table')),p(class='muted','KII priorities and HESPER counts remain separate. Counts describe only this purposive sample.')),
      div(class='panel',h3('Coverage, methods and use in response'),uiOutput(ns('details'))))
    else if(key=='vulnerability') tagList(uiOutput(ns('details')),div(class='panel',h3('Tier 2 decisions by alert and community'),DT::DTOutput(ns('table'))))
    else tagList(div(class='panel',h3('Interventions linked to selected alerts'),DT::DTOutput(ns('table'))),div(class='two-col',
      div(class='panel',h3('Delay and response timing'),uiOutput(ns('details'))),div(class='panel',h3('Transfer of response responsibilities'),DT::DTOutput(ns('transfers'))))),
    div(class='method-strip',switch(key,
      coverage='Coverage uses effective assignment dates. Unknown responsibilities remain explicit. Map boundaries are supplied geographic context; locality points do not establish response locations.',
      alerts='Arrival geography selects alerts; KPI caseloads remain alert-wide. Counts across alerts may overlap and do not represent unique people. RNA totals exclude alerts awaiting verification.',
      rna='One assessment round at a time. No pooling of sites or extrapolation to the affected population. Reviewed ranking is supplied by the source.',
      vulnerability='Only reviewed aggregate profile summaries are shown. No household scores, registries, individual results or eligibility lists.',
      activity='KPIs count completed interventions only. Gross HH reach may include repeat assistance. Kits and consultations are service outputs; donor breakdowns remain in the source.')))
}
kpi <- function(title,value,note) div(class='kpi',span(class='kpi-title',title),div(class='kpi-value',value),span(class='muted',note))
kpi_row <- function(...) div(class='kpi-row',...)
empty_ui <- function() div(class='empty',h4('No matching records'),p('Adjust the filters or reset the selection.'))
text_or <- function(x,fallback='Not reported') if(!length(x)||is.na(x)||!nzchar(x)) fallback else as.character(x)
field <- function(label,value) p(strong(paste0(label,': ')),text_or(value))
page_server <- function(id,key,d) moduleServer(id,function(input,output,session) {
  specs <- filter_spec(key,d)
  observeEvent(input$reset, {
    for(s in specs) {
      choices <- if(s[[1]]=='assessment_id') sort(unique(s[[3]])) else all_choices(s[[3]])
      updateSelectInput(session,s[[1]],selected=choices[1])
    }
    if(key=='coverage') {
      updateDateInput(session,'as_of',value=d$metadata$source_updated)
      updateSelectInput(session,'map_province',selected='All')
      updateSelectInput(session,'map_district',selected='All')
      updateSelectInput(session,'map_post',selected='All')
    }
    else {
      x <- switch(key,alerts=d$alerts$alert_date,rna=d$assessments$start_date,vulnerability=d$screening$decision_date,activity=d$activities$start_date)
      b <- if(length(x)&&any(!is.na(x))) range(x,na.rm=TRUE) else c(Sys.Date(),Sys.Date())
      updateDateRangeInput(session,'dates',start=b[1],end=b[2])
    }
  })
  filtered <- reactive({
    if(key=='rna' && nrow(d$assessments)) req(input$assessment_id,cancelOutput=TRUE)
    x <- switch(key,coverage=d$coverage,alerts=d$alerts,rna=d$assessments,vulnerability=d$screening,activity=d$activities)
    for(s in specs) if(s[[1]] %in% names(x)) x <- filter_equal(x,s[[1]],input[[s[[1]]]])
    if(key=='coverage') {
      req(input$as_of,cancelOutput=TRUE)
      x <- x[x$effective_from <= input$as_of & (is.na(x$effective_to)|x$effective_to >= input$as_of),,drop=FALSE]
    } else {
      col <- switch(key,alerts='alert_date',rna='start_date',vulnerability='decision_date',activity='start_date')
      x <- filter_date(x,col,input$dates)
    }
    if(key=='alerts' && !is.null(input$arrival) && input$arrival!='All') {
      ids <- d$routes$alert_id[d$routes$arrival==input$arrival]
      x <- x[x$alert_id %in% ids,,drop=FALSE]
    }
    x
  })
  output$metrics <- renderUI({
    x <- filtered()
    if(!nrow(x)) return(empty_ui())
    switch(key,
      coverage=kpi_row(kpi('Primary GLAs',length(unique(x$partner[x$role=='Primary'])),if(d$metadata$mode=='demo') 'Illustrative assignments' else 'Distinct assigned partners'),
        kpi('Secondary GLAs',length(unique(x$partner[x$role=='Secondary'])),if(d$metadata$mode=='demo') 'Illustrative assignments' else 'Distinct assigned partners'),
        kpi('Assigned areas',length(unique(x$area[x$role!='Unknown'])),'Distinct coverage areas'),
        kpi('Coverage source',paste(unique(x$source_version),collapse=' / '),'Confirm effective dates')),
      alerts=kpi_row(kpi('Selected alerts',nrow(x),'One record per alert'),
        kpi('Verified people',fmt(known_sum(x$rna_people)),paste(sum(!is.na(x$rna_people)),'of',nrow(x),'alerts verified · alert-wide')),
        kpi('Verified households',fmt(known_sum(x$rna_hh)),'RNA-stage caseload · alert-wide'),
        kpi('Severity',if(nrow(x)==1) paste(text_or(x$alert_severity),text_or(x$rna_severity,'Pending'),sep=' / ') else 'See evidence table','Alert stage / RNA stage')),
      rna=kpi_row(kpi('Selected assessment',x$assessment_id[1],paste('Linked to',x$alert_id[1])),
        kpi('Assessment dates',paste(format(x$start_date[1],'%d %b'),format(x$end_date[1],'%d %b'),sep=' – '),'One assessment round'),
        kpi('Method',x$method[1],'Evidence streams kept separate'),
        kpi('Sample',paste(x$kii_sample[1],x$hh_sample[1],x$observation_sample[1],sep=' / '),'KIIs / HH / observations')),
      vulnerability={
        decisions <- unique(x[c('alert_id','community','decision')])
        kpi_row(kpi('Selected alerts',length(unique(x$alert_id)),'Community-level decisions'),
          kpi('Tier 2 decision',if(length(unique(x$decision))==1) unique(x$decision) else 'Mixed','Decision recorded in source'),
          kpi('IDP profiles',sum(x$population=='IDP' & x$reviewed=='TRUE'),'Reviewed aggregate summaries'),
          kpi('Host profiles',sum(x$population=='Host' & x$reviewed=='TRUE'),'Reviewed aggregate summaries'))
      },
      activity={t <- activity_totals(x);kpi_row(kpi('Gross household reach',fmt(t$hh),'Sum of completed HH assistance'),
        kpi('Kits distributed',fmt(t$kits),'Service output; not HH'),kpi('Clinic consultations',fmt(t$consultations),'Visits; not unique people'),
        kpi('First response',if(is.na(t$days)) 'Unavailable' else paste(t$days,'days'),'Earliest completed, filtered intervention'))})
  })
  display_table <- reactive({
    x <- filtered()
    switch(key,
      coverage=x[c('partner','area','role','effective_from','effective_to','source_version')],
      alerts=x[c('alert_id','alert_date','alert_hh','alert_people','alert_severity','alert_evidence_date','rna_hh','rna_people','rna_severity','rna_evidence_date')],
      rna={
        y <- d$needs[d$needs$assessment_id %in% x$assessment_id,,drop=FALSE]
        y <- y[order(y$rank),,drop=FALSE]
        data.frame(Rank=y$rank,Need=y$need,`KII summary`=y$kii_summary,`HESPER households`=if(nrow(y)) paste(y$hesper_serious,'of',y$hesper_valid,'serious need') else character(0),`Ranking note`=y$ranking_note,check.names=FALSE)
      },
      vulnerability=unique(x[c('alert_id','community','decision_date','population','decision','reason','reviewed')]),
      activity=x[c('event_id','alert_id','area','tier','modality','start_date','quantity','unit','measure_type','delivery_status','delivery_partner','donor','days_from_alert')])
  })
  output$table <- DT::renderDT({
    if(key=='coverage') DT::datatable(display_table()[c('partner','area','role')],colnames=c('Partner','Area','Role'),rownames=FALSE,escape=TRUE,
      options=list(pageLength=4,scrollX=TRUE,autoWidth=TRUE,ordering=FALSE,language=list(emptyTable='No matching records'),dom='tp'))
    else DT::datatable(display_table(),rownames=FALSE,escape=TRUE,options=list(pageLength=8,scrollX=TRUE,autoWidth=TRUE,language=list(emptyTable='No matching records'),dom='ftp'))
  })
  output$severity_calc <- DT::renderDT({
    y <- d$severity_calculations
    if(is.null(y)||!nrow(y)) return(DT::datatable(data.frame(Note='No calculation inputs supplied; displayed severity is source-recorded.'),rownames=FALSE,escape=TRUE,options=list(dom='t')))
    y <- y[y$alert_id %in% filtered()$alert_id,,drop=FALSE]
    DT::datatable(y,rownames=FALSE,escape=TRUE,options=list(scrollX=TRUE,pageLength=5))
  })
  output$download <- downloadHandler(
    filename=function() paste0('rrm_',key,'_',d$metadata$mode,'_',Sys.Date(),'.csv'),
    content=function(file) {
      # Export only the deliberate display columns; never export unreviewed profile text.
      write.csv(display_table(),file,row.names=FALSE,na='',fileEncoding='UTF-8')
    })
  output$routes <- renderUI({
    x <- filtered(); if(!nrow(x)) return(empty_ui())
    y <- d$routes[d$routes$alert_id %in% x$alert_id,,drop=FALSE]
    y <- filter_equal(y,'arrival',input$arrival)
    if(!nrow(y)) return(empty_ui())
    tagList(div(class='map-notice','SCHEMATIC ROUTES · no geographic boundaries or verified coordinates supplied'),
      lapply(seq_len(nrow(y)),function(i) div(class='route',div(span(class='eyebrow',y$alert_id[i]),h4(y$origin[i])),
        span(class='route-arrow','→'),div(h4(y$arrival[i]),p(paste(fmt(y$people[i]),'people ·',fmt(y$households[i]),'HH')),
        span(class='badge',paste('Targeted:',y$targeted[i])),p(class='muted',paste('Caseload stage:',y$caseload_stage[i]))))),
      p(class='muted','Counts are route-specific. Missing routes or route counts can leave a gap versus alert totals; unknown counts remain unavailable.'))
  })
  output$details <- renderUI({
    x <- filtered(); if(!nrow(x)) return(empty_ui())
    switch(key,
      alerts=tagList(lapply(seq_len(nrow(x)),function(i) div(class='evidence',
        h4(x$alert_id[i]),field('Alert issued',x$alert_date[i]),field('Trigger / movement',paste(x$trigger[i],x$movement[i],sep=' / ')),
        field('Alert stage',paste(text_or(x$alert_severity[i]),'·',fmt(x$alert_hh[i]),'HH · evidence',text_or(x$alert_evidence_date[i]))),
        field('RNA stage',paste(text_or(x$rna_severity[i],'Pending'),'·',fmt(x$rna_hh[i]),'HH · evidence',text_or(x$rna_evidence_date[i]))),
        field('Rationale',x$rationale[i]),field('Related alert',x$related_alert[i]),field('Overlap',x$overlap_status[i])))),
      rna=tagList(lapply(seq_len(nrow(x)),function(i) tagList(field('Coverage',x$coverage_note[i]),field('Method and limitations',x$limitations[i]),field('Evidence to response',x$response_use[i]),field('Source',x$source[i])))),
      vulnerability={
        y <- x[x$reviewed=='TRUE',,drop=FALSE]
        if(!nrow(y)) return(div(class='panel',h3('Aggregate profiles'),p('No reviewed profile summary is available for this selection.')))
        div(class='two-col',lapply(seq_len(nrow(y)),function(i) div(class='panel',
          span(class='eyebrow',paste(y$alert_id[i],y$community[i],sep=' · ')),h3(paste(y$population[i],'profiles associated with highest concurrence')),
          p(y$profile_summary[i]),p(class='muted',paste('Analysis:',y$analysis_version[i],'· Review:',y$review_date[i])),
          span(class='badge','Reviewed aggregate summary'))))
      },
      activity={
        y <- x[x$delivery_status=='Completed',,drop=FALSE]
        if(!nrow(y)) return(p('No completed interventions in the selection.'))
        combinations <- unique(y[c('alert_id','tier')])
        tagList(lapply(seq_len(nrow(combinations)),function(i) {
          z <- y[y$alert_id==combinations$alert_id[i]&y$tier==combinations$tier[i],,drop=FALSE]
          reasons <- unique(z$delay_reason[!is.na(z$delay_reason)])
          div(class='evidence',h4(paste(combinations$alert_id[i],combinations$tier[i],sep=' · ')),
            field('First completed response in selection',paste(min(z$days_from_alert),'days after alert')),
            field('Delay reason',if(length(reasons)) paste(reasons,collapse='; ') else 'Not reported'))
        }))
      })
  })
  output$transfers <- DT::renderDT({
    x <- filtered(); y <- d$transfers[d$transfers$alert_id %in% x$alert_id,,drop=FALSE]
    y <- filter_equal(y,'area',input$area)
    # Transfer dates and partners are independent of intervention-date and modality filters.
    DT::datatable(y[c('component','from_partner','to_partner','transfer_date','note')],escape=TRUE,rownames=FALSE,
      options=list(dom='t',scrollX=TRUE,language=list(emptyTable='No responsibility transfers reported for selected alerts and geography.')))
  })
  if(key=='coverage') {
    layers <- tryCatch(read_map_layers(),error=function(e) {warning(conditionMessage(e));NULL})
    observeEvent(input$map_province, {
      r <- map_reference(); r <- r[r$level=='admin2',,drop=FALSE]
      if(input$map_province!='All') r <- r[r$parent_pcode==input$map_province,,drop=FALSE]
      choices <- c('All'='All',setNames(r$pcode,r$label))
      selected <- if(!is.null(input$map_district)&&input$map_district %in% choices) input$map_district else 'All'
      updateSelectInput(session,'map_district',choices=choices,selected=selected)
    })
    observeEvent(list(input$map_province,input$map_district), {
      r <- map_reference(); r <- r[r$level=='admin3',,drop=FALSE]
      if(!is.null(input$map_province)&&input$map_province!='All') r <- r[substr(r$pcode,1,4)==input$map_province,,drop=FALSE]
      if(!is.null(input$map_district)&&input$map_district!='All') r <- r[r$parent_pcode==input$map_district,,drop=FALSE]
      choices <- c('All'='All',setNames(r$pcode,paste(r$label,r$pcode,sep=' · ')))
      selected <- if(!is.null(input$map_post)&&input$map_post %in% choices) input$map_post else 'All'
      updateSelectInput(session,'map_post',choices=choices,selected=selected)
    })
    output$map_slot <- renderUI({
      if(is.null(layers)) return(div(class='map-placeholder',h4('Geographic map unavailable'),p('Check the supplied geography files.')))
      tagList(
        p(class='muted coverage-map-caption',if(d$metadata$mode=='demo') 'Geographic context only. Demo areas are fictional; no district assignments are implied.' else 'Coral: known assignment. Sand: unknown or no matching assignment.'),
        p(class='muted','Filter partner and role; keep unknown coverage explicit.'),
        tags$details(class='map-details',tags$summary('Map view and sources'),downloadButton(session$ns('download'),'Export filtered assignments',class='btn-export'),geography_controls(session$ns,include_province=FALSE),
          uiOutput(session$ns('map_note')),
          p(class='muted','Supplied boundaries: 2019. Localities provide context, not response locations. OpenStreetMap requires internet; choose No basemap for local boundaries.')))
    })
    if(!is.null(layers)) {
      map_data <- reactive(coverage_map_payload(filtered(),d$metadata$mode,input$map_province,input$map_district,layers,input$map_post))
      output$coverage_map <- render_rrm_map({map_data()})
      output$map_note <- renderUI({
        n <- map_data()$unmapped
        if(n>0) p(class='map-notice',paste(n,'filtered assignment record(s) could not be linked to a listed district. They remain in the table and KPIs.'))
      })
    }
  }
})
