# Supplied geography is context; only dated coverage assignments can colour districts.
map_reference <- function(path = file.path('data', 'geography', 'admin_reference.csv')) {
  read.csv(
    path,
    stringsAsFactors = FALSE,
    colClasses = 'character',
    fileEncoding = 'UTF-8',
    na.strings = character()
  )
}
map_key <- function(x) {
  x <- iconv(as.character(x), from = 'UTF-8', to = 'ASCII//TRANSLIT')
  tolower(gsub('[^[:alnum:]]', '', x))
}
coverage_district_codes <- function(x, reference = map_reference()) {
  r <- reference[reference$level == 'admin2', , drop = FALSE]
  aliases <- rbind(
    data.frame(key = map_key(r$pcode), pcode = r$pcode),
    data.frame(key = map_key(r$name), pcode = r$pcode),
    data.frame(key = map_key(r$label), pcode = r$pcode),
    # Explicit spelling variants and the user-confirmed MDP abbreviation.
    data.frame(key = c('meuda', 'montepez', 'mteuge', 'pemba', 'mdp'),
               pcode = c('mz0112', 'mz0111', 'mz0109', 'mz0104', 'mz0110'))
  )
  aliases <- aliases[aliases$pcode %in% r$pcode, , drop = FALSE]
  lookup <- split(aliases$pcode, aliases$key)
  values <- if ('area_pcode' %in% names(x))
    x$area_pcode
  else
    x$area
  vapply(map_key(values), function(k) {
    if (is.na(k) ||
        !nzchar(k) || is.null(lookup[[k]]))
      return(NA_character_)
    code <- unique(lookup[[k]])
    if (length(code) == 1)
      code
    else
      NA_character_
  }, character(1), USE.NAMES = FALSE)
}
coverage_assignment_links <- function(x, reference = map_reference()) {
  empty <- data.frame(assignment_row = integer(), pcode = character())
  if (!nrow(x)) return(empty)
  values <- if ('area_pcode' %in% names(x)) x$area_pcode else x$area
  # Expand only the map links. Source rows and dashboard totals stay unchanged.
  links <- lapply(seq_len(nrow(x)), function(i) {
    parts <- if (is.na(values[i]) || !nzchar(trimws(values[i]))) {
      NA_character_
    } else {
      trimws(strsplit(values[i], '[,;]', perl = TRUE)[[1]])
    }
    if (!length(parts)) parts <- NA_character_
    codes <- coverage_district_codes(data.frame(area = parts), reference)
    data.frame(assignment_row = i, pcode = unique(codes))
  })
  do.call(rbind, links)
}
coverage_area_names <- function(x, mode = 'operational', reference = map_reference()) {
  values <- if ('area_pcode' %in% names(x)) x$area_pcode else x$area
  parts <- trimws(unlist(strsplit(values[!is.na(values)], '[,;]', perl = TRUE),
                        use.names = FALSE))
  parts <- parts[nzchar(parts)]
  if (mode != 'demo' && length(parts)) {
    codes <- coverage_district_codes(data.frame(area = parts), reference)
    matched <- !is.na(codes)
    parts[matched] <- reference$label[match(codes[matched], reference$pcode)]
  }
  sort(unique(parts))
}
filter_coverage_area <- function(x, area, mode = 'operational') {
  if (is.null(area) || !length(area) || identical(area, 'All')) return(x)
  code <- if (mode == 'demo') NA_character_ else
    coverage_district_codes(data.frame(area = area))
  if (!is.na(code)) {
    links <- coverage_assignment_links(x)
    rows <- unique(links$assignment_row[which(links$pcode == code)])
    return(x[rows, , drop = FALSE])
  }
  # Fictional demo areas and unresolved source tokens still filter exactly.
  rows <- vapply(seq_len(nrow(x)), function(i)
    area %in% coverage_area_names(x[i, , drop = FALSE], mode), logical(1))
  x[rows, , drop = FALSE]
}
read_map_layers <- function(path = file.path('data', 'geography')) {
  read <- function(name) {
    g <- jsonlite::fromJSON(file.path(path, paste0(name, '.geojson')), simplifyVector =
                              FALSE)
    if (!identical(g$type, 'FeatureCollection'))
      stop('Expected a GeoJSON FeatureCollection: ', name)
    g
  }
  list(
    districts = read('districts'),
    provinces = read('provinces'),
    towns = read('towns'),
    posts = read('administrative_posts')
  )
}
# Map icons served from www/map_icons; partners without an icon get a text button.
map_partner_icons <- c(NRC = 'map_icons/nrc.svg', SI = 'map_icons/si.svg',
                       ACF = 'map_icons/acf.svg', SCI = 'map_icons/sci.svg')
map_partner_names <- c(NRC = 'Norwegian Refugee Council', SI = 'Solidarités International',
                       ACF = 'Action Against Hunger', SCI = 'Save the Children')
