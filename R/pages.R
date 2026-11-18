source('R/table_labels.R', local = TRUE)
source('R/alert_detail.R', local = TRUE)
source('R/alert_summary.R', local = TRUE)
source('R/geography.R', local = TRUE)
source('R/alert_locations.R', local = TRUE)
page_titles <- c(
  coverage = 'Geographic coverage',
  alerts = 'Alerts',
  rna = 'Light RNA',
  vulnerability = 'Vulnerability screening',
  activity = 'Activity reporting'
)
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
      list('arrival', 'Arrival geography', d$routes$arrival),
      list('alert_id', 'Alert ID', d$alerts$alert_id),
      list('trigger', 'Trigger', d$alerts$trigger),
      list('gla', 'GLA', d$alerts$gla),
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
      ! s[[1]] %in% c('arrival', 'alert_id'), specs)
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
    div(
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
          ns('arrival'),
          'Arrival geography',
          choices = c('All verified areas' = 'All', setNames(sort(
            unique(d$routes$arrival)
          ), sort(
            unique(d$routes$arrival)
          ))),
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
      if (key != 'coverage')
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
            gla = 'All GLAs',
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
    ),
    if (key == 'alerts')
      div(
        class = 'kpi-row alert-kpis',
        div(
          class = 'kpi alert-selection',
          selectInput(
            ns('alert_id'),
            'Selected alert',
            choices = all_choices(d$alerts$alert_id),
            selected = if ('DEMO-001' %in% d$alerts$alert_id)
              'DEMO-001'
            else
              'All',
            selectize = FALSE
          ),
          span(class = 'muted', 'Choose Alert ID')
        ),
        uiOutput(ns('metrics'), class = 'alert-metrics')
      )
    else
      uiOutput(ns('metrics')),
    if (key == 'coverage')
      div(
        class = 'two-col coverage-panels',
        div(
          class = 'panel coverage-map-panel',
          h3('Assigned GLA coverage'),
          rrm_map_output(ns('coverage_map')),
          div(class = 'map-legend', span(
            span(class = 'map-swatch', style = 'background:#EE5859;'),
            'District with assigned GLA'
          ), span(
            span(class = 'map-swatch', style = 'background:#D2CBB8;'),
            'No GLA assigned'
          )),
          p(class = 'muted coverage-map-caption',
            'Hover over an area to see the district GLA and role. Click for details. Click a partner icon to show its primary and secondary districts.'),
          uiOutput(ns('map_slot')),
          uiOutput(ns('map_note'))
        ),
        div(
          class = 'panel coverage-responsibilities',
          h3('Partner and area responsibilities'),
          DT::DTOutput(ns('table'))
        )
      )
    else if (key == 'alerts')
      tagList(
        uiOutput(ns('alert_summary')),
        div(class = 'panel', h3('Latest alerts'), DT::DTOutput(ns('latest_alerts'))),
        p(class = 'muted',
          'RRM response is not limited to displacement. Population status describes the affected people; Trigger identifies the crisis event.'),
        div(
          class = 'two-col alert-panels',
          div(
            class = 'panel',
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
            class = 'panel',
            h3('Alert summary and severity evidence'),
            uiOutput(ns('details'))
          )
        ),
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
    observeEvent(input$reset, {
      for (s in specs) {
        choices <- all_choices(s[[3]])
        updateSelectInput(session, s[[1]], selected = choices[1])
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
    filtered <- reactive({
      if (key == 'rna' &&
          nrow(d$assessments))
        req(input$assessment_id, cancelOutput = TRUE)
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
        req(input$as_of, cancelOutput = TRUE)
        x <- x[which(
          !is.na(x$effective_from) &
            x$effective_from <= input$as_of &
            (is.na(x$effective_to) | x$effective_to >= input$as_of)
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
      if (key == 'alerts' &&
          !is.null(input$arrival) && input$arrival != 'All') {
        ids <- d$routes$alert_id[d$routes$arrival == input$arrival]
        x <- x[x$alert_id %in% ids, , drop = FALSE]
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
        filter_equal(x, 'arrival', input$arrival)
      })
      endpoint_links <- reactive({
        req(is.null(location_source$error), cancelOutput = TRUE)
        alert_endpoint_links(selected_routes(),
                             location_source$data,
                             d$metadata$mode)
      })
      if (!is.null(alert_layers))
        output$alert_map <- render_rrm_map({
          req(is.null(location_source$error), cancelOutput = TRUE)
          alert_map_payload(selected_routes(),
                            location_source$data,
                            d$metadata$mode,
                            alert_layers)
        })
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
      y <- filter_equal(y, 'arrival', input$arrival)
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
      switch(
        key,
        alerts = tagList(lapply(seq_len(nrow(x)), function(i)
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
            )
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
            input$map_post
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
