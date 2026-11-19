alert_summary_values <- function(alerts, activities=NULL, reporting=FALSE) {
  ids <- unique(alerts$alert_id[!is.na(alerts$alert_id) & nzchar(trimws(alerts$alert_id))])
  a <- if (!is.null(activities))
    activities[which(activities$alert_id %in% ids), , drop=FALSE]
  if (!reporting) {
    tier_count <- function(tier) length(unique(a$alert_id[a$tier %in% tier]))
    completed_ids <- setdiff(a$alert_id, a$alert_id[!a$delivery_status %in% 'Completed'])
    return(list(total_alerts=length(ids), tier_1=tier_count('Tier 1'),
                tier_2=tier_count('Tier 2'), completed=length(completed_ids)))
  }
  households <- NA_real_
  a <- if (!is.null(a)) a[which(a$eligible %in% TRUE & a$link_status == 'Confirmed' &
    a$metric == 'Households assisted' & a$unit == 'households' &
    a$hh_basis == 'Unique within record'), , drop=FALSE]
  amounts <- a$households
  # No rows or incomplete quantities do not establish zero or a complete total.
  if (length(amounts) && all(is.finite(amounts)) && all(amounts >= 0))
    households <- sum(amounts)
  # Activation has no agreed source field. Never substitute consortium response or RNA status.
  list(total_alerts=length(ids), activated_alerts=NA_integer_,
       non_activated_alerts=NA_integer_, households=households)
}

alert_summary_ui <- function(values, reporting=FALSE) {
  card <- function(label, value) shiny::div(class='kpi',
    shiny::div(class='kpi-title',label),
    shiny::div(class='kpi-value',if (length(value) && !is.na(value))
      format(value,big.mark=',',scientific=FALSE,trim=TRUE) else ''))
  shiny::div(class='panel alert-summary',shiny::h3('Alert summary'),
    shiny::div(class='kpi-row',
      card('Total alerts',values$total_alerts),
      if (reporting) shiny::tagList(
        card('Activated alerts',values$activated_alerts),
        card('Non-activated alerts',values$non_activated_alerts),
        card('Gross validated household reach',values$households))
      else shiny::tagList(
        card('Tier 1',values$tier_1), card('Tier 2',values$tier_2),
        card('All recorded activities completed',values$completed))),
    if (!reporting) shiny::p(class='alert-summary-note',
      'Tier counts can overlap. Completion requires at least one recorded activity, with every recorded activity marked Completed.'))
}
