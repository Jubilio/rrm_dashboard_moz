rna_reported_locations <- function(note, label) {
  if (is.na(note)) return(character())
  match <- regmatches(note, regexec(paste0('(?:^|[.] )', label, ': ([^.]+)'), note, perl=TRUE))[[1]]
  if (!length(match)) return(character())
  trimws(strsplit(match[2], ';', fixed=TRUE)[[1]])
}

rna_rounds <- function(d) {
  rounds <- d$assessments
  alerts <- d$alerts[match(rounds$alert_id, d$alerts$alert_id), , drop=FALSE]
  rounds$gla <- alerts$gla
  reference <- map_reference()
  codes <- coverage_district_codes(rounds, reference)
  rounds$district <- reference$label[match(codes, reference$pcode)]
  rounds$posts <- lapply(rounds$coverage_note, rna_reported_locations, label='Posto')
  rounds$communities <- Map(function(note, area, district) {
    sites <- rna_reported_locations(note, 'Sites')
    if (!length(sites) && is.na(district) && !is.na(area)) sites <- route_communities(area)
    sites
  }, rounds$coverage_note, rounds$area, rounds$district)
  rounds[order(-as.numeric(rounds$start_date), rounds$assessment_id, na.last=TRUE), , drop=FALSE]
}

rna_day <- function(date) paste(as.integer(format(date, '%d')), format(date, '%b %Y'))

rna_round_date <- function(start, end) {
  if (is.na(start)) return('Date unavailable')
  if (is.na(end) || end <= start) return(rna_day(start))
  if (format(start, '%Y-%m') == format(end, '%Y-%m'))
    return(paste0(as.integer(format(start, '%d')), '\u2013', rna_day(end)))
  if (format(start, '%Y') == format(end, '%Y'))
    return(paste(as.integer(format(start, '%d')), format(start, '%b'), '\u2013', rna_day(end)))
  paste(rna_day(start), '\u2013', rna_day(end))
}

# "12/12 KIs" -> c(12, 12); NA when the summary is free text.
rna_counts <- function(text) {
  m <- regmatches(text, regexec('([0-9]+)\\s*/\\s*([0-9]+)', text, perl=TRUE))
  t(vapply(m, function(x) if (length(x)) as.numeric(x[2:3]) else c(NA_real_, NA_real_), numeric(2)))
}

rna_arrow_label <- function(label) tagList(label, span(class='rrm-arrow', `aria-hidden`='true', '\u2192'))

rna_evidence_card <- function(title, subtitle, needs, values, numerator, denominator) {
  share <- numerator / denominator
  ord <- order(-share, needs$rank, na.last=TRUE)
  div(class='rrm-evidence',
    div(class='rrm-evidence-head', h4(title), p(subtitle)),
    tags$dl(lapply(ord, function(i) div(class='rrm-evidence-row', tags$dt(needs$need[i]), tags$dd(values[i])))))
}

rna_period_key <- function(dates, unit) {
  if (identical(unit, 'day')) format(dates, '%Y-%m-%d') else date_period_key(dates, unit)
}

light_rna_ui <- function(id, d) {
  ns <- NS(id)
  rounds <- rna_rounds(d)
  tagged <- function(x, label) setNames(all_choices(x), c(label, sort(unique(x[!is.na(x)]))))
  alert_names <- vapply(seq_len(nrow(d$alerts)), function(i) {
    alert <- d$alerts[i,]
    ix <- which(rounds$alert_id %in% alert$alert_id)
    parts <- unique(c(alert$alert_id,alert$gla,rounds$district[ix],unlist(rounds$communities[ix]),alert$trigger))
    paste(parts[!is.na(parts)],collapse=' · ')
  }, character(1))
  div(class='dashboard-page rrm-workspace rrm-rna',
    div(class='panel rrm-rna-filters',
      div(class='rrm-workspace-toolbar', h3('Filter assessments'),
        actionButton(ns('reset'),'Clear filters',class='rrm-link-button')),
      div(class='rrm-rna-filter-grid',
        selectInput(ns('gla'),'Responsible GLA',tagged(rounds$gla,'All GLAs')),
        div(class='rrm-period-field',
          radioButtons(ns('period_unit'),'Assessment period',
            c(Year='year',Month='month',Week='week',Day='day'),selected='month',inline=TRUE),
          div(class='rrm-period-select',
            selectInput(ns('period'),span(class='sr-only','Period'),c('All periods'='All'),selectize=FALSE))),
        selectInput(ns('district'),'District',tagged(rounds$district,'All districts')),
        selectInput(ns('post'),'Administrative post',tagged(unlist(rounds$posts),'All posts')),
        selectInput(ns('community'),'Community',tagged(unlist(rounds$communities),'All communities')))),
    div(class='rrm-rna-grid',
      div(class='panel rrm-rounds-panel',
        h3('Assessment rounds'),
        uiOutput(ns('round_count')),
        div(class='rrm-alert-search',
          selectizeInput(ns('alert'),span(class='sr-only','Find an alert'),
            c('Find an alert by name or ID'='',setNames(d$alerts$alert_id,alert_names)),
            options=list(placeholder='Find an alert by name or ID'))),
        uiOutput(ns('rounds'))),
      uiOutput(ns('findings'))))
}

