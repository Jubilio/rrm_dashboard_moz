# Exact alert links only. Missing values remain blank; caseloads are never pooled.
alert_detail_rows <- function(x, id, field='alert_id') {
  if (is.null(x) || !field %in% names(x)) return(data.frame())
  x[which(!is.na(x[[field]]) & x[[field]] == id), , drop=FALSE]
}

alert_detail_data <- function(id, d=NULL, h=NULL, activity=NULL) {
  core <- alert_detail_rows(d$alerts, id)
  registry <- alert_detail_rows(h$registry, id)
  assessments <- alert_detail_rows(d$assessments, id)
  needs <- if (!is.null(d$needs))
    d$needs[d$needs$assessment_id %in% assessments$assessment_id, , drop=FALSE] else data.frame()
  if (nrow(needs)) needs <- needs[order(needs$assessment_id, needs$rank, na.last=TRUE), , drop=FALSE]
  evidence <- alert_detail_rows(h$evidence, id, 'linked_alert_id')
  if (nrow(evidence)) {
    # Proposed/conflicting ID matches stay in the review table, not this detail.
    evidence <- evidence[which(evidence$source_alert_id == id &
      !is.na(evidence$link_status) &
      !grepl('review required|unresolved', evidence$link_status, ignore.case=TRUE)), , drop=FALSE]
  }
  reported <- alert_detail_rows(activity$activities, id)
  if (nrow(reported)) reported <- reported[which(reported$link_status == 'Confirmed' &
    reported$eligible %in% TRUE), , drop=FALSE]
  alert_pdf <- if (nrow(registry)) source_document_url(registry$alert_source,
    if ('alert_source_url' %in% names(registry)) registry$alert_source_url else NA, h$source_links) else NA_character_
  # Every element is a table; the shared alert PDF travels as an attribute.
  structure(list(core=core, registry=registry, assessments=assessments, needs=needs,
       evidence=evidence, assistance=alert_detail_rows(d$activities, id),
       reported_assistance=reported), alert_pdf=alert_pdf)
}

alert_detail_cell <- function(x) {
  if (!length(x) || is.na(x[1])) return('')
  as.character(x[1])
}

alert_detail_table <- function(x, fields) {
  columns <- intersect(names(fields), names(x))
  shiny::div(class='alert-detail-table', shiny::tags$table(
    class='table table-striped',
    shiny::tags$thead(shiny::tags$tr(lapply(columns, function(n)
      shiny::tags$th(unname(fields[n]))))),
    shiny::tags$tbody(lapply(seq_len(nrow(x)), function(i)
      shiny::tags$tr(lapply(columns, function(n)
        shiny::tags$td(alert_detail_cell(x[[n]][i]))))))))
}

