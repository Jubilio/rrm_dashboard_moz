# Partner-facing copy: the About the RRM text and the "How to use this tab" help.
# Edit the wording here; layout and behaviour live in www/styles.css and www/tables.js.

# Small (i) button. The help opens on hover or keyboard focus, and click/tap toggles it.
help_tip <- function(id, items, title = 'How to use this tab') {
  panel_id <- paste0(id, '-help')
  div(class = 'rrm-help',
    tags$button(type = 'button', class = 'rrm-help-button', `data-toggle-target` = panel_id,
      `aria-controls` = panel_id, `aria-expanded` = 'false',
      span(class = 'rrm-help-icon', `aria-hidden` = 'true', 'i'), span(title)),
    div(id = panel_id, class = 'rrm-help-panel', role = 'note', hidden = NA,
      p(class = 'rrm-help-title', title),
      tags$ul(lapply(items, function(x) tags$li(strong(x[[1]]), ' ', x[[2]])))))
}

alerts_help_items <- list(
  c('Narrow your search.', 'Filter by location, date or alert characteristics. Select Reset filters to see all alerts.'),
  c('Check the totals.', 'See how many alerts match your filters, how many are recorded under each tier and how many have all recorded activities marked complete. An alert can count under both tiers.'),
  c('Understand the severity rating.', 'The RRM assigns a preliminary rating based on the information available at the alert stage. When a Light Rapid Needs Assessment (RNA) is conducted, its findings help confirm or update the rating. Select a point or route on the map to see the evidence behind the rating. A dashed route indicates that the number of people who moved was not reported.'),
  c('Open the alert and assessment.', 'In Latest alerts, select View details to read the alert summary and open the original alert PDF or the linked Light RNA, where available.'))

rna_help_items <- list(
  c('Find an assessment.', 'Filter by responsible agency, assessment period or location, or search by alert name or ID. Select a round to see its findings.'),
  c('Read the priorities.', 'The two panels show how many key informants or interviewed households ranked each issue among their top three. HESPER stands for Humanitarian Emergency Settings Perceived Needs Scale and captures what affected people identify as their most serious problems.'),
  c('Check the method.', 'Legacy RNA means the assessment used an earlier Rapid Needs Assessment method. Household HESPER results may be unavailable for these rounds. Open Coverage, methods and sources to see who was consulted and what the findings cover.'),
  c('Follow the response.', 'Select View alert details for the original alert or Open in Activity reporting to see the activities reported for it.'))

activity_help_items <- list(
  c('Find a response.', 'Filter by alert, location or activity period. Use More filters to narrow by partner, tier, sector, modality or delivery status.'),
  c('See what was reported.', 'Use List to compare activities and outputs by community or Map to see where they were reported. Select All activities for a wider view or expand Timing and handovers for follow-up information.'),
  c('Check both statuses.', 'Delivery status shows what the partner reported about delivery. Review status shows whether the record has been checked. Pending review means the figures are provisional. Validated and reconciled means the record has passed the data review.'),
  c('Check the context.', 'Use View alert details or View Light RNA to see what informed the response. Select Export filtered activities to download the records matching your filters.'))

counting_units_text <- paste(
  'Households, vouchers and kits are different units and are never added together.',
  'Household counts across activities or rounds may include the same households.')
counting_definition_text <- paste('Reported output is the figure the partner reported, in the unit they used.',
  counting_units_text)

# About the RRM: the text is split into pages so the panel keeps the map's height.
about_rrm_pages <- function() list(
  tagList(
    h3('About the Rapid Response Mechanism'),
    p('The Mozambique Rapid Response Mechanism (MOZ-RRM) brings together coordination, preparedness, anticipatory action and rapid, multi-sector assistance for people affected by conflict, natural hazards and disease outbreaks in northern Mozambique. A crisis modifier allows the mechanism to respond to major emergencies elsewhere in the country.'),
    p('The response can provide up to three months of support through two tiers.'),
    tags$dl(class = 'rrm-tiers',
      div(tags$dt('Tier 1'), tags$dd('Provides immediate, life-saving assistance to newly affected people, guided by verified alerts and a Light Rapid Needs Assessment.')),
      div(tags$dt('Tier 2'), tags$dd('Uses a more in-depth assessment to prioritise follow-up support based on needs and vulnerabilities among newly affected households, previously affected households and host communities.')))),
  tagList(
    h3('Working across both tiers'),
    p('Across both tiers, partners work with authorities and other first-line responders to deliver safe, accessible assistance, coordinate referrals and avoid duplication. This dashboard brings together alerts, severity scores, assessment findings and reported activities to support those decisions in Cabo Delgado.'),
    h3('How to use the dashboard'),
    p('Start with the map. Hover over a district to see its assigned Geographical Lead Agency (GLA), or click the district to open its alerts. Click a partner icon to highlight its primary and secondary districts. To see what assistance was reported in a district, open Activity reporting.')),
  tagList(
    h3('What each tab shows'),
    tags$table(class = 'rrm-about-table',
      tags$thead(tags$tr(tags$th(scope = 'col', 'Tab'), tags$th(scope = 'col', 'What you can find'))),
      tags$tbody(
        tags$tr(tags$th(scope = 'row', 'Alerts'), tags$td('Where and when a shock was reported, which communities were affected and what informed the severity rating.')),
        tags$tr(tags$th(scope = 'row', 'Light RNA'), tags$td('Where and when Light Rapid Needs Assessments took place and what they found about immediate needs.')),
        tags$tr(tags$th(scope = 'row', 'Vulnerability screening'), tags$td('Tier 2 prioritisation decisions by alert and community, with filters for displaced and host populations.')),
        tags$tr(tags$th(scope = 'row', 'Activity reporting'), tags$td('What partners reported delivering, where and when. Use Response by community to switch between the list and map views.')))),
    p('To follow a specific event, find it in Alerts and use its Alert ID wherever an alert filter is available. Use the district, community or period filters to explore a wider area or timeframe. Select Clear filters or Reset filters to return to the full view.')))

about_rrm_panel <- function(id) {
  pages <- about_rrm_pages()
  n <- length(pages)
  div(class = 'panel coverage-intro-text rrm-pager', id = id, `data-page` = '1',
    div(class = 'rrm-pager-body', `aria-live` = 'polite',
      lapply(seq_len(n), function(i)
        div(class = 'rrm-pager-page', `data-page-index` = i, hidden = if (i > 1) NA,
          `aria-label` = sprintf('Page %s of %s', i, n), pages[[i]]))),
    div(class = 'rrm-pager-nav',
      tags$button(type = 'button', class = 'rrm-pager-prev', `data-pager-step` = '-1', disabled = NA,
        span(`aria-hidden` = 'true', '←'), ' Previous'),
      span(class = 'rrm-pager-count', sprintf('1 of %s', n)),
      tags$button(type = 'button', class = 'rrm-pager-next', `data-pager-step` = '1',
        'Next page ', span(`aria-hidden` = 'true', '→'))))
}