light_rna_server <- function(id, d, open_alert, response_available) moduleServer(id, function(input, output, session) {
  rounds <- rna_rounds(d)
  selected_round <- reactiveVal(NULL)
  filters <- c('gla','period_unit','period','district','post','community')
  clear <- function() {
    for (field in setdiff(filters,'period_unit')) updateSelectInput(session, field, selected='All')
    updateRadioButtons(session, 'period_unit', selected='month')
  }
  select_latest <- function(alert) {
    x <- rounds[rounds$alert_id %in% alert & !is.na(rounds$start_date),,drop=FALSE]
    selected_round(if (nrow(x)) x$assessment_id[1] else NULL)
  }
  observeEvent(open_alert(), {
    alert <- open_alert()
    req(alert %in% d$alerts$alert_id)
    clear()
    updateSelectizeInput(session,'alert',selected=alert)
    select_latest(alert)
  })
  observeEvent(input$reset, {
    clear()
    updateSelectizeInput(session,'alert',selected='')
    selected_round(NULL)
  })
  observeEvent(input$period_unit, {
    unit <- input$period_unit
    dates <- do.call(c, lapply(which(!is.na(rounds$start_date)), function(i) {
      start <- rounds$start_date[i]; end <- rounds$end_date[i]
      seq(start, if (is.na(end) || end < start) start else end, by='day')
    }))
    choices <- if (unit == 'day' && length(dates)) {
      dates <- sort(unique(dates),decreasing=TRUE)
      setNames(format(dates,'%Y-%m-%d'),format(dates,'%d %b %Y'))
    } else if (length(dates)) date_period_choices(dates, unit)[-1]
    updateSelectInput(session,'period',choices=c('All periods'='All',choices),selected='All')
  })
  active_value <- function(field) {
    value <- input[[field]]
    if (length(value) && nzchar(value) && value != 'All') value else NULL
  }
  filtered <- reactive({
    x <- rounds
    alert <- active_value('alert')
    if (!is.null(alert)) x <- x[x$alert_id %in% alert,,drop=FALSE]
    for (field in c('gla','district')) {
      value <- active_value(field)
      if (!is.null(value)) x <- x[x[[field]] %in% value,,drop=FALSE]
    }
    for (field in c('post','community')) {
      value <- active_value(field)
      if (!is.null(value)) {
        locations <- if (field == 'post') x$posts else x$communities
        x <- x[vapply(locations, function(items) value %in% items, logical(1)),,drop=FALSE]
      }
    }
    period <- active_value('period'); unit <- active_value('period_unit')
    if (!is.null(period) && !is.null(unit)) {
      end <- x$end_date; end[is.na(end)] <- x$start_date[is.na(end)]
      from <- rna_period_key(x$start_date,unit); to <- rna_period_key(end,unit)
      x <- x[which(!is.na(from) & from <= period & to >= period),,drop=FALSE]
    }
    x
  })
  observeEvent(input$alert, select_latest(active_value('alert')), ignoreNULL=FALSE)
  observeEvent(lapply(filters, active_value), {
    if (any(lengths(lapply(filters, active_value)) > 0L)) selected_round(NULL)
  }, ignoreInit=TRUE)
  observeEvent(input$select_round, {
    req(is.character(input$select_round), length(input$select_round)==1L)
    if (input$select_round %in% filtered()$assessment_id) selected_round(input$select_round)
  })
  any_filter <- reactive(any(vapply(c('alert','gla','district','post','community','period'),
                                     function(field) !is.null(active_value(field)), logical(1))))
  output$round_count <- renderUI({
    if (!any_filter()) return(p(class='rrm-round-count muted','Choose a filter or an alert to list rounds.'))
    n <- nrow(filtered())
    div(class='rrm-round-count', span(sprintf('%s matching %s',n,if (n==1) 'round' else 'rounds')),
        if (n > 1) span('Latest first'))
  })
  output$rounds <- renderUI({
    if (!any_filter()) return(NULL)
    x <- filtered()
    if (!nrow(x)) return(p(class='rrm-round-empty',if (!is.null(active_value('alert')) && !active_value('alert') %in% rounds$alert_id)
      'No Light RNA assessment recorded for this alert.' else 'No assessment rounds match these filters.'))
    div(class='rrm-round-list', role='list', lapply(seq_len(nrow(x)), function(i) {
      communities <- paste(x$communities[[i]],collapse=' and ')
      place <- if (nzchar(communities)) communities else text_or(x$area[i])
      selected <- identical(x$assessment_id[i],selected_round())
      div(role='listitem', tags$button(type='button',class='rrm-alert-link rrm-round-item',
        `data-input`=session$ns('select_round'),`data-alert`=x$assessment_id[i],
        `aria-pressed`=tolower(as.character(selected)),
        if (!is.na(x$district[i])) span(class='rrm-round-district',x$district[i]),
        span(class='rrm-round-place',place),
        span(class='rrm-round-meta',paste(rna_round_date(x$start_date[i],x$end_date[i]),text_or(x$gla[i]),sep=' \u00b7 ')),
        span(class='rrm-round-chevron',`aria-hidden`='true','\u203a')))
    }))
  })
  output$findings <- renderUI({
    x <- filtered(); x <- x[x$assessment_id %in% selected_round(),,drop=FALSE]
    alert <- active_value('alert')
    if (!nrow(x) && (is.null(alert) || alert %in% rounds$alert_id)) return(NULL)
    if (nrow(x)) alert <- x$alert_id[1]
    record <- d$alerts[match(alert,d$alerts$alert_id),,drop=FALSE]
    available <- response_available()
    alert_date <- if (is.na(record$alert_date)) 'Date unavailable' else rna_day(record$alert_date)
    links <- div(class='rrm-linked-alert',
      div(strong('Linked alert'), p(paste(alert,alert_date,sep=' \u00b7 '))),
      tagAppendAttributes(alert_navigation_button('open_alert_record',alert,rna_arrow_label('View alert details')),
                          class='rrm-btn-outline'))
    response <- div(class='rrm-linked-alert rrm-response-link',
      div(strong('Community response'),
        p(if (!is.null(available) && !alert %in% available) 'No response activities recorded for this alert.'
          else 'See the activities reported for this alert.')),
      tagAppendAttributes(alert_navigation_button('open_reported_response',alert,rna_arrow_label('Open in Activity reporting')),
                          class='rrm-btn-primary'))
    if (!nrow(x)) return(div(class='panel rrm-rna-findings',div(class='rrm-findings-head',links),
                             div(class='rrm-findings-body',response)))
    needs <- d$needs[d$needs$assessment_id %in% x$assessment_id,,drop=FALSE]
    kii_n <- rna_counts(needs$kii_summary)
    kii <- ifelse(!is.na(kii_n[,1]),paste(kii_n[,1],'of',kii_n[,2]),
                  ifelse(is.na(needs$kii_summary),'Not reported',needs$kii_summary))
    households <- ifelse(is.na(needs$hesper_serious) | is.na(needs$hesper_valid),
      'Not available',paste(needs$hesper_serious,'of',needs$hesper_valid))
    latest <- rounds$assessment_id[rounds$alert_id %in% alert & !is.na(rounds$start_date)]
    posts <- x$posts[[1]]
    location <- c(if (!is.na(x$district)) paste(x$district,'district'),
                  if (length(posts)) paste(paste(posts,collapse=', '),
                                           if (length(posts) > 1) 'administrative posts' else 'administrative post'))
    method <- if ('method' %in% names(x) && !is.na(x$method)) x$method
    div(class='panel rrm-rna-findings',
      div(class='rrm-findings-head',
        if (!is.null(active_value('alert')) && length(latest) && x$assessment_id[1] == latest[1])
          p(class='rrm-accent rrm-eyebrow','Latest assessment for this alert'),
        h3(class='rrm-findings-title',
           if (length(x$communities[[1]])) paste(x$communities[[1]],collapse=' and ') else text_or(x$area)),
        if (length(location)) p(class='rrm-findings-location',paste(location,collapse=' \u00b7 ')),
        p(class='rrm-findings-meta',paste(c(rna_round_date(x$start_date,x$end_date),text_or(x$gla),method),collapse=' \u00b7 ')),
        links),
      div(class='rrm-findings-body',
        h3('What we learned'),
        if (nrow(needs)) tagList(
          div(class='rrm-evidence-grid',
            rna_evidence_card('Key informant priorities','Informants citing each need in their top three',
                              needs,kii,kii_n[,1],kii_n[,2]),
            rna_evidence_card('Household priorities (HESPER)','Households citing each problem in their top three',
                              needs,households,needs$hesper_serious,needs$hesper_valid)),
          p(class='rrm-evidence-note','Counts describe the interviews conducted in this round.'))
        else p('No findings recorded for this round.'),
        response,
        tags$details(class='rrm-rna-details',tags$summary('Coverage, methods and sources'),
          field('Method',x$method),field('Coverage',x$coverage_note),field('Limitations',x$limitations),
          field('Use in response',x$response_use),field('Source',x$source))))
  })
})
