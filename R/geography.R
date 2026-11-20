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
# Boundary layers are read once per path and cached. Each feature geometry is
# stored as pre-encoded JSON (class "json"): Shiny sends it verbatim, so a map
# update no longer re-encodes ~870 KB of nested coordinate lists (~11 s per send).
# Geometry is encoded from simplified arrays, which gives identical JSON ~10x faster.
read_map_layers <- local({
  cache <- list()
  function(path = file.path('data', 'geography')) {
    key <- normalizePath(path, winslash = '/', mustWork = FALSE)
    if (!is.null(cache[[key]])) return(cache[[key]])
    read <- function(name) {
      file <- file.path(path, paste0(name, '.geojson'))
      g <- jsonlite::fromJSON(file, simplifyVector = FALSE)
      if (!identical(g$type, 'FeatureCollection'))
        stop('Expected a GeoJSON FeatureCollection: ', name)
      arrays <- jsonlite::fromJSON(file, simplifyVector = TRUE,
                                   simplifyDataFrame = FALSE, simplifyMatrix = TRUE)
      for (i in seq_along(g$features))
        g$features[[i]]$geometry <- jsonlite::toJSON(arrays$features[[i]]$geometry,
                                                     auto_unbox = TRUE, digits = NA)
      g
    }
    layers <- list(
      districts = read('districts'),
      provinces = read('provinces'),
      towns = read('towns'),
      posts = read('administrative_posts')
    )
    cache[[key]] <<- layers
    layers
  }
})
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
# Link alerts to districts named in their route origin/arrival text. Route text
# starts with the district part ("Ancuabe & Chiure - Metoro: ..."); when that part
# says "Multiple districts" the whole text is searched. Name-based, no coordinates.
# District names (and spelling variants) found in free text, as admin2 pcodes.
# With whole = FALSE only the district part before " - " is read, unless it says
# "Multiple districts"; with whole = TRUE the full text is read.
district_codes_in_text <- function(text, reference = map_reference(), whole = FALSE) {
  if (is.na(text) || !nzchar(text)) return(character())
  r <- reference[reference$level == 'admin2', , drop = FALSE]
  names_tbl <- unique(rbind(
    data.frame(pcode = r$pcode, name = r$name),
    data.frame(pcode = r$pcode, name = r$label),
    data.frame(pcode = c('mz0110', 'mz0104'), name = c('MDP', 'Pemba'))
  ))
  norm <- function(x) {
    x <- iconv(as.character(x), from = 'UTF-8', to = 'ASCII//TRANSLIT')
    paste0(' ', gsub('[^a-z0-9]+', ' ', tolower(x)), ' ')
  }
  keys <- trimws(norm(names_tbl$name))
  ok <- nzchar(keys)
  names_tbl <- names_tbl[ok, , drop = FALSE]; keys <- keys[ok]
  head <- sub(' - .*$', '', text)
  scope <- if (whole || grepl('multiple', head, ignore.case = TRUE)) text else head
  t <- norm(scope)
  unique(names_tbl$pcode[vapply(keys, function(k) grepl(paste0(' ', k, ' '), t, fixed = TRUE), logical(1))])
}
# Link alerts to districts named in their route origin/arrival text. Route text
# starts with the district part ("Ancuabe & Chiure - Metoro: ..."); when that part
# says "Multiple districts" the whole text is searched. Name-based, no coordinates.
alert_district_links <- function(alerts, routes, reference = map_reference()) {
  empty <- data.frame(alert_id = character(), pcode = character(), endpoint = character())
  if (is.null(routes) || !nrow(routes)) return(empty)
  rows <- lapply(seq_len(nrow(routes)), function(i) {
    out <- list()
    for (endpoint in c('arrival', 'origin')) {
      codes <- district_codes_in_text(routes[[endpoint]][i], reference)
      if (length(codes))
        out[[endpoint]] <- data.frame(alert_id = routes$alert_id[i], pcode = codes, endpoint = endpoint)
    }
    do.call(rbind, out)
  })
  x <- do.call(rbind, c(list(empty), rows))
  x <- x[!is.na(x$alert_id) & x$alert_id %in% alerts$alert_id, , drop = FALSE]
  unique(x)
}
# Split one route arrival text into community names, e.g.
# "Ancuabe - Mesa: Nacueja/Nacoja; Minheuene" -> c("Nacueja/Nacoja", "Minheuene").
route_communities <- function(text) {
  if (is.na(text) || !nzchar(trimws(text))) return(character())
  rest <- if (grepl(' - ', text, fixed = TRUE)) sub('^.*? - ', '', text, perl = TRUE) else text
  split_places <- function(x, extra = '') {
    parts <- unlist(strsplit(x, paste0(';|,|\\+| and | & ', extra), perl = TRUE))
    parts <- trimws(gsub('\\s+', ' ', parts))
    parts <- sub('^(village of|the) ', '', parts, ignore.case = TRUE)
    parts <- parts[nzchar(parts)]
    # Drop narrative fragments and generic phrases that are not place names.
    bad <- grepl('^(reported|other|others|movement|host communit|tbc$|unresolved|not stated)',
                 parts, ignore.case = TRUE) |
      grepl(' district$', parts, ignore.case = TRUE) | nchar(parts) > 45
    unique(parts[!bad])
  }
  # "Admin post: community list" -> the list after the last colon; if that is only
  # narrative, fall back to the text before the colon ("Meloco town / other ...").
  if (grepl(':', rest, fixed = TRUE)) {
    out <- split_places(sub('^.*:', '', rest))
    if (length(out)) return(out)
    return(split_places(sub(':.*$', '', rest), extra = '| / '))
  }
  split_places(rest)
}
# One row per route community with its district pcode (NA when the route names
# no district). A community in a multi-district route goes to the district its
# own name contains, otherwise to every arrival district of that route.
route_community_table <- function(routes, reference = map_reference()) {
  empty <- data.frame(route_id = character(), alert_id = character(),
                      community = character(), pcode = character())
  if (is.null(routes) || !nrow(routes)) return(empty)
  rows <- lapply(seq_len(nrow(routes)), function(i) {
    comm <- route_communities(routes$arrival[i])
    if (!length(comm)) return(NULL)
    route_codes <- district_codes_in_text(routes$arrival[i], reference)
    do.call(rbind, lapply(comm, function(cm) {
      own <- district_codes_in_text(cm, reference, whole = TRUE)
      codes <- if (length(own) && (!length(route_codes) || any(own %in% route_codes)))
        intersect(own, if (length(route_codes)) route_codes else own)
      else if (length(route_codes)) route_codes else NA_character_
      data.frame(route_id = routes$route_id[i], alert_id = routes$alert_id[i],
                 community = cm, pcode = codes)
    }))
  })
  unique(do.call(rbind, c(list(empty), rows)))
}
coverage_map_payload <- function(assignments,
                                 mode,
                                 province = 'All',
                                 district = 'All',
                                 layers = read_map_layers(),
                                 post = 'All',
                                 alert_links = NULL) {
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
    if (!is.null(alert_links)) {
      a <- alert_links[alert_links$pcode == f$properties$pcode, , drop = FALSE]
      ids <- unique(a$alert_id)
      f$properties$alerts <- lapply(ids, function(id) list(
        alert_id = id,
        endpoint = paste(sort(unique(a$endpoint[a$alert_id == id])), collapse = ' & ')))
    }
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
    '1.11.0',
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
