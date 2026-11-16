# Rebuild isolated fictional examples; never changes operational snapshots.
source('R/activity_workbook.R')
a <- as.data.frame(setNames(rep(list(rep(NA_character_,2)),length(activity_fields)),names(activity_fields)))
values <- list(record_id=c('DEMO-ACT-01','DEMO-ACT-02'),alert_id='DEMO-ALERT-01',link_status='Confirmed',
 reporting_month='2026-09-01',start_date=c('2026-09-05','2026-09-12'),end_date=c('2026-09-06','2026-09-13'),
 lead_agency='Demo Partner A',implementing_agency=c('Demo Partner A','Demo Partner B'),
 province='Cabo Delgado',district='Namuno',community='DEMO Community (fictional)',location_coverage='Single location',
 tier=c('Tier 1','Tier 2'),sector='Shelter',activity='Fictional household assistance',modality='In-kind',
 metric='Households assisted',quantity=c('20','10'),households=c('20','10'),hh_basis='Unique within record',
 people_scope='Members of assisted households',people_basis='Unique within record',age_sex_status='Complete',
 female_0_4=c('10','5'),female_5_17=c('15','7'),female_18_49=c('20','10'),female_50_plus=c('5','3'),
 male_0_4=c('10','5'),male_5_17=c('15','7'),male_18_49=c('20','10'),male_50_plus=c('5','3'),
 reported_people=c('100','50'),pwd_f_children=c('1','1'),pwd_m_children=c('1','1'),pwd_f_adults=c('2','1'),pwd_m_adults=c('2','1'),
 idp_female=c('40','20'),idp_male=c('40','20'),host_female=c('10','5'),host_male=c('10','5'),returnee_female='0',returnee_male='0',
 population_status='Complete',funding='Other',delay_reason=c('Demo: access assessment before delivery','Demo: stock transfer before follow-up'),
 previous_agency=c(NA,'Demo Partner A'),handover_date=c(NA,'2026-09-10'),
 handover_reason=c('Not applicable: initial response','Demo: agreed transfer of follow-up responsibility'),
 evidence_source=c('DEMO RNA summary (fictional; no report link)','DEMO follow-up monitoring (fictional; no report link)'),
 evidence_use=c('Demo: shelter findings informed household assistance and accessible distribution','Demo: monitoring identified follow-up needs; Partner B assumed responsibility'),review_status='Validated')
for(n in names(values)) a[[n]] <- rep(values[[n]],length.out=2)
a$source_row <- 2:3
raw <- list(activities=a,extra=data.frame(record_id=character(),metric=character(),quantity=character(),source_row=integer()),
 alerts=data.frame(alert_id='DEMO-ALERT-01',alert_date='2026-09-01',lead_agency='Demo Partner A',arrival_district='Namuno',source_row=2),
 metrics=data.frame(metric='Households assisted',unit='households',definition='Fictional demonstration: assisted households per record; repeat rounds can overlap.',source_row=2),
 metadata=data.frame(source='DEMONSTRATION - fictional examples only',source_updated='2026-11-05'))
d <- prepare_activity_data(raw)
stopifnot(all(d$activities$eligible),all(d$activities$people_total==c(100,50)))
dir.create('data/activity_demo',showWarnings=FALSE)
for(n in names(raw)) write.csv(raw[[n]],file.path('data/activity_demo',paste0(n,'.csv')),row.names=FALSE,na='')
