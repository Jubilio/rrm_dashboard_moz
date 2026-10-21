# One consolidated workbook for the core dashboard; the reporting workbook is separate.
input_sheet_names <- c(coverage='Coverage',alerts='Alerts',routes='Routes',route_locations='Route Locations',
  assessments='Assessments',needs='Needs',screening='Screening',activities='Activities',transfers='Transfers',metadata='Metadata')
input_date_fields <- c('effective_from','effective_to','alert_date','alert_evidence_date','rna_evidence_date',
  'start_date','end_date','decision_date','review_date','transfer_date','source_updated')
input_excel_origin <- function(path) {
  con <- unz(path,'xl/workbook.xml',open='rb');on.exit(close(con))
  xml <- rawToChar(readBin(con,'raw',n=10000000L))
  if(grepl('date1904="(1|true)"',xml,perl=TRUE)) '1904-01-01' else '1899-12-30'
}
read_dashboard_workbook <- function(path,mode=NULL,base_dir='.',allow_incomplete=TRUE) {
  if(!requireNamespace('readxl',quietly=TRUE)) stop('Install readxl to read the consolidated input workbook.')
  if(!file.exists(path)) stop('Consolidated input workbook not found: ',path)
  sheets <- readxl::excel_sheets(path)
  missing <- setdiff(unname(input_sheet_names),sheets)
  if(length(missing)) stop('Missing input worksheet(s): ',paste(missing,collapse=', '))
  origin <- input_excel_origin(path)
  tables <- lapply(names(input_sheet_names),function(key) {
    x <- as.data.frame(readxl::read_excel(path,sheet=input_sheet_names[[key]],col_types='text',
      .name_repair='minimal',trim_ws=TRUE,progress=FALSE),stringsAsFactors=FALSE)
    expected <- names(read.csv(file.path(base_dir,'data','templates',paste0(key,'.csv')),nrows=0,check.names=FALSE))
    if(!identical(names(x),expected)) stop(input_sheet_names[[key]],': headers must match the supplied example exactly.')
    for(field in names(x)) {x[[field]] <- trimws(gsub('\u00a0',' ',x[[field]],fixed=TRUE));x[[field]][!is.na(x[[field]])&!nzchar(x[[field]])] <- NA_character_}
    if(nrow(x)) x <- x[rowSums(!is.na(x))>0,,drop=FALSE]
    for(field in intersect(input_date_fields,names(x))) {
      raw <- x[[field]]
      serial <- which(!is.na(raw)&grepl('^[0-9]{4,6}(\\.0+)?$',raw))
      if(length(serial)) raw[serial] <- format(as.Date(as.numeric(raw[serial]),origin=origin),'%Y-%m-%d')
      x[[field]] <- raw
    }
    x
  });names(tables) <- names(input_sheet_names)
  if(nrow(tables$metadata)!=1L) stop('Metadata must contain exactly one populated row.')
  source_mode <- tables$metadata$mode[1]
  if(is.na(source_mode)||!source_mode %in% c('demo','operational')) stop('Metadata.mode must be demo or operational.')
  if(!is.null(mode)&&!identical(mode,source_mode)) stop('Workbook mode does not match RRM_DATA_MODE. No fallback to CSV is allowed.')
  core <- tables[setdiff(names(tables),'route_locations')]
  d <- validate_rrm_tables(core,source_mode,base_dir,allow_severity_inputs=FALSE,allow_incomplete=allow_incomplete)
  d$route_locations <- validate_alert_locations(tables$route_locations,source_mode,allow_incomplete=allow_incomplete)
  if(!all(d$route_locations$route_id %in% d$routes$route_id)) stop('Route Locations contains an unknown route_id.')
  attr(d,'input_workbook') <- normalizePath(path,winslash='/',mustWork=TRUE)
  d
}
load_dashboard_input <- function(path='data/RRM_Dashboard_Input.xlsx',mode='demo',mode_explicit=FALSE,base_dir='.') {
  if(nzchar(Sys.getenv('RRM_INPUT_WORKBOOK')) || file.exists(path)) {
    read_dashboard_workbook(path,if(mode_explicit) mode else NULL,base_dir)
  } else read_rrm_data(mode,base_dir)
}
