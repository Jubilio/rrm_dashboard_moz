source('R/source_links.R')
mapping <- data.frame(filename=c('alert.pdf','rna.docx'),
  url=c('https://example.org/alert.pdf?x=1&y=2','https://example.org/rna.docx'))
labels <- c('alert.pdf','rna.docx','missing.pdf',NA_character_,'<script>')
links <- source_document_links(labels,mapping=mapping)
stopifnot(grepl('href="https://example.org/alert.pdf?x=1&amp;y=2"',links[1],fixed=TRUE),
          grepl('target="_blank"',links[1],fixed=TRUE),
          grepl('noopener noreferrer',links[1],fixed=TRUE),
          links[3]=='missing.pdf (link unavailable)',links[4]=='Not reported',
          !grepl('<script>',links[5],fixed=TRUE))
unsafe <- source_document_links('alert.pdf','javascript:alert(1)')
stopifnot(!grepl('<a ',unsafe,fixed=TRUE))
x <- data.frame(alert_source='alert.pdf',rna_source='rna.docx',notes='<script>')
before <- x
linked <- source_link_table(x,mapping)
stopifnot(identical(x,before),identical(linked$escape,3L),
          grepl('<a ',linked$data$alert_source,fixed=TRUE),
          grepl('<a ',linked$data$rna_source,fixed=TRUE))
direct <- source_link_table(data.frame(source_file='Evidence',source_url='https://example.org/evidence.pdf'))
stopifnot(!'source_url' %in% names(direct$data),grepl('<a ',direct$data$source_file,fixed=TRUE))
empty <- source_link_table(x[FALSE,],mapping)
stopifnot(nrow(empty$data)==0L)
duplicate <- rbind(mapping,mapping[1,])
stopifnot(inherits(try(source_document_links(labels,mapping=duplicate),silent=TRUE),'try-error'))
message('PASS: explicit document links, safe labels and schemes, missing destinations, empty tables and unchanged source values.')
