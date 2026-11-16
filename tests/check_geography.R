library(shiny)
source('R/data.R'); source('R/pages.R')
r <- map_reference(); g <- read_map_layers()
stopifnot(nrow(r)==85L,sum(r$level=='admin3')==64L,!anyDuplicated(r$pcode),
          length(g$posts$features)==64L,length(g$districts$features)==19L,length(g$provinces$features)==2L,length(g$towns$features)==65L)
post_codes <- vapply(g$posts$features,function(f) f$properties$pcode,character(1))
stopifnot(setequal(post_codes,r$pcode[r$level=='admin3']))
for(f in g$posts$features) stopifnot(f$properties$district_pcode==r$parent_pcode[match(f$properties$pcode,r$pcode)])
codes <- vapply(g$districts$features,function(f) f$properties$pcode,character(1))
stopifnot(setequal(codes,r$pcode[r$level=='admin2']))
x <- data.frame(area=c('MZ0101','Mocímboa da Praia','Cidade De Pemba','Memba','Area 1','Unknown'),
                partner=c('A','B','C','D','E','F'),role=c('Primary','Secondary','Unknown','Primary','Primary','Unknown'))
stopifnot(identical(coverage_district_codes(x),c('mz0101','mz0110','mz0104','mz0711',NA_character_,NA_character_)))
# A source assignment may cover several districts without becoming extra KPI rows.
multi <- data.frame(area=c('Mueda, Nangade, Muidumbe, Mteuge, Montepuez',
                          'Meuda; Montepez; Pemba; Meuda',
                          'Quissanga, MDP, Ibo, Ancuabe, Unknown district'),
                    partner=c('NRC','ACF','NRC'),role=c('Primary','Secondary','Secondary'))
links <- coverage_assignment_links(multi)
stopifnot(setequal(links$pcode[links$assignment_row==1L],
                  c('mz0112','mz0115','mz0113','mz0109','mz0111')),
          sum(links$assignment_row==2L)==3L, anyNA(links$pcode),nrow(multi)==3L)
mapped <- coverage_map_payload(multi,'operational',layers=g)
district_properties <- function(payload,code) {
  Filter(function(f) f$properties$pcode==code,payload$districts$features)[[1]]$properties
}
stopifnot(mapped$unmapped==1L,
          district_properties(mapped,'mz0112')$assignment=='NRC: Primary; ACF: Secondary',
          district_properties(mapped,'mz0104')$assignment=='ACF: Secondary',
          district_properties(mapped,'mz0118')$assigned,
          district_properties(mapped,'mz0110')$assignment=='NRC: Secondary')
only_acf <- coverage_map_payload(multi[multi$partner=='ACF',],'operational',layers=g)
stopifnot(only_acf$unmapped==0L,
          district_properties(only_acf,'mz0112')$assignment=='ACF: Secondary',
          !district_properties(only_acf,'mz0118')$assigned)
area_choices <- coverage_area_names(multi)
stopifnot(!any(grepl('[,;]',area_choices)),
          all(c('Mueda','Metuge','Montepuez','Cidade de Pemba') %in% area_choices),
          !any(c('Meuda','Mteuge','Montepez','MDP') %in% area_choices),
          nrow(filter_coverage_area(multi,'Mueda'))==2L,
          nrow(filter_coverage_area(multi,'Mocimboa da Praia'))==1L,
          nrow(filter_coverage_area(multi,'Unknown district'))==1L,
          nrow(filter_coverage_area(multi,'Absent'))==0L,
          identical(filter_coverage_area(multi,'All'),multi))
explicit_codes <- data.frame(area='Unknown',area_pcode='mz0112, mz0111',
                             partner='A',role='Primary')
stopifnot(setequal(coverage_assignment_links(explicit_codes)$pcode,c('mz0112','mz0111')),
          nrow(coverage_assignment_links(multi[FALSE,]))==0L,
          is.na(coverage_assignment_links(data.frame(area=NA_character_))$pcode))
