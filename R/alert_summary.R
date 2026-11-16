alert_summary_values <- function(alerts, activities=NULL, reporting=FALSE) {
  ids <- unique(alerts$alert_id[!is.na(alerts$alert_id) & nzchar(trimws(alerts$alert_id))])
  households <- NA_real_
  if (!is.null(activities) && nrow(activities)) {
    a <- activities[which(activities$alert_id %in% ids), , drop=FALSE]
    if (reporting) {
      a <- a[which(a$eligible %in% TRUE & a$link_status == 'Confirmed' &
        a$metric == 'Households assisted' & a$unit == 'households' &
        a$hh_basis == 'Unique within record'), , drop=FALSE]
      amounts <- a$households
    } else {
      a <- a[which(a$delivery_status == 'Completed' & a$measure_type == 'Assistance' &
        a$unit == 'HH'), , drop=FALSE]
      amounts <- a$quantity
    }
    # No rows or incomplete quantities do not establish zero or a complete total.
    if (length(amounts) && all(!is.na(amounts)) && all(is.finite(amounts)) && all(amounts >= 0))
      households <- sum(amounts)
  }
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
      card('Activated alerts',values$activated_alerts),
      card('Non-activated alerts',values$non_activated_alerts),
      card(if (reporting) 'Gross validated household reach' else 'Gross reported household reach',
           values$households)))
}
