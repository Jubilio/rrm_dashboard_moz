# Verification guide

[Documentation index](../../README.md) · Commands and source paths are relative to the project root.

Run commands from the project root. Checks exercise software behaviour and source contracts; they do not establish the operational truth of submitted values. Use the [Operations guide](../OPERATIONS.md) for publication and handover.

## Prerequisites

Install the application packages with `source("install_packages.R")`. Tests using shiny::testServer also require testthat. The optional HTTP/WebSocket check requires Node.js 22 or newer and Rscript on PATH. A live reporting workbook is optional; its reader can be checked by setting RRM_TEST_WORKBOOK to the private source path.

Run fixture checks in a clean R session without private source overrides. Consolidated-input and production tests assume the repository fixtures rather than a populated local deployment file. Do not remove a live file to run tests; use a separate checkout if the default input path is populated.

## Check selection

| Area changed | Checks | Main coverage |
| --- | --- | --- |
| Core data contracts/calculations | check_data.R | Invalid fields/IDs/dates, route bounds, HESPER denominators, KPI units and planned rows |
| Consolidated Excel reader | check_input_workbook.R | XLSX/CSV equivalence, Excel dates, five pages, route endpoints, source mode and source errors |
| Shiny modules | check_shiny.R | Filters, empty outputs, assessment round isolation and aggregate profile visibility |
| Source mode/review controls | check_production.R, check_layout.R | Operational exclusion of demo scenarios, typed empty widgets, initial page and source labels |
| Alerts | check_alert_layout.R, check_alert_map.R | Route-specific counts, arrival versus alert-wide counts, coordinate provenance/review and partial endpoints |
| Vulnerability profiles | check_vulnerability_layout.R | Review states, non-empty narratives, filters and decision deduplication |
| Activity overview | check_activity_layout.R | Unit-specific metrics, timing, transfers, filters and audit exports |
| Standardised real activity workbook | check_activity_workbook.R | Review/link/reconciliation gate, quantities, funding, demographic checks and source refresh |
| Geography | check_geography.R | Reference codes/hierarchy, district assignment isolation, admin3 boundaries and map payloads |
| Settlement matching | check_intervention_locations.R | Administrative matching, ambiguous/combined names, unchanged review status and filtered points |
| Severity/household methods | check_rules.R, check_integration.R | Boundary cases, stage evidence, missingness, draft/approved rules and aggregate release controls |

The files are in tests/. For example, in the R console:

```r
source("tests/check_input_workbook.R")
source("tests/check_shiny.R")
```

For a broad fixture regression in a clean development checkout:

```r
checks <- list.files("tests", pattern = "^check_.*\\.R$", full.names = TRUE)
for (check in checks) source(check)
```

A failure needs investigation; do not change source review flags to make tests or KPIs pass.

## HTTP and WebSocket startup

In a terminal from the project root:

```sh
node tests/check_startup.mjs
```

The script starts a local Shiny process, checks initial asset routes and map binding, and verifies non-null table payloads, geographic layers, alert endpoints and real intervention markers. It allows a bounded cold-start wait and fails on Shiny output errors. RRM_TEST_R can override the Rscript executable; RRM_TEST_MODE selects demo or operational test mode. RRM_INPUT_WORKBOOK can select the consolidated example when testing it deliberately.

These checks verify transport and payloads. They do not prove that all browser interactions or external OpenStreetMap tile requests work.

## Browser review before publication

1. Open a fresh session and confirm Geographic coverage is selected.
2. Check source labels and versions in every relevant subtab; confirm fictional and real reporting sources remain distinct.
3. Test a representative filter, reset, empty selection and CSV export in each page.
4. Open hidden tabs and expandable sections; verify table width, header alignment and horizontal scrolling.
5. Inspect map visibility, layer controls, endpoint colours/popups and unresolved geographic records.
6. Compare at least one alert, assessment, reviewed profile and intervention against its source fields and counting definition.
7. Repeat at a narrow viewport and inspect the hosted version after deployment.

## Known verification limits

Browser appearance, CSV download clicks, external tile availability, simultaneous source-file editing and hosted file access require review in the target deployment. A passing local test does not imply the latest commit is published. Keep the deployed commit and source version/date in the handover record.

Earlier source integrations were exercised with the supplied 83-record activity snapshot, 19 districts, 64 administrative posts and settlement reference data. These counts describe the bundled fixtures, not completeness of future operational reporting. Preserve the source provenance and matching exclusions documented in the corresponding references.
