## Presentation labels only: source field names and download schemas stay intact.
rrm_column_labels <- function(fields) {
  labels <- c(
    consortium_response_status='Consortium response status',
    alert_id='Alert ID', arrival_district='Arrival district', movement='Population status (source)',
    rna_done_raw='RNA completed (source value)', rna_done='RNA completed',
    tier2_done='Tier 2 completed', tier2_date='Tier 2 date',
    recorded_alert_severity='Alert severity (source)', recorded_latest_severity='Latest severity (source)',
    alert_caseload_text='Alert caseload (source text)', latest_caseload_text='Latest caseload (source text)',
    linked='Linked alert flag (source)', registry_quality='Registry quality notes',
    days_open='Days since alert', provisional_status='Provisional alert status',
    source_change='Recorded severity change', record_key='Evidence record ID',
    source_alert_id='Source alert ID', linked_alert_id='Linked alert ID', link_status='Alert link status',
    conditions_rating='Humanitarian conditions rating', protection_rating='Protection / threat rating',
    recorded_override='Override recorded in source', domain_recalculation='Severity from domain ratings',
    source_rule_recalculation='Severity from source rules', recorded_severity='Severity recorded in source',
    calculation_agrees='Calculation matches source', completeness='Evidence completeness',
    confidence='Source confidence', caseload_text='Caseload (source text)',
    source_override_asserted='Override asserted in source',
    coordinate_source='Coordinate source', coordinate_status='Coordinate status',
    from_partner='Transferring partner', to_partner='Receiving partner',
    gla='Source'
  )
  acronyms <- c('id','rna','idp','hh','kii','hesper','pwd','fcs','hhs','jmp','gla','csv','gps')
  vapply(fields, function(field) {
    if (field %in% names(labels)) return(unname(labels[[field]]))
    if (!grepl('_', field, fixed=TRUE)) {
      if (tolower(field) %in% acronyms) return(toupper(field))
      return(paste0(toupper(substr(field, 1, 1)), substring(field, 2)))
    }
    words <- strsplit(field, '_', fixed=TRUE)[[1]]
    words <- vapply(words, function(word) {
      if (tolower(word) %in% acronyms) toupper(word)
      else if (tolower(word) == 'tier2') 'Tier 2'
      else word
    }, character(1))
    label <- paste(words, collapse=' ')
    paste0(toupper(substr(label, 1, 1)), substring(label, 2))
  }, character(1), USE.NAMES=FALSE)
}

rrm_datatable <- function(data, ...) {
  args <- list(...)
  if (is.null(args$colnames)) args$colnames <- rrm_column_labels(colnames(data))
  do.call(DT::datatable, c(list(data=data), args))
}

latest_alert_rows <- function(x) {
  # ISO dates sort chronologically; missing issue dates remain at the end.
  x <- x[order(-as.numeric(as.Date(x$alert_date)), x$alert_id, na.last=TRUE), , drop=FALSE]
  fields <- intersect(c('alert_date','alert_id','organisation','gla','arrival_district',
                        'trigger','population','alert_severity','recorded_alert_severity',
                        'consortium_response_status'), names(x))
  x[fields]
}

alert_detail_button <- function(id, detail_input) {
  htmltools::tags$button(type='button', class='btn btn-default btn-sm rrm-alert-detail-button',
    `data-input`=detail_input, `data-alert`=id,
    `aria-label`=paste('View details for', id), 'View details')
}

latest_alert_table <- function(x, detail_input=NULL) {
  rows <- latest_alert_rows(x)
  escape <- TRUE
  if (!is.null(detail_input)) {
    buttons <- vapply(rows$alert_id, function(id)
      as.character(alert_detail_button(id, detail_input)), character(1))
    rows <- data.frame(Details=buttons,rows,check.names=FALSE)
    escape <- seq_len(ncol(rows))[-1L]
  }
  table <- rrm_datatable(rows, width='100%', rownames=FALSE, escape=escape,
    selection='none',
    options=list(pageLength=5, scrollX=TRUE, ordering=FALSE, dom='tp',
                 language=list(emptyTable='No alerts available for this selection.')))
  if ('alert_severity' %in% names(rows)) {
    fills <- c(Low='#E6F2E0', Moderate='#E6DDCA', High='#F49695', Critical='#C0474A')
    ink <- c('#232323', '#232323', '#232323', '#FFFFFF')
    table <- DT::formatStyle(table, 'alert_severity',
      backgroundColor=DT::styleEqual(names(fills), unname(fills)),
      color=DT::styleEqual(names(fills), ink))
  }
  table
}
