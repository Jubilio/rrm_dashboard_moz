# Data entry guide

Use [RRM_Dashboard_Input_Example.xlsx](../data/examples/RRM_Dashboard_Input_Example.xlsx) as the starting example. All supplied records, profile narratives and route coordinates are fictional. It contains ten input worksheets plus ReadMe instructions and a Field Guide.

All paths and commands in this guide are relative to the project root unless stated otherwise.

## Load the file

The current application default is **`data/RRM_Dashboard_Input_RNA_populated.xlsx`**. Save updates to that file and restart Shiny. Check `INPUT_WORKBOOK_PATH` in `config.R` if you maintain another filename. Include the file in the shinyapps.io deployment bundle when publishing.

Alternatively, use an explicit absolute path in the **R console** before starting the app:

```r
Sys.setenv(RRM_INPUT_WORKBOOK = 'C:/RRM/data/RRM_Dashboard_Input.xlsx')
shiny::runApp('.')
```

This Windows path is illustrative; replace it with the actual file path. A file outside the app directory must be made available on the deployment server; a local Windows path is not accessible from shinyapps.io. The bundled `data/` path is the simplest initial deployment option.

The workbook is read once at startup. Save and close it, then restart locally or republish to shinyapps.io after changes. There is no automatic cloud synchronization or consolidated workbook upload interface in this change. The existing Reporting workbook tab retains its separate real-workbook upload/refresh workflow through RRM_ACTIVITY_WORKBOOK.

## Worksheets and headers

Keep input worksheet names and row 1 headers exactly as supplied. Dates may be Excel date cells or YYYY-MM-DD text. Identifiers stay text; counts stay numeric. Entirely blank rows are ignored. Add rows below the headers; imported ranges are not limited by the original example table boundaries. Keep headers when a dataset is unavailable. Metadata requires exactly one populated row.

| Worksheet | One row represents | Key |
| --- | --- | --- |
| Coverage | Partner responsibility for an area and effective period | assignment_id |
| Alerts | One alert, retaining separate initial and RNA evidence | alert_id |
| Routes | Disjoint origin–arrival segment within an alert/stage | route_id |
| Route Locations | Coordinate source/review for one route endpoint | route_id + endpoint |
| Assessments | One assessment round | assessment_id |
| Needs | One ranked need per assessment | assessment_id + need / rank |
| Screening | Decision and aggregate profile for a community/population group | screening_id |
| Activities | One intervention/output record with its unit and donor | event_id |
| Transfers | One responsibility handover | transfer_id |
| Metadata | Source mode, date, version and methods | Exactly one row |

ReadMe and Field Guide are not imported. Additional worksheets are ignored. Unknown or missing input columns, malformed dates/counts, duplicate keys, invalid categories and broken alert/assessment links are rejected. Input formulas are not recalculated by the importer; use entered values.

## Information still being collected

The consolidated Excel reader accepts blank dates, sample counts, need ranks, HESPER counts, quantities, descriptive fields and review/status fields. Blanks (including non-breaking spaces copied from documents) remain `NA`. They are never replaced with zero, an estimated date or an invented ranking. Pages display a data-pending notice. Light RNA shows **Not ranked** and **Unavailable** where appropriate.

Keep identifiers and links populated: alert IDs, assessment IDs, activity IDs, assessment/alert references and need names are required. Coverage also needs area, partner and role; routes need origin, arrival and caseload stage. Metadata still needs exactly one row with mode `demo` or `operational`. Entirely unavailable worksheets may contain only their original headers.

Use **Include records without a date** to retain undated records while filtering. Turning it off excludes them. Undated interventions have no response-delay calculation. Coverage assignments with no effective start remain in the source but are excluded from dated active-coverage results. RNA caseloads without severity or evidence date remain in the source and evidence table but do not contribute to verified KPIs. Missing activity status does not mean Completed. Missing quantities do not become zero; totals sum reported quantities, and the data-pending notice indicates incomplete inputs.

Known invalid values still stop loading: negative or non-integer counts, malformed dates, repeated IDs/ranks, unsupported categories, invalid coordinates and broken links. Fix these using the source. For a strict completeness check, run `read_dashboard_workbook(INPUT_WORKBOOK_PATH, allow_incomplete=FALSE)`. CSV ingestion retains strict validation.

Run `Rscript tests/check_incomplete_input.R` to test missing values and integrity checks.

## Mode and source separation

