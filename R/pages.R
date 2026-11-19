source('R/table_labels.R', local = TRUE)
source('R/alert_detail.R', local = TRUE)
source('R/alert_summary.R', local = TRUE)
source('R/geography.R', local = TRUE)
source('R/alert_locations.R', local = TRUE)
page_titles <- c(
  coverage = 'RNA Intro',
  alerts = 'Alerts',
  rna = 'Light RNA',
  vulnerability = 'Vulnerability screening',
  activity = 'Activity reporting'
)
# Alert-to-district links (route text), shared by the Alerts district filter and the RNA Intro map.
alert_links_for <- function(d) {
  if (d$metadata$mode == 'demo') return(NULL)
  tryCatch(alert_district_links(d$alerts, d$routes), error = function(e) NULL)
}
alert_district_choices <- function(links, selected = NULL) {
  r <- map_reference()
  codes <- intersect(c(links$pcode, selected), r$pcode[r$level == 'admin2'])
  if (!length(codes)) return(c('All districts' = 'All'))
  labels <- r$label[match(codes, r$pcode)]
  o <- order(labels)
  c('All districts' = 'All', setNames(codes[o], labels[o]))
}
# Period keys for the Alerts date filter: ISO week (2026-W37), month (2026-09) or year (2026).
date_period_key <- function(dates, unit) {
  switch(unit,
         week = ifelse(is.na(dates), NA_character_, format(dates, '%G-W%V')),
         month = format(dates, '%Y-%m'),
         year = format(dates, '%Y'),
         rep(NA_character_, length(dates)))
}
date_period_choices <- function(dates, unit) {
  dates <- sort(unique(dates[!is.na(dates)]), decreasing = TRUE)
  if (!length(dates) || !unit %in% c('week', 'month', 'year'))
    return(c('All periods' = 'All'))
  keys <- date_period_key(dates, unit)
  first <- !duplicated(keys)
  labels <- vapply(which(first), function(i) {
    d <- dates[i]
    switch(unit,
           week = {
             start <- d - (as.integer(format(d, '%u')) - 1L)
             paste0('Week ', as.integer(format(d, '%V')), ' · ',
                    format(start, '%d %b'), ' – ', format(start + 6, '%d %b %Y'))
           },
           month = format(d, '%b %Y'),
           year = format(d, '%Y'))
  }, character(1))
  c('All periods' = 'All', setNames(keys[first], labels))
}
# Community filter choices, optionally limited to one district pcode.
community_choices <- function(tbl, district = 'All') {
  if (!is.null(district) && district != 'All')
    tbl <- tbl[!is.na(tbl$pcode) & tbl$pcode == district, , drop = FALSE]
  c('All communities' = 'All', sort(unique(tbl$community)))
}
# Routes whose arrival text lists the chosen community.
routes_in_community <- function(routes, tbl, community) {
  if (is.null(community) || identical(community, 'All')) return(routes)
  routes[routes$route_id %in% tbl$route_id[tbl$community == community], , drop = FALSE]
}
# Alerts matching the filter selections in `sel` (a list of input values).
# Filters named in `skip` are ignored: this gives the alerts available to that
# filter under all the others, so every Alerts filter can follow the rest.
filter_alerts <- function(x, sel, links, ctbl, skip = character()) {
  on <- function(id) !(id %in% skip) && length(sel[[id]]) == 1L && !identical(sel[[id]], 'All')
  for (id in c('alert_id', 'trigger', 'gla', 'movement'))
    if (on(id) && id %in% names(x)) x <- filter_equal(x, id, sel[[id]])
  if (on('consortium_response_status'))
    x <- if (identical(sel$consortium_response_status, 'Not reported'))
      x[is.na(x$consortium_response_status), , drop = FALSE]
    else
      filter_equal(x, 'consortium_response_status', sel$consortium_response_status)
  if (on('community'))
    x <- x[x$alert_id %in% ctbl$alert_id[ctbl$community == sel$community], , drop = FALSE]
  if (on('date_period') && length(sel$date_unit) == 1L &&
      sel$date_unit %in% c('week', 'month', 'year')) {
    # A chosen period excludes undated alerts; 'All periods' keeps them.
    k <- date_period_key(x$alert_date, sel$date_unit)
    x <- x[!is.na(k) & k == sel$date_period, , drop = FALSE]
  }
  if (on('district')) {
    ids <- if (is.null(links)) character() else links$alert_id[links$pcode == sel$district]
    x <- x[x$alert_id %in% ids, , drop = FALSE]
  }
  x
}
# Choices for each linked Alerts filter: only values found in the alerts that
# match every other filter (e.g. Source = ACF limits District, Trigger, etc. to ACF alerts).
linked_alert_choices <- function(alerts, sel, links, ctbl) {
  avail <- function(id) filter_alerts(alerts, sel, links, ctbl, skip = id)
  labelled <- function(v, all) {
    ch <- all_choices(v)
    names(ch) <- ch
    names(ch)[1] <- all
    ch
  }
  district_ids <- avail('district')$alert_id
  community_ids <- avail('community')$alert_id
  status <- avail('consortium_response_status')$consortium_response_status
  status_values <- c(intersect(c('Yes', 'No', 'Pending go/no-go'), status),
                     if (any(is.na(status))) 'Not reported')
  unit <- if (length(sel$date_unit) == 1L) sel$date_unit else 'All'
  list(
    district = alert_district_choices(links[links$alert_id %in% district_ids, , drop = FALSE],
                                      selected = sel$district),
    community = community_choices(ctbl[ctbl$alert_id %in% community_ids, , drop = FALSE],
                                  if (length(sel$district) == 1L) sel$district else 'All'),
    date_period = date_period_choices(avail('date_period')$alert_date, unit),
    trigger = labelled(avail('trigger')$trigger, 'All triggers'),
    gla = labelled(avail('gla')$gla, 'All sources'),
    movement = labelled(avail('movement')$movement, 'All population statuses'),
    consortium_response_status = labelled(status_values, 'All response statuses')
  )
}

all_choices <- function(x)
  c('All', sort(unique(x[!is.na(x)])))
