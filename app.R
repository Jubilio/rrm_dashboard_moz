# RRM dashboard — independent R Shiny project based on supplied page mock-ups.
required <- c('shiny', 'DT', 'readxl')
missing <- required[!vapply(required, requireNamespace, logical(1), quietly =
                              TRUE)]
if (length(missing))
  stop('Run source("install_packages.R") first. Missing: ',
       paste(missing, collapse = ', '))
library(shiny)
source('config.R', local = TRUE)
source('R/footer_branding.R', local = TRUE)
source('R/data.R', local = TRUE)
source('R/pages.R', local = TRUE)
source('R/light_rna.R', local = TRUE)
source('R/input_workbook.R', local = TRUE)
source('R/severity.R', local = TRUE)
source('R/household.R', local = TRUE)
source('R/household_ui.R', local = TRUE)
source('R/activity_workbook.R', local = TRUE)
source('R/activity_workbook_ui.R', local = TRUE)
history <- read_history()
d <- load_dashboard_input(INPUT_WORKBOOK_PATH, DATA_MODE, mode_explicit =
                            nzchar(Sys.getenv('RRM_DATA_MODE')))
DATA_MODE <- d$metadata$mode
if (is.null(attr(d, 'input_workbook')))
  d <- apply_alert_severity(d)
d <- add_activity_communities(d, if (file.exists('data/activity_snapshot/activities.csv'))
  read_activity_snapshot()$activities else NULL)
d <- harmonise_alert_triggers(d)
alert_activity <- if (file.exists('data/activity_snapshot/activities.csv'))
  prepare_activity_data(read_activity_snapshot()) else NULL
