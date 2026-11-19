# User guide

For colleagues viewing and checking dashboard results. No R knowledge is required to use the published application. To prepare source data, use the [Data entry guide](DATA_ENTRY.md); installation and hosting are in [Operations](OPERATIONS.md).

## 1. Check the source before using results

Read the source label at the top of the page. **DRAFT LAYOUT - DEMO DATA ONLY** identifies fictional core records. The Reporting workbook view identifies its separate reporting source and retains original review statuses. Opening a demo dashboard does not make its real workbook source fictional, or its pending records validated.

If figures are unexpected, confirm the selected subtab, date range, geography and alert before reporting a problem. The consolidated workbook loads at startup; refreshing the browser alone does not import a changed file into an existing R process.

## 2. Navigate and filter

Use the left navigation to choose a page. The dashboard always starts on RNA Intro. Additional tabs within Alerts, Vulnerability screening and Activity reporting provide distinct source views.

Select filters from the top of each view. **All** includes available records for that field. Dates refer to different events on different pages; the label identifies the event being filtered. **Reset filters** restores all-value selections and the source's date bounds, not necessarily the initial demonstration selection.

When a selection has no records, change or reset the filters. An empty result does not prove there were no needs or interventions. Blank or unavailable values are not confirmed zeros.

## 3. Geographic coverage

Use Coverage as of to select the effective assignment date and Partner, GLA role and Area to select responsibilities. The Geography selector changes the province view of the map; it does not filter the assignment table or KPIs by province.

The cards show distinct primary partners, secondary partners, assigned areas and source version. The table lists responsibilities. A known responsibility is not evidence that assistance occurred. Fictional demo areas are never assigned to real district polygons. Select a district on the RNA Intro map to open Alerts → Dashboard records with that arrival district selected. The other alert filters reset, and a district with no linked records shows an empty result.

## 4. Alerts

Dashboard records shows core alert data. Filter by arrival geography, alert-issued date, trigger, reporting source, population status or consortium response status. Historical severity review is a separate source view; it opens by default inside Alerts in operational mode.

**Alert summary** follows the alert filters and counts distinct Alert IDs. Activated/non-activated indicators remain blank until an agreed activation field is supplied; consortium response, RNA completion and alert age are not substitutes. Core gross household reach sums only completed HH assistance quantities linked to the selected alerts. Historical gross validated household reach uses the supplied activity snapshot, confirmed exact links, validated records, the Households assisted metric and a Unique within record household basis. The two sources are not added together. Reach is gross across activity records, not unique families across interventions. No eligible reported values, or missing quantities within the eligible records, leave reach blank; a reported zero remains zero. Activity dates do not restrict this alert-level reach: the alert date filters select the alerts, then linked activity records are used. Session uploads do not replace the historical snapshot.

Both views include **Latest alerts**, newest first. Click **View details** to open that alert's detail, including dates, caseloads, linked assessments, needs and assistance. Missing values remain blank. Historical caseload narratives retain their original wording; latest recorded severity is separate from RNA severity. Proposed or unresolved historical ID matches are excluded from the detail. Validated reporting assistance comes from the supplied activity snapshot and requires an exact, confirmed alert link and passed validation; it is separate from core dashboard activity records and is not combined into a reach total. Session uploads in Activity reporting do not update this detail.

The map uses charcoal origin markers and coral arrival markers. Select a point or dashed connection to show the linked alert summaries in the panel next to the map. A shared point can list several alerts. Use **View details** to open a full alert record or **Clear selection** to restore the panel prompt. The map pop-up shows route counts, stage, targeting and coordinate provenance. Dashed lines connect endpoints; they are not travelled paths. Demo coordinates are fictional. In operational mode, only confirmed coordinates with matching names and provenance are shown.

Arrival filtering narrows the map to matching routes but selects whole alerts for the caseload KPIs. RNA-stage verified values remain alert-wide and are not reduced to the selected arrival. Related alerts may overlap. Expand **Alert records and calculation evidence** for the schematic, coordinate review, source records, CSV export and calculation details.

## 5. Light RNA

Select one assessment round. Review the assessment dates, method and samples before reading priorities. KII summaries and HESPER household counts describe separate evidence streams. The HESPER denominator is the valid sample for that need, not the affected population.

The table displays Rank, Need, KII summary and HESPER households. The source ranking note is retained in the input contract but hidden from this view. Purposive samples must not be interpreted as population prevalence or pooled across rounds. Review the companion panel for coverage, limitations, source and use in response.

