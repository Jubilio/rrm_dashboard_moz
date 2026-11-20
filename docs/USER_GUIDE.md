# User guide

For colleagues viewing and checking dashboard results. No R knowledge is required to use the published application. To prepare source data, use the [Data entry guide](DATA_ENTRY.md); installation and hosting are in [Operations](OPERATIONS.md).

## 1. Check the source before using results

Read the source label at the top of the page. **DRAFT LAYOUT - DEMO DATA ONLY** identifies fictional core records. **Activity reporting** uses the separate standardised reporting source and retains the workbook review statuses in every dashboard mode.

If figures are unexpected, confirm the selected subtab, date range, geography and alert before reporting a problem. The consolidated workbook loads at startup; refreshing the browser alone does not import a changed file into an existing R process.

## 2. Navigate and filter

Use the left navigation to choose a page. The dashboard always starts on About the RRM. Additional tabs within Vulnerability screening and Activity reporting provide distinct source views.

Select filters from the top of each view. **All** includes available records for that field. Dates refer to different events on different pages; the label identifies the event being filtered. **Reset filters** restores all-value selections and the source's date bounds, not necessarily the initial demonstration selection.

When a selection has no records, change or reset the filters. An empty result does not prove there were no needs or interventions. Blank or unavailable values are not confirmed zeros.

## 3. About the RRM

The first tab explains the Rapid Response Mechanism, its two tiers and what each tab shows. Use **Next page** and **Previous** in the panel beside the map to read the text; it keeps the map's height. On a small screen the text scrolls inside the panel.

On Alerts, Light RNA and Activity reporting, **How to use this tab** (the ⓘ near the top) opens short guidance. It opens on hover or keyboard focus, and click or tap opens and closes it; Escape closes it.

### Geographic coverage

Use Coverage as of to select the effective assignment date and Partner, GLA role and Area to select responsibilities. The Geography selector changes the province view of the map; it does not filter the assignment table or KPIs by province.

The cards show distinct primary partners, secondary partners, assigned areas and source version. The table lists responsibilities. A known responsibility is not evidence that assistance occurred. Fictional demo areas are never assigned to real district polygons. Select a district on the About the RRM map to open Alerts with that arrival district selected. The other alert filters reset, and a district with no linked records shows an empty result.

## 4. Alerts

Alerts shows core alert data. Filter by arrival geography, alert-issued date, trigger, reporting source, population status or delivery status. **Delivery status** selects alerts with at least one linked activity in the chosen status.

**Alert summary** sits below the filters and counts distinct alert IDs. **Tier 1** and **Tier 2** count alerts with a linked activity in the corresponding tier. An alert can appear in both. **All recorded activities completed** requires at least one linked activity and a Completed status on every linked activity.

**Latest alerts** lists records newest first. Click **View details** to open that alert's detail, including dates, caseloads, linked assessments, needs and assistance. Missing values remain blank. Historical caseload narratives retain their original wording; latest recorded severity is separate from RNA severity. Proposed or unresolved historical ID matches are excluded from the detail. Validated reporting assistance comes from the supplied activity snapshot and requires an exact, confirmed alert link and passed validation; it is separate from core dashboard activity records and is not combined into a reach total. Session uploads in Activity reporting do not update this detail.

The map draws each route as a curved arrow from origin to arrival. Arrow width follows the people reported on the route; a thin dashed arrow means people were not reported. Arrival circles are sized by the people arriving across the shown routes, and the largest are labelled. Small dots mark origins. Select a point or arrow to show the linked alert summaries in the panel next to the map. A shared point can list several alerts. Use **View details** to open a full alert record or **Clear selection** to restore the panel prompt. The navigation buttons sit at the top of the detail and stay in view while you scroll. At the top of the detail, each linked Light RNA round has its own button that opens that exact round, and **View original alert (PDF)** appears when a shareable link is recorded. The severity rating is preliminary at the alert stage; a Light RNA can confirm or update it. The map pop-up shows route counts, stage, targeting and coordinate provenance. Arrows connect endpoints; their curve is not a travelled path. Demo coordinates are fictional. In operational mode, only confirmed coordinates with matching names and provenance are shown.

Arrival filtering narrows the map to matching routes but selects whole alerts for the caseload KPIs. RNA-stage verified values remain alert-wide and are not reduced to the selected arrival. Related alerts may overlap. Expand **Alert records and calculation evidence** for the schematic, coordinate review, source records, CSV export and calculation details.

