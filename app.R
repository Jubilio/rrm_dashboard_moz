# RRM dashboard — independent R Shiny project based on supplied page mock-ups.
required <- c('shiny','DT')
missing <- required[!vapply(required,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) stop('Run source("install_packages.R") first. Missing: ',paste(missing,collapse=', '))
library(shiny)
source('config.R',local=TRUE)
source('R/data.R',local=TRUE)
source('R/pages.R',local=TRUE)
source('R/severity.R',local=TRUE)
source('R/household.R',local=TRUE)
source('R/household_ui.R',local=TRUE)
history <- read_history()
d <- apply_alert_severity(read_rrm_data(DATA_MODE))
ui <- fluidPage(
  tags$head(tags$title(paste(APP_TITLE,APP_SUBTITLE,sep=' | ')),tags$meta(name='viewport',content='width=device-width, initial-scale=1'),
    tags$link(rel='stylesheet',type='text/css',href='styles.css')),
  div(class='app-header',div(h1(APP_TITLE),p(APP_SUBTITLE)),
    div(class=if(DATA_MODE=='demo') 'mode demo' else 'mode live',if(DATA_MODE=='demo') 'DEMO RECORDS · HISTORICAL REVIEW SEPARATE' else 'OPERATIONAL RECORDS · HISTORICAL REVIEW SEPARATE')),
  div(class='app-shell',
    tags$aside(class='app-sidebar',span(class='eyebrow','WORKSPACE'),
      radioButtons('page',NULL,choices=setNames(names(page_titles),page_titles),selected='coverage'),
      div(class='sidebar-note',h4('Evidence to action'),p('Coverage · alerts · assessment · screening · response'),
        if(DATA_MODE=='demo') p('Dashboard records are illustrative. Historical workbook review and synthetic household scenarios are labelled separately.')),
      actionLink('methods','Methods & data sources')),
    tags$main(class='app-main',lapply(names(page_titles),function(key)
      conditionalPanel(sprintf("input.page == '%s'",key),
        if(key=='alerts') tabsetPanel(tabPanel('Historical severity review',history_ui('history',history)),tabPanel('Dashboard records',page_ui(key,key,d)))
        else if(key=='vulnerability') tabsetPanel(tabPanel('Household analysis — draft',household_ui('household',history)),tabPanel('Reviewed profile summaries',page_ui(key,key,d)))
        else page_ui(key,key,d))))),
  tags$footer(class='app-footer',
    div(class='footer-meta',
      div(if(DATA_MODE=='demo') 'Demo dashboard records · historical source review and synthetic scenarios labelled separately' else 'Aggregate operational reporting'),
      div(paste('Last successful load:',attr(d,'loaded_at'),' | Source updated:',d$metadata$source_updated,' | Version:',d$metadata$source_version))),
    div(class='footer-brand',
      tags$img(src='reach-logo.png',class='reach-logo reach-logo-footer',
        alt='REACH — Informing more effective humanitarian action',width=308,height=68))))
server <- function(input,output,session) {
  for(key in names(page_titles)) page_server(key,key,d)
  history_server('history',history)
  household_server('household',history)
  observeEvent(input$methods,showModal(modalDialog(title='Methods and data sources',
    p(d$metadata$methods_note),
    tags$ul(tags$li('Coverage is evaluated against effective assignment dates.'),
      tags$li('Alert and RNA stages are retained separately. Verified caseloads come from the RNA stage. Related alerts may overlap.'),
      tags$li('RNA selects one assessment round. HESPER counts use the valid household denominator for each need; purposive samples do not estimate prevalence.'),
      tags$li('Vulnerability profiles are reviewed aggregate narratives, never household records. Household sector mappings remain draft; native indicators and draft scenario outputs are distinguished.'),
      tags$li('Historical severities are source classifications. Duplicate/mismatched source IDs are retained and flagged. No estimated caseload text is converted into a verified numeric count.'),
      tags$li('Activity KPIs sum completed assistance or outputs with matching units and measure types. Gross household reach is not unique reach.'),
      tags$li('First response is the minimum elapsed time from linked alert date among the completed interventions in the current filter selection.'),
      tags$li('Transfers follow selected alerts and geography; their dates and partners are independent of intervention filters.'),
      tags$li('CSV files load at application startup. Restart the application after replacing data. No automatic Kobo synchronization is configured.')),
    p('See README.md and DATA_DICTIONARY.md in the project for the data contract.'),easyClose=TRUE,footer=modalButton('Close'))))
}
shinyApp(ui,server)
