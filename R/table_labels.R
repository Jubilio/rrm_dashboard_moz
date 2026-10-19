## Presentation labels only: source field names and download schemas stay intact.
rrm_column_labels <- function(fields) {
  labels <- c(
    alert_id='Alert ID', arrival_district='Arrival district', movement='Population movement',
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
    from_partner='Transferring partner', to_partner='Receiving partner'
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
