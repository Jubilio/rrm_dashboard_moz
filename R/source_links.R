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
