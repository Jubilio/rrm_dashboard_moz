# Geographic linkage is separate from source validation and never allocates reach.
read_settlement_points <- function(path='data/geography/settlements.csv') {
  x <- read.csv(path,stringsAsFactors=FALSE,colClasses='character',na.strings='',fileEncoding='UTF-8')
  fields <- c('point_id','name','longitude','latitude','district_pcode','post_pcode','admin_conflict')
  if(!all(fields %in% names(x))||anyDuplicated(x$point_id)) stop('Settlement gazetteer schema or IDs are invalid.')
  x$longitude <- suppressWarnings(as.numeric(x$longitude));x$latitude <- suppressWarnings(as.numeric(x$latitude))
  if(any(!is.finite(x$longitude)|!is.finite(x$latitude)|abs(x$longitude)>180|abs(x$latitude)>90)) stop('Invalid settlement coordinates.')
  if(any(!x$admin_conflict %in% c('True','False','TRUE','FALSE'))) stop('Invalid settlement administrative conflict flag.')
  x$admin_conflict <- tolower(x$admin_conflict)=='true'
  x
}
location_reference_code <- function(value,level,reference=map_reference(),parent=NULL) {
  if(!length(value)||is.na(value)||!nzchar(trimws(value)))return(NA_character_)
  r<-reference[reference$level==level,,drop=FALSE]
  if(!is.null(parent))r<-r[r$parent_pcode==parent,,drop=FALSE]
  k<-map_key(value)
  ids<-unique(r$pcode[map_key(r$pcode)==k|map_key(r$name)==k|map_key(r$label)==k])
  if(length(ids)==1)ids else NA_character_
}
match_intervention_locations <- function(activities,points,reference=map_reference()) {
  n<-nrow(activities)
  result<-data.frame(record_id=activities$record_id,source_row=activities$source_row,alert_id=activities$alert_id,
    implementing_agency=activities$implementing_agency,
    district=activities$district,admin_post=activities$admin_post,community=activities$community,
    review_status=activities$review_status,eligible=activities$eligible,
    match_status=rep('Not found',n),match_method=rep(NA_character_,n),point_id=rep(NA_character_,n),
    matched_place=rep(NA_character_,n),source_layer=rep(NA_character_,n),
    longitude=rep(NA_real_,n),latitude=rep(NA_real_,n),candidate_count=integer(n),
    candidates=rep(NA_character_,n),match_note=rep(NA_character_,n),stringsAsFactors=FALSE)
  if(!n)return(result)
  if(is.null(points)) {result$match_status<-'Gazetteer unavailable';return(result)}
  point_keys<-map_key(points$name)
  for(i in seq_len(n)) {
    a<-activities[i,,drop=FALSE]
    dc<-location_reference_code(a$district,'admin2',reference)
    if(is.na(dc)) {result$match_status[i]<-'Missing / unknown district';next}
    province<-location_reference_code(a$province,'admin1',reference)
    if(!is.na(province)&&substr(dc,1,4)!=province) {result$match_status[i]<-'Province/district mismatch';next}
    name<-a$community
    if(is.na(name)||!nzchar(trimws(name))) {result$match_status[i]<-'Missing community';next}
    scope<-a$location_coverage
    if(is.na(scope)||scope!='Single location'||grepl('[,;/&\n]|\\band\\b|\\be\\b',name,ignore.case=TRUE,perl=TRUE)) {
      result$match_status[i]<-if(!is.na(scope)&&scope=='Unconfirmed') 'Location scope unconfirmed' else 'Combined locations - review'
      next
    }
    pc<-location_reference_code(a$admin_post,'admin3',reference,dc)
    district_rows<-which(points$district_pcode==dc)
    exact<-district_rows[point_keys[district_rows]==map_key(name)]
    # Source Pcodes are not an approved point-code crosswalk (four supplied values are Tier labels).
    note<-character()
    if(!is.na(a$pcode)&&nzchar(trimws(a$pcode))) note<-c(note,'Source Pcode retained in workbook; not used as a settlement identifier.')
    if(!is.na(a$admin_post)&&nzchar(trimws(a$admin_post))&&is.na(pc)) note<-c(note,'Reported administrative post could not be resolved; unique district/name required.')
    good<-exact[!points$admin_conflict[exact]]
    if(length(exact)&&!length(good))result$match_status[i]<-'Settlement administrative conflict'
    if(!is.na(pc)&&length(good)) {
      good<-good[!is.na(points$post_pcode[good])&points$post_pcode[good]==pc]
      if(!length(good))result$match_status[i]<-'Administrative-post mismatch'
    }
    # Collapse exact co-located duplicate names only (coordinates rounded to ~1 m).
    if(length(good)) {
      place_key<-paste(point_keys[good],points$district_pcode[good],points$post_pcode[good],round(points$longitude[good],5),round(points$latitude[good],5))
      good<-good[!duplicated(place_key)]
    }
    result$candidate_count[i]<-length(good)
    if(length(good)==1) {
      p<-points[good,,drop=FALSE]
      result$match_status[i]<-'Matched'
      result$match_method[i]<-if(is.na(pc)) 'Exact community + district' else 'Exact community + district + administrative post'
      for(field in c('point_id','longitude','latitude','source_layer'))result[[field]][i]<-p[[field]]
      result$matched_place[i]<-p$name
      note<-c(note,'Geographic name match only; intervention delivery and source review are not independently verified.')
    } else {
      if(length(good)>1)result$match_status[i]<-'Ambiguous settlement'
      suggestions<-if(length(exact))exact else {
        distance<-as.integer(adist(map_key(name),point_keys[district_rows]))
        limit<-min(2L,max(1L,floor(nchar(map_key(name))*0.2)))
        district_rows[order(distance)][sort(distance)<=limit]
      }
      suggestions<-head(suggestions,5)
      if(length(suggestions))result$candidates[i]<-paste(paste(points$name[suggestions],points$admin_post[suggestions],points$point_id[suggestions],sep=' | '),collapse='; ')
    }
    if(length(note))result$match_note[i]<-paste(note,collapse=' ')
  }
  result
}
intervention_map_payload <- function(activities,links,points,layers=read_map_layers()) {
  empty<-data.frame(area=character(),partner=character(),role=character())
  payload<-coverage_map_payload(empty,'operational',layers=layers)
  payload$kind<-'interventions'
  dc<-unique(vapply(activities$district,location_reference_code,character(1),level='admin2'))
  if(any(!is.na(dc))) {
    payload$districts$features<-Filter(function(f)f$properties$pcode %in% dc,payload$districts$features)
    payload$posts$features<-Filter(function(f)f$properties$district_pcode %in% dc,payload$posts$features)
    payload$towns$features<-Filter(function(f)f$properties$district_pcode %in% dc,payload$towns$features)
  }
  payload$markers<-list(type='FeatureCollection',features=list())
  for(id in unique(links$point_id[links$match_status=='Matched'])) {
    ix<-which(links$match_status=='Matched'&!is.na(links$point_id)&links$point_id==id)
    p<-points[match(id,points$point_id),,drop=FALSE];a<-activities[ix,,drop=FALSE]
    properties<-list(point_id=id,name=p$name,district=p$district,admin_post=p$admin_post,source_layer=p$source_layer,
      record_count=length(unique(a$record_id)),validated_records=length(unique(a$record_id[a$eligible])),
      other_records=length(unique(a$record_id[!a$eligible])),
      agencies=paste(sort(unique(a$implementing_agency[!is.na(a$implementing_agency)])),collapse=', '),
      sectors=paste(sort(unique(a$sector[!is.na(a$sector)])),collapse=', '))
    payload$markers$features[[length(payload$markers$features)+1L]]<-list(type='Feature',properties=properties,
       geometry=list(type='Point',coordinates=unname(c(p$longitude,p$latitude))))
  }
  payload$settlements<-list(type='FeatureCollection',features=list())
  if(!is.null(points)) {
    p<-points[if(any(!is.na(dc))) points$district_pcode %in% dc else rep(TRUE,nrow(points)),,drop=FALSE]
    payload$settlements$features<-lapply(seq_len(nrow(p)),function(i)list(type='Feature',
      properties=list(name=p$name[i],point_id=p$point_id[i],source_layer=p$source_layer[i],district=p$district[i],admin_post=p$admin_post[i]),
      geometry=list(type='Point',coordinates=unname(c(p$longitude[i],p$latitude[i])))))
  }
  payload
}