## 5. Light RNA

Start with the alert search in **Assessment rounds** or apply an assessment filter. Filters list matching rounds newest first. Select a round to read its findings. Choosing an alert opens its latest dated round and leaves earlier and undated rounds in the list. **Clear filters** clears the results and findings.

The period filter matches any day in the reported assessment window. Undated rounds appear when filtering without a period. Sites and administrative posts come from the reported assessment coverage. Review **What we learned** for the separate key informant and HESPER findings. Each available denominator belongs to its own finding. Expand **Coverage, methods and sources** for interpretation. Open the linked alert or the reported response using the alert ID. Links from Alerts open the exact round. After **View alert details**, use **Back to Light RNA round** in the alert detail; after **Open in Activity reporting**, **View Light RNA** returns to the round you came from, also when an alert has several rounds. **View full assessment brief (PDF)** appears under the round when a shareable link is recorded.

## 6. Vulnerability screening

Reviewed profile summaries opens with community, decision-date, alert, population and decision filters. The cards identify the alert, Tier 2 decision and IDP/Host review states. **Partly reviewed** means some selected records still lack a reviewed narrative; **Unavailable** means no records for that group.

The paired panels display reviewed aggregate narratives, analysis versions and review dates. Missing reviewed summaries remain explicit. The decision table deduplicates the same alert/community/decision/reason across population groups; its CSV export retains the filtered decision fields and review flags. Use **Export decision records** beside the table to download it.

Household analysis is a separate tab. Draft synthetic scenarios are available only in demo mode; operational household views accept reviewed non-synthetic aggregates under approved rules. This dashboard is not a household registry or an eligibility list.

## 7. Activity reporting

### Response by community

The response workspace uses the configured standardised reporting workbook or the supplied snapshot. District, administrative post and community come from Activity Entry. Related records use the exact alert ID. A combined location stays on one record, and its reported quantity is shown for the combined locations.

Use **Alert**, **Response district**, **Community** and **Activity period** to narrow the results. The period uses the reported start month. Open **More filters** for partner, tier, sector, modality and delivery status. Select **All activities →** under **Reported activities** to include assessment and supporting records. **List**, **Map** and **Export filtered activities** share the same selection. Unmatched locations remain in List.

Delivery and review statuses are independent. An explicit Delivery Status in Activity Entry takes precedence. If absent, an exact unique core event match can supply the recorded status. Use the arrow at the end of a row to see its provenance. A blank review status remains Pending review. The bar above the results shows validated totals, **How counts work** and when the activity data was last updated; check with the delivering agency before planning follow-up on older data. Headline totals use validated, reconciled records with confirmed links and retain separate metrics and units. When none apply, it reads *No validated totals for this selection. Reported activities are shown below.* Households, vouchers and kits are different units and are never added together; household counts across activities or rounds may include the same households. Expand **Methods and counting definitions** for the unit definitions. Expand **Timing and handovers** for records and, for a selected alert, the earliest validated reported delivery start with documented status.

### Data review (internal)

Data review is not part of the partner-facing dashboard. Start the app with `RRM_SHOW_DATA_REVIEW=true` to show it as a second tab for record review and source workbook management.


Use **Refresh source** or **Manage workbook** to select a session source. The reporting month filter, review queue, geographic matching, and counting definitions are in **Data review**. Use the arrow at the end of a row to see its source row, alert link and geographic match. Duplicate record IDs require review and are excluded from response counts. Geographic matching does not validate delivery or allocate an output to individual communities. See the [workbook reference](reference/ACTIVITY_WORKBOOK.md) for source and validation rules.

## 8. Maps, tables and exports

- Zoom or drag maps and use the layer control to toggle contextual boundaries. Choose No basemap when external tiles are unavailable; local boundaries remain usable.
- Use table pagination and horizontal scrolling for wide records. Column widths adjust when tabs or expandable sections become visible.
- Exports follow the relevant filters. Keep the source version, selection and download date with any analysis you share. Do not add separate CSV exports together without checking overlap, units and scope.

## 9. Report an issue

Send the maintainer the page/subtab, source mode/version, filter selection, time of occurrence and a screenshot or exact error. State the expected result and its source record IDs. Do not include credentials or household personal records. Input corrections belong in the source file; the dashboard does not write them back.
