# Private analytical pipeline. The public UI consumes aggregates only.
# Source: supplied Draft 0.1, 2 October 2026. RRM mappings are not approved standards.
household_rules <- function(status='draft',version='Draft-0.1-2026-10-02',fcs_cutoffs=c(21,35),water_high_day=3) {
 if(!status %in% c('draft','approved')||!nzchar(version)) stop('Explicit rule status/version required.')
 if(!identical(as.numeric(fcs_cutoffs),c(21,35))&&!identical(as.numeric(fcs_cutoffs),c(28,42))) stop('Choose the documented 21/35 or 28/42 cutoff set.')
 if(!water_high_day %in% c(1,3,4)) stop('Water high-need sensitivity cutoff must be 1, 3 or 4 days.')
 list(status=status,version=version,fcs_cutoffs=fcs_cutoffs,water_high_day=water_high_day,
      lcs_classes=c(sell_assets=2,spend_savings=2,borrow=2,eat_elsewhere=2,sell_productive=3,reduce_health=3,withdraw_school=3,sell_house_land=4,beg_scavenge=4,high_risk_work=4))
}
text_or_profile <- function(x) if(is.na(x)||!x %in% c('yes','no')) NA_character_ else x
normalise_answer <- function(x) {
 x<-tolower(trimws(as.character(x)))
 x[x %in% c('','na','dont_know','don_t_know','dk','unknown','prefer_not','prefer_not_to_answer','prefer_not_answer','prefer_not_to_answer','pna','refused','dk_pnta')]<-NA_character_
 x
}
valid_integer <- function(x,lower=0,upper=Inf) {
 n<-suppressWarnings(as.numeric(x))
 if(!length(n)||is.na(n)||!is.finite(n)||n!=floor(n)||n<lower||n>upper) NA_real_ else n
}
component <- function(level=NA_real_,complete=!is.na(level)) list(level=level,complete=complete)
max_component <- function(items) {
 vals<-vapply(items,`[[`,numeric(1),'level');known<-!is.na(vals)
 component(if(any(known)) max(vals[known]) else NA_real_,all(vapply(items,`[[`,logical(1),'complete')))
}
sector_result <- function(item) {
 v<-item$level;c<-isTRUE(item$complete)
 list(level=v,status=if(c) 'complete' else if(is.na(v)) 'unknown' else 'partial',
      high=if(!is.na(v)&&v>=3) 1L else if(c) 0L else NA_integer_,
      very_high=if(!is.na(v)&&v==4) 1L else if(c) 0L else NA_integer_,
      exact=if(c||(!is.na(v)&&v==4)) v else NA_real_)
}
count_bounds <- function(flags) {
 lower<-sum(flags==1,na.rm=TRUE);unknown<-sum(is.na(flags))
 list(lower=lower,upper=lower+unknown,exact=if(unknown==0) lower else NA_integer_,known=length(flags)-unknown,
      concurrence=if(lower>=2) 1L else if(lower+unknown<2) 0L else NA_integer_)
}
analyse_households <- function(x,rules=household_rules(),allow_draft=FALSE,observed_handwashing_only=FALSE) {
 ids<-c('hh_id','submission_id','alert_id','assessment_occasion','interview_date','use_mode','community','population')
 if(!all(ids %in% names(x))) stop('Missing household identity/occasion columns; see household_input.csv.')
 if(anyNA(x[ids])||any(vapply(x[ids],function(z) any(trimws(z)==''),logical(1)))) stop('Missing household record metadata.')
 if(anyDuplicated(x$submission_id)||anyDuplicated(x[c('hh_id','alert_id','assessment_occasion')] )) stop('Duplicate baseline occasion: resolve records explicitly; automatic name/phone deduplication is not used.')
 date<-as.Date(x$interview_date,format='%Y-%m-%d')
 if(anyNA(date)||any(format(date,'%Y-%m-%d')!=x$interview_date)) stop('Invalid interview date.')
 release<-rules$status=='approved'||isTRUE(allow_draft)
 out<-lapply(seq_len(nrow(x)),function(i) {
  raw<-function(n) if(n %in% names(x)) as.character(x[[n]][i]) else NA_character_
  get<-function(n) normalise_answer(raw(n))
  qa<-character(0)
  int<-function(n,lo=0,hi=Inf) {
   raw_value<-raw(n);value<-valid_integer(raw_value,lo,hi)
   if(!is.na(normalise_answer(raw_value))&&is.na(value)) qa<<-c(qa,paste0(n,': invalid number'))
   value
  }
  map<-function(n,mapping) {
   a<-get(n)
   if(is.na(a)) return(NA_real_)
   if(!a %in% names(mapping)) {qa<<-c(qa,paste0(n,': unmapped code'));return(NA_real_)}
   as.numeric(mapping[[a]])
  }
  f<-vapply(c('cereals','pulses','vegetables','fruit','meat','milk','sugar','oil'),function(n) int(paste0('fcs_',n,'_days'),0,7),numeric(1))
  fcs<-if(all(!is.na(f))) sum(f*c(2,3,1,1,4,4,.5,.5)) else NA_real_
  fc<-if(is.na(fcs)) NA_character_ else if(fcs<=rules$fcs_cutoffs[1]) 'Poor' else if(fcs<=rules$fcs_cutoffs[2]) 'Borderline' else 'Acceptable'
  fl<-if(is.na(fc)) NA_real_ else c(Poor=3,Borderline=2,Acceptable=1)[[fc]]
  h<-vapply(1:3,function(j) {
   a<-get(paste0('hhs_',j,'_occurrence'));b<-get(paste0('hhs_',j,'_frequency'))
   if(!is.na(a)&&a=='no') {
    if(!is.na(b)) qa<<-c(qa,paste0('hhs_',j,': frequency contradicts no occurrence'))
    return(0)
   }
   if(!is.na(a)&&a=='yes') {
    if(!is.na(b)&&b %in% c('rarely','sometimes')) return(1)
    if(!is.na(b)&&b=='often') return(2)
   }
   NA_real_
  },numeric(1))
  hs<-if(all(!is.na(h))) sum(h) else NA_real_
  hlo<-sum(h,na.rm=TRUE);hup<-hlo+2*sum(is.na(h))
  hcat<-function(v) if(v<=1) 'Little/no hunger' else if(v<=3) 'Moderate hunger' else 'Severe hunger'
  hc<-if(!is.na(hs)) hcat(hs) else NA_character_
  hb<-if(hcat(hlo)==hcat(hup)) hcat(hlo) else NA_character_
  hl<-if(!is.na(hs)) {if(hs>=4) 4 else if(hs>=2) 3 else 1} else if(hlo>=4) 4 else if(hlo>=2) 3 else NA_real_
  food<-max_component(list(component(fl),component(hl,!is.na(hs))))
  type<-get('shelter_type')
  condition<-if(!is.na(type)&&type=='sleeping_outdoors') 4 else map('shelter_condition',c(adequate=1,minor=2,major=3,uninhabitable=4,unsafe_to_occupy=4))
  issues<-get('shelter_issues')
  issue<-component()
  if(!is.na(issues)) {
   parts<-trimws(strsplit(issues,';',fixed=TRUE)[[1]])
   exclusive<-c('none','dont_know','dk','prefer_not','pna','dk_pnta')
   issue_map<-c(none=1,thermal_ventilation=2,rain_leaks=3,insufficient_space=2,lack_privacy=2,cannot_lock=2,unsafe_location=2)
   if(length(parts)>1&&any(parts %in% exclusive)) qa<-c(qa,'shelter_issues: exclusive answer combined')
   else {
    vals<-unname(issue_map[parts]);issue<-component(if(any(!is.na(vals))) max(vals,na.rm=TRUE) else NA_real_,all(!is.na(vals)))
    if(any(is.na(vals))) qa<-c(qa,'shelter_issues: unresolved Other/unmapped code')
   }
  }
  fn<-lapply(c('cooking','sleeping','storage'),function(n) {
   attributed<-get(paste0('shelter_',n,'_attribution'))
   if(!is.na(attributed)&&attributed=='yes') component(map(paste0('shelter_',n),c(without_difficulty=1,with_difficulty=2,unable=3))) else component()
  })
  shelter<-max_component(c(list(component(condition),issue),fn))
  source<-get('drinking_water_source'); water_type<-NA_character_
  if(!is.na(source)) {
   if(source %in% c('option_1','option_2','option_3','rainwater','water_truck','protected_dug_well','public_standpipe','packaged_water')) water_type<-'improved'
   else if(source=='unprotected_wells_or_springs') water_type<-'unimproved'
   else if(source=='surface_water') water_type<-'surface'
   else qa<-c(qa,'drinking_water_source: review type mapping')
  }
  minutes<-int('water_collection_minutes',0)
  water_service<-if(is.na(water_type)) NA_character_ else if(water_type=='surface') 'surface_water' else if(water_type=='unimproved') 'unimproved' else if(is.na(minutes)) NA_character_ else if(minutes<=30) 'at_least_basic' else 'limited'
  wl<-if(is.na(water_service)) NA_real_ else c(at_least_basic=1,limited=2,unimproved=2,surface_water=3)[[water_service]]
  days<-int('water_shortage_days_7d',0,7)
  shortage<-if(is.na(days)) NA_real_ else if(days>=6) 4 else if(days>=rules$water_high_day) 3 else if(days>0) 2 else 1
  facility<-get('sanitation_facility');shared<-get('sanitation_shared');sanitation<-NA_character_
  if(!is.na(facility)) {
   if(facility=='no_facility___bush___field') sanitation<-'open_defecation'
   else if(facility %in% c('flush_to_open_drain','dry_pit_latrine_without_slab___open_pit','bucket','other_container','hanging_toilet___hanging_latrine')) sanitation<-'unimproved'
   else if(facility %in% c('option_1','option_2','flush_to_pit_latrine','dry_pit_latrine_with_slap')) {
    if(!is.na(shared)&&shared %in% c('yes','no')) sanitation<-if(shared=='yes') 'limited' else 'at_least_basic'
   } else qa<-c(qa,'sanitation_facility: Other/composting/destination needs reviewed recode')
  }
  sl<-if(is.na(sanitation)) NA_real_ else c(at_least_basic=1,limited=2,unimproved=2,open_defecation=3)[[sanitation]]
  hw<-get('handwashing_status');provenance<-get('handwashing_evidence');handwashing<-NA_character_
  if(!is.na(provenance)&&provenance %in% c('observed','reported_only')&&(!observed_handwashing_only||provenance=='observed')&&!is.na(hw)) {
   handwashing<-if(hw=='both') 'basic' else if(hw %in% c('water_only','soap_only','neither')) 'limited' else if(hw=='no_place') 'no_facility' else NA_character_
  }
  hwl<-if(is.na(handwashing)) NA_real_ else if(handwashing=='basic') 1 else 2
  hygiene<-map('water_hygiene_sufficient_7d',c(yes=1,no=2))
  wash<-max_component(list(component(wl),component(shortage),component(sl),component(hwl),component(hygiene)))
  need<-get('health_need_30d');access<-get('health_access');unresolved<-get('health_unresolved');impact<-get('health_activity_impact')
  health<-component();historical_unmet<-NA_real_;current_unmet<-NA_real_
  if(!is.na(need)&&need=='no') {health<-component(1);historical_unmet<-0;current_unmet<-0}
  else if(!is.na(need)&&need=='yes'&&!is.na(access)) {
   if(access=='all') {health<-component(1);historical_unmet<-0;current_unmet<-0}
   else if(access %in% c('some','none')) {
    historical_unmet<-1
    if(!is.na(unresolved)&&unresolved=='no') {health<-component(1);current_unmet<-0}
    else if(!is.na(unresolved)&&unresolved=='yes') {
     current_unmet<-1;v<-map('health_activity_impact',c(no_limitation=2,some_limitation=3,unable_usual_activities=4))
     health<-if(is.na(v)) component(2,FALSE) else component(v)
    }
   } else qa<-c(qa,'health_access: unmapped code')
  }
  sectors<-lapply(list(food=food,shelter=shelter,wash=wash,health=health),sector_result)
  levels<-vapply(sectors,`[[`,numeric(1),'level');high<-vapply(sectors,`[[`,integer(1),'high');very<-vapply(sectors,`[[`,integer(1),'very_high')
  cb<-count_bounds(high);vb<-count_bounds(very)
  max_obs<-if(all(is.na(levels))) NA_real_ else max(levels,na.rm=TRUE)
  exact<-vapply(sectors,`[[`,numeric(1),'exact')
  max_exact<-if(!is.na(max_obs)&&(max_obs==4||all(!is.na(exact)))) max_obs else NA_real_
  active<-vapply(names(rules$lcs_classes),function(n) {
   a<-get(paste0('lcsen_',n));if(is.na(a)) NA_real_ else if(a %in% c('yes','no_exhausted')) 1 else if(a %in% c('no_not_needed','not_applicable')) 0 else NA_real_
  },numeric(1))
  lcs<-if(all(is.na(active))) NA_real_ else if(any(active==1,na.rm=TRUE)) max(rules$lcs_classes[!is.na(active)&active==1]) else 1
  baseline<-get('use_mode') %in% c('idp_baseline','host_baseline')
  allowed<-release&&baseline
  rec<-as.list(x[i,ids,drop=FALSE]);rec$rule_version<-rules$version;rec$rule_status<-rules$status
  rec$analysis_status<-if(!baseline) 'excluded_nonbaseline' else if(!release) 'native_only_draft_mappings_withheld' else if(rules$status=='draft') 'draft_scenario_not_for_targeting' else 'approved_rules'
  rec$fcs_score<-if(baseline) fcs else NA_real_;rec$fcs_category<-if(baseline) fc else NA_character_;rec$fcs_complete<-baseline&&!is.na(fcs);rec$fcs_cutoffs<-paste(rules$fcs_cutoffs,collapse='/')
  rec$hhs_score<-if(baseline) hs else NA_real_;rec$hhs_category<-if(baseline) hc else NA_character_;rec$hhs_lower<-if(baseline) hlo else NA_real_;rec$hhs_upper<-if(baseline) hup else NA_real_;rec$hhs_bounded_category<-if(baseline) hb else NA_character_;rec$hhs_extreme_review<-if(baseline&&!is.na(hs)) hs>=5 else NA
  rec$water_service_category<-if(baseline) water_service else NA_character_;rec$sanitation_service_category<-if(baseline) sanitation else NA_character_;rec$handwashing_service_category<-if(baseline) handwashing else NA_character_;rec$handwashing_evidence<-provenance
  rec$health_unmet_30d<-if(baseline) historical_unmet else NA_real_;rec$health_current_unmet<-if(baseline) current_unmet else NA_real_
  rec$lcs_class_observed<-if(allowed) lcs else NA_real_;rec$lcs_complete<-if(allowed) all(!is.na(active)) else NA
  rec$lcs_used_strategies<-paste(names(active)[vapply(names(active),function(n) identical(get(paste0('lcsen_',n)),'yes'),logical(1))],collapse=';')
  rec$lcs_exhausted_strategies<-paste(names(active)[vapply(names(active),function(n) identical(get(paste0('lcsen_',n)),'no_exhausted'),logical(1))],collapse=';')
  for(s in names(sectors)) {
   rec[[paste0(s,'_level_observed')]]<-if(allowed) sectors[[s]]$level else NA_real_
   rec[[paste0(s,'_classification_status')]]<-if(allowed) sectors[[s]]$status else 'withheld'
   rec[[paste0(s,'_high_need')]]<-if(allowed) sectors[[s]]$high else NA_integer_
   rec[[paste0(s,'_very_high_need')]]<-if(allowed) sectors[[s]]$very_high else NA_integer_
  }
  for(n in c('lower','upper','exact','known','concurrence')) {rec[[paste0('high_count_',n)]]<-if(allowed) cb[[n]] else NA_real_;rec[[paste0('very_high_count_',n)]]<-if(allowed) vb[[n]] else NA_real_}
  rec$number_sectors_complete<-if(allowed) sum(vapply(sectors,function(s) s$status=='complete',logical(1))) else NA_integer_
  rec$highest_level_observed<-if(allowed) max_obs else NA_real_;rec$highest_level_exact<-if(allowed) max_exact else NA_real_
  labels<-c('Food','Shelter','WASH','Health');rec$high_combination_observed<-if(allowed) paste(labels[!is.na(high)&high==1],collapse=';') else NA_character_
  rec$combination_status<-if(allowed) if(all(!is.na(high))) 'exact' else 'partial' else 'withheld'
  for(n in c('hhh_sex','hhh_age','household_size','hosting_others','hosted_by_others','repeat_displacement','functional_difficulty_present','pregnant_breastfeeding_present')) rec[[n]]<-get(n)
  # Independent descriptive profiles; none contributes points to sector needs.
  yesno<-function(n) map(n,c(yes=1,no=0))
  age<-int('hhh_age',0,120);size<-int('household_size',1)
  rec$head_age_group<-if(is.na(age)) NA_character_ else if(age<18) '<18' else if(age<50) '18–49' else '50+'
  rec$child_headed<-if(is.na(age)) NA_real_ else as.numeric(age<18)
  demo_names<-c('girls_0_4','girls_5_17','women_18_49','women_50_plus','boys_0_4','boys_5_17','men_18_49','men_50_plus')
  dem<-vapply(demo_names,int,numeric(1));female<-dem[1:4];male<-dem[5:8];child<-dem[c(1,2,5,6)]
  complete_sum<-function(v) if(anyNA(v)) NA_real_ else sum(v)
  total<-complete_sum(dem);children<-complete_sum(child)
  rec$female_total<-complete_sum(female);rec$male_total<-complete_sum(male);rec$children_total<-children;rec$adults_total<-complete_sum(dem[c(3,4,7,8)])
  rec$household_composition_difference<-if(is.na(total)||is.na(size)) NA_real_ else total-size
  rec$household_composition_status<-if(is.na(total)||is.na(size)) 'unknown' else if(total==size) 'consistent' else 'mismatch'
  rec$child_share<-if(!is.na(total)&&total>0&&!is.na(size)&&total==size) children/total else NA_real_
  presence<-function(v) if(any(v>0,na.rm=TRUE)) 1 else if(all(!is.na(v))) 0 else NA_real_
  rec$children_present<-presence(child);rec$children_0_4_present<-presence(dem[c(1,5)])
  diff<-vapply(c('seeing','hearing','walking','remembering','selfcare','communicating'),function(n) get(paste0('difficulty_',n)),character(1))
  qualifying<-diff %in% c('a_lot','cannot')
  rec$functional_difficulty_present<-if(any(qualifying)) 'yes' else if(all(!is.na(diff))&&all(diff %in% c('none','some'))) 'no' else text_or_profile(get('functional_difficulty_present'))
  away<-get('currently_away');ever<-get('ever_displaced');returned<-get('returned')
  displacement<-NA_character_
  if(!is.na(away)&&away=='yes') displacement<-'currently_displaced'
  else if(!is.na(away)&&away=='no') {
   if(!is.na(returned)&&returned=='yes') displacement<-'returned_after_displacement'
   else if(!is.na(ever)&&ever=='no') displacement<-'never_displaced'
   else if(!is.na(ever)&&ever=='yes'&&!is.na(returned)&&returned=='no') displacement<-'other_displacement_history'
  }
  if((!is.na(away)&&away=='yes'&&!is.na(ever)&&ever=='no')||(!is.na(returned)&&returned=='yes'&&!is.na(ever)&&ever=='no')) {displacement<-NA_character_;qa<-c(qa,'displacement: inconsistent history')}
  rec$displacement_profile<-displacement;rec$affected_by_alert<-yesno('affected_by_alert');rec$displacement_alert_link<-if(identical(ever,'no')) NA_real_ else yesno('displacement_alert_link')
  episodes<-int('displacement_episodes',1)
  rec$repeat_displacement<-if(identical(ever,'no')) NA_character_ else if(!is.na(episodes)) if(episodes>=2) 'yes' else 'no' else get('repeat_displacement')
  hosted<-int('hosted_people_count',0);rec$hosted_people_count<-hosted;rec$hosting_load<-if(!is.na(size)&&!is.na(hosted)&&rec$household_composition_status=='consistent') hosted/size else NA_real_
  exact_days<-function(name) {
   precision<-get(paste0(name,'_precision'));v<-raw(paste0(name,'_date'))
   if(is.na(precision)||precision!='exact'||is.na(v)) return(NA_real_)
   value<-suppressWarnings(as.Date(v,format='%Y-%m-%d'))
   if(is.na(value)||format(value,'%Y-%m-%d')!=v||value>date[i]) {qa<<-c(qa,paste0(name,': invalid/future exact date'));return(NA_real_)}
   as.numeric(date[i]-value)
  }
  rec$days_since_departure<-exact_days('departure');rec$days_at_location<-exact_days('arrival')
  school_total<-int('children_5_17_total',0);school_flag<-yesno('children_out_of_school');school_count<-int('children_out_of_school_count',0)
  if(!is.na(school_total)&&school_total==0) {school_flag<-NA_real_;school_count<-NA_real_}
  else if(!is.na(school_flag)&&school_flag==0) {
   if(!is.na(school_count)&&school_count>0) {qa<-c(qa,'education: no attendance gap contradicts positive count');school_flag<-NA_real_;school_count<-NA_real_} else school_count<-0
  }
  if(!is.na(school_total)&&!is.na(school_count)&&school_count>school_total) {qa<-c(qa,'education: count exceeds school-age total');school_count<-NA_real_}
  rec$education_flag<-school_flag;rec$education_proportion<-if(!is.na(school_total)&&school_total>0&&!is.na(school_count)) school_count/school_total else NA_real_
  rec$protection_flag<-yesno('protection_concern');rec$water_shortage_present<-if(is.na(days)) NA_real_ else as.numeric(days>0)
  # Descriptive flags can be retained privately for excluded records; no baseline need score is produced.
  rec$qa_flags<-paste(unique(qa),collapse='; ')
  as.data.frame(rec,stringsAsFactors=FALSE,check.names=FALSE)
 })
 if(!length(out)) stop('Household input has no records.')
 do.call(rbind,out)
}
aggregate_households <- function(derived,min_cell=5,reviewed=FALSE,synthetic=FALSE) {
 if(!is.numeric(min_cell)||length(min_cell)!=1||min_cell<1) stop('Positive minimum cell size required.')
 # No record-level identifiers, coordinates, names, phone numbers or scores reach the dashboard.
 d<-derived[derived$analysis_status %in% c('draft_scenario_not_for_targeting','approved_rules'),,drop=FALSE]
 if(!nrow(d)) return(data.frame())
 profiles<-c('all_households','hhh_sex','hosting_others','repeat_displacement','functional_difficulty_present')
 rows<-list();index<-0
 strata<-split(seq_len(nrow(d)),interaction(d$alert_id,d$community,d$population,d$use_mode,drop=TRUE,lex.order=TRUE))
 for(ix in strata) for(profile in profiles) {
  z<-d[ix,,drop=FALSE];values<-if(profile=='all_households') rep('All',nrow(z)) else ifelse(is.na(z[[profile]]),'Unknown',z[[profile]])
  for(value in unique(values)) {
   y<-z[values==value,,drop=FALSE];n<-nrow(y);known<-!is.na(y$high_count_concurrence);positive<-sum(y$high_count_concurrence==1,na.rm=TRUE)
   # Suppress small denominators and small positive/negative outcome cells, including complements.
   unknown<-sum(!known);negative<-sum(y$high_count_concurrence==0,na.rm=TRUE)
   vknown<-!is.na(y$very_high_count_concurrence);vpositive<-sum(y$very_high_count_concurrence==1,na.rm=TRUE);vunknown<-sum(!vknown);vnegative<-sum(y$very_high_count_concurrence==0,na.rm=TRUE)
   combination_labels<-paste0(ifelse(is.na(y$high_combination_observed)|y$high_combination_observed=='','None observed',y$high_combination_observed),' [',y$combination_status,']')
   combination_counts<-table(combination_labels)
   combination_text<-paste(paste(names(combination_counts),as.integer(combination_counts),sep=': '),collapse=' | ')
   suppress<-n<min_cell||any(c(positive,negative,unknown)>0 & c(positive,negative,unknown)<min_cell)
   # Profile splits share strata totals. Suppress the entire stratum/profile whenever any subgroup is unsafe.
   subgroup_sizes<-table(values)
   suppress<-suppress||any(subgroup_sizes<min_cell)||any(c(vpositive,vnegative,vunknown)>0 & c(vpositive,vnegative,vunknown)<min_cell)||any(combination_counts<min_cell)
   index<-index+1
   rows[[index]]<-data.frame(alert_id=y$alert_id[1],community=y$community[1],population=y$population[1],use_mode=y$use_mode[1],profile=profile,profile_value=value,
    n_assessed=if(suppress) NA_integer_ else n,n_known_outcome=if(suppress) NA_integer_ else sum(known),n_unknown_outcome=if(suppress) NA_integer_ else unknown,
    n_concurrent_high=if(suppress) NA_integer_ else positive,
    percent_concurrent_known=if(suppress||!sum(known)) NA_real_ else round(100*positive/sum(known),1),
    prevalence_lower=if(suppress) NA_real_ else round(100*positive/n,1),prevalence_upper=if(suppress) NA_real_ else round(100*(positive+unknown)/n,1),
    exact_count_0=if(suppress) NA_integer_ else sum(y$high_count_exact==0,na.rm=TRUE),
    exact_count_1=if(suppress) NA_integer_ else sum(y$high_count_exact==1,na.rm=TRUE),
    exact_count_2=if(suppress) NA_integer_ else sum(y$high_count_exact==2,na.rm=TRUE),
    exact_count_3=if(suppress) NA_integer_ else sum(y$high_count_exact==3,na.rm=TRUE),
    exact_count_4=if(suppress) NA_integer_ else sum(y$high_count_exact==4,na.rm=TRUE),
    n_exact_count_unknown=if(suppress) NA_integer_ else sum(is.na(y$high_count_exact)),
    n_concurrent_very_high=if(suppress) NA_integer_ else vpositive,
    n_very_high_known=if(suppress) NA_integer_ else sum(vknown),n_very_high_unknown=if(suppress) NA_integer_ else vunknown,
    very_high_percent_known=if(suppress||!sum(vknown)) NA_real_ else round(100*vpositive/sum(vknown),1),
    very_high_prevalence_lower=if(suppress) NA_real_ else round(100*vpositive/n,1),very_high_prevalence_upper=if(suppress) NA_real_ else round(100*(vpositive+vunknown)/n,1),
    very_high_count_0=if(suppress) NA_integer_ else sum(y$very_high_count_exact==0,na.rm=TRUE),
    very_high_count_1=if(suppress) NA_integer_ else sum(y$very_high_count_exact==1,na.rm=TRUE),
    very_high_count_2=if(suppress) NA_integer_ else sum(y$very_high_count_exact==2,na.rm=TRUE),
    very_high_count_3=if(suppress) NA_integer_ else sum(y$very_high_count_exact==3,na.rm=TRUE),
    very_high_count_4=if(suppress) NA_integer_ else sum(y$very_high_count_exact==4,na.rm=TRUE),
    n_very_high_exact_unknown=if(suppress) NA_integer_ else sum(is.na(y$very_high_count_exact)),
    high_combination_distribution=if(suppress) NA_character_ else combination_text,
    number_sectors='4: Food; Shelter; WASH; Health',suppressed=suppress,reviewed=reviewed,synthetic=synthetic,
    rule_version=y$rule_version[1],rule_status=y$rule_status[1],stringsAsFactors=FALSE)
  }
 }
 result<-do.call(rbind,rows)
 # Complement protection: blank all rows of a profile within a stratum if any output cell is unsafe.
 groups<-split(seq_len(nrow(result)),interaction(result$alert_id,result$community,result$population,result$use_mode,result$profile,drop=TRUE))
 numeric_cols<-names(result)[vapply(result,is.numeric,logical(1))]
 for(ix in groups) {
  unsafe<-any(result$suppressed[ix])
  counts<-as.matrix(result[ix,c('exact_count_0','exact_count_1','exact_count_2','exact_count_3','exact_count_4','n_exact_count_unknown','very_high_count_0','very_high_count_1','very_high_count_2','very_high_count_3','very_high_count_4','n_very_high_exact_unknown')])
  unsafe<-unsafe||any(counts>0&counts<min_cell,na.rm=TRUE)
  if(unsafe) {result[ix,numeric_cols]<-NA;result$high_combination_distribution[ix]<-NA_character_;result$suppressed[ix]<-TRUE}
 }
 # Overall cells can expose hidden subgroups. Conservatively suppress the whole stratum if any profile is unsafe.
 strata_out<-split(seq_len(nrow(result)),interaction(result$alert_id,result$community,result$population,result$use_mode,drop=TRUE))
 for(ix in strata_out) if(any(result$suppressed[ix])) {result[ix,numeric_cols]<-NA;result$high_combination_distribution[ix]<-NA_character_;result$suppressed[ix]<-TRUE}
 result
}