## 6. Vulnerability screening

Reviewed profile summaries opens with community, decision-date, alert, population and decision filters. The cards identify the alert, Tier 2 decision and IDP/Host review states. **Partly reviewed** means some selected records still lack a reviewed narrative; **Unavailable** means no records for that group.

The paired panels display reviewed aggregate narratives, analysis versions and review dates. Missing reviewed summaries remain explicit. The decision table deduplicates the same alert/community/decision/reason across population groups; its CSV export retains the filtered decision fields and review flags. Expand **Export decision records** to download it.

Household analysis is a separate tab. Draft synthetic scenarios are available only in demo mode; operational household views accept reviewed non-synthetic aggregates under approved rules. This dashboard is not a household registry or an eligibility list.

## 7. Activity reporting

### Dashboard overview

This view uses the core input mode. Filter response geography, intervention start date, alert, tier, modality and delivery partner. The cards keep gross HH assistance, kits and clinic consultations separate. KPIs use completed interventions only; the table and CSV retain other reported statuses when present.

First response is the earliest completed intervention in the current selection. Changing the intervention filters can change that value. It is different from the Reporting workbook timing definition. Gross HH assistance can include repeat recipients. Do not add household counts to kits or consultations.

**Days from alert** is intervention start minus the linked alert issue date, in calendar days including weekends and holidays. An alert on 1 September and start on 5 September gives 4 days; a same-day start gives 0. The First response card takes the minimum of these delays among completed, filtered interventions, each measured against its own alert; across alerts it does not describe one common timeline. Missing dates leave the delay unavailable. Start date is the reported first day of the intervention; the core activity input does not collect an end date.

The lower panels show timing/delay reasons and responsibility transfers. Transfers follow selected alerts and geography independently of intervention dates, tiers, modalities or delivery partners. A transfer adds no reach. Expand **Export intervention records** for the audit CSV, including units, measure types, status and donor.

Delay reasons appear beside each activity in the overview table and alert detail. In **Reporting workbook → Timing, handovers and evidence → Reported delay reasons**, review the original reason alongside activity dates, partner, review status and alert-link status. This table includes pending/excluded records under the current filters; it does not validate their contents. Blank reasons stay blank. Enter or amend reasons in the source workbook using the [data entry guide](DATA_ENTRY.md#delay-reasons).

### Reporting workbook

This is the separate real reporting source. Its Intervention map, validated outputs, reach/demographics, timing, Records and review and definitions retain their own filters and review rules.

Here **Days from alert** is Activity Start minus the workbook Alert Shared Date, also in calendar days with same-day start equal to 0. Activity Start and Activity End delimit the activity period covered by the record; end date does not establish closure of the whole response and does not enter the delay calculation. Continuing activities must be reported in separate monthly periods, with actual dates rather than “Ongoing”. Missing/invalid required dates, an end before start or a start before the linked alert shared date prevent inclusion in validated results. The timing summary finds the earliest validated start by alert and tier across all months: other filters select alert IDs, then all validated activities for those alerts are considered, including assessment and coordination. It does not necessarily measure first assistance delivery.

Validated results require Review Status=Validated, Alert Link Status=Confirmed, a unique known alert and reconciled inputs. A blank review status remains Pending review. Missing validated results are not a reason to mark source records Validated without review. Use **Records and review** to inspect reported records and issues.

Map matching uses the reported community and administrative context. Unresolved or combined locations stay in review; matching a place does not validate delivery or allocate reach. A session-uploaded workbook affects only that session and does not persist to the server. See the [workbook reference](reference/ACTIVITY_WORKBOOK.md) for detailed counting and refresh rules.

## 8. Maps, tables and exports

- Zoom or drag maps and use the layer control to toggle contextual boundaries. Choose No basemap when external tiles are unavailable; local boundaries remain usable.
- Use table pagination and horizontal scrolling for wide records. Column widths adjust when tabs or expandable sections become visible.
- Exports follow the relevant filters. Keep the source version, selection and download date with any analysis you share. Do not add separate CSV exports together without checking overlap, units and scope.

## 9. Report an issue

Send the maintainer the page/subtab, source mode/version, filter selection, time of occurrence and a screenshot or exact error. State the expected result and its source record IDs. Do not include credentials or household personal records. Input corrections belong in the source file; the dashboard does not write them back.
