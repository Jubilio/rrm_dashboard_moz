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

# Button that shows/hides another element by id (handled in www/tables.js).
rrm_toggle_button <- function(target, label, class='') {
  tags$button(type='button', class=paste('rrm-toggle', class), `data-toggle-target`=target,
              `aria-controls`=target, `aria-expanded`='false', label,
              span(class='rrm-toggle-chevron', `aria-hidden`='true'))
}

rrm_export_button <- function(id, label)
  tagAppendAttributes(downloadButton(id, label, icon=NULL), class='rrm-btn-outline')

activity_workbook_ui <- function(id) {
  ns <- NS(id)
  show <- function(field,value) sprintf("input['%s'] == '%s'",ns(field),value)
  div(class='dashboard-page rrm-workspace rrm-activity',
    conditionalPanel(sprintf("input['%s'] != 'review'",ns('workspace')),
      p(class='rrm-page-lede','See what partners reported delivering, where and when.')),
    conditionalPanel(show('workspace','review'),
      p(class='rrm-page-lede','Review reported activities, resolve alert links and check community matches.')),
    uiOutput(ns('load_error')),
    tabsetPanel(id=ns('workspace'),
      tabPanel('Response by community',value='response',
        div(class='panel rrm-activity-filters',
          div(class='rrm-activity-filter-grid',
            selectizeInput(ns('alert'),'Alert',c('All alerts'='All')),
            selectInput(ns('district'),'Response district',c('All districts'='All')),
            selectInput(ns('community'),'Community',c('All communities'='All')),
            selectInput(ns('period'),'Activity period',c('All dates'='All')),
            rrm_toggle_button(ns('more_filters'),'More filters','rrm-btn-outline'),
            actionButton(ns('reset'),'Clear filters',class='rrm-link-button')),
          div(id=ns('more_filters'),class='rrm-more-filters',hidden=NA,
            selectInput(ns('partner'),'Delivery partner','All'),
            selectInput(ns('tier'),'Tier','All'),selectInput(ns('sector'),'Sector','All'),
            selectInput(ns('modality'),'Modality','All'),
            selectInput(ns('delivery_status'),'Delivery status','All'))),
        uiOutput(ns('linked_alert')),
        div(class='rrm-section-head',
          div(h3('Reported activities'),uiOutput(ns('scope_line'))),
          div(class='rrm-section-actions',
            div(class='rrm-segmented',radioButtons(ns('response_view'),span(class='sr-only','View'),
              c(List='list',Map='map'),inline=TRUE)),
            rrm_export_button(ns('response_export'),'Export filtered activities'),
            div(class='rrm-totals',uiOutput(ns('response_totals'))))),
        div(class='sr-only',radioButtons(ns('scope'),'Activity scope',
                       c('Delivery activities'='delivery','All activities'='all'),inline=TRUE)),
        uiOutput(ns('response_empty')),
        conditionalPanel(show('response_view','list'),uiOutput(ns('responses'))),
        conditionalPanel(show('response_view','map'),div(class='panel rrm-map-panel',
          h3('Reported activity locations'),uiOutput(ns('location_status')),rrm_map_output(ns('location_map')),
          p(class='rrm-footnote','Use List to see records without a confirmed map location.'))),
        tags$details(class='panel rrm-plain-details',tags$summary('Timing and handovers'),
          p(class='rrm-footnote','Validated totals use reviewed and reconciled records with confirmed alert links.'),
          uiOutput(ns('first_delivery')),DT::DTOutput(ns('response_timeline')),DT::DTOutput(ns('handovers')))),
      tabPanel('Data review',value='review',
        div(class='panel rrm-source-panel',
          div(class='rrm-source-head',uiOutput(ns('source_status')),
            div(class='rrm-section-actions',
              actionButton(ns('refresh'),'Refresh source',class='rrm-btn-outline'),
              rrm_toggle_button(ns('manage'),'Manage workbook','rrm-btn-outline'))),
          div(id=ns('manage'),class='rrm-manage',hidden=NA,
            fileInput(ns('upload'),'Load a standardised workbook (.xlsx)',accept='.xlsx'),
            actionButton(ns('clear_upload'),'Use configured source',class='rrm-btn-outline'),
            p(class='rrm-footnote','Uploads apply to this session only.'))),
        uiOutput(ns('metrics')),
        div(class='panel rrm-review-panel',
          div(class='rrm-section-head',h3('Review queue'),
            div(class='rrm-section-actions',
              selectInput(ns('month'),span(class='sr-only','Reporting month'),'All'),
              rrm_export_button(ns('export'),'Export review records'))),
          tabsetPanel(type='pills',
            tabPanel('Pending review',uiOutput(ns('review_queue')),
              tags$details(class='rrm-plain-details',tags$summary('Validation issues'),DT::DTOutput(ns('issues')))),
            tabPanel('Geographic matching',
              div(class='rrm-tab-actions',rrm_export_button(ns('location_export'),'Export geographic matching')),
              uiOutput(ns('geographic_queue'))),
            tabPanel('Counting definitions',DT::DTOutput(ns('definitions')))),
          tags$details(class='rrm-plain-details',tags$summary('Validated output and reach breakdowns'),
            DT::DTOutput(ns('outputs')),DT::DTOutput(ns('households')),DT::DTOutput(ns('people')),
            DT::DTOutput(ns('demographics')),DT::DTOutput(ns('subsets'))))),
      selected='response'))
}

