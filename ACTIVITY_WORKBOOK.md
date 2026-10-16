# Excel-backed activity reporting

The **Activity reporting** page now reads the standardised RRM workbook directly. The interface, filters, definitions and diagnostics are in English; the REACH footer and reference palette are retained.

## Start and refresh

Install the added Excel reader once from the project root:

```r
source("install_packages.R")
```

There are three source routes:

1. **Supplied workbook snapshot**, the default: an allowlisted CSV extract of the attached workbook. It contains 83 activity rows, four extra-output rows and the workbook's own alert/metric dictionaries. All 83 source review statuses are blank and therefore displayed as Pending review; **none is silently validated**. Seventy-seven activity rows have Confirmed links. Missing output/reach values remain missing, not zero.
2. **Configured workbook**, for automatic updates: keep the live workbook outside the public repository and set its absolute path before launching:

```r
Sys.setenv(RRM_ACTIVITY_WORKBOOK = "C:/private/RRM_Activity_Reporting.xlsx")
shiny::runApp(".")
```

The application checks modification time and size every 10 seconds. **Refresh now** forces a reload even when file metadata is unchanged. Core CSV demo/operational configuration is independent of this activity source. The activity panel displays its own last successful refresh time. If a workbook is unavailable or malformed, the page shows the error and retains the last successfully loaded dataset and its timestamp. It does not silently substitute the supplied snapshot for a broken configured source.

3. **Session upload**: use **Load a standardised workbook (.xlsx)**. The uploaded workbook is used only in that Shiny session; it does not overwrite the configured source or repository. **Use configured source** returns to the configured workbook, or to the supplied snapshot if no workbook path is set. Uploads are not a persistent editing interface, and the dashboard does not write review statuses back to Excel.

Close the workbook after saving if Excel/your hosting platform prevents simultaneous reads. A failed read is visible and preserves the last good dataset.

## Excel contract and recalculation

The importer locates these named table ranges in the XLSX archive, then reads their expected sheets with `readxl`:

| Table | Sheet | Role |
| --- | --- | --- |
| RRMInterventions | Activity Entry | One activity/alert/tier/implementer/location/reporting period per stable Record ID |
| RRMExtraOutputs | Extra Outputs | Additional distinct output metrics, linked by Record ID |
| RRMAlerts | Alerts | Exact Alert ID and alert shared date |
| ReferenceLists | Lists | Metric, unit and counting definition |

The actual table ranges are read dynamically; the code does not hard-code 489 activity rows or 301 extra rows. Extend the Excel tables when adding records; rows outside their declared ranges are not imported. Capacity rows with blank Record IDs are ignored.

Cached formula outputs are not trusted or required. Units come from the metric dictionary; extra-output context comes from the unique parent record; shared dates come from the workbook Alerts table; elapsed days and demographic/status totals are recalculated from inputs. No SUMIFS, cached Auto columns, Legacy Source totals or summary cells feed dashboard results. Actual date cells, Excel serial dates, YYYY-MM-DD, YYYY-MM and DD-MM-YYYY are supported. Dates must be valid; a Reporting Month must be its first day.

## Eligibility and review

Published result tables require **Review Status = Validated**, **Alert Link Status = Confirmed**, a unique known alert and reconciled inputs. A blank source review status is displayed as Pending review without changing the workbook. Superseded rows remain excluded and are not counted as awaiting partner review. The **Records and review** tab shows all imported rows by default, including unresolved and excluded records. Disabling **Include pending and excluded records for review** restricts both the records table and its CSV export to eligible rows.

Blocking checks include duplicate Record IDs, unknown/duplicate alert links, missing essential context/dates/quantities, negative or invalid numbers, fractional count outputs, impossible or cross-month periods, starts before alert shared date, false Complete breakdowns, inconsistent reported/demographic/population-status totals, disability counts exceeding sex totals, and unresolved counting basis or funding. Corrections and explicit partner validation are required in the source. Do not change review status just to populate dashboard KPIs.

Mixed funding — unsplit and combined locations are retained with warnings. They are not allocated proportionally or replicated across donors/communities. Unknown alert mappings are not guessed from organisation or geography. The separate historical severity workbook is not used to overwrite this workbook's own Alerts table or invent crosswalks.

## Counting rules

- Primary and additional quantities are grouped by **metric AND unit**, tier and funding. MZN, litres, people, households, kits, vouchers, sessions, consultations and other units are never summed together. Different kit metrics remain separate.
- A known zero is a real zero. No validated records, or no reported quantity, is not shown as zero delivered assistance.
- **Households Reached** and **Households assisted** are separate reach/output measures. They are not added. Gross reported HH reach can include repeat or estimated bases, which remain visible in its counting-basis table.
- Extra Outputs form a separate long output table; they never multiply the activity-level household or people reach. An extra metric equal to the primary metric is excluded. Duplicate extra metrics for a parent are excluded pending correction. Orphan/ambiguous parents are not inherited by position or name.
- People totals use the independently reported total where present, otherwise a complete valid age/sex total. The two are alternatives, not additive. Mismatches block validated results. Scope and counting basis remain in every aggregate group; estimated catchments, participants, direct users and household members are not pooled into one beneficiary KPI. Unique within record is not unique across months, partners, sectors or tiers.
- Complete age/sex figures retain the original 0–59 months, 5–17 years, 18–49 years and 50+ years. PWD and IDP/host/returnee figures are **subsets** of people; they are displayed separately and never added to reach.
- Reporting-month filters use the **Reporting Month**, not the activity start month. Validated periods must be incremental and within that reporting month. Split multi-month/cumulative records in the source using verified allocations; the application does not distribute counts evenly.
- **First validated activity by alert/tier** uses the earliest eligible start across all reported months for alerts in the current selection. Other activity filters select which alerts appear, but do not redefine their earliest activity. Assessment/coordination records can be activities; this table is explicitly not automatically first delivery of assistance.
- Handover, delay and evidence-use fields are retained on the activity record. A transfer adds no additional reach. Blank dates and evidence-use statements are not invented.

## Data minimisation and repository snapshot

The raw uploaded workbook is **not committed**. An explicit input allowlist excludes Reporting Contact, personal contact details, private reference fields, comments and review-note text. Cached formulas and Legacy Source are also excluded. The public source snapshot contains activity-level aggregate reporting data, not household registries. Uploads follow the same allowlist. All table output escapes source text.

To intentionally refresh the public snapshot from a reviewed source workbook:

```bash
Rscript scripts/refresh_activity_snapshot.R /private/RRM_Activity_Reporting.xlsx
```

The script validates structure, exports only the five allowlisted tables and records source modification time plus a file checksum. The workbook remains unchanged. Review the resulting aggregate data before committing. Source review status is preserved; structural checks do not establish the operational truth of submitted quantities.

## Verification

```r
source("tests/check_activity_workbook.R")
```

Set `RRM_TEST_WORKBOOK` to test the live Excel reader against the supplied workbook as well as the repository snapshot. Tests cover parent/extra joins, duplicate IDs and metrics, unknown links, month/date rules, negative/fractional/missing/zero values, monetary decimals, demographics, mixed funding, empty datasets and Shiny refresh/last-good-data behaviour. Full graphical browser interaction review remains separate from the automated tests.