p <- coverage_map_payload(x,'operational',layers=g)
stopifnot(p$unmapped==2L,sum(vapply(p$districts$features,function(f) f$properties$assigned,logical(1)))==3L)
p <- coverage_map_payload(x,'demo',layers=g)
stopifnot(!any(vapply(p$districts$features,function(f) f$properties$assigned,logical(1))))
p <- coverage_map_payload(x,'operational','mz07',layers=g)
stopifnot(length(p$districts$features)==2L,all(vapply(p$towns$features,function(f) f$properties$district_pcode %in% c('mz0703','mz0711'),logical(1))))
p <- coverage_map_payload(x,'operational','mz01','mz0101',g)
stopifnot(length(p$districts$features)==1L,p$districts$features[[1]]$properties$assigned)
p <- coverage_map_payload(x[FALSE,],'operational',layers=g)
stopifnot(p$unmapped==0L,!any(vapply(p$districts$features,function(f) f$properties$assigned,logical(1))))
p <- coverage_map_payload(x,'operational','mz01','mz0101',g,'mz010102')
stopifnot(length(p$posts$features)==1L,length(p$districts$features)==1L,
          p$posts$features[[1]]$properties$administrative_post=='Mesa',p$selected_post=='mz010102',
          p$districts$features[[1]]$properties$assigned,
          !'assigned' %in% names(p$posts$features[[1]]$properties),
          all(vapply(p$towns$features,function(f) identical(f$properties$post_pcode,'mz010102'),logical(1))))
p <- coverage_map_payload(x,'operational','mz07','All',g,'mz010102')
stopifnot(length(p$posts$features)==0L,length(p$districts$features)==0L,length(p$towns$features)==0L)
p <- coverage_map_payload(x,'operational',layers=g,post='mz010102')
stopifnot(length(p$posts$features)==1L,length(p$districts$features)==1L)
d <- read_rrm_data('demo')

district_data <- d
district_data$metadata$mode <- 'operational'
district_data$coverage <- d$coverage[seq_len(3),]
district_data$coverage$area <- multi$area
district_data$coverage$partner <- multi$partner
district_data$coverage$role <- multi$role
testServer(page_server,args=list(key='coverage',d=district_data),{
  session$setInputs(as_of=as.Date('2026-09-30'),area='Mueda',partner='All',role='All',
                    map_province='All',map_district='All',map_post='All')
  stopifnot(nrow(filtered())==2L,length(map_data()$districts$features)==1L,
            map_data()$districts$features[[1]]$properties$pcode=='mz0112',
            !is.null(output$metrics),!is.null(output$table))
  session$setInputs(partner='ACF')
  stopifnot(nrow(filtered())==1L,filtered()$role=='Secondary')
  session$setInputs(role='Primary')
  stopifnot(nrow(filtered())==0L)
  session$setInputs(area='All',partner='All',role='All')
  stopifnot(nrow(filtered())==3L,length(map_data()$districts$features)==19L)
})
testServer(page_server,args=list(key='coverage',d=d),{
  session$setInputs(as_of=as.Date('2026-09-30'),area='All',partner='All',role='All',map_province='All',map_district='All',map_post='All')
  stopifnot(length(map_data()$districts$features)==19L,!is.null(output$coverage_map),is.null(output$map_slot))
  before <- nrow(filtered())
  session$setInputs(map_province='mz07',map_district='All')
  stopifnot(length(map_data()$districts$features)==2L,nrow(filtered())==before)
  session$setInputs(map_province='mz01',map_district='mz0101')
  stopifnot(length(map_data()$districts$features)==1L,nrow(filtered())==before)
  session$setInputs(map_post='mz010102')
  stopifnot(length(map_data()$posts$features)==1L,nrow(filtered())==before,
            map_data()$selected_post=='mz010102')
  session$setInputs(partner='Absent')
  stopifnot(nrow(filtered())==0L,length(map_data()$districts$features)==1L)
})
message('PASS: supplied geography, exact district joins, demo isolation, missing assignments, hierarchy and Shiny map output.')