rrm_day <- function(date) ifelse(is.na(date), NA_character_,
  paste(as.integer(format(date,'%d')), format(date,'%b %Y')))

# "RRM_SCI_NAMUNO-MONTEPUEZ_26052026_IDP" -> "SCI · Namuno–Montepuez · 26 May"
alert_short_label <- function(id) {
  m <- regmatches(id, regexec('^RRM_([^_]+)_(.+)_([0-9]{8})(_.*)?$', id))
  vapply(seq_along(id), function(i) {
    x <- m[[i]]
    if (is.na(id[i])) return('Not reported')
    if (!length(x)) return(id[i])
    place <- gsub('-', '–', tools::toTitleCase(tolower(gsub('_',' ',x[3]))), fixed=TRUE)
    date <- as.Date(x[4], '%d%m%Y')
    paste(c(x[2], place, if (!is.na(date)) paste(as.integer(format(date,'%d')), format(date,'%b'))), collapse=' · ')
  }, character(1))
}

rrm_row_id <- function(prefix, i) paste0(prefix, 'row-', i)

rrm_row_toggle <- function(target)
  tags$button(type='button', class='rrm-toggle rrm-row-toggle', `data-toggle-target`=target,
              `aria-controls`=target, `aria-expanded`='false',
              span(class='sr-only','Show record details'), span(class='rrm-toggle-chevron',`aria-hidden`='true'))

response_row_details <- function(a) {
  div(class='rrm-record-details',
    field('Record ID',a$record_id),field('Reported metric',a$metric),field('Funding',a$funding),
    field('Delay reason',a$delay_reason),
    field('Source',paste(a$source_sheet,'row',a$source_row)),
    field('Delivery status source',a$delivery_status_source),
    field('Alert link',a$link_status))
}

response_status_label <- function(value, missing='Status not reported') {
  if (is.na(value) || !nzchar(value)) return(span(class='rrm-status-missing',missing))
  style <- switch(value, Completed='rrm-status-completed', Validated='rrm-status-completed',
                  'Pending review'='rrm-status-pending', 'Needs correction'='rrm-status-pending', '')
  span(class=paste('rrm-status',style),value)
}