# Per-partner district pcodes by role, for the clickable partner icons on the map.
coverage_partner_layers <- function(assignments, links) {
  ok <- !is.na(assignments$partner) & nzchar(trimws(assignments$partner))
  partners <- sort(unique(trimws(assignments$partner[ok])))
  lapply(partners, function(p) {
    codes <- function(role) {
      rows <- which(trimws(assignments$partner) == p & assignments$role == role)
      unique(stats::na.omit(links$pcode[links$assignment_row %in% rows]))
    }
    primary <- codes('Primary')
    list(
      partner = p,
      name = if (p %in% names(map_partner_names)) unname(map_partner_names[[p]]) else p,
      icon = if (p %in% names(map_partner_icons)) unname(map_partner_icons[[p]]) else '',
      primary = as.list(primary),
      # A district listed under both roles for one partner is shown as primary.
      secondary = as.list(setdiff(codes('Secondary'), primary))
    )
  })
}
coverage_map_payload <- function(assignments,
                                 mode,
                                 province = 'All',
                                 district = 'All',
                                 layers = read_map_layers(),
                                 post = 'All') {
  if (is.null(province))
    province <- 'All'
  if (is.null(district))
    district <- 'All'
  if (is.null(post))
    post <- 'All'
  links <- if (mode == 'demo')
    data.frame(assignment_row = integer(), pcode = character())
  else
    coverage_assignment_links(assignments)
  districts <- layers$districts
  districts$features <- Filter(function(f) {
    (province == 'All' ||
       f$properties$province_pcode == province) &&
      (district == 'All' || f$properties$pcode == district)
  }, districts$features)
  posts <- layers$posts
  selected_districts <- vapply(districts$features, function(f)
    f$properties$pcode, character(1))
  posts$features <- Filter(function(f) {
    f$properties$district_pcode %in% selected_districts &&
      (post == 'All' || f$properties$pcode == post)
  }, posts$features)
  if (post != 'All') {
    parents <- vapply(posts$features, function(f)
      f$properties$district_pcode, character(1))
    districts$features <- Filter(function(f)
      f$properties$pcode %in% parents,
      districts$features)
  }
  districts$features <- lapply(districts$features, function(f) {
    matched_rows <- unique(links$assignment_row[which(
      !is.na(links$pcode) & links$pcode == f$properties$pcode)])
    rows <- assignments[matched_rows, , drop = FALSE]
    f$properties$assigned <- any(!is.na(rows$role) &
                                   rows$role != 'Unknown')
    f$properties$assignment <- if (mode == 'demo')
      'Geographic context only; demo areas are fictional.'
    else if (nrow(rows))
      paste(unique(paste(rows$partner, rows$role, sep = ': ')), collapse = '; ')
    else
      'Unknown / no matching assignment in the current filters.'
    f
  })
  selected <- vapply(districts$features, function(f)
    f$properties$pcode, character(1))
  towns <- layers$towns
  towns$features <- Filter(
    function(f)
      f$properties$district_pcode %in% selected &&
      (post == 'All' ||
         identical(f$properties$post_pcode, post)),
    towns$features
  )
  provinces <- layers$provinces
  parents <- unique(vapply(districts$features, function(f)
    f$properties$province_pcode, character(1)))
  provinces$features <- Filter(function(f)
    f$properties$pcode %in% parents,
    provinces$features)
  list(
    districts = districts,
    provinces = provinces,
    towns = towns,
    posts = posts,
    partners = if (mode == 'demo') list() else coverage_partner_layers(assignments, links),
    selected_post = post,
    unmapped = if (mode == 'demo')
      0L
    else
      length(unique(links$assignment_row[is.na(links$pcode)])),
    mode = mode
  )
}
geography_controls <- function(ns, include_province = TRUE) {
  r <- map_reference()
  p <- r[r$level == 'admin1', ]
  a <- r[r$level == 'admin2', ]
  b <- r[r$level == 'admin3', ]
  shiny::tagList(
    shiny::div(
      class = 'map-filters',
      if (include_province)
        shiny::selectInput(
          ns('map_province'),
          'Map province',
          choices = c('All' = 'All', setNames(p$pcode, p$label))
        ),
      shiny::selectInput(
        ns('map_district'),
        'Map district',
        choices = c('All' = 'All', setNames(a$pcode, a$label))
      ),
      shiny::selectInput(
        ns('map_post'),
        'Map administrative post',
        choices = c('All' = 'All', setNames(
          b$pcode, paste(b$label, b$pcode, sep = ' · ')
        ))
      )
    ),
    shiny::p(
      class = 'muted',
      'Map controls change the geographic view. Assignment filters above control the table and KPIs.'
    )
  )
}
rrm_map_output <- function(outputId) {
  dep <- htmltools::htmlDependency(
    'rrm-geography',
    '1.6.0',
    src = c(file = 'www'),
    script = c('vendor/leaflet/leaflet.js', 'geography.js'),
    stylesheet = c('vendor/leaflet/leaflet.css', 'geography.css')
  )
  htmltools::attachDependencies(
    shiny::div(
      id = outputId,
      class = 'rrm-map-output',
      role = 'region',
      `aria-label` = if (grepl('alert_map$', outputId))
        'Alert origin and arrival map'
      else
        'District coverage map'
    ),
    dep
  )
}
render_rrm_map <- function(expr,
                           env = parent.frame(),
                           quoted = FALSE) {
  func <- shiny::exprToFunction(expr, env, quoted)
  shiny::createRenderFunction(func, function(value, session, name, ...)
    value, rrm_map_output)
}

source("R/intervention_locations.R", local = TRUE)