filter_spec <- function(key, d) {
  switch(
    key,
    coverage = list(
      list('area', 'Area', coverage_area_names(d$coverage, d$metadata$mode)),
      list('partner', 'Partner', d$coverage$partner),
      list('role', 'GLA role', d$coverage$role)
    ),
    alerts = list(
      list('community', 'Community', route_community_table(d$routes)$community),
      list('alert_id', 'Alert ID', d$alerts$alert_id),
      list('trigger', 'Trigger', d$alerts$trigger),
      list('gla', 'Source', d$alerts$gla),
      list('movement', 'Population status', d$alerts$movement),
      list('consortium_response_status', 'Consortium response status',
           c('Yes', 'No', 'Pending go/no-go', 'Not reported'))
    ),
    rna = list(
      list('area', 'Assessed geography', d$assessments$area),
      list('alert_id', 'Alert ID', d$assessments$alert_id),
      list('method', 'Method', d$assessments$method),
      list(
        'assessment_id',
        'Assessment round',
        d$assessments$assessment_id
      )
    ),
    vulnerability = list(
      list('community', 'Community', d$screening$community),
      list('alert_id', 'Alert ID', d$screening$alert_id),
      list('population', 'Population', d$screening$population),
      list('decision', 'Decision', d$screening$decision)
    ),
    activity = list(
      list('area', 'Response geography', d$activities$area),
      list('alert_id', 'Alert ID', d$activities$alert_id),
      list('tier', 'Tier', d$activities$tier),
      list('modality', 'Modality', d$activities$modality),
      list(
        'delivery_partner',
        'Delivery partner',
        d$activities$delivery_partner
      )
    )
  )
}
# Alerts filters are shown as one panel with three labelled groups
# (Location, Period, Alert) and the reset button in the panel header.
group_alert_filters <- function(filters) {
  items <- list()
  collect <- function(x) {
    if (inherits(x, 'shiny.tag')) {
      items[[length(items) + 1L]] <<- x
    } else if (is.list(x)) {
      for (y in x) collect(y)
    }
  }
  collect(filters$children)
  html <- vapply(items, function(x) as.character(x), character(1))
  pick <- function(id) {
    hit <- grepl(paste0('id="alerts-', id, '"'), html, fixed = TRUE)
    if (any(hit)) items[[which(hit)[1]]]
  }
  group <- function(title, ids, cls)
    div(class = paste('filter-group', cls),
        div(class = 'filter-group-title', title),
        div(class = 'filter-group-inputs', lapply(ids, pick)))
  div(
    class = 'filters filter-panel',
    div(class = 'filter-panel-head', span(class = 'filter-panel-title', 'Filters'), pick('reset')),
    div(
      class = 'filter-groups',
      group('Location', c('district', 'community'), 'filter-group-location'),
      group('Period', c('date_unit', 'date_period'), 'filter-group-period'),
      group('Alert', c('trigger', 'gla', 'movement', 'consortium_response_status'),
            'filter-group-alert')
    )
  )
}