response_list <- function(a, prefix='response-') {
  community <- ifelse(is.na(a$community),'Community not reported',a$community)
  place <- vapply(seq_len(nrow(a)), function(i) {
    parts <- c(if (!is.na(a$admin_post[i])) paste(a$admin_post[i],'administrative post'),
               if (!is.na(a$district[i])) paste(a$district[i],'district'))
    if (length(parts)) paste(parts, collapse=' · ') else 'District not reported'
  }, character(1))
  groups <- split(seq_len(nrow(a)),factor(paste(community,place,sep='|'),levels=unique(paste(community,place,sep='|'))))
  headers <- c('Activity','Tier','Partner','Start date','Reported output','Delivery status','Review status')
  ncol <- length(headers) + 1L
  div(class='panel rrm-response-table',
    tags$table(class='table',
      tags$thead(tags$tr(lapply(headers,tags$th,scope='col'),tags$th(scope='col',span(class='sr-only','Details')))),
      lapply(groups,function(ix) {
        tags$tbody(
          tags$tr(class='rrm-group-row',tags$th(colspan=ncol,scope='rowgroup',
            div(class='rrm-group-label',span(community[ix[1]]),span(class='rrm-group-place',place[ix[1]])))),
          lapply(ix,function(i) {
            row <- a[i,,drop=FALSE]
            target <- rrm_row_id(prefix, i)
            output <- if (is.na(row$quantity)) span(class='rrm-status-missing','Not reported') else
              paste(fmt(row$quantity),if (is.na(row$unit)) '' else row$unit)
            tagList(
              tags$tr(class='rrm-record-row',
                tags$td(class='rrm-strong',text_or(row$activity)),tags$td(text_or(row$tier)),
                tags$td(text_or(row$implementing_agency)),tags$td(text_or(rrm_day(row$start_date),'Date unavailable')),
                tags$td(class='rrm-strong',output),
                tags$td(response_status_label(row$delivery_status)),
                tags$td(response_status_label(row$review_status,'Unavailable')),
                tags$td(class='rrm-toggle-cell',rrm_row_toggle(target))),
              tags$tr(id=target,class='rrm-detail-row',hidden=NA,tags$td(colspan=ncol,response_row_details(row))))
          }))
      })))
}

response_review_table <- function(a, links, indices, prefix='review-') {
  if (!length(indices)) return(p(class='rrm-footnote','No records in this selection.'))
  headers <- c('Record ID','Linked alert','Reported community','Location matching','Review status')
  ncol <- length(headers) + 1L
  tagList(
    div(class='rrm-response-table rrm-review-table',tags$table(class='table',
      tags$thead(tags$tr(lapply(headers,tags$th,scope='col'),tags$th(scope='col',span(class='sr-only','Details')))),
      tags$tbody(lapply(indices,function(i) {
        link <- links[i,]
        target <- rrm_row_id(prefix, i)
        tagList(
          tags$tr(class='rrm-record-row',
            tags$td(class='rrm-strong',a$record_id[i]),
            tags$td(title=text_or(a$alert_id[i]),alert_short_label(a$alert_id[i])),
            tags$td(text_or(a$community[i],'Community not reported')),
            tags$td(link$match_status),
            tags$td(response_status_label(a$review_status[i],'Unavailable')),
            tags$td(class='rrm-toggle-cell',rrm_row_toggle(target))),
          tags$tr(id=target,class='rrm-detail-row',hidden=NA,tags$td(colspan=ncol,div(class='rrm-record-details',
            field('Linked alert',a$alert_id[i]),field('Source row',a$source_row[i]),field('Match method',link$match_method),
            field('Coordinates',if (!is.na(link$longitude)) paste(link$longitude,link$latitude,sep=', ')),
            field('Geographic notes',link$match_note),field('Link status',a$link_status[i])))))
      })))),
    p(class='rrm-footnote',sprintf('%s %s. Open a record to see its source row, alert link and geographic match details.',
      length(indices), if (length(indices)==1) 'record' else 'records')))
}
