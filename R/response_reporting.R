response_delivery_records <- function(x) {
  supporting <- grepl('assessment|monitoring|coordination|survey|mapping|children mapped|training|interview|KIIs completed',
                      paste(x$activity,x$metric),ignore.case=TRUE)
  x[!supporting & !is.na(x$activity),,drop=FALSE]
}

response_communities <- function(value) {
  if (is.na(value)) return('Community not reported')
  names <- trimws(strsplit(value,'[,;\n]| and | & ',perl=TRUE)[[1]])
  names[nzchar(names)]
}

response_status_records <- function(x, core) {
  x$delivery_status_source <- ifelse(is.na(x$delivery_status),NA_character_,'Activity Entry')
  if (!is.null(core) && nrow(core) && nrow(x)) {
    match <- activity_core_matches(core, x)
    missing <- which(!is.na(match) & !is.na(core$delivery_status) & is.na(x$delivery_status[match]))
    x$delivery_status[match[missing]] <- core$delivery_status[missing]
    x$delivery_status_source[match[missing]] <- 'Exact core event match'
  }
  x
}

activity_workbook_ui <- function(id) {
  ns <- NS(id)
  show <- function(field,value) sprintf("input['%s'] == '%s'",ns(field),value)
  div(class='dashboard-page rrm-workspace',
    h2('Activity reporting'),
    uiOutput(ns('load_error')),
    tabsetPanel(id=ns('workspace'),
      tabPanel('Response by community',value='response',
        div(class='panel',
          div(class='filters rrm-workspace-filters',
            selectizeInput(ns('alert'),'Alert',c('All alerts'='All')),
            selectInput(ns('district'),'Response district',c('All districts'='All')),
            selectInput(ns('community'),'Community',c('All communities'='All')),
            selectInput(ns('period'),'Activity period',c('All dates'='All')),
            actionButton(ns('reset'),'Clear filters')),
          tags$details(tags$summary('More filters'),
            div(class='filters rrm-workspace-filters',
              selectInput(ns('partner'),'Delivery partner','All'),
              selectInput(ns('tier'),'Tier','All'),selectInput(ns('sector'),'Sector','All'),
              selectInput(ns('modality'),'Modality','All'),
              selectInput(ns('delivery_status'),'Delivery status','All')))),
        uiOutput(ns('linked_alert')),
        div(class='rrm-workspace-toolbar',h3('Reported activities'),
          div(class='rrm-workspace-actions',
            radioButtons(ns('response_view'),'View',c(List='list',Map='map'),inline=TRUE),
            downloadButton(ns('response_export'),'Export filtered activities'))),
        div(class='rrm-workspace-toolbar',
          radioButtons(ns('scope'),'Activity scope',
                       c('Delivery activities'='delivery','All activities'='all'),inline=TRUE),
          uiOutput(ns('response_totals'))),
        uiOutput(ns('response_empty')),
        conditionalPanel(show('response_view','list'),uiOutput(ns('responses'))),
        conditionalPanel(show('response_view','map'),div(class='panel',
          h3('Reported activity locations'),uiOutput(ns('location_status')),rrm_map_output(ns('location_map')),
          p(class='muted','Use List to see records without a matched map location.'))),
        tags$details(class='panel',tags$summary('Timing and handovers'),
          uiOutput(ns('first_delivery')),DT::DTOutput(ns('response_timeline')),DT::DTOutput(ns('handovers')))),
      tabPanel('Data review',value='review',
        div(class='panel',h3('Reporting source'),uiOutput(ns('source_status')),
          actionButton(ns('refresh'),'Refresh source'),
          tags$details(tags$summary('Manage workbook'),
            fileInput(ns('upload'),'Load a standardised workbook (.xlsx)',accept='.xlsx'),
            actionButton(ns('clear_upload'),'Use configured source'),
            p(class='muted','Uploads apply to this session only.'))),
        uiOutput(ns('metrics')),
        div(class='panel',
          div(class='rrm-workspace-toolbar',h3('Review queue'),
            selectInput(ns('month'),'Reporting month','All'),
            downloadButton(ns('export'),'Export review records')),
          tabsetPanel(
            tabPanel('Pending review',uiOutput(ns('review_queue')),DT::DTOutput(ns('issues'))),
            tabPanel('Geographic matching',downloadButton(ns('location_export'),'Export geographic matching CSV'),
              uiOutput(ns('geographic_queue'))),
            tabPanel('Counting definitions',DT::DTOutput(ns('definitions')))),
          tags$details(tags$summary('Validated output and reach breakdowns'),
            DT::DTOutput(ns('outputs')),DT::DTOutput(ns('households')),DT::DTOutput(ns('people')),
            DT::DTOutput(ns('demographics')),DT::DTOutput(ns('subsets'))))),
      selected='response'))
}

