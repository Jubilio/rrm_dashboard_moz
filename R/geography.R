# Supplied geography is context; only dated coverage assignments can colour districts.
map_reference <- function(path=file.path('data','geography','admin_reference.csv')) {
  read.csv(path, stringsAsFactors=FALSE, colClasses='character', fileEncoding='UTF-8', na.strings=character())
}
map_key <- function(x) {
  x <- iconv(as.character(x),from='UTF-8',to='ASCII//TRANSLIT')
  tolower(gsub('[^[:alnum:]]','',x))
}
coverage_district_codes <- function(x, reference=map_reference()) {
  r <- reference[reference$level=='admin2',,drop=FALSE]
  aliases <- rbind(data.frame(key=map_key(r$pcode),pcode=r$pcode),
                   data.frame(key=map_key(r$name),pcode=r$pcode),
                   data.frame(key=map_key(r$label),pcode=r$pcode))
  lookup <- split(aliases$pcode,aliases$key)
  values <- if('area_pcode' %in% names(x)) x$area_pcode else x$area
  vapply(map_key(values),function(k) {
    if(is.na(k)||!nzchar(k)||is.null(lookup[[k]])) return(NA_character_)
    code <- unique(lookup[[k]])
    if(length(code)==1) code else NA_character_
  },character(1),USE.NAMES=FALSE)
}
read_map_layers <- function(path=file.path('data','geography')) {
  read <- function(name) {
    g <- jsonlite::fromJSON(file.path(path,paste0(name,'.geojson')),simplifyVector=FALSE)
    if(!identical(g$type,'FeatureCollection')) stop('Expected a GeoJSON FeatureCollection: ',name)
    g
  }
  list(districts=read('districts'),provinces=read('provinces'),towns=read('towns'),posts=read('administrative_posts'))
}
coverage_map_payload <- function(assignments,mode,province='All',district='All',layers=read_map_layers(),post='All') {
  if(is.null(province)) province <- 'All'
  if(is.null(district)) district <- 'All'
  if(is.null(post)) post <- 'All'
  codes <- if(mode=='demo') rep(NA_character_,nrow(assignments)) else coverage_district_codes(assignments)
  districts <- layers$districts
  districts$features <- Filter(function(f) {
    (province=='All'||f$properties$province_pcode==province) && (district=='All'||f$properties$pcode==district)
  },districts$features)
  posts <- layers$posts
  selected_districts <- vapply(districts$features,function(f) f$properties$pcode,character(1))
  posts$features <- Filter(function(f) {
    f$properties$district_pcode %in% selected_districts && (post=='All'||f$properties$pcode==post)
  },posts$features)
  if(post!='All') {
    parents <- vapply(posts$features,function(f) f$properties$district_pcode,character(1))
    districts$features <- Filter(function(f) f$properties$pcode %in% parents,districts$features)
  }
  districts$features <- lapply(districts$features,function(f) {
    rows <- assignments[which(!is.na(codes) & codes==f$properties$pcode),,drop=FALSE]
    f$properties$assigned <- any(!is.na(rows$role)&rows$role!='Unknown')
    f$properties$assignment <- if(mode=='demo') 'Geographic context only; demo areas are fictional.' else if(nrow(rows)) paste(unique(paste(rows$partner,rows$role,sep=': ')),collapse='; ') else 'Unknown / no matching assignment in the current filters.'
    f
  })
  selected <- vapply(districts$features,function(f) f$properties$pcode,character(1))
  towns <- layers$towns
  towns$features <- Filter(function(f) f$properties$district_pcode %in% selected && (post=='All'||identical(f$properties$post_pcode,post)),towns$features)
  provinces <- layers$provinces
  parents <- unique(vapply(districts$features,function(f) f$properties$province_pcode,character(1)))
  provinces$features <- Filter(function(f) f$properties$pcode %in% parents,provinces$features)
  list(districts=districts,provinces=provinces,towns=towns,posts=posts,selected_post=post,
       unmapped=if(mode=='demo') 0L else sum(is.na(codes)),mode=mode)
}
geography_controls <- function(ns) {
  r <- map_reference(); p <- r[r$level=='admin1',]; a <- r[r$level=='admin2',]; b <- r[r$level=='admin3',]
  shiny::tagList(
    shiny::div(class='map-filters',
      shiny::selectInput(ns('map_province'),'Map province',choices=c('All'= 'All',setNames(p$pcode,p$label))),
      shiny::selectInput(ns('map_district'),'Map district',choices=c('All'= 'All',setNames(a$pcode,a$label))),
      shiny::selectInput(ns('map_post'),'Map administrative post',choices=c('All'='All',setNames(b$pcode,paste(b$label,b$pcode,sep=' · '))))),
    shiny::p(class='muted','Map controls change the geographic view. Assignment filters above control the table and KPIs.'))
}
rrm_map_output <- function(outputId) {
  dep <- htmltools::htmlDependency('rrm-geography','1.1.1',src=c(file='www'),
      script=c('vendor/leaflet/leaflet.js','geography.js'),stylesheet=c('vendor/leaflet/leaflet.css','geography.css'))
  htmltools::attachDependencies(shiny::div(id=outputId,class='rrm-map-output',
      role='region',`aria-label`='District coverage map',style='height:430px;'),dep)
}
render_rrm_map <- function(expr,env=parent.frame(),quoted=FALSE) {
  func <- shiny::exprToFunction(expr,env,quoted)
  shiny::createRenderFunction(func,function(value,session,name,...) value,rrm_map_output)
}