# Warm process-wide caches at start so the first visitor does not wait for them.
invisible(tryCatch(read_map_layers(), error = function(e) NULL))
invisible(tryCatch(cached_settlement_points(), error = function(e) NULL))
invisible(tryCatch(warm_activity_cache(ACTIVITY_WORKBOOK_PATH), error = function(e) NULL))
ui <- fluidPage(
  tags$head(
    tags$title(paste(APP_TITLE, APP_SUBTITLE, sep = ' | ')),
    tags$meta(name = 'viewport', content = 'width=device-width, initial-scale=1'),
    tags$meta(name = 'description', content = APP_DESCRIPTION),
    tags$meta(name = 'theme-color', content = '#A62C32'),
    tags$link(rel = 'icon', href = 'favicon.svg', type = 'image/svg+xml'),
    tags$link(rel = 'icon', href = 'favicon-32.png', type = 'image/png', sizes = '32x32'),
    tags$link(rel = 'shortcut icon', href = 'favicon.ico'),
    tags$link(rel = 'apple-touch-icon', href = 'apple-touch-icon.png'),
    # Link preview (WhatsApp, Teams, Slack, LinkedIn, X).
    tags$meta(property = 'og:type', content = 'website'),
    tags$meta(property = 'og:site_name', content = APP_TITLE),
    tags$meta(property = 'og:title', content = paste(APP_TITLE, APP_SUBTITLE, sep = ' | ')),
    tags$meta(property = 'og:description', content = APP_DESCRIPTION),
    tags$meta(property = 'og:url', content = APP_URL),
    tags$meta(property = 'og:image', content = paste0(APP_URL, 'og-image.png')),
    tags$meta(property = 'og:image:width', content = '1200'),
    tags$meta(property = 'og:image:height', content = '630'),
    tags$meta(property = 'og:image:alt', content = 'RRM dashboard, Cabo Delgado, Mozambique: curved arrows from origin to arrival with circles sized by people arriving.'),
    tags$meta(name = 'twitter:card', content = 'summary_large_image'),
    tags$link(rel = 'stylesheet', type = 'text/css', href = paste0('styles.css?v=', as.numeric(file.info('www/styles.css')$mtime))),
    tags$script(src = paste0('tables.js?v=', unname(tools::md5sum('www/tables.js'))), defer = 'defer')
  ),
  div(
    class = 'app-header',
    div(h1(APP_TITLE), textOutput('page_subtitle', container = tags$p)),
    textOutput(
      'source_label',
      container = function(...)
        div(class = 'mode', ...)
    )
  ),
  div(
    class = 'app-shell',
    tags$aside(
      class = 'app-sidebar',
      radioButtons(
        'page',
        NULL,
        choices = setNames(names(page_titles), page_titles),
        selected = 'coverage'
      )
    ),
    tags$main(class = 'app-main', lapply(names(page_titles), function(key)
      conditionalPanel(
        sprintf("input.page == '%s'", key),
        if (key == 'vulnerability')
          tabsetPanel(
            id = 'vulnerability_view',
            tabPanel('Reviewed profile summaries', value = 'summaries', page_ui(key, key, d)),
            tabPanel(
              if (DATA_MODE == 'demo')
                'Household analysis — draft'
              else
                'Reviewed household aggregates',
              value = 'households',
              household_ui('household', history, allow_synthetic = DATA_MODE == 'demo')
            ),
            selected = 'summaries'
          )
        else if (key == 'activity')
          activity_workbook_ui('activity_excel')
        else if (key == 'rna')
          light_rna_ui('rna', d)
        else
          page_ui(key, key, d)
      )))
  ),
  tags$footer(
    class = 'app-footer',
    style = 'flex-wrap:wrap;',
    conditionalPanel(
      "input.page != 'coverage'",
      class = 'footer-meta',
      textOutput('source_footer'),
      div(
        paste(
          'Core input loaded:',
          attr(d, 'loaded_at'),
          ' | Source updated:',
          d$metadata$source_updated
        ),
        ' · ',
        actionLink('methods', 'Methods and sources')
      )
    ),
    div(
      class = 'footer-brand',
      tags$img(
        src = 'reach-logo.png',
        class = 'reach-logo reach-logo-footer',
        alt = 'REACH — Informing more effective humanitarian action',
        width = 308,
        height = 68
      )
    ),
    footer_acknowledgements()
  )
)
server <- function(input, output, session) {
  output$page_subtitle <- renderText(paste(page_titles[[if (is.null(input$page))
    'coverage'
    else
      input$page]], APP_SUBTITLE, sep = ' | '))
  workbook_view <- reactive(identical(input$page, 'activity'))
  output$source_label <- renderText({
    if (workbook_view())
      'REPORTED INTERVENTIONS · WORKBOOK SOURCE'
    else if (DATA_MODE == 'demo')
      'DRAFT LAYOUT - DEMO DATA ONLY'
    else
      'OPERATIONAL DATA'
  })
  output$source_footer <- renderText({
    if (workbook_view())
      'Activity reporting uses the supplied workbook. Original review statuses are retained.'
    else if (DATA_MODE == 'demo')
      'Demonstration data: fictional records and illustrative results only.'
    else
      'Operational core data. Coverage responsibilities are not evidence of an intervention.'
  })
  for (key in setdiff(names(page_titles),c('rna','activity')))
    page_server(key, key, d, h=history, activity=alert_activity)
  household_server('household', history, allow_synthetic = DATA_MODE == 'demo')
  response_available <- activity_workbook_server('activity_excel', ACTIVITY_WORKBOOK_PATH,
    core=d, open_alert=reactive(input$open_reported_response))
  light_rna_server('rna', d, reactive(input$open_light_rna), response_available)
  known_alert <- function(id) is.character(id) && length(id)==1L && id %in% d$alerts$alert_id
  observeEvent(input$open_light_rna, {
    req(known_alert(input$open_light_rna))
    removeModal()
    updateRadioButtons(session,'page',selected='rna')
  })
  observeEvent(input$open_reported_response, {
    req(known_alert(input$open_reported_response))
    removeModal()
    updateRadioButtons(session,'page',selected='activity')
  })
  observeEvent(input$open_alert_record, {
    req(known_alert(input$open_alert_record))
    updateRadioButtons(session,'page',selected='alerts')
    show_alert_detail(input$open_alert_record,d,history,alert_activity)
  })
  # Clicking a district on the RNA Intro map opens the Alerts page filtered to that district.
  district_alert_links <- reactive(alert_links_for(d))
  observeEvent(input$map_district_alerts, {
    code <- input$map_district_alerts
    req(is.character(code), length(code) == 1L, !is.na(code), code != 'All')
    choices <- alert_district_choices(district_alert_links(), code)
    req(code %in% choices)
    updateRadioButtons(session, 'page', selected = 'alerts')
    updateSelectInput(session, 'alerts-district', choices = choices, selected = code)
    for (filter in c('community', 'date_unit', 'date_period', 'trigger', 'gla',
                     'movement', 'delivery_status'))
      updateSelectInput(session, paste0('alerts-', filter), selected = 'All')
  })
  observeEvent(input$methods, showModal(
    modalDialog(
      title = 'Methods and data sources',
      p(d$metadata$methods_note),
      tags$ul(
        tags$li('Coverage is evaluated against effective assignment dates.'),
        tags$li(
          'Alert and RNA stages are retained separately. Verified caseloads come from the RNA stage. Related alerts may overlap.'
        ),
        tags$li(
          'Light RNA shows findings for one selected assessment round. HESPER counts use the valid household denominator for each need. Purposive samples do not estimate prevalence.'
        ),
        tags$li(
          'Vulnerability profiles are reviewed aggregate narratives, never household records. Household sector mappings remain draft; native indicators and draft scenario outputs are distinguished.'
        ),
        tags$li(
          'Historical severities are source classifications. Duplicate/mismatched source IDs are retained and flagged. No estimated caseload text is converted into a verified numeric count.'
        ),
        tags$li(
          'Activity results use source-Validated records with Confirmed alert links and reconciled inputs. Pending records remain available in Records and review. Gross household reach is not unique reach.'
        ),
        tags$li(
          'Activity timing uses the first validated activity per selected alert and tier across all reporting months; it is not automatically the first delivery of assistance.'
        ),
        tags$li(
          'Transfers follow selected alerts and geography; their dates and partners are independent of intervention filters.'
        ),
        tags$li(
          'Core input loads at startup from the configured consolidated workbook or CSV files. Activity reporting reads the configured Excel workbook, with automatic file checks, session uploads and an explicit review gate. No automatic Kobo synchronization is configured.'
        )
      ),
      p(
        'See README.md, docs/DATA_ENTRY.md and docs/reference/DATA_DICTIONARY.md for guidance and the data contract.'
      ),
      easyClose = TRUE,
      footer = modalButton('Close')
    )
  ))
}
shinyApp(ui, server)