response_row_details <- function(a) {
  tags$details(tags$summary('Details'),
    field('Record ID',a$record_id),field('Funding',a$funding),field('Delay reason',a$delay_reason),
    field('Source',paste(a$source_sheet,'row',a$source_row)),
    field('Delivery status source',a$delivery_status_source),
    field('Alert link',a$link_status))
}

response_status_label <- function(value) {
  label <- text_or(value,'Status not reported')
  style <- switch(label, Completed='rrm-status-completed', Validated='rrm-status-completed',
                  'Pending review'='rrm-status-pending', 'Needs correction'='rrm-status-pending', '')
  span(class=paste('rrm-status',style),label)
}

response_list <- function(a) {
  district <- ifelse(is.na(a$district),'District not reported',a$district)
  community <- ifelse(is.na(a$community),'Community not reported',a$community)
  post <- ifelse(is.na(a$admin_post),'',a$admin_post)
  groups <- split(seq_len(nrow(a)),paste(district,post,community,sep=' · '))
  headers <- c('Activity','Tier','Delivery partner','Start date','Reported output','Delivery status','Review status','Record details')
  div(class='panel rrm-response-table',
    tags$table(class='table',
      tags$thead(tags$tr(lapply(headers,tags$th,scope='col'))),
      lapply(groups,function(ix) {
        location <- c(community[ix[1]],post[ix[1]],district[ix[1]])
        tags$tbody(
        tags$tr(class='rrm-group-row',tags$th(colspan=length(headers),scope='rowgroup',
          paste(location[nzchar(location)],collapse=' · '))),
        lapply(ix,function(i) {
          row <- a[i,,drop=FALSE]
          output <- if (is.na(row$quantity)) 'Output not reported' else
            paste(fmt(row$quantity),if (is.na(row$unit)) 'unit not reported' else row$unit,
                  if (!is.na(row$metric)) paste0('· ',row$metric))
          cells <- list(text_or(row$activity),text_or(row$tier),text_or(row$implementing_agency),
            text_or(format(row$start_date,'%d %b %Y'),'Date unavailable'),output,
            response_status_label(row$delivery_status),response_status_label(row$review_status),response_row_details(row))
          tags$tr(lapply(cells,tags$td))
        }))
      })))
}

response_review_table <- function(a, links, indices) {
  if (!length(indices)) return(p('No records in this selection.'))
  headers <- c('Record ID','Linked alert','Reported community','Geographic match','Review status','Record details')
  div(class='rrm-response-table',tags$table(class='table',
    tags$thead(tags$tr(lapply(headers,tags$th,scope='col'))),
    tags$tbody(lapply(indices,function(i) {
      link <- links[i,]
      cells <- list(a$record_id[i],text_or(a$alert_id[i]),text_or(a$community[i],'Community not reported'),
        link$match_status,response_status_label(a$review_status[i]),
        tags$details(tags$summary('Details'),
          field('Source row',a$source_row[i]),field('Match method',link$match_method),
          field('Coordinates',if (!is.na(link$longitude)) paste(link$longitude,link$latitude,sep=', ')),
          field('Geographic notes',link$match_note),field('Link status',a$link_status[i])))
      tags$tr(lapply(cells,tags$td))
    }))))
}
