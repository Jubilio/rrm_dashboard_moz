source('R/table_labels.R')
fields <- c('alert_id','organisation','arrival_district','rna_done_raw','rna_done',
            'tier2_done','recorded_latest_severity','days_open','population','source_row')
expected <- c('Alert ID','Organisation','Arrival district','RNA completed (source value)',
              'RNA completed','Tier 2 completed','Latest severity (source)',
              'Days since alert','Population','Source row')
stopifnot(identical(rrm_column_labels(fields), expected))
x <- as.data.frame(setNames(rep(list('example'), length(fields)), fields))
before <- x
widget <- rrm_datatable(x, rownames=FALSE, escape=TRUE)
stopifnot(identical(x, before), identical(names(widget$x$data), fields))
for (label in expected) stopifnot(grepl(label, widget$x$container, fixed=TRUE))
custom <- rrm_datatable(x[1], rownames=FALSE, colnames='Custom heading')
stopifnot(grepl('Custom heading', custom$x$container, fixed=TRUE))
empty <- rrm_datatable(x[FALSE, ], rownames=FALSE)
stopifnot(grepl('RNA completed (source value)', empty$x$container, fixed=TRUE))
stopifnot(identical(rrm_column_labels(c('RNA coverage','hh_reached','linked_alert_id')),
                    c('RNA coverage','HH reached','Linked alert ID')))
message('PASS: readable headers, explicit labels, empty tables and original source schema preserved.')