page_ui <- function(id, key, d) {
  ns <- NS(id)
  specs <- filter_spec(key, d)
  if (key == 'coverage')
    specs <- specs[c(2, 3, 1)]
  if (key == 'activity')
    specs <- Filter(function(s)
      s[[1]] != 'area', specs)
  if (key == 'vulnerability')
    specs <- Filter(function(s)
      s[[1]] != 'community', specs)
  if (key == 'alerts')
    specs <- Filter(function(s)
      ! s[[1]] %in% c('community', 'alert_id'), specs)
  date_col <- switch(
    key,
    alerts = 'alert_date',
    rna = 'start_date',
    vulnerability = 'decision_date',
    activity = 'start_date'
  )
  source <- switch(
    key,
    coverage = d$coverage,
    alerts = d$alerts,
    rna = d$assessments,
    vulnerability = d$screening,
    activity = d$activities
  )
  dates <- if (key != 'coverage')
    source[[date_col]]
  else
    d$metadata$source_updated
  bounds <- if (length(dates) &&
                any(!is.na(dates)))
    range(dates, na.rm = TRUE)
  else
    c(Sys.Date(), Sys.Date())
  issues <- attr(d, 'validation_issues')
  table_key <- switch(
    key,
    rna = 'assessments',
    vulnerability = 'screening',
    activity = 'activities',
    key
  )
  pending_count <- if (is.null(issues))
    0L
  else
    sum(issues$table %in% c(table_key, if (key == 'rna')
      'needs'))
  div(
    class = paste('dashboard-page', paste0('page-', key)),
    if (pending_count > 0L)
      div(
        class = 'method-strip',
        paste(
          'Data pending:',
          pending_count,
          'missing fields or evidence checks. Unreported values remain unavailable.'
        )
      ),
    if (!key %in% c('coverage', 'alerts', 'vulnerability', 'activity'))
      div(
        class = 'page-heading',
        div(
          span(class = 'eyebrow', 'RAPID RESPONSE MECHANISM'),
          h2(page_titles[[key]])
        ),
        downloadButton(ns('download'), 'Export filtered CSV', class = 'btn-export')
      ),
    if (d$metadata$mode == 'operational' &&
        !nrow(source))
      div(
        class = 'method-strip',
        paste('No operational', switch(
          key,
          coverage = 'responsibility assignments',
          alerts = 'core alert records',
          rna = 'assessment records',
          vulnerability = 'screening decisions',
          activity = 'core activity records'
        ), 'have been supplied for this page.')
      ),
    if (key != 'coverage') (if (key == 'alerts') group_alert_filters else identity)(div(
      class = 'filters',
      if (key == 'activity')
        selectInput(
          ns('area'),
          'Response geography',
          choices = c('All areas' = 'All', setNames(sort(
            unique(d$activities$area)
          ), sort(
            unique(d$activities$area)
          ))),
          selectize = FALSE
        ),
      if (key == 'vulnerability')
        selectInput(
          ns('community'),
          'Community',
          choices = c('All communities' = 'All', setNames(sort(
            unique(d$screening$community)
          ), sort(
            unique(d$screening$community)
          ))),
          selected = if (d$metadata$mode == 'demo' &&
                         'Community B' %in% d$screening$community)
            'Community B'
          else
            'All',
          selectize = FALSE
        ),
      if (key == 'alerts')
        selectInput(
          ns('district'),
          'District',
          choices = alert_district_choices(alert_links_for(d)),
          selectize = FALSE
        ),
      if (key == 'alerts')
        # Communities come from route arrival text and follow the District filter.
        selectInput(
          ns('community'),
          'Community',
          choices = community_choices(route_community_table(d$routes)),
          selectize = FALSE
        ),
      if (key == 'coverage')
        tagList(
          selectInput(
            ns('map_province'),
            'Geography',
            choices = c(
              'All verified areas' = 'All',
              'Cabo Delgado' = 'mz01',
              'Nampula' = 'mz07'
            ),
            selectize = FALSE
          ),
          dateInput(
            ns('as_of'),
            'Coverage as of',
            value = if (is.na(d$metadata$source_updated))
              Sys.Date()
            else
              d$metadata$source_updated,
            format = 'dd M yyyy'
          )
        )
      else if (key == 'alerts')
        # Alert issued date is picked as a week, month or year rather than a date range.
        tagList(
          selectInput(
            ns('date_unit'),
            'Alert issued date',
            choices = c('All dates' = 'All', 'By week' = 'week',
                        'By month' = 'month', 'By year' = 'year'),
            selectize = FALSE
          ),
          selectInput(ns('date_period'), 'Period', choices = c('All periods' = 'All'),
                      selectize = FALSE)
        )
      else
        dateRangeInput(
          ns('dates'),
          switch(
            key,
            alerts = 'Alert issued date',
            rna = 'RNA start date',
            vulnerability = 'Tier 2 decision date',
            activity = 'Intervention start date'
          ),
          start = bounds[1],
          end = bounds[2],
          format = 'dd M yyyy'
        ),
      # Alerts always include undated records (no checkbox; the server defaults to TRUE).
      if (!key %in% c('coverage', 'alerts'))
        checkboxInput(
          ns('include_undated'),
          'Include records without a date',
          value = TRUE
        ),
      lapply(specs, function(s) {
        choices <- all_choices(s[[3]])
        if (key %in% c('coverage', 'alerts', 'vulnerability', 'activity', 'rna')) {
          names(choices) <- choices
          names(choices)[1] <- switch(
            s[[1]],
            partner = 'All partners',
            role = 'Primary / secondary',
            area = 'All areas',
            trigger = 'All triggers',
            gla = 'All sources',
            movement = 'All population statuses',
            consortium_response_status = 'All response statuses',
            alert_id = 'All alerts',
            population = 'IDPs / hosts',
            decision = 'All decisions',
            tier = 'All tiers',
            modality = 'All modalities',
            delivery_partner = 'All partners',
            assessment_id = 'All assessments',
            method = 'All methods'
          )
        }
        selected <- if (s[[1]] == 'alert_id' &&
                        key %in% c('alerts', 'activity', 'vulnerability') &&
                        'DEMO-001' %in% choices)
          'DEMO-001'
        else
          choices[1]
        selectInput(
          ns(s[[1]]),
          s[[2]],
          choices = choices,
          selected = selected,
          selectize = FALSE
        )
      }),
      actionButton(ns('reset'), 'Reset filters', class = 'btn-reset')
    )),
    # Alerts has no KPI cards or alert selector; the Alert summary covers the filtered alerts.
    if (!key %in% c('alerts', 'coverage'))
      uiOutput(ns('metrics')),
    if (key == 'coverage')
      div(
        class = 'two-col coverage-panels',
        div(
          class = 'panel coverage-map-panel',
          h3('Assigned GLA coverage'),
          rrm_map_output(ns('coverage_map')),
          p(class = 'muted coverage-map-caption',
            'Hover over a district to see its GLA. Select a district to open its alerts. Click a partner icon to show its primary and secondary districts.'),
          uiOutput(ns('map_slot')),
          uiOutput(ns('map_note'))
        ),
        div(
          class = 'panel coverage-intro-text',
          h3('Rapid Needs Assessment (RNA)'),
          # Placeholder: replace with the RNA introduction text.
          p(class = 'muted', 'RNA introduction text to be added.')
        )
      )
    else if (key == 'alerts')
      tagList(
        uiOutput(ns('alert_summary')),
        div(
          class = 'two-col alert-panels',
          div(
            class = 'panel alert-map-panel',
            h3('Origin to arrival and targeted locations'),
            rrm_map_output(ns('alert_map')),
            div(class = 'map-legend', span(
              span(class = 'map-swatch map-swatch-point', style = 'background:#58585A;'),
              'Origin'
            ), span(
              span(class = 'map-swatch map-swatch-point', style = 'background:#EE5859;'),
              'Arrival'
            )),
            uiOutput(ns('alert_map_note'))
          ),
          div(
            class = 'panel alert-map-selection',
            h3('Alert summary and severity evidence'),
            uiOutput(ns('details'), `aria-live` = 'polite')
          )
        ),
        div(class = 'panel', h3('Latest alerts'), DT::DTOutput(ns('latest_alerts'))),
        p(class = 'muted',
          'RRM response is not limited to displacement. Population status describes the affected people; Trigger identifies the crisis event.'),
        tags$details(
          class = 'alert-evidence-details',
          tags$summary('Alert records and calculation evidence'),
          div(class = 'panel', h3('Route schematic'), uiOutput(ns('routes'))),
          div(
            class = 'panel',
            h3('Origin and arrival coordinate review'),
            DT::DTOutput(ns('endpoint_review'))
          ),
          downloadButton(ns('download'), 'Export filtered CSV', class = 'btn-export'),
          div(
            class = 'panel',
            h3('Stage-specific alert evidence'),
            DT::DTOutput(ns('table'))
          ),
          div(
            class = 'panel',
            h3('Calculated domain ratings and evidence provenance'),
            DT::DTOutput(ns('severity_calc'))
          )
        )
      )
    else if (key == 'rna')
      div(
        class = 'two-col',
        div(
          class = 'panel',
          h3('Top needs · separate evidence streams'),
          DT::DTOutput(ns('table')),
          p(
            class = 'muted',
            'KII priorities and HESPER counts remain separate. Counts describe only this purposive sample.'
          )
        ),
        div(
          class = 'panel',
          h3('Coverage, methods and use in response'),
          uiOutput(ns('details'))
        )
      )
    else if (key == 'vulnerability')
      tagList(
        uiOutput(ns('details')),
        div(
          class = 'panel',
          h3('Tier 2 decisions by alert and community'),
          DT::DTOutput(ns('table')),
          tags$details(
            class = 'decision-export',
            tags$summary('Export decision records'),
            downloadButton(ns('download'), 'Export filtered CSV', class = 'btn-export')
          )
        )
      )
    else
      tagList(
        div(
          class = 'panel activity-events',
          textOutput(ns('table_title'), container = tags$h3),
          DT::DTOutput(ns('table')),
          tags$details(
            class = 'activity-export',
            tags$summary('Export intervention records'),
            downloadButton(ns('download'), 'Export filtered CSV', class = 'btn-export')
          )
        ),
        div(
          class = 'two-col activity-notes',
          div(
            class = 'panel',
            h3('Delay and response timing'),
            p(
              class = 'muted',
              'Days from alert = intervention start date minus linked alert issue date, in calendar days (including weekends and holidays). Example: alert on 1 September, start on 5 September = 4 days; same-day start = 0 days. The end date is not used in this calculation. Missing dates leave the delay unavailable.'
            ),
            p(class = 'muted', 'Start date is the reported first day of the intervention. This core view does not collect an activity end date. First response shows the minimum days from alert among completed interventions in the current selection, measured against each intervention\'s own linked alert. Across multiple alerts, it is not one shared response timeline. It is not necessarily the first delivery of assistance.'),
            uiOutput(ns('details'))
          ),
          div(
            class = 'panel',
            h3('Transfer of response responsibilities'),
            uiOutput(ns('transfer_summary'))
          )
        )
      ),
    if (key != 'coverage')
      div(class = 'method-strip', switch(
        key,
        coverage = 'Coverage uses effective assignment dates. Unknown responsibilities remain explicit. Map boundaries are supplied geographic context; locality points do not establish response locations.',
        alerts = 'Arrival geography selects alerts; KPI caseloads remain alert-wide. Counts across alerts may overlap and do not represent unique people. RNA totals exclude alerts awaiting verification.',
        rna = 'Select one assessment for round-specific indicators, or All assessments to browse findings across rounds. All-round summaries are not pooled; no extrapolation to the affected population. Reviewed ranking is supplied by the source.',
        vulnerability = 'Only reviewed aggregate profile summaries are shown. No household scores, registries, individual results or eligibility lists.',
        activity = 'KPIs count completed interventions only. Gross HH reach may include repeat assistance. Kits and consultations are service outputs; donor breakdowns remain in the source.'
      ))
  )
}
kpi <- function(title, value, note)
  div(
    class = 'kpi',
    span(class = 'kpi-title', title),
    div(class = 'kpi-value', value),
    span(class = 'muted', note)
  )