The example has Metadata.mode=`demo`. If RRM_DATA_MODE is not explicitly set, the app uses the workbook's metadata mode. For actual inputs, replace all example records, update source date/version/methods and set Metadata.mode=`operational`. If RRM_DATA_MODE is explicitly set, it must match the workbook. Operational data rejects DEMO labels and Demo coordinate status. Do not mark records reviewed merely to populate summaries.

The consolidated workbook replaces the core CSV inputs as a single source, including alert endpoint coordinates. It never mixes its Route Locations sheet with the CSV coordinate file. Missing or unconfirmed endpoints remain unmapped. RNA severity and evidence dates are needed before caseloads contribute to verified KPIs; optional CSV severity calculation inputs are not applied to the consolidated workbook. Historical severity evidence, reviewed household analysis inputs and the standardised real activity-reporting workbook remain separate sources.

With no default workbook and no explicit RRM_INPUT_WORKBOOK setting, the app retains the existing CSV workflow. An explicitly configured missing or invalid workbook fails clearly; it does not fall back to CSV/demo inputs.

Run `Rscript tests/check_input_workbook.R` to verify the supplied example and all five core pages.

## Recommended filling sequence

1. Read ReadMe and Field Guide in the example workbook. Keep a working copy before editing.
2. Enter Alerts first and assign a stable alert_id to each alert. Related datasets must reuse exactly that identifier.
3. Enter Coverage responsibilities, then Routes and their Route Locations. Use one route per disjoint origin/arrival segment and one coordinate row for each endpoint.
4. Enter Assessments and then Needs. Each Needs row must reference an existing assessment_id. Keep the KII narrative and HESPER numerator/denominator distinct.
5. Enter Screening decisions and aggregate profile narratives. Record the analysis version and review date. Set reviewed to TRUE only after review and when a summary is supplied.
6. Enter Activities with one output quantity/unit per event, and Transfers when a responsibility changes hands. Do not repeat the same reach once per donor or output.
7. Update Metadata, save, close and ask the maintainer to restart or republish. Check the imported selection and exports against the source after loading.

## A connected example

The supplied fictional example links DEMO-001 in Alerts to R01/R02 in Routes, DEMO-RNA-01 in Assessments, Community B in Screening and A01–A04 in Activities. Route Locations identifies each route endpoint; Needs uses the assessment identifier. These identifiers demonstrate relationships rather than a numbering convention for real reporting.

## Entry rules that affect results

| Input | Entry rule |
| --- | --- |
| Unknown value | Leave blank. Enter 0 only for a confirmed zero. |
| Alert/RNA caseload | Keep provisional alert values separate from verified RNA values; supply RNA severity and evidence date with RNA caseloads. |
| Route counts | Record the segment count, not a copy of the whole alert total. Segments within an alert/stage must not overlap. |
| Administrative area | Prefer supplied Pcodes; use the geographic reference names when codes are unavailable. |
| Coordinates | Use WGS84 longitude/latitude, matching endpoint names and a traceable source. Operational map points need Confirmed coordinate status. |
| Reviewed profile | Supply aggregate text only. Review flags do not authorise uploading household identifiers or scores. |
| Household reach | Gross assistance can repeat recipients across interventions. It is not unique reach. |
| Output units | HH assistance, kits and consultations remain distinct; other units are retained in records/exports. |
| Dates | Enter actual dates. Assessment end and coverage end cannot precede their starts; activities cannot precede the linked alert. |
| Input headers | Do not rename, translate, reorder or delete required columns. Ranking note remains an input field even though it is hidden in Light RNA. |

## Preparing real inputs

Replace every fictional row, including the fictional route coordinates. Retain empty header-only sheets for unavailable sources and fill the one Metadata row with operational, the source date, version and methods. Coordinate status must be Confirmed, Pending or Rejected in operational mode. If the maintainer set RRM_DATA_MODE, it must also be operational. The loader rejects DEMO-labelled operational inputs; it does not establish whether the reported values are factually correct.

## Two Excel formats

This consolidated input feeds the five core pages and Dashboard overview. The separate standardised activity workbook feeds Activity reporting > Reporting workbook, including its map, review queue and validated result tables. The formats are not interchangeable; replacing one does not update the other. See [Reporting workbook reference](reference/ACTIVITY_WORKBOOK.md) for its Activity Entry, Extra Outputs, Alerts and Lists tables.

## Alternative CSV workflow

When no consolidated file is selected, use data/operational with the exact headers in data/templates. Update metadata.csv and restart. The equivalent optional route_locations.csv supplies alert coordinates. Do not populate unrelated coverage or assessment tables by duplicating intervention records. See [Data dictionary](reference/DATA_DICTIONARY.md) for field-level details.
