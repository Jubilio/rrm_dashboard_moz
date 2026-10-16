# Operations and maintenance

For the colleague responsible for installing, configuring and publishing the dashboard. Run commands from the project root. Code blocks labelled R belong in the **R console** in Positron/RStudio, not PowerShell.

## Responsibilities

| Role | Responsibility |
| --- | --- |
| Data focal point | Maintain source records, stable identifiers, source versions and update dates |
| Reviewer | Confirm coordinate provenance, profile review and activity validation within their respective processes |
| Dashboard maintainer | Configure inputs, run checks, deploy and investigate technical errors |
| Viewer | Check source/filters and interpret results within the stated counting limits |

Agree actual names and handover responsibilities within the team. The application does not implement accounts, roles or an approval workflow.

## Install and start

1. Obtain the current main branch and open rrm_dashboard.Rproj.
2. Install the application packages once:

```r
source("install_packages.R")
```

3. Configure the intended sources, then start:

```r
shiny::runApp(".", launch.browser = TRUE)
```

R package requirements are shiny, DT and readxl. Optional Shiny tests use testthat. Geographic preparation utilities require Python packages only when rebuilding supplied map assets; running the dashboard does not require those utilities or R geospatial packages.

## Choose the core input

| Setting | Behaviour |
| --- | --- |
| data/RRM_Dashboard_Input.xlsx exists | Read the consolidated file at startup |
| RRM_INPUT_WORKBOOK is explicitly set | Read that path; missing/invalid files fail without CSV fallback |
| No default workbook or explicit path | Read core CSVs from data/demo or data/operational |
| RRM_DATA_MODE explicitly set | Must match workbook metadata; selects the CSV mode when using CSVs |
| No explicit RRM_DATA_MODE | Use workbook Metadata.mode, or demo for the CSV workflow |
| RRM_ACTIVITY_WORKBOOK | Independent standardised real activity workbook; blank uses the supplied allowlisted snapshot |

To try the example without overwriting live data:

```r
Sys.setenv(RRM_INPUT_WORKBOOK = "data/examples/RRM_Dashboard_Input_Example.xlsx")
Sys.unsetenv("RRM_DATA_MODE")
shiny::runApp(".")
```

For a real consolidated file at the default path:

```r
Sys.unsetenv("RRM_INPUT_WORKBOOK")
Sys.setenv(RRM_DATA_MODE = "operational")
shiny::runApp(".")
```

This requires Metadata.mode=operational and real inputs replacing all fictional records. For operational CSVs, ensure the default Excel is absent as well as clearing RRM_INPUT_WORKBOOK. Environment variables set in an R session do not automatically configure a later server process.

## Update routine

1. Keep a dated backup of the last working input and record the source version.
2. Ask the data focal point/reviewer to complete the [data-entry steps](DATA_ENTRY.md).
3. Save and close the consolidated file, then restart the local Shiny process.
4. Check source labels, date/version, selected alerts, route points, profile review states and representative totals/exports against the input.
5. Run the relevant automated checks. Publish the updated app and its intended data bundle.
6. Open the hosted dashboard and repeat the representative checks. A GitHub merge alone does not publish to shinyapps.io.

The consolidated file is read once at startup. The separate configured reporting workbook is checked every 10 seconds and can retain its last good dataset on a reload failure; that behaviour does not apply to consolidated startup errors.

## Publish to shinyapps.io

Use an already registered rsconnect account. The existing repository deployment record identifies the current app; it does not register credentials. Use the project's existing shinyapps.io connection rather than connectCloudUser, which belongs to a different service workflow.

```r
# Install only if needed:
install.packages("rsconnect")
rsconnect::accounts()

# Confirm that the intended consolidated input is in the bundle:
files <- rsconnect::listDeploymentFiles(appDir = ".")
"data/RRM_Dashboard_Input.xlsx" %in% files
```

If that check is FALSE, resolve the bundle selection before publishing a consolidated-data deployment. A local Windows path outside the app folder is not available on shinyapps.io. Keep the live default file excluded from git while deliberately including the intended file in the deployment bundle. Set required mode/source settings in the deployment environment; a workbook at the default path supplies its metadata mode when no explicit override is set.

For the existing deployment, run in the R console:

```r
rsconnect::deployApp(
  appDir = ".",
  appName = "rrm_dashboard",
  account = "athman",
  server = "shinyapps.io"
)
```

Use your registered account/app names for a different deployment. After deployment, inspect the hosted app and its logs when investigating a startup error. Do not commit account tokens, credentials or populated private source workbooks.

## Troubleshooting

| Symptom | Check and action |
| --- | --- |
| appDir is not recognised as a command | Run the complete deployApp call in the R console |
| Missing input worksheet/header | Compare the file against the example; retain exact sheet/header names and header row 1 |
| Workbook mode conflicts with RRM_DATA_MODE | Correct the explicit mode or metadata; do not relabel fictional records as operational |
| Consolidated changes do not appear | Save/close, restart the R process or republish the hosted bundle |
| No records after filtering | Reset the relevant filters and check source/date coverage |
| No validated activity outputs | Inspect source review/link statuses and reconciliation issues in Reporting workbook |
| Alert point is missing | Check route_id, endpoint name, coordinates, source and Confirmed status; review unresolved endpoints |
| Intervention point is missing | Review community/administrative matching, combined locations and ambiguous candidates |
| Map tiles are blank | Try No basemap and inspect local boundaries; check internet access for OSM tiles |
| Table columns appear compressed | Open the tab/section fully, resize once and confirm the latest tables.js/styles.css are deployed |
| Uploaded reporting file disappears later | Session uploads are temporary; configure a persistent source or republish it |

## Verification and change control

Run the applicable checks in [Verification](reference/VALIDATION.md). Automated schema checks do not confirm operational truth or replace source review. Browser review is needed after visual changes or publication.

Before a handover, record the deployed commit, source file location, mode, source version/date, last publication and known unresolved issues. Keep deployment credentials in the team's approved credential store. Retain original source workbooks and preparation provenance for reproducibility.

## Repository housekeeping

Keep application code, templates, fictional examples/fixtures, tests, geographic references, Leaflet license/assets, source-method references and deployment metadata. Do not remove a file merely because it is not shown in the interface. Ignore editor/session files and temporary outputs. Rendered HTML copies of Markdown documentation are not maintained; Markdown is authoritative.