kpi_row <- function(...)
  div(class = 'kpi-row', ...)
empty_ui <- function()
  div(class = 'empty',
      h4('No matching records'),
      p('Adjust the filters or reset the selection.'))
text_or <- function(x, fallback = 'Not reported') {
  if (!length(x) || is.na(x) || !nzchar(x)) {
    fallback
  } else {
    as.character(x)
  }
}
field <- function(label, value)
  p(strong(paste0(label, ': ')), text_or(value))
reviewed_profile_rows <- function(x)
  x[which(x$reviewed == 'TRUE' &
            !is.na(x$profile_summary) &
            nzchar(trimws(x$profile_summary))), , drop = FALSE]
profile_review_status <- function(x, population) {
  x <- x[which(x$population == population), , drop = FALSE]
  if (!nrow(x))
    return('Unavailable')
  n <- nrow(reviewed_profile_rows(x))
  if (n == nrow(x))
    'Reviewed'
  else if (n > 0)
    'Partly reviewed'
  else
    'Pending review'
}
page_server <- function(id, key, d, h=NULL, activity=NULL)
  moduleServer(id, function(input, output, session) {
    specs <- filter_spec(key, d)
    alert_links <- if (key %in% c('alerts', 'coverage')) alert_links_for(d) else NULL
    community_tbl <- if (key == 'alerts') route_community_table(d$routes) else NULL
    alert_selection <- reactive(list(
      alert_id = input$alert_id, district = input$district, community = input$community,
      date_unit = input$date_unit, date_period = input$date_period,
      trigger = input$trigger, gla = input$gla, movement = input$movement,
      consortium_response_status = input$consortium_response_status
    ))
    if (key == 'alerts') {
      # Linked filters: each menu lists only values present under the other filters.
      sent <- new.env()
      observe({
        sel <- alert_selection()
        choices <- linked_alert_choices(d$alerts, sel, alert_links, community_tbl)
        for (id in names(choices)) {
          ch <- choices[[id]]
          current <- sel[[id]]
          keep <- if (length(current) == 1L && current %in% ch) current else 'All'
          if (identical(sent[[id]], ch) && identical(keep, current)) next
          sent[[id]] <- ch
          updateSelectInput(session, id, choices = ch, selected = keep)
        }
      })
    }
    observeEvent(input$reset, {
      for (s in specs) {
        choices <- all_choices(s[[3]])
        updateSelectInput(session, s[[1]], selected = choices[1])
      }
      if (key == 'alerts') {
        updateSelectInput(session, 'district', selected = 'All')
        updateSelectInput(session, 'date_unit', selected = 'All')
      }
      if (key == 'coverage') {
        updateDateInput(session,
                        'as_of',
                        value = if (is.na(d$metadata$source_updated))
                          Sys.Date()
                        else
                          d$metadata$source_updated)
        updateSelectInput(session, 'map_province', selected = 'All')
        updateSelectInput(session, 'map_district', selected = 'All')
        updateSelectInput(session, 'map_post', selected = 'All')
      }
      else {
        x <- switch(
          key,
          alerts = d$alerts$alert_date,
          rna = d$assessments$start_date,
          vulnerability = d$screening$decision_date,
          activity = d$activities$start_date
        )
        b <- if (length(x) &&
                 any(!is.na(x)))
          range(x, na.rm = TRUE)
        else
          c(Sys.Date(), Sys.Date())
        updateDateRangeInput(session, 'dates', start = b[1], end = b[2])
        updateCheckboxInput(session, 'include_undated', value = TRUE)
      }
    })
    if (key == 'alerts')
      observeEvent(input$date_unit, {
        updateSelectInput(session, 'date_period',
                          label = switch(input$date_unit, week = 'Week', month = 'Month',
                                         year = 'Year', 'Period'),
                          selected = 'All')
      })
    filtered <- reactive({
      if (key == 'rna' &&
          nrow(d$assessments))
        req(input$assessment_id, cancelOutput = TRUE)
      if (key == 'alerts')
        return(filter_alerts(d$alerts, alert_selection(), alert_links, community_tbl))
      x <- switch(
        key,
        coverage = d$coverage,
        alerts = d$alerts,
        rna = d$assessments,
        vulnerability = d$screening,
        activity = d$activities
      )
      for (s in specs)
        if (key == 'coverage' && s[[1]] == 'area')
          x <- filter_coverage_area(x, input$area, d$metadata$mode)
        else if (key == 'alerts' && s[[1]] == 'consortium_response_status' &&
                 identical(input$consortium_response_status, 'Not reported'))
          x <- x[is.na(x$consortium_response_status), , drop = FALSE]
        else if (s[[1]] %in% names(x))
          x <- filter_equal(x, s[[1]], input[[s[[1]]]])
      if (key == 'coverage') {
        as_of <- if (!is.null(input$as_of)) input$as_of
          else if (!is.na(d$metadata$source_updated)) d$metadata$source_updated
          else Sys.Date()
        x <- x[which(
          !is.na(x$effective_from) &
            x$effective_from <= as_of &
            (is.na(x$effective_to) | x$effective_to >= as_of)
        ), , drop = FALSE]
      } else {
        col <- switch(
          key,
          alerts = 'alert_date',
          rna = 'start_date',
          vulnerability = 'decision_date',
          activity = 'start_date'
        )
        x <- filter_date(x,
                         col,
                         input$dates,
                         include_missing = !identical(input$include_undated, FALSE))
      }
      x
    })
    output$table_title <- renderText({
      ids <- unique(filtered()$alert_id)
      if (length(ids) == 1)
        paste('Interventions linked to', ids)
      else
        'Interventions linked to selected alerts'
    })
    output$transfer_summary <- renderUI({
      x <- filtered()
      y <- d$transfers[d$transfers$alert_id %in% x$alert_id, , drop = FALSE]
      y <- filter_equal(y, 'area', input$area)
      if (!nrow(y))
        return(p(
          class = 'muted',
          'No responsibility transfers reported for this selection.'
        ))
      tagList(lapply(seq_len(nrow(y)), function(i)
        p(
          class = 'transfer-entry',
          paste(
            y$component[i],
            'transferred from',
            y$from_partner[i],
            'to',
            y$to_partner[i],
            'on',
            format(y$transfer_date[i], '%d %b %Y')
          ),
          if (!is.na(y$note[i]))
            tagList(br(), span(class = 'muted', y$note[i]))
        )))
    })
    output$alert_summary <- renderUI({
      req(key == 'alerts')
      alert_summary_ui(alert_summary_values(filtered(),d$activities))
    })
    output$latest_alerts <- DT::renderDT({
      req(key == 'alerts')
      latest_alert_table(filtered(), session$ns('open_alert_detail'))
    })
    observeEvent(input$open_alert_detail, {
      req(key == 'alerts', length(input$open_alert_detail)==1L,
          input$open_alert_detail %in% filtered()$alert_id)
      show_alert_detail(input$open_alert_detail,d,h,activity)
    })
    observeEvent(input$latest_alerts_rows_selected, {
      req(key == 'alerts', length(input$latest_alerts_rows_selected) == 1L)
      rows <- latest_alert_rows(filtered())
      selected <- input$latest_alerts_rows_selected
      req(selected >= 1L, selected <= nrow(rows))
      show_alert_detail(rows$alert_id[selected],d,h,activity)
      DT::selectRows(DT::dataTableProxy('latest_alerts',session=session),NULL)
    })
    output$metrics <- renderUI({
      x <- filtered()
      if (!nrow(x))
        return(empty_ui())
      switch(
        key,
        coverage = kpi_row(
          kpi(
            'Primary GLAs',
            length(unique(x$partner[x$role == 'Primary'])),
            if (d$metadata$mode == 'demo')
              'Illustrative assignments'
            else
              'Distinct assigned partners'
          ),
          kpi(
            'Secondary GLAs',
            length(unique(x$partner[x$role == 'Secondary'])),
            if (d$metadata$mode == 'demo')
              'Illustrative assignments'
            else
              'Distinct assigned partners'
          ),
          kpi(
            'Assigned areas',
            if (!is.null(input$area) && input$area != 'All')
              as.integer(any(x$role != 'Unknown', na.rm = TRUE))
            else
              length(coverage_area_names(x[x$role != 'Unknown', , drop = FALSE],
                                        d$metadata$mode)),
            'Distinct coverage areas'
          ),
          kpi(
            'Coverage source',
            paste(unique(x$source_version), collapse = ' / '),
            'Confirm effective dates'
          )
        ),
        alerts = tagList(
          kpi(
            'Verified people',
            fmt(known_sum(x$rna_people[!is.na(x$rna_severity) &
                                         !is.na(x$rna_evidence_date)])),
            'RNA records with severity and evidence date'
          ),
          kpi(
            'Verified households',
            fmt(known_sum(x$rna_hh[!is.na(x$rna_severity) &
                                     !is.na(x$rna_evidence_date)])),
            'RNA records with severity and evidence date'
          ),
          kpi(
            'Severity',
            if (nrow(x) == 1)
              paste(
                text_or(x$alert_severity),
                text_or(x$rna_severity, 'Pending'),
                sep = ' / '
              )
            else
              'See evidence table',
            'Alert stage / RNA stage'
          )
        ),
        rna = {
          # When multiple assessment rounds are selected, avoid showing first-row
          # metrics or summing potentially overlapping, non-probability samples.
          rounds <- unique(x$assessment_id[!is.na(x$assessment_id)])
          if (length(rounds) != 1L) {
            kpi_row(
              kpi(
                'Assessment rounds',
                length(rounds),
                'Selected rounds; see findings below'
              ),
              kpi(
                'Date range',
                if (any(!is.na(x$start_date)))
                  paste(format(
                    min(x$start_date, na.rm = TRUE), '%d %b %Y'
                  ), '–', format(
                    max(x$start_date, na.rm = TRUE), '%d %b %Y'
                  ))
                else
                  'Unavailable',
                'Across selected rounds'
              ),
              kpi(
                'Method',
                paste(unique(x$method[!is.na(x$method)]), collapse = ' / '),
                'Methods may differ across rounds'
              ),
              kpi(
                'Sample',
                'See individual rounds',
                'Do not sum potentially overlapping samples'
              )
            )
          } else
            kpi_row(
              kpi(
                'Selected assessment',
                x$assessment_id[1],
                paste('Linked to', x$alert_id[1])
              ),
              kpi(
                'Assessment dates',
                paste(text_or(format(
                  x$start_date[1], '%d %b'
                )), text_or(format(
                  x$end_date[1], '%d %b'
                )), sep = ' – '),
                'One assessment round'
              ),
              kpi(
                'Method',
                text_or(x$method[1]),
                'Evidence streams kept separate'
              ),
              kpi(
                'Sample',
                paste(vapply(
                  c(x$kii_sample[1], x$hh_sample[1], x$observation_sample[1]),
                  fmt,
                  character(1)
                ), collapse = ' / '),
                'KIIs / HH / observations'
              )
            )
        },
        vulnerability = {
          alerts <- unique(x$alert_id)
          profile_note <- function(population)
            if (nrow(reviewed_profile_rows(x[which(x$population == population), , drop =
                                             FALSE]))) {
              if (d$metadata$mode == 'demo')
                'Illustrative profile below'
              else
                'Reviewed aggregate below'
            } else
              'No reviewed summary available'
          kpi_row(
            kpi(
              if (length(alerts) == 1)
                'Selected alert'
              else
                'Selected alerts',
              if (length(alerts) == 1)
                alerts
              else
                length(alerts),
              paste(unique(x$community), collapse = ' / ')
            ),
            kpi(
              'Tier 2 decision',
              if (length(unique(x$decision)) == 1)
                unique(x$decision)
              else
                'Mixed',
              'Decision recorded in source'
            ),
            kpi(
              'IDP profile summary',
              profile_review_status(x, 'IDP'),
              profile_note('IDP')
            ),
            kpi(
              'Host profile summary',
              profile_review_status(x, 'Host'),
              profile_note('Host')
            )
          )
        },
        activity = {
          t <- activity_totals(x)
          kpi_row(
            kpi(
              'Gross household reach',
              fmt(t$hh),
              'Sum of completed HH assistance'
            ),
            kpi('Kits distributed', fmt(t$kits), 'Service output; not HH'),
            kpi(
              'Clinic consultations',
              fmt(t$consultations),
              'Visits; not unique people'
            ),
            kpi(
              'First response',
              if (is.na(t$days))
                'Unavailable'
              else
                paste(t$days, 'days'),
              'Earliest completed, filtered intervention'
            )
          )
        }
      )
    })
    display_table <- reactive({
      x <- filtered()
      switch(
        key,
        coverage = x[c('partner',
                       'area',
                       'role',
                       'effective_from',
                       'effective_to',
                       'source_version')],
        alerts = {
          y <- x[c(
          'alert_id',
          'alert_date',
          'consortium_response_status',
          'alert_hh',
          'alert_people',
          'alert_severity',
          'alert_evidence_date',
          'rna_hh',
          'rna_people',
          'rna_severity',
          'rna_evidence_date'
          )]
          y$consortium_response_status <- vapply(y$consortium_response_status,
                                                text_or, character(1))
          y
        },
        rna = {
          y <- d$needs[d$needs$assessment_id %in% x$assessment_id, , drop = FALSE]
          y <- y[order(y$rank, na.last = TRUE), , drop = FALSE]
          result <- data.frame(
            Rank = ifelse(is.na(y$rank), 'Not ranked', as.character(y$rank)),
            Need = y$need,
            `KII summary` = y$kii_summary,
            `HESPER households` = ifelse(
              is.na(y$hesper_serious) |
                is.na(y$hesper_valid),
              'Unavailable',
              paste(y$hesper_serious, 'of', y$hesper_valid, 'serious need')
            ),
            check.names = FALSE
          )
          if (length(unique(x$assessment_id)) > 1L)
            result <- data.frame(
              `Assessment round` = y$assessment_id,
              `Alert ID` = x$alert_id[match(y$assessment_id, x$assessment_id)],
              result,
              check.names = FALSE
            )
          result
        },
        vulnerability = unique(x[c(
          'alert_id',
          'community',
          'decision_date',
          'population',
          'decision',
          'reason',
          'reviewed'
        )]),
        activity = x[intersect(c(
          'event_id',
          'alert_id',
          'area',
          'community',
          'community_source',
          'tier',
          'modality',
          'start_date',
          'quantity',
          'unit',
          'measure_type',
          'delivery_status',
          'delivery_partner',
          'donor',
          'days_from_alert',
          'delay_reason'
        ), names(x))]
      )
    })
    output$table <- DT::renderDT({
      if (key == 'coverage')
        rrm_datatable(
          width = '100%',
          display_table()[c('partner', 'area', 'role')],
          colnames = c('Partner', 'Area', 'Role'),
          rownames = FALSE,
          escape = TRUE,
          options = list(
            pageLength = 4,
            scrollX = TRUE,
            autoWidth = TRUE,
            ordering = FALSE,
            language = list(emptyTable = 'No matching records'),
            dom = 'tp'
          )
        )
      else if (key == 'vulnerability') {
        x <- unique(filtered()[c('alert_id', 'community', 'decision', 'reason')])
        y <- data.frame(
          `Alert / community` = paste(x$alert_id, x$community, sep = ' / '),
          Decision = x$decision,
          Reason = x$reason,
          check.names = FALSE
        )
        rrm_datatable(
          width = '100%',
          y,
          rownames = FALSE,
          escape = TRUE,
          options = list(
            pageLength = 8,
            scrollX = TRUE,
            autoWidth = TRUE,
            dom = 'tp',
            language = list(emptyTable = 'No decisions available for this selection.')
          )
        )
      }
      else if (key == 'activity') {
        x <- filtered()
        y <- data.frame(
          Event = x$event_id,
          `Alert ID` = x$alert_id,
          `Response geography` = x$area,
          Community = if ('community' %in% names(x))
            vapply(x$community, text_or, character(1)) else
              rep('Not reported', nrow(x)),
          Tier = x$tier,
          Modality = x$modality,
          `Start date` = vapply(format(x$start_date, '%d %b %Y'), text_or, character(1)),
          Scope = paste(
            vapply(x$quantity, fmt, character(1)),
            vapply(x$unit, text_or, character(1))
          ),
          Partner = x$delivery_partner,
          `Days from alert` = x$days_from_alert,
          `Delay reason` = ifelse(is.na(x$delay_reason),'',x$delay_reason),
          check.names = FALSE
        )
        rrm_datatable(
          width = '100%',
          y,
          rownames = FALSE,
          escape = TRUE,
          options = list(
            pageLength = 8,
            scrollX = TRUE,
            autoWidth = TRUE,
            dom = 'tp',
            language = list(emptyTable = 'No interventions available for this selection.')
          )
        )
      }
      else
        rrm_datatable(
          width = '100%',
          display_table(),
          rownames = FALSE,
          escape = TRUE,
          options = list(
            pageLength = 8,
            scrollX = TRUE,
            autoWidth = TRUE,
            language = list(emptyTable = 'No matching records'),
            dom = 'ftp'
          )
        )
    })
    output$severity_calc <- DT::renderDT({
      y <- d$severity_calculations
      if (is.null(y) ||
          !nrow(y))
        return(
          rrm_datatable(
            width = '100%',
            data.frame(Note = 'No calculation inputs supplied; displayed severity is source-recorded.'),
            rownames = FALSE,
            escape = TRUE,
            options = list(dom = 't')
          )
        )
      y <- y[y$alert_id %in% filtered()$alert_id, , drop = FALSE]
      rrm_datatable(
        width = '100%',
        y,
        rownames = FALSE,
        escape = TRUE,
        options = list(scrollX = TRUE, pageLength = 5)
      )
    })
    output$download <- downloadHandler(
      filename = function()
        paste0('rrm_', key, '_', d$metadata$mode, '_', Sys.Date(), '.csv'),
      content = function(file) {
        # Export only the deliberate display columns; never export unreviewed profile text.
        write.csv(
          display_table(),
          file,
          row.names = FALSE,
          na = '',
          fileEncoding = 'UTF-8'
        )
      }
    )
    if (key == 'alerts') {
      alert_layers <- tryCatch(
        read_map_layers(),
        error = function(e)
          NULL
      )
      location_source <- tryCatch(
        list(
          data = if (!is.null(d$route_locations))
            d$route_locations
          else
            read_alert_locations(d$metadata$mode),
          error = NULL
        ),
        error = function(e)
          list(data = NULL, error = conditionMessage(e))
      )
      selected_routes <- reactive({
        x <- d$routes[d$routes$alert_id %in% filtered()$alert_id, , drop = FALSE]
        routes_in_community(x, community_tbl, input$community)
      })
      endpoint_links <- reactive({
        req(is.null(location_source$error), cancelOutput = TRUE)
        alert_endpoint_links(selected_routes(),
                             location_source$data,
                             d$metadata$mode)
      })
      map_data <- reactive({
        if (is.null(alert_layers) || !is.null(location_source$error))
          return(NULL)
        payload <- alert_map_payload(selected_routes(), location_source$data,
                                     d$metadata$mode, alert_layers)
        # The District filter highlights and frames that district on the map.
        payload$selected_district <- if (is.null(input$district)) 'All' else input$district
        payload$selection_input <- session$ns('alert_map_selection')
        payload
      })
      output$alert_map <- render_rrm_map(req(map_data(), cancelOutput = TRUE))
      map_features <- reactive({
        payload <- map_data()
        features <- lapply(c(payload$markers$features, payload$connections$features),
                           function(feature) feature$properties)
        names(features) <- vapply(features, function(feature) feature$selection_id, character(1))
        features
      })
      selected_feature <- reactiveVal(NULL)
      observeEvent(input$alert_map_selection, {
        id <- input$alert_map_selection
        if (is.character(id) && length(id) == 1L && id %in% names(map_features()))
          selected_feature(id)
      })
      observeEvent(input$clear_alert_map_selection, selected_feature(NULL))
      observeEvent(map_features(), {
        id <- selected_feature()
        if (!is.null(id) && !id %in% names(map_features()))
          selected_feature(NULL)
      }, ignoreNULL = FALSE)
      output$alert_map_note <- renderUI({
        if (!is.null(location_source$error))
          return(p(
            class = 'muted',
            paste(
              'Route coordinate source unavailable:',
              location_source$error
            )
          ))
        if (is.null(alert_layers))
          return(
            p(
              class = 'muted',
              'Map boundaries are unavailable. Check the supplied geography files.'
            )
          )
        x <- endpoint_links()
        p(
          class = 'muted alert-map-status',
          if (d$metadata$mode == 'demo')
            'DEMO POINTS · Fictional coordinates and movements. '
          else
            '',
          paste(sum(x$mapped), 'of', nrow(x), 'route endpoints mapped.'),
          ' Lines show origin–arrival connections, not the travelled path.',
          if (any(!x$mapped))
            ' Missing or unconfirmed locations remain in coordinate review.'
        )
      })
      output$endpoint_review <- DT::renderDT({
        if (!is.null(location_source$error))
          return(
            rrm_datatable(
              width = '100%',
              data.frame(Note = location_source$error),
              rownames = FALSE,
              escape = TRUE,
              options = list(dom = 't')
            )
          )
        rrm_datatable(
          width = '100%',
          endpoint_links(),
          rownames = FALSE,
          escape = TRUE,
          options = list(pageLength = 6, scrollX = TRUE)
        )
      })
    }
    output$routes <- renderUI({
      x <- filtered()
      if (!nrow(x))
        return(empty_ui())
      y <- d$routes[d$routes$alert_id %in% x$alert_id, , drop = FALSE]
      y <- routes_in_community(y, community_tbl, input$community)
      if (!nrow(y))
        return(empty_ui())
      groups <- split(y,
                      interaction(
                        y$alert_id,
                        y$origin,
                        drop = TRUE,
                        lex.order = TRUE
                      ))
      tagList(
        p(class = 'schematic-caption', 'Schematic route display · not a geographic map'),
        lapply(groups, function(z) {
          positions <- (seq_len(nrow(z)) - .5) / nrow(z) * 100
          tagList(
            if (length(unique(y$alert_id)) > 1)
              h4(z$alert_id[1]),
            div(
              class = 'route-diagram',
              style = paste0('height:', max(260, nrow(z) * 125), 'px;'),
              tags$svg(
                class = 'route-connections',
                viewBox = '0 0 100 100',
                preserveAspectRatio = 'none',
                `aria-hidden` = 'true',
                lapply(positions, function(pos)
                  tags$line(
                    x1 = 29,
                    y1 = 50,
                    x2 = 64,
                    y2 = pos,
                    stroke = '#58585A',
                    `stroke-width` = '0.4'
                  ))
              ),
              div(class = 'route-origin', h4(z$origin[1])),
              lapply(seq_len(nrow(z)), function(i)
                div(
                  class = 'route-arrival',
                  style = paste0('top:', positions[i], '%;'),
                  h4(z$arrival[i]),
                  p(paste(fmt(z$people[i]), 'people')),
                  p(class = 'route-target', paste(
                    'RRM targeted:', text_or(z$targeted[i], 'Unknown')
                  ))
                ))
            )
          )
        }),
        p(
          class = 'muted route-footnote',
          'Numbers are route-specific. Missing route counts remain unavailable; totals are never copied to individual routes.'
        )
      )
    })
    output$details <- renderUI({
      x <- filtered()
      if (!nrow(x))
        return(empty_ui())
      if (key == 'alerts') {
        features <- map_features()
        if (!length(features))
          return(p('No routes or locations are mapped for the current filters. Open an alert from Latest alerts to view its details.'))
        id <- selected_feature()
        if (is.null(id) || !id %in% names(features))
          return(p('Select a point or a route on the map to see its alert summary.'))
        feature <- features[[id]]
        alert_ids <- if (startsWith(id, 'point:')) feature$alert_ids else feature$alert_id
        x <- x[x$alert_id %in% alert_ids, , drop = FALSE]
      }
      switch(
        key,
        alerts = tagList(
          div(class = 'alert-map-selection-header',
              h4(if (startsWith(id, 'point:'))
                paste(if (feature$endpoint == 'origin') 'Origin' else 'Arrival', feature$name, sep = ' · ')
              else
                paste(feature$origin, '→', feature$arrival)),
              actionButton(session$ns('clear_alert_map_selection'), 'Clear selection', class = 'btn-sm')),
          lapply(seq_len(nrow(x)), function(i)
          div(
            class = 'evidence alert-evidence',
            h4(paste(x$alert_id[i], text_or(
              format(x$alert_date[i], '%d %b %Y')
            ), sep = ' | ')),
            field('Consortium response status',
                  text_or(x$consortium_response_status[i])),
            p(
              paste0(
                'Trigger: ',
                text_or(x$trigger[i]),
                '. Population status: ',
                text_or(x$movement[i]),
                '.'
              ),
              br(),
              'Focus: conditions at the arrival locations.'
            ),
            div(
              class = 'alert-stage-evidence',
              field(
                'Alert stage',
                paste(
                  text_or(x$alert_severity[i]),
                  '· provisional',
                  fmt(x$alert_hh[i]),
                  'HH · evidence',
                  text_or(x$alert_evidence_date[i])
                )
              ),
              field(
                'RNA stage',
                paste(
                  text_or(x$rna_severity[i], 'Pending'),
                  '· verified',
                  fmt(x$rna_hh[i]),
                  'HH · evidence',
                  text_or(x$rna_evidence_date[i])
                )
              ),
              field('Rationale', x$rationale[i])
            ),
            div(
              class = 'alert-related',
              field('Related alert', x$related_alert[i]),
              field('Overlap', x$overlap_status[i])
            ),
            alert_detail_button(x$alert_id[i], session$ns('open_alert_detail'))
          ))),
        rna = tagList(lapply(seq_len(nrow(x)), function(i)
          tagList(
            field('Coverage', x$coverage_note[i]),
            field('Method and limitations', x$limitations[i]),
            field('Evidence to response', x$response_use[i]),
            field('Source', x$source[i])
          ))),
        vulnerability = {
          y <- reviewed_profile_rows(x)
          populations <- unique(c('IDP', 'Host', x$population[!is.na(x$population)]))
          div(class = 'two-col vulnerability-profiles', lapply(populations, function(population) {
            z <- y[which(y$population == population), , drop = FALSE]
            div(
              class = 'panel profile-summary',
              h3(
                paste(
                  population,
                  'profiles associated with highest concurrence'
                )
              ),
              if (!nrow(z))
                p(
                  class = 'muted',
                  'No reviewed aggregate profile summary is available for this selection.'
                )
              else
                tagList(lapply(seq_len(nrow(z)), function(i)
                  div(
                    class = 'profile-entry',
                    strong(
                      if (d$metadata$mode == 'demo')
                        'Illustrative summary only'
                      else
                        'Reviewed aggregate summary'
                    ),
                    p(z$profile_summary[i]),
                    p(
                      class = 'muted profile-provenance',
                      paste(
                        'Analysis version:',
                        text_or(z$analysis_version[i]),
                        '| Review date:',
                        text_or(z$review_date[i])
                      )
                    ),
                    if (length(unique(paste(
                      y$alert_id, y$community
                    ))) > 1)
                      p(class = 'muted', paste(z$alert_id[i], z$community[i], sep = ' · '))
                  )))
            )
          }))
        },
        activity = {
          y <- x[which(x$delivery_status == 'Completed'), , drop = FALSE]
          if (!nrow(y))
            return(p('No completed interventions in the selection.'))
          combinations <- unique(y[c('alert_id', 'tier')])
          tagList(lapply(seq_len(nrow(combinations)), function(i) {
            z <- y[which(
              y$alert_id == combinations$alert_id[i] &
                (
                  if (is.na(combinations$tier[i]))
                    is.na(y$tier)
                  else!is.na(y$tier) & y$tier == combinations$tier[i]
                )
            ), , drop = FALSE]
            reasons <- unique(z$delay_reason[!is.na(z$delay_reason)])
            div(
              class = 'evidence',
              h4(
                paste(combinations$alert_id[i], combinations$tier[i], sep = ' · ')
              ),
              field(
                'First completed response in selection',
                if (any(!is.na(z$days_from_alert)))
                  paste(min(z$days_from_alert, na.rm = TRUE), 'days after alert')
                else
                  'Unavailable'
              ),
              p(strong('Delay reason: '),paste(reasons, collapse = '; '))
            )
          }))
        }
      )
    })
    output$transfers <- DT::renderDT({
      x <- filtered()
      y <- d$transfers[d$transfers$alert_id %in% x$alert_id, , drop = FALSE]
      y <- filter_equal(y, 'area', input$area)
      # Transfer dates and partners are independent of intervention-date and modality filters.
      rrm_datatable(
        width = '100%',
        y[c('component',
            'from_partner',
            'to_partner',
            'transfer_date',
            'note')],
        escape = TRUE,
        rownames = FALSE,
        options = list(
          dom = 't',
          scrollX = TRUE,
          language = list(emptyTable = 'No responsibility transfers reported for selected alerts and geography.')
        )
      )
    })
    if (key == 'coverage') {
      layers <- tryCatch(
        read_map_layers(),
        error = function(e) {
          warning(conditionMessage(e))
          NULL
        }
      )
      observeEvent(input$map_province, {
        r <- map_reference()
        r <- r[r$level == 'admin2', , drop = FALSE]
        if (input$map_province != 'All')
          r <- r[r$parent_pcode == input$map_province, , drop = FALSE]
        choices <- c('All' = 'All', setNames(r$pcode, r$label))
        selected <- if (!is.null(input$map_district) &&
                        input$map_district %in% choices)
          input$map_district
        else
          'All'
        updateSelectInput(session,
                          'map_district',
                          choices = choices,
                          selected = selected)
      })
      observeEvent(list(input$map_province, input$map_district), {
        r <- map_reference()
        r <- r[r$level == 'admin3', , drop = FALSE]
        if (!is.null(input$map_province) &&
            input$map_province != 'All')
          r <- r[substr(r$pcode, 1, 4) == input$map_province, , drop = FALSE]
        if (!is.null(input$map_district) &&
            input$map_district != 'All')
          r <- r[r$parent_pcode == input$map_district, , drop = FALSE]
        choices <- c('All' = 'All', setNames(r$pcode, paste(r$label, r$pcode, sep =
                                                              ' · ')))
        selected <- if (!is.null(input$map_post) &&
                        input$map_post %in% choices)
          input$map_post
        else
          'All'
        updateSelectInput(session,
                          'map_post',
                          choices = choices,
                          selected = selected)
      })
      output$map_slot <- renderUI({
        if (is.null(layers))
          return(div(
            class = 'map-placeholder',
            h4('Geographic map unavailable'),
            p('Check the supplied geography files.')
          ))
        NULL
      })
      if (!is.null(layers)) {
        map_data <- reactive({
          district <- input$map_district
          if (d$metadata$mode != 'demo' && !is.null(input$area) && input$area != 'All') {
            selected_code <- coverage_district_codes(data.frame(area = input$area))
            if (!is.na(selected_code)) district <- selected_code
          }
          coverage_map_payload(
            filtered(),
            d$metadata$mode,
            input$map_province,
            district,
            layers,
            input$map_post,
            alert_links = alert_links
          )
        })
        output$coverage_map <- render_rrm_map({
          map_data()
        })
        output$map_note <- renderUI({
          n <- map_data()$unmapped
          if (n > 0)
            p(
              class = 'map-notice',
              paste(
                n,
                'filtered assignment record(s) contain an area that could not be linked to a listed district. Recognised districts are still shown; source records remain in the table and KPIs.'
              )
            )
        })
      }
    }
  })
