# Consolidated dashboard input

Use `data/examples/RRM_Dashboard_Input_Example.xlsx` as the starting example. All supplied records, profile narratives and route coordinates are fictional. It contains ten input worksheets plus ReadMe instructions and a Field Guide.

## Load the file

Copy the example to **`data/RRM_Dashboard_Input.xlsx`** in the application project and restart Shiny. The application reads this path automatically when it exists. Keep this live input out of the public repository; it is excluded by .gitignore. Include it in your private shinyapps.io deployment bundle when publishing.

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

ReadMe and Field Guide are not imported. Additional worksheets are ignored. Unknown or missing input columns, malformed dates/counts, duplicate keys, invalid categories and broken alert/assessment links are rejected using the same checks as the CSV pipeline. Input formulas are not recalculated by the importer; use entered values.

## Mode and source separation

The example has Metadata.mode=`demo`. If RRM_DATA_MODE is not explicitly set, the app uses the workbook's metadata mode. For actual inputs, replace all example records, update source date/version/methods and set Metadata.mode=`operational`. If RRM_DATA_MODE is explicitly set, it must match the workbook. Operational data rejects DEMO labels and Demo coordinate status. Do not mark records reviewed merely to populate summaries.

The consolidated workbook replaces the core CSV inputs as a single source, including alert endpoint coordinates. It never mixes its Route Locations sheet with the CSV coordinate file. Missing or invalid endpoints remain unmapped. RNA severity and evidence dates must be supplied in Alerts when RNA caseloads are supplied; optional CSV severity calculation inputs are not applied to the consolidated workbook. Historical severity evidence, reviewed household analysis inputs and the standardised real activity-reporting workbook remain separate sources.

With no default workbook and no explicit RRM_INPUT_WORKBOOK setting, the app retains the existing CSV workflow. An explicitly configured missing or invalid workbook fails clearly; it does not fall back to CSV/demo inputs.

Run `Rscript tests/check_input_workbook.R` to verify the supplied example and all five core pages.
