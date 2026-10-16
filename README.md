# RRM dashboard — Cabo Delgado

An R Shiny dashboard for geographic responsibilities, alerts and displacement routes, rapid needs assessments, reviewed vulnerability profiles and intervention reporting in Mozambique. The interface and documentation are in English. The dashboard opens on **Geographic coverage**.

## Choose your task

| Task | Guide |
| --- | --- |
| Navigate pages, filters, maps and exports | [User guide](docs/USER_GUIDE.md) |
| Prepare and update the consolidated Excel input | [Data entry guide](docs/DATA_ENTRY.md) |
| Install, configure, publish and maintain the application | [Operations guide](docs/OPERATIONS.md) |
| Look up source fields and relationships | [Data dictionary](docs/reference/DATA_DICTIONARY.md) |
| Review technical checks and their limits | [Verification guide](docs/reference/VALIDATION.md) |

## Start locally

Install R and open `rrm_dashboard.Rproj` in RStudio or Positron. Run these commands in the **R console**, from the project root:

```r
source("install_packages.R")
shiny::runApp(".", launch.browser = TRUE)
```

The application requires `shiny`, `DT` and `readxl`. Existing checks were exercised with R 4.3.3; use a supported R installation compatible with those packages. Optional automated Shiny tests also require `testthat`. Leaflet and geographic boundaries are bundled; OpenStreetMap tiles require internet.

## Load your inputs

1. Download or copy [the example workbook](data/examples/RRM_Dashboard_Input_Example.xlsx).
2. Save it as `data/RRM_Dashboard_Input.xlsx` inside the application folder.
3. Follow its ReadMe and Field Guide, keeping input worksheet names and headers unchanged.
4. Save, close and restart the application. Republish when updating a hosted deployment.

**The example contains fictional records and coordinates.** Replace them and set `Metadata.mode` to `operational` before using the workbook for operational reporting. Without an explicitly set `RRM_DATA_MODE`, the consolidated workbook's mode controls the interface. A conflicting explicit mode or invalid selected workbook is rejected.

With no default workbook or explicit `RRM_INPUT_WORKBOOK`, the application uses its CSV workflow; demo is the default core mode. The live consolidated file is excluded from version control. Include it explicitly in the intended deployment bundle.

## Understand the sources

| Source | Feeds | Update method |
| --- | --- | --- |
| Consolidated Excel, or core CSVs | Five core pages and Activity reporting > Dashboard overview | Restart locally; republish the hosted app |
| Standardised activity workbook, or supplied aggregate snapshot | Activity reporting > Reporting workbook | Configured file checks every 10 seconds, Refresh now, or session upload |
| Supplied historical severity evidence | Alerts > Historical severity review | Maintainer-controlled source update |
| Reviewed household aggregates | Vulnerability screening > Reviewed household aggregates | Separate approved aggregate workflow |

The consolidated and standardised activity workbooks are different formats. They do not synchronise automatically. Demo mode opens Activity reporting on Dashboard overview; operational mode opens its Reporting workbook view. Source labels distinguish fictional core records from the real reporting source. CSV exports are deliberate projections of the selected records and may retain audit fields beyond the visible columns.

## Repository layout

| Location | Purpose |
| --- | --- |
| `app.R`, `config.R` | Startup, navigation and source configuration |
| `R/` | Readers, validation, calculations and Shiny modules |
| `data/examples/` | Fictional consolidated example |
| `data/templates/`, `data/operational/` | CSV contracts and operational CSV inputs |
| `data/demo/`, `data/household/` | Fictional fixtures and synthetic household scenarios |
| `data/reference/`, `data/activity_snapshot/` | Supplied reference evidence and allowlisted reporting snapshot |
| `data/geography/` | Administrative boundaries, reference codes and settlement gazetteer |
| `www/` | Styles, table/map behaviour, footer logo and local Leaflet assets/license |
| `scripts/`, `tests/` | Preparation utilities and verification checks |
| `docs/` | User, data-entry and maintenance documentation |
| `rsconnect/` | Existing deployment metadata; account registration is separate |

## Technical references

- [Standardised activity workbook](docs/reference/ACTIVITY_WORKBOOK.md)
- [Alert origin/arrival coordinates](docs/reference/ALERT_LOCATIONS.md)
- [Geographic boundaries and Pcodes](docs/reference/GEOGRAPHY.md)
- [Intervention-to-settlement matching](docs/reference/INTERVENTION_LOCATIONS.md)
- [Severity framework](docs/reference/SEVERITY_INTEGRATION.md)
- [Household analysis and release controls](docs/reference/HOUSEHOLD_ANALYSIS.md)

Coverage is a responsibility, not proof of delivery. Gross reach is not unique reach. Severity source evidence, coordinate confirmation and activity review are different review processes. Read the relevant guide before interpreting or publishing results.
