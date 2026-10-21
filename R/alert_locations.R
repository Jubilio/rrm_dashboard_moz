# Route endpoint coordinates are supplied separately from route caseloads.
read_alert_locations <- function(mode,base_dir='.') {
  if(!mode %in% c('demo','operational')) stop('Invalid alert location data mode.')
  fields <- c('route_id','endpoint','location_name','longitude','latitude','coordinate_source','coordinate_status')
  path <- file.path(base_dir,'data',mode,'route_locations.csv')
  if(!file.exists(path)) {
    empty <- as.data.frame(setNames(rep(list(character()),length(fields)),fields),stringsAsFactors=FALSE)
    empty$longitude <- numeric();empty$latitude <- numeric();return(empty)
  }
  x <- read.csv(path,colClasses='character',na.strings='',check.names=FALSE,fileEncoding='UTF-8')
  validate_alert_locations(x,mode)
}
validate_alert_locations <- function(x,mode,allow_incomplete=FALSE) {
  fields <- c('route_id','endpoint','location_name','longitude','latitude','coordinate_source','coordinate_status')
  if(!identical(names(x),fields)) stop('route_locations.csv columns must match the template.')
  if(anyDuplicated(x[c('route_id','endpoint')])) stop('Duplicate route endpoint coordinates.')
  if(any(is.na(x$route_id)|!nzchar(trimws(x$route_id)))||any(!x$endpoint %in% c('origin','arrival'))) stop('Route endpoint IDs or types are invalid.')
  allowed <- if(mode=='demo') 'Demo' else c('Confirmed','Pending','Rejected')
  if(allow_incomplete) allowed <- union(allowed,c('Pending','Rejected'))
  status <- x$coordinate_status
  if(allow_incomplete) status <- status[!is.na(status)]
  if(any(!status %in% allowed)) stop('Coordinate status is not permitted in this data mode.')
  if(mode=='operational'&&any(grepl('DEMO',as.matrix(x),ignore.case=TRUE),na.rm=TRUE)) stop('Operational route locations contain DEMO labels.')
  for(field in c('longitude','latitude')) {
    raw <- x[[field]];x[[field]] <- suppressWarnings(as.numeric(raw))
    if(any(!is.na(raw)&(!is.finite(x[[field]])|abs(x[[field]])>if(field=='longitude') 180 else 90))) stop('Invalid route ',field)
  }
  x
}
alert_endpoint_links <- function(routes,locations,mode) {
  x <- data.frame(route_id=rep(routes$route_id,each=2),alert_id=rep(routes$alert_id,each=2),
    endpoint=rep(c('origin','arrival'),nrow(routes)),location_name=as.vector(t(as.matrix(routes[c('origin','arrival')]))),
    people=rep(routes$people,each=2),households=rep(routes$households,each=2),
    caseload_stage=rep(routes$caseload_stage,each=2),targeted=rep(routes$targeted,each=2),stringsAsFactors=FALSE)
  ix <- match(paste(x$route_id,x$endpoint),paste(locations$route_id,locations$endpoint))
  for(field in c('longitude','latitude','coordinate_source','coordinate_status')) x[[field]] <- locations[[field]][ix]
  x$match_status <- rep('Coordinates not supplied',nrow(x))
  found <- !is.na(ix)
  names_match <- found & !is.na(locations$location_name[ix]) & map_key(x$location_name)==map_key(locations$location_name[ix])
  x$match_status[found & !names_match] <- 'Endpoint name mismatch'
  approved <- names_match & !is.na(x$coordinate_status) & x$coordinate_status==if(mode=='demo') 'Demo' else 'Confirmed'
  x$match_status[names_match & !approved] <- 'Coordinates awaiting confirmation / rejected'
  valid <- approved & is.finite(x$longitude)&is.finite(x$latitude)&!is.na(x$coordinate_source)&nzchar(trimws(x$coordinate_source))
  x$match_status[approved & !valid] <- 'Coordinates or provenance missing'
  x$match_status[valid] <- if(mode=='demo') 'Demo point' else 'Confirmed point'
  x$mapped <- valid
  x
}
alert_map_payload <- function(routes,locations,mode,layers=read_map_layers()) {
  payload <- coverage_map_payload(data.frame(area=character(),partner=character(),role=character()),mode,layers=layers)
  payload$kind <- 'alert_routes';payload$markers <- list(type='FeatureCollection',features=list())
  payload$connections <- list(type='FeatureCollection',features=list())
  links <- alert_endpoint_links(routes,locations,mode)
  good <- links[links$mapped,,drop=FALSE]
  if(nrow(good)) {
    groups <- split(seq_len(nrow(good)),paste(good$endpoint,good$location_name,good$longitude,good$latitude,sep='|'))
    payload$markers$features <- lapply(groups,function(ix) {
      p <- good[ix[1],];z <- good[ix,,drop=FALSE]
      details <- vapply(seq_len(nrow(z)),function(i) paste(z$alert_id[i],z$route_id[i],paste0('Route people: ',fmt(z$people[i])),
        paste0('Route HH: ',fmt(z$households[i])),paste0('Stage: ',z$caseload_stage[i]),paste0('RRM targeted at arrival: ',z$targeted[i]),sep=' | '),character(1))
      list(type='Feature',properties=list(location_id=paste(p$endpoint,p$location_name,p$longitude,p$latitude),name=p$location_name,
        endpoint=p$endpoint,coordinate_source=paste(unique(z$coordinate_source),collapse='; '),coordinate_status=p$coordinate_status,
        details=paste(details,collapse='\n')),
        geometry=list(type='Point',coordinates=unname(c(p$longitude,p$latitude))))
    })
    payload$markers$features <- unname(payload$markers$features)
  }
  for(id in unique(links$route_id)) {
    z <- links[links$route_id==id,,drop=FALSE]
    if(nrow(z)==2L && all(z$mapped)) payload$connections$features[[length(payload$connections$features)+1L]] <- list(type='Feature',
      properties=list(route_id=id,alert_id=z$alert_id[1],origin=z$location_name[1],arrival=z$location_name[2],
        people=z$people[1],households=z$households[1],stage=z$caseload_stage[1],targeted=z$targeted[1]),
      geometry=list(type='LineString',coordinates=lapply(seq_len(2),function(i)unname(c(z$longitude[i],z$latitude[i])))))
  }
  payload$mapped_endpoints <- sum(links$mapped);payload$total_endpoints <- nrow(links)
  payload
}
