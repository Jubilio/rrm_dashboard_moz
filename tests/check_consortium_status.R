library(shiny)
source('R/data.R'); source('R/pages.R')
d <- read_rrm_data('demo')
stopifnot(all(is.na(d$alerts$consortium_response_status)))
headers <- names(read.csv('data/templates/alerts.csv',nrows=0))
stopifnot(rrm_input_headers_match('alerts',c(headers,'consortium_response_status'),headers),
          !rrm_input_headers_match('alerts',c(headers,'unexpected_status'),headers),
          !rrm_input_headers_match('alerts',c(headers,rep('consortium_response_status',2)),headers))
raw <- setNames(lapply(names(d),function(n)
  read.csv(file.path('data','demo',paste0(n,'.csv')),colClasses='character',na.strings='',check.names=FALSE)),names(d))
raw$alerts$consortium_response_status <- c('Yes','No','Pending go/no-go')
d <- validate_rrm_tables(raw,'demo')
bad <- raw; bad$alerts$consortium_response_status[1] <- 'Approved'
stopifnot(inherits(try(validate_rrm_tables(bad,'demo'),silent=TRUE),'try-error'))
testServer(page_server,args=list(key='alerts',d=d),{
  session$setInputs(alert_id='All',arrival='All',trigger='All',gla='All',movement='All',
                    consortium_response_status='All')
  stopifnot(nrow(filtered())==3L)
  for(status in c('Yes','No','Pending go/no-go')) {
    session$setInputs(consortium_response_status=status)
    stopifnot(nrow(filtered())==1L,filtered()$consortium_response_status==status,
              display_table()$consortium_response_status==status,
              grepl(status,paste(as.character(output$details),collapse=' '),fixed=TRUE))
  }
  session$setInputs(consortium_response_status='Not reported')
  stopifnot(nrow(filtered())==0L,!is.null(output$table))
})
d <- read_rrm_data('demo')
testServer(page_server,args=list(key='alerts',d=d),{
  session$setInputs(alert_id='All',consortium_response_status='Not reported')
  stopifnot(nrow(filtered())==3L,all(display_table()$consortium_response_status=='Not reported'),
            all(is.na(filtered()$consortium_response_status)))
})
message('PASS: optional consortium decision field, legacy compatibility, controlled values, filters and explicit unknown states.')
