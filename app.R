# RRM dashboard — independent R Shiny project based on supplied page mock-ups.
required <- c('shiny','DT','readxl')
missing <- required[!vapply(required,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) stop('Run source("install_packages.R") first. Missing: ',paste(missing,collapse=', '))
library(shiny)
source('config.R',local=TRUE)
source('R/data.R',local=TRUE)
source('R/pages.R',local=TRUE)
source('R/severity.R',local=TRUE)
source('R/household.R',local=TRUE)
source('R/household_ui.R',local=TRUE)
source('R/activity_workbook.R',local=TRUE)
source('R/activity_workbook_ui.R',local=TRUE)
history <- read_history()
d <- apply_alert_severity(read_rrm_data(DATA_MODE))
ui <- fluidPage(
  tags$head(tags$title(paste(APP_TITLE,APP_SUBTITLE,sep=' | ')),tags$meta(name='viewport',content='width=device-width, initial-scale=1'),
    tags$link(rel='stylesheet',type='text/css',href='styles.css'),
    tags$script(src='tables.js',defer='defer')),
  div(class='app-header',div(h1(APP_TITLE),textOutput('page_subtitle',container=tags$p)),
    textOutput('source_label',container=function(...) div(class='mode',...))),
  div(class='app-shell',
    tags$aside(class='app-sidebar',
      radioButtons('page',NULL,choices=setNames(names(page_titles),page_titles),selected='coverage'),
      div(class='sidebar-note',p('Select a page to explore the dashboard.'),
        if(DATA_MODE=='demo') p('Filters and values are design examples. Replace all demo records before use.'))),
    tags$main(class='app-main',lapply(names(page_titles),function(key)
      conditionalPanel(sprintf("input.page == '%s'",key),
        if(key=='alerts') tabsetPanel(id='alerts_view',
          tabPanel('Dashboard records',value='dashboard',page_ui(key,key,d)),
          tabPanel('Historical severity review',value='history',history_ui('history',history)),
          selected=if(DATA_MODE=='demo') 'dashboard' else 'history')
        else if(key=='vulnerability') tabsetPanel(id='vulnerability_view',
          tabPanel('Reviewed profile summaries',value='summaries',page_ui(key,key,d)),
          tabPanel(if(DATA_MODE=='demo') 'Household analysis — draft' else 'Reviewed household aggregates',value='households',household_ui('household',history,allow_synthetic=DATA_MODE=='demo')),
          selected='summaries')
        else if(key=='activity') activity_workbook_ui('activity_excel')
        else page_ui(key,key,d))))),
  tags$footer(class='app-footer',
    conditionalPanel("input.page != 'coverage'",class='footer-meta',
      textOutput('source_footer'),
      div(paste('Core CSV loaded:',attr(d,'loaded_at'),' | Source updated:',d$metadata$source_updated,' | Version:',d$metadata$source_version),
        ' · ',actionLink('methods','Methods and sources'))),
    div(class='footer-brand',
      tags$img(src='reach-logo.png',class='reach-logo reach-logo-footer',
        alt='REACH — Informing more effective humanitarian action',width=308,height=68))))
server <- function(input,output,session) {
  output$page_subtitle <- renderText(paste(page_titles[[if(is.null(input$page)) 'coverage' else input$page]],APP_SUBTITLE,sep=' | '))
  output$source_label <- renderText({
    if(identical(input$page,'activity')) 'REPORTED INTERVENTIONS · WORKBOOK SOURCE'
    else if(identical(input$page,'alerts') && identical(input$alerts_view,'history')) 'HISTORICAL SEVERITY EVIDENCE · SOURCE CLASSIFICATIONS'
    else if(DATA_MODE=='demo') 'DRAFT LAYOUT - DEMO DATA ONLY'
    else 'OPERATIONAL DATA · SOURCE REVIEW REQUIRED'
  })
  output$source_footer <- renderText({
    if(identical(input$page,'activity')) 'Activity reporting uses the supplied workbook. Original review statuses are retained.'
    else if(identical(input$page,'alerts') && identical(input$alerts_view,'history')) 'Historical severity evidence is a separate source. Source classifications and evidence dates are retained.'
    else if(DATA_MODE=='demo') 'Layout mock-up. All figures and DEMO records on this page are illustrative, not operational data.'
    else 'Operational core data. Coverage responsibilities are not evidence of an intervention.'
  })
  for(key in setdiff(names(page_titles),'activity')) page_server(key,key,d)
  history_server('history',history)
  household_server('household',history,allow_synthetic=DATA_MODE=='demo')
  activity_workbook_server('activity_excel',ACTIVITY_WORKBOOK_PATH)
  observeEvent(input$methods,showModal(modalDialog(title='Methods and data sources',
    p(d$metadata$methods_note),
    tags$ul(tags$li('Coverage is evaluated against effective assignment dates.'),
      tags$li('Alert and RNA stages are retained separately. Verified caseloads come from the RNA stage. Related alerts may overlap.'),
      tags$li('RNA selects one assessment round. HESPER counts use the valid household denominator for each need; purposive samples do not estimate prevalence.'),
      tags$li('Vulnerability profiles are reviewed aggregate narratives, never household records. Household sector mappings remain draft; native indicators and draft scenario outputs are distinguished.'),
      tags$li('Historical severities are source classifications. Duplicate/mismatched source IDs are retained and flagged. No estimated caseload text is converted into a verified numeric count.'),
      tags$li('Activity results use source-Validated records with Confirmed alert links and reconciled inputs. Pending records remain available in Records and review. Gross household reach is not unique reach.'),
      tags$li('Activity timing uses the first validated activity per selected alert and tier across all reporting months; it is not automatically the first delivery of assistance.'),
      tags$li('Transfers follow selected alerts and geography; their dates and partners are independent of intervention filters.'),
      tags$li('Core CSV files load at startup. Activity reporting reads the configured Excel workbook, with automatic file checks, session uploads and an explicit review gate. No automatic Kobo synchronization is configured.')),
    p('See README.md and DATA_DICTIONARY.md in the project for the data contract.'),easyClose=TRUE,footer=modalButton('Close'))))
}
shinyApp(ui,server)
