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

rna_round_date <- function(start, end) {
  if (is.na(start)) return('Date unavailable')
  start_label <- format(start, '%d %b %Y')
  if (is.na(end) || end == start) start_label else paste(start_label, format(end, '%d %b %Y'), sep=' – ')
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
  div(class='dashboard-page rrm-workspace',
    h2('Light RNA'),
    div(class='panel',
      div(class='rrm-workspace-toolbar', h3('Filter assessments'), actionButton(ns('reset'),'Clear filters')),
      div(class='filters rrm-workspace-filters',
        selectInput(ns('gla'),'Responsible GLA',tagged(rounds$gla,'All GLAs')),
        selectInput(ns('period_unit'),'Assessment period',
          c('All dates'='All','Year'='year','Month'='month','Week'='week','Day'='day'),selectize=FALSE),
        selectInput(ns('period'),'Period',c('All periods'='All'),selectize=FALSE),
        selectInput(ns('district'),'District',tagged(rounds$district,'All districts')),
        selectInput(ns('post'),'Administrative post',tagged(unlist(rounds$posts),'All posts')),
        selectInput(ns('community'),'Community',tagged(unlist(rounds$communities),'All communities')))),
    div(class='rrm-rna-grid',
      div(class='panel', h3('Assessment rounds'),
        selectizeInput(ns('alert'),'Find an alert',c('Choose an alert'='',setNames(d$alerts$alert_id,alert_names))),
        uiOutput(ns('rounds'))),
      uiOutput(ns('findings'))))
}

light_rna_server <- function(id, d, open_alert, response_available) moduleServer(id, function(input, output, session) {
  rounds <- rna_rounds(d)
  selected_round <- reactiveVal(NULL)
  filters <- c('gla','period_unit','period','district','post','community')
  clear <- function() for (field in filters) updateSelectInput(session, field, selected='All')
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
  output$rounds <- renderUI({
    if (all(vapply(c('alert','gla','district','post','community','period'),
                   function(field) is.null(active_value(field)), logical(1)))) return(NULL)
    x <- filtered()
    if (!nrow(x)) return(p(if (!is.null(active_value('alert')) && !active_value('alert') %in% rounds$alert_id)
      'No Light RNA assessment recorded for this alert.' else 'No assessment rounds match these filters.'))
    tagList(p(class='muted',sprintf('%s matching %s',nrow(x),if (nrow(x)==1) 'round' else 'rounds')),
      lapply(seq_len(nrow(x)), function(i) {
        communities <- paste(x$communities[[i]],collapse='; ')
        place <- if (nzchar(communities)) communities else text_or(x$area[i])
        div(class='rrm-round-item',
          alert_navigation_button(session$ns('select_round'),x$assessment_id[i],place,
                                  selected=identical(x$assessment_id[i],selected_round())),
          p(class='muted',paste(rna_round_date(x$start_date[i],x$end_date[i]),text_or(x$gla[i]),sep=' · ')))
      }))
  })
  output$findings <- renderUI({
    x <- filtered(); x <- x[x$assessment_id %in% selected_round(),,drop=FALSE]
    alert <- active_value('alert')
    if (!nrow(x) && (is.null(alert) || alert %in% rounds$alert_id)) return(NULL)
    if (nrow(x)) alert <- x$alert_id[1]
    record <- d$alerts[match(alert,d$alerts$alert_id),,drop=FALSE]
    available <- response_available()
    links <- div(class='rrm-linked-alert',div(strong('Linked alert'), p(paste(alert,rna_round_date(record$alert_date,record$alert_date),sep=' · '))),
      alert_navigation_button('open_alert_record',alert,'View alert details'))
    response <- div(class='rrm-linked-alert',div(strong('Community response'),
      if (!is.null(available) && !alert %in% available) p('No response activities recorded for this alert.')),
      alert_navigation_button('open_reported_response',alert,'Open in Activity reporting'))
    if (!nrow(x)) return(div(class='panel',links,response))
    needs <- d$needs[d$needs$assessment_id %in% x$assessment_id,,drop=FALSE]
    needs <- needs[order(needs$rank,na.last=TRUE),,drop=FALSE]
    kii <- ifelse(is.na(needs$kii_summary),'Finding not reported',needs$kii_summary)
    kii <- gsub('([0-9]+)\\s*/\\s*([0-9]+)\\s*(KIs)?','\\1 of \\2 key informants',kii,perl=TRUE)
    households <- ifelse(is.na(needs$hesper_serious) | is.na(needs$hesper_valid),
      'Household finding unavailable',paste(needs$hesper_serious,'of',needs$hesper_valid,'households'))
    evidence <- function(title, values) div(class='rrm-evidence',h4(title),tags$dl(
      lapply(seq_len(nrow(needs)),function(i) tagList(tags$dt(needs$need[i]),tags$dd(values[i])))))
    latest <- rounds$assessment_id[rounds$alert_id %in% alert & !is.na(rounds$start_date)]
    locations <- c(x$district, x$posts[[1]])
    div(class='panel rrm-rna-findings',
      if (!is.null(active_value('alert')) && length(latest) && x$assessment_id[1] == latest[1])
        p(class='rrm-accent','Latest assessment for this alert'),
      h3(if (length(x$communities[[1]])) paste(x$communities[[1]],collapse='; ') else text_or(x$area)),
      p(class='muted',paste(c(locations[!is.na(locations)],rna_round_date(x$start_date,x$end_date),text_or(x$gla)),collapse=' · ')),
      links, h3('What we learned'),
      if (nrow(needs)) div(class='rrm-evidence-grid',evidence('Key informant priorities',kii),
                            evidence('Household findings (HESPER)',households))
      else p('No findings recorded for this round.'),
      response,
      tags$details(tags$summary('Coverage, limitations and sources'),
        field('Coverage',x$coverage_note),field('Limitations',x$limitations),
        field('Use in response',x$response_use),field('Source',x$source)))
  })
})