alert_detail_ui <- function(id, detail) {
  core <- detail$core; registry <- detail$registry
  value <- function(field, historical=NULL) {
    v <- if (field %in% names(core) && nrow(core)) alert_detail_cell(core[[field]]) else ''
    if (!nzchar(v) && !is.null(historical) && historical %in% names(registry) && nrow(registry))
      v <- alert_detail_cell(registry[[historical]])
    v
  }
  summary <- data.frame(
    field=c('Alert ID','Alert date','RNA date','RNA evidence date','Tier 2 date','Source',
            'Arrival district','Trigger','Trigger (source text)','Population status','Consortium response status',
            'Alert households','Alert people','RNA households','RNA people',
            'Alert caseload (source text)','Latest caseload (source text)',
            'Alert severity','RNA severity','Latest recorded severity'),
    value=c(id,value('alert_date','alert_date'),value('rna_date','rna_date'),value('rna_evidence_date'),
      value('tier2_date','tier2_date'),value('gla','organisation'),
      value('arrival_district','arrival_district'),value('trigger'),value('trigger_detail'),value('movement','movement'),
      value('consortium_response_status','consortium_response_status'),
      value('alert_hh'),value('alert_people'),value('rna_hh'),value('rna_people'),
      value('alert_caseload_text','alert_caseload_text'),value('latest_caseload_text','latest_caseload_text'),
      value('alert_severity','recorded_alert_severity'),value('rna_severity'),
      value('recorded_latest_severity','recorded_latest_severity')),
    stringsAsFactors=FALSE)
  rounds <- detail$assessments
  if (nrow(rounds) && 'start_date' %in% names(rounds))
    rounds <- rounds[order(rounds$start_date, decreasing=TRUE, na.last=TRUE), , drop=FALSE]
  round_label <- function(i) {
    when <- if ('start_date' %in% names(rounds)) rna_round_date(rounds$start_date[i],
      if ('end_date' %in% names(rounds)) rounds$end_date[i] else NA) else ''
    place <- if ('area' %in% names(rounds) && !is.na(rounds$area[i])) rounds$area[i] else rounds$assessment_id[i]
    paste(c(place, when), collapse=' \u00b7 ')
  }
  links <- shiny::div(class='alert-detail-links',
    document_link(attr(detail, 'alert_pdf'), 'View original alert (PDF)'),
    if (nrow(rounds)) shiny::div(class='alert-detail-rounds',
      shiny::span(class='alert-detail-links-label',
        if (nrow(rounds) == 1) 'Linked Light RNA' else sprintf('Linked Light RNA rounds (%s)', nrow(rounds))),
      lapply(seq_len(nrow(rounds)), function(i)
        alert_navigation_button('open_rna_round', rounds$assessment_id[i],
          shiny::tagList(round_label(i), shiny::span(class='rrm-arrow', `aria-hidden`='true', '\u2192')))))
    else shiny::span(class='alert-detail-links-label', 'No Light RNA recorded for this alert.'))
  shiny::tagList(
    links,
    shiny::h3('Alert details'),
    alert_detail_table(summary, c(field='Field',value='Value')),
    shiny::h3('RNA assessments'),
    alert_detail_table(detail$assessments,c(assessment_id='Assessment ID',area='Area',
      start_date='Start date',end_date='End date',method='Method',coverage_note='Coverage',
      limitations='Limitations',response_use='Evidence to response',source='Source')),
    shiny::h3('Needs'),
    alert_detail_table(detail$needs,c(assessment_id='Assessment ID',rank='Rank',need='Need',
      kii_summary='KII summary',hesper_serious='HESPER serious need',hesper_valid='HESPER valid responses')),
    alert_detail_table(detail$evidence,c(stage='Stage',stage_date='Evidence date',
      needs_evidence='Needs evidence',protection_evidence='Protection evidence',
      caseload_text='Caseload (source text)',recorded_severity='Recorded severity',source_file='Source file')),
    shiny::h3('Assistance — dashboard records'),
    alert_detail_table(detail$assistance,c(event_id='Event ID',area='Area',tier='Tier',
      modality='Modality',start_date='Activity start date',delivery_partner='Partner',
      quantity='Quantity',unit='Unit',measure_type='Measure type',delivery_status='Delivery status',
      delay_reason='Delay reason')),
    shiny::h3('Assistance — validated reporting records'),
    alert_detail_table(detail$reported_assistance,c(record_id='Record ID',district='District',
      community='Community',implementing_agency='Partner',activity='Activity',tier='Tier',
      start_date='Activity start date',end_date='Activity end date',metric='Output metric',
      quantity='Quantity',unit='Unit',households='Reported households',hh_basis='Household counting basis',
      people_total='Reported people',people_scope='People reach scope',people_basis='People counting basis',
      delay_reason='Delay reason')))
}

# return_round: the Light RNA round the user came from, offered as a way back.
# Navigation sits at the top of the window (and stays visible while scrolling).
show_alert_detail <- function(id, d=NULL, h=NULL, activity=NULL, return_round=NULL) {
  back <- !is.null(return_round) && return_round %in% d$assessments$assessment_id[d$assessments$alert_id %in% id]
  arrow <- function(label, left=FALSE) if (left)
    shiny::tagList(shiny::span(class='rrm-arrow', `aria-hidden`='true', '\u2190'), label) else
    shiny::tagList(label, shiny::span(class='rrm-arrow', `aria-hidden`='true', '\u2192'))
  actions <- shiny::div(class='alert-detail-actions', role='navigation', `aria-label`='Alert detail navigation',
    shiny::div(class='alert-detail-actions-main',
      if (back) shiny::tagAppendAttributes(
        alert_navigation_button('open_rna_round', return_round, arrow('Back to Light RNA round', left=TRUE)),
        class='alert-detail-back')
      else alert_navigation_button('open_light_rna', id, arrow('Open Light RNA')),
      alert_navigation_button('open_reported_response', id, arrow('Open reported response'))),
    shiny::tags$button(type='button', class='btn alert-detail-close', `data-dismiss`='modal',
      `data-bs-dismiss`='modal', 'Close'))
  shiny::showModal(shiny::modalDialog(
    title=id, size='l', easyClose=TRUE, footer=NULL,
    actions,
    alert_detail_ui(id,alert_detail_data(id,d,h,activity))))
}

alert_navigation_button <- function(input, id, label, selected=NULL) {
  shiny::tags$button(type='button', class='btn btn-default rrm-alert-link',
    `data-input`=input, `data-alert`=id,
    `aria-pressed`=if (!is.null(selected)) tolower(as.character(selected)), label)
}
