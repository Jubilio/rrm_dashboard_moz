# Link only explicitly supplied HTTPS destinations; never invent a document URL.
source_document_links <- function(labels, urls = NULL, mapping = NULL) {
  labels <- as.character(labels)
  if (is.null(urls)) urls <- rep(NA_character_, length(labels))
  if (length(urls) != length(labels)) stop('Source names and URLs must have the same length.')
  if (!is.null(mapping) && nrow(mapping)) {
    if (!all(c('filename','url') %in% names(mapping)) || anyDuplicated(mapping$filename))
      stop('Source links require unique filename values and filename,url columns.')
    missing <- is.na(urls) | !nzchar(trimws(urls))
    urls[missing] <- mapping$url[match(labels[missing],mapping$filename)]
  }
  vapply(seq_along(labels), function(i) {
    label <- labels[i]
    if (is.na(label) || !nzchar(trimws(label))) return('Not reported')
    url <- urls[i]
    if (is.na(url) || !nzchar(trimws(url))) url <- label
    url <- trimws(url)
    if (grepl('^https://[^[:space:][:cntrl:]]+$',url,ignore.case=TRUE))
      return(as.character(htmltools::tags$a(href=url,target='_blank',
        rel='noopener noreferrer',label)))
    paste0(htmltools::htmlEscape(label),' (link unavailable)')
  }, character(1))
}
source_link_table <- function(x, mapping = NULL) {
  fields <- intersect(c('alert_source','rna_source','source_file'),names(x))
  url_fields <- c(alert_source='alert_source_url',rna_source='rna_source_url',source_file='source_url')
  for (field in fields) {
    url_field <- url_fields[[field]]
    x[[field]] <- source_document_links(x[[field]],
      if (url_field %in% names(x)) x[[url_field]] else NULL, mapping)
  }
  x <- x[setdiff(names(x),unname(url_fields))]
  list(data=x, escape=which(!names(x) %in% fields))
}

# The HTTPS address for one document, or NA when none was supplied. Same rule as above:
# an explicit URL column first, then data/reference/source_links.csv by exact filename.
source_document_url <- function(label, url = NA_character_, mapping = NULL) {
  label <- if (length(label)) as.character(label[1]) else NA_character_
  url <- if (length(url)) as.character(url[1]) else NA_character_
  if ((is.na(url) || !nzchar(trimws(url))) && !is.na(label) && !is.null(mapping) && nrow(mapping) &&
      all(c('filename','url') %in% names(mapping)))
    url <- mapping$url[match(label, mapping$filename)]
  url <- trimws(url)
  if (!is.na(url) && grepl('^https://[^[:space:][:cntrl:]]+$', url, ignore.case=TRUE)) url else NA_character_
}

# Link that opens a shared document in a new tab.
document_link <- function(url, label) {
  if (is.null(url) || is.na(url)) return(NULL)
  htmltools::tags$a(class='rrm-doc-link', href=url, target='_blank', rel='noopener noreferrer',
    label, htmltools::span(class='sr-only', ' (opens in a new tab)'))
}

# Original alert documents kept in data/alert and served by the app at alert-docs/.
# data/reference/alert_documents.csv maps each alert ID to its exact filename.
ALERT_DOCUMENT_DIR <- 'data/alert'
read_alert_documents <- function(path = 'data/reference/alert_documents.csv') {
  if (!file.exists(path)) return(data.frame(alert_id=character(), filename=character()))
  x <- utils::read.csv(path, stringsAsFactors=FALSE, check.names=FALSE, encoding='UTF-8')
  if (!all(c('alert_id','filename') %in% names(x)) || anyDuplicated(x$alert_id))
    stop('alert_documents.csv needs alert_id,filename columns and one row per alert.')
  x
}
# Link details for one alert's document, or NULL when no file is mapped or the file is missing.
alert_document <- function(id, documents = read_alert_documents(), dir = ALERT_DOCUMENT_DIR) {
  filename <- documents$filename[match(id, documents$alert_id)]
  if (!length(filename) || is.na(filename) || !nzchar(filename) || !file.exists(file.path(dir, filename))) return(NULL)
  ext <- tolower(tools::file_ext(filename))
  kind <- if (ext == 'pdf') 'PDF' else if (ext %in% c('doc','docx')) 'Word' else toupper(ext)
  list(url=paste0('alert-docs/', utils::URLencode(filename, reserved=TRUE)),
       label=sprintf('View original alert (%s)', kind))
}
