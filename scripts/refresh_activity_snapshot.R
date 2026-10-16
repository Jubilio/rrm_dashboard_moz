# Run from the project root: Rscript scripts/refresh_activity_snapshot.R /private/report.xlsx
args<-commandArgs(trailingOnly=TRUE)
if(length(args)<1||length(args)>2)stop('Provide source workbook; optional sanitised snapshot directory.')
source('R/activity_workbook.R')
raw<-read_activity_workbook(args[1]);checked<-prepare_activity_data(raw)
destination<-if(length(args)==2)args[2] else 'data/activity_snapshot'
dir.create(destination,recursive=TRUE,showWarnings=FALSE)
raw$metadata$source_checksum_md5<-unname(tools::md5sum(args[1]))
# Tables were selected through an explicit field allowlist. Never copy the source XLSX here.
for(n in names(raw))write.csv(raw[[n]],file.path(destination,paste0(n,'.csv')),row.names=FALSE,na='',fileEncoding='UTF-8')
message(nrow(checked$activities),' activity records; ',nrow(checked$extra),' extra outputs; ',sum(checked$activities$eligible),' validated/reconciled records. Snapshot refreshed; source workbook unchanged.')
