# Run from the project root:
# Rscript scripts/run_household_analysis.R /private/input.csv /private/output
# Add --draft-scenario for an explicit provisional scenario, never a targeting release.
args<-commandArgs(trailingOnly=TRUE)
scenario<-'--draft-scenario' %in% args;args<-args[!args %in% '--draft-scenario']
if(length(args)!=2) stop('Provide input CSV and a private output directory; optional --draft-scenario.')
source('R/household.R');source('household_rule_config.R')
if(HOUSEHOLD_RULE_STATUS=='approved'&&any(!nzchar(c(APPROVAL_REFERENCE,APPROVED_BY,APPROVAL_DATE)))) stop('Approved operational rules require reference, reviewer and approval date.')
rules<-household_rules(HOUSEHOLD_RULE_STATUS,HOUSEHOLD_RULE_VERSION,FCS_CUTOFFS,WATER_HIGH_DAY)
x<-read.csv(args[1],colClasses='character',na.strings='',check.names=FALSE,fileEncoding='UTF-8')
dir.create(args[2],recursive=TRUE,showWarnings=FALSE)
out_dir<-normalizePath(args[2],mustWork=TRUE);app_dir<-normalizePath('.',mustWork=TRUE)
if(out_dir==app_dir||startsWith(out_dir,paste0(app_dir,.Platform$file.sep))) stop('Private record-level outputs must be outside the deployable app folder.')
derived<-analyse_households(x,rules,allow_draft=scenario)
write.csv(derived,file.path(out_dir,'household_indicators_PRIVATE.csv'),row.names=FALSE,na='')
aggregates<-aggregate_households(derived,MIN_AGGREGATE_CELL,reviewed=FALSE,synthetic=FALSE)
if(nrow(aggregates)) write.csv(aggregates,file.path(out_dir,'household_aggregates_REVIEW_REQUIRED.csv'),row.names=FALSE,na='')
writeLines(c(paste('Rules:',HOUSEHOLD_RULE_VERSION),paste('Status:',HOUSEHOLD_RULE_STATUS),paste('Approval reference:',APPROVAL_REFERENCE),paste('Approved by:',APPROVED_BY),paste('Approval date:',APPROVAL_DATE),paste('Draft scenario:',scenario),paste('Input records:',nrow(x)),paste('Baseline records:',sum(x$use_mode %in% c('idp_baseline','host_baseline')))),file.path(out_dir,'analysis_provenance.txt'))
message('Private analysis completed. Aggregate release still requires source and disclosure review. No eligibility list was generated.')
