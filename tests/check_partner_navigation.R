library(shiny)
source('config.R'); source('R/data.R'); source('R/pages.R'); source('R/activity_workbook.R')
source('R/activity_workbook_ui.R'); source('R/response_reporting.R'); source('R/light_rna.R')
source('R/source_links.R')
d <- read_rrm_data('demo')
# A second, later round for DEMO-001, with its own source document.
extra <- d$assessments[d$assessments$assessment_id == 'DEMO-RNA-01', , drop=FALSE]
extra$assessment_id <- 'DEMO-RNA-09'; extra$start_date <- extra$end_date <- as.Date('2026-10-20')
extra$source <- 'DEMO later round summary'
d$assessments <- rbind(d$assessments, extra)
rounds <- d$assessments[d$assessments$alert_id == 'DEMO-001', , drop=FALSE]
stopifnot(nrow(rounds) >= 2L)
rounds <- rounds[order(rounds$start_date, decreasing=TRUE), , drop=FALSE]
latest <- rounds$assessment_id[1]; older <- rounds$assessment_id[2]

# Light RNA opens the exact round asked for, not the latest one for the alert.
request <- reactiveVal(NULL)
links <- data.frame(filename=d$assessments$source[d$assessments$assessment_id == older],
                    url='https://example.org/brief.pdf', stringsAsFactors=FALSE)
testServer(light_rna_server, args=list(d=d, open_alert=function() NULL,
    response_available=function() character(), open_round=request, source_links=links), {
  html <- function(value) if (is.null(value)) '' else value$html
  request(list(id=older, at=1)); session$flushReact()
  session$setInputs(alert='DEMO-001'); session$flushReact()
  stopifnot(identical(selected_round(), older))
  stopifnot(grepl('View full assessment brief (PDF)', html(output$findings), fixed=TRUE),
            grepl('https://example.org/brief.pdf', html(output$findings), fixed=TRUE))
  session$setInputs(select_round=latest)
  stopifnot(identical(selected_round(), latest),
            !grepl('View full assessment brief', html(output$findings), fixed=TRUE))
  # Asking again for the older round returns to it, even with the same alert selected.
  request(list(id=older, at=2)); session$flushReact()
  stopifnot(identical(selected_round(), older))
})

# Alert detail: one link per Light RNA round and the original alert PDF when shared.
h <- list(registry=data.frame(alert_id='DEMO-001', alert_source='Alert DEMO-001.pdf', stringsAsFactors=FALSE),
          source_links=data.frame(filename='Alert DEMO-001.pdf', url='https://example.org/alert.pdf', stringsAsFactors=FALSE))
ui <- as.character(alert_detail_ui('DEMO-001', alert_detail_data('DEMO-001', d, h)))
stopifnot(grepl('View original alert (PDF)', ui, fixed=TRUE), grepl('https://example.org/alert.pdf', ui, fixed=TRUE),
          all(vapply(rounds$assessment_id, function(id)
            grepl(sprintf('data-input="open_rna_round" data-alert="%s"', id), ui, fixed=TRUE), logical(1))),
          grepl(sprintf('Linked Light RNA rounds (%s)', nrow(rounds)), ui, fixed=TRUE))
# No link is invented: a missing or non-HTTPS address shows no PDF button.
h$source_links$url <- 'http://example.org/alert.pdf'
stopifnot(!grepl('View original alert', as.character(alert_detail_ui('DEMO-001', alert_detail_data('DEMO-001', d, h))), fixed=TRUE))
h$source_links <- NULL
stopifnot(!grepl('View original alert', as.character(alert_detail_ui('DEMO-001', alert_detail_data('DEMO-001', d, h))), fixed=TRUE))

# Help (i) on Alerts, Light RNA and Activity reporting; About the RRM is paged.
stopifnot(grepl('How to use this tab', as.character(page_ui('alerts', 'alerts', d)), fixed=TRUE),
          grepl('Understand the severity rating.', as.character(page_ui('alerts', 'alerts', d)), fixed=TRUE),
          grepl('How to use this tab', as.character(light_rna_ui('rna', d)), fixed=TRUE))
about <- as.character(page_ui('coverage', 'coverage', d))
stopifnot(grepl('About the Rapid Response Mechanism', about, fixed=TRUE), grepl('Next page', about, fixed=TRUE),
          page_titles[['coverage']] == 'About the RRM')

# Partners see Response by community only; Data review is internal.
partner <- as.character(activity_workbook_ui('activity', show_review=FALSE))
internal <- as.character(activity_workbook_ui('activity', show_review=TRUE))
stopifnot(!grepl('>Data review<', partner, fixed=TRUE), grepl('>Data review<', internal, fixed=TRUE),
          grepl('How counts work', partner, fixed=TRUE), grepl('Methods and counting definitions', partner, fixed=TRUE),
          grepl('How to use this tab', partner, fixed=TRUE))
message('PASS: exact Light RNA rounds, return links, shared PDFs, help text, About the RRM and partner Activity view.')
