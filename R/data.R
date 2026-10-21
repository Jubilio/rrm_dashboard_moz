# Data contract and pure calculation helpers. No household-level data is accepted.
read_rrm_data <- function(mode = 'operational', base_dir = '.') {
  if (!mode %in% c('demo', 'operational')) stop('RRM_DATA_MODE must be demo or operational.')
  names <- c('coverage','alerts','routes','assessments','needs','screening','activities','transfers','metadata')
  result <- setNames(lapply(names, function(name) {
    file <- file.path(base_dir, 'data', mode, paste0(name, '.csv'))
    template <- file.path(base_dir, 'data', 'templates', paste0(name, '.csv'))
    if (!file.exists(file)) stop('Missing ', file, '. Copy and populate every CSV template first.')
    x <- read.csv(file, colClasses = 'character', na.strings = '', check.names = FALSE, fileEncoding = 'UTF-8')
    expected <- names(read.csv(template, nrows = 0, check.names = FALSE))
    if (!identical(names(x), expected)) stop(name, ': columns must match the template exactly (including order).')
    x
  }), names)
  validate_rrm_tables(result,mode,base_dir)
}
validate_rrm_tables <- function(result,mode,base_dir='.',allow_severity_inputs=TRUE,allow_incomplete=FALSE) {
  # Missing information stays NA; never infer zero, a date, rank or review status.
  for (name in names(result)) for (col in names(result[[name]])) {
    if(is.character(result[[name]][[col]])) {
      value <- trimws(gsub('\u00a0',' ',result[[name]][[col]],fixed=TRUE))
      value[!is.na(value) & !nzchar(value)] <- NA_character_
      result[[name]][[col]] <- value
    }
  }
  issues <- data.frame(table=character(),column=character(),row=integer(),issue=character())
  pending <- function(name,col,rows,message='Not reported') {
    if(length(rows)) issues <<- rbind(issues,data.frame(table=name,column=col,row=rows+1L,issue=message))
  }
  dates <- c('effective_from','effective_to','alert_date','alert_evidence_date','rna_evidence_date','start_date','end_date','decision_date','review_date','transfer_date','source_updated')
  numbers <- c('alert_hh','alert_people','rna_hh','rna_people','people','households','kii_sample','hh_sample','observation_sample','rank','hesper_serious','hesper_valid','quantity')
  for (name in names(result)) {
    for (col in intersect(dates, names(result[[name]]))) {
      raw <- result[[name]][[col]]
      value <- as.Date(raw, format = '%Y-%m-%d')
      if (any(!is.na(raw) & (is.na(value) | format(value, '%Y-%m-%d') != raw))) stop(name, ': invalid ISO date in ', col)
      result[[name]][[col]] <- value
    }
    for (col in intersect(numbers, names(result[[name]]))) {
      raw <- result[[name]][[col]]; value <- suppressWarnings(as.numeric(raw))
      if (any(!is.na(raw) & (is.na(value) | !is.finite(value) | value < 0 | value != floor(value)))) stop(name, ': invalid non-negative integer in ', col)
      result[[name]][[col]] <- value
    }
  }
  required <- list(coverage=c('assignment_id','area','partner','role','effective_from','source_version'),
    alerts=c('alert_id','alert_date','trigger','gla','movement','alert_evidence_date'),
    routes=c('route_id','alert_id','origin','arrival','caseload_stage','targeted'),
    assessments=c('assessment_id','alert_id','area','start_date','end_date','method','kii_sample','hh_sample','observation_sample'),
    needs=c('assessment_id','need','rank','kii_summary','hesper_serious','hesper_valid','ranking_note'),
    screening=c('screening_id','alert_id','community','decision_date','population','decision','reason','reviewed','analysis_version','review_date'),
    activities=c('event_id','alert_id','area','tier','modality','start_date','delivery_partner','quantity','unit','measure_type','delivery_status','donor'),
    transfers=c('transfer_id','alert_id','area','component','from_partner','to_partner','transfer_date'),
    metadata=c('mode','source_updated','source_version','methods_note'))
  identity <- list(coverage=c('assignment_id','area','partner','role'),alerts='alert_id',
    routes=c('route_id','alert_id','origin','arrival','caseload_stage'),
    assessments=c('assessment_id','alert_id'),needs=c('assessment_id','need'),
    screening=c('screening_id','alert_id'),activities=c('event_id','alert_id'),
    transfers=c('transfer_id','alert_id'),metadata='mode')
  for (name in names(required)) for (col in required[[name]]) {
    rows <- which(is.na(result[[name]][[col]]))
    if(length(rows)) {
      if(!allow_incomplete || col %in% identity[[name]])
        stop(name, ': missing ', col, ' at source row(s) ',paste(rows+1L,collapse=', '))
      pending(name,col,rows)
    }
  }
  keys <- c(coverage='assignment_id', alerts='alert_id', routes='route_id', assessments='assessment_id', screening='screening_id', activities='event_id', transfers='transfer_id')
  for (name in names(keys)) if (anyDuplicated(result[[name]][[keys[[name]]]])) stop(name, ': duplicate ID')
  ranked <- result$needs[!is.na(result$needs$rank),,drop=FALSE]
  if (anyDuplicated(result$needs[c('assessment_id','need')]) || anyDuplicated(ranked[c('assessment_id','rank')])) stop('Duplicate need or rank within an assessment.')
  if (nrow(result$metadata) != 1 || result$metadata$mode != mode) stop('Metadata must contain one row whose mode matches config.')
  # Match a demo label/token, not ordinary words such as demonstrates/demonstrated.
  if (mode == 'operational' && any(vapply(result, function(x) any(grepl('(^|[^[:alnum:]])DEMO([^[:alnum:]]|$)', as.matrix(x), ignore.case=TRUE), na.rm=TRUE), logical(1)))) stop('Operational data still contains DEMO labels.')
  for (name in c('routes','assessments','screening','activities','transfers'))
    if (!all(result[[name]]$alert_id %in% result$alerts$alert_id)) stop(name, ': unknown alert_id')
  if (!all(result$needs$assessment_id %in% result$assessments$assessment_id)) stop('needs: unknown assessment_id')
  enums <- list(coverage=list(role=c('Primary','Secondary','Unknown')),
    routes=list(caseload_stage=c('Alert','RNA'),targeted=c('Yes','No','Unknown')),
    screening=list(reviewed=c('TRUE','FALSE'),population=c('IDP','Host','Returnee','Other'),decision=c('Proceed','Not proceeding','Pending')),
    activities=list(tier=c('Tier 1','Tier 2'),delivery_status=c('Completed','Planned','Ongoing','Cancelled'),measure_type=c('Assistance','Service output')))
  for (name in names(enums)) for (col in names(enums[[name]])) {
    value <- result[[name]][[col]]
    if(allow_incomplete) value <- value[!is.na(value)]
    if (!all(value %in% enums[[name]][[col]])) stop(name, ': unsupported value in ', col)
  }
  if (any(result$needs$hesper_serious > result$needs$hesper_valid,na.rm=TRUE)) stop('HESPER numerator exceeds denominator.')
  hh <- result$assessments$hh_sample[match(result$needs$assessment_id, result$assessments$assessment_id)]
  if (any(result$needs$hesper_valid > hh,na.rm=TRUE)) stop('HESPER denominator exceeds the assessment household sample.')
  if (any(result$needs$rank < 1,na.rm=TRUE)) stop('Need ranks start at 1.')
  if (any(result$screening$reviewed == 'TRUE' & is.na(result$screening$profile_summary),na.rm=TRUE)) {
    if(!allow_incomplete) stop('Reviewed profiles require a summary.')
    pending('screening','profile_summary',which(result$screening$reviewed=='TRUE' & is.na(result$screening$profile_summary)))
  }
  a <- result$alerts
  unverified <- which((!is.na(a$rna_hh) | !is.na(a$rna_people)) & (is.na(a$rna_severity) | is.na(a$rna_evidence_date)))
  if (!(allow_severity_inputs && file.exists(file.path(base_dir,'data',mode,'severity_inputs.csv'))) && length(unverified)) {
    if(!allow_incomplete) stop('RNA caseload requires severity and evidence date.')
    pending('alerts','rna_caseload',unverified,'Verification evidence incomplete; excluded from verified KPIs')
  }
  if (any(result$assessments$end_date < result$assessments$start_date,na.rm=TRUE)) stop('Assessment end precedes start.')
  c <- result$coverage
  if (any(!is.na(c$effective_to) & c$effective_to < c$effective_from,na.rm=TRUE)) stop('Coverage end precedes start.')
  # Each route is a disjoint origin-arrival segment within an alert and stage.
  r <- result$routes
  if (anyDuplicated(r[c('alert_id','origin','arrival','caseload_stage')])) stop('Duplicate route segment.')
  for (id in unique(r$alert_id)) for (stage in unique(r$caseload_stage[r$alert_id == id])) {
    part <- r[r$alert_id == id & r$caseload_stage == stage,,drop=FALSE]
    ar <- a[a$alert_id == id,,drop=FALSE]
    for (pair in list(c('households','hh'), c('people','people'))) {
      total <- ar[[paste0(if (stage == 'RNA') 'rna_' else 'alert_', pair[2])]]
      if (is.na(total) && any(!is.na(part[[pair[1]]]))) {
        if(!allow_incomplete) stop('Route counts have no matching alert-stage total.')
        pending('routes',pair[1],which(r$alert_id==id & r$caseload_stage==stage),'Alert-stage total not reported; reconciliation pending')
      }
      if (!is.na(total) && sum(part[[pair[1]]],na.rm=TRUE) > total) stop('Route counts exceed alert-stage total.')
    }
  }
  event_dates <- a$alert_date[match(result$activities$alert_id,a$alert_id)]
  if (any(result$activities$start_date < event_dates,na.rm=TRUE)) stop('Activity starts before its linked alert.')
  result$activities$days_from_alert <- as.integer(result$activities$start_date - event_dates)
  if(allow_incomplete) attr(result,'validation_issues') <- issues
  attr(result, 'loaded_at') <- format(Sys.time(), '%Y-%m-%d %H:%M:%S %Z')
  result
}
filter_equal <- function(x, column, value) {
  if (is.null(value) || identical(value, 'All')) return(x)
  x[!is.na(x[[column]]) & x[[column]] == value,,drop=FALSE]
}
filter_date <- function(x, column, dates, include_missing=FALSE) {
  if (is.null(dates) || length(dates) != 2 || anyNA(dates)) return(x)
  keep <- !is.na(x[[column]]) & x[[column]] >= as.Date(dates[1]) & x[[column]] <= as.Date(dates[2])
  if(include_missing) keep <- keep | is.na(x[[column]])
  x[which(keep),,drop=FALSE]
}
known_sum <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else sum(x,na.rm=TRUE)
fmt <- function(x) if (!length(x) || is.na(x)) 'Unavailable' else format(x,big.mark=',',scientific=FALSE,trim=TRUE)
activity_totals <- function(x) {
  unknown_status <- any(is.na(x$delivery_status))
  x <- x[which(x$delivery_status == 'Completed'),,drop=FALSE]
  unknown_output <- any(is.na(x$unit)|is.na(x$measure_type))
  total <- function(unit, type) {
    values <- x$quantity[which(x$unit == unit & x$measure_type == type)]
    if(!length(values)) {
      if(unknown_status || unknown_output) NA_real_ else 0
    } else known_sum(values)
  }
  list(hh=total('HH','Assistance'), kits=total('kits','Service output'), consultations=total('consultations','Service output'),
    days=if(any(!is.na(x$days_from_alert))) min(x$days_from_alert,na.rm=TRUE) else NA_real_)
}
