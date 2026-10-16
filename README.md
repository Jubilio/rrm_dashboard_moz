# RRM dashboard — Cabo Delgado (v2)

The dashboard interface is entirely **English**. This update integrates the supplied 2026 severity workbook and Draft 0.1 household matrix. See **SEVERITY_INTEGRATION.md** and **HOUSEHOLD_ANALYSIS.md** for the implemented rules, source issues, private processing workflow and draft release controls.

The Alerts page has separate Historical severity review and Dashboard records tabs. Vulnerability screening has separate Household analysis — draft and Reviewed profile summaries tabs. Historical source records, ordinary dashboard demo records and synthetic household scenarios are explicitly labelled and never pooled.


Independent **R Shiny** dashboard implementing the five pages in `RRM_Dashboard_Page_Mockups.pdf`. It keeps the lightweight Shiny approach of the supplied WASH tracker and its coral, charcoal and white palette. The pages and data model are rebuilt for RRM. The WASH household records, saved sessions, publishing credentials and Windows package library are not carried into this project.

## Open in RStudio

1. Extract the ZIP to a normal writable folder.
2. Open `rrm_dashboard.Rproj`.
3. Run the following once in the R console:

```r
source("install_packages.R")
```

4. Start the dashboard:

```r
shiny::runApp(".", launch.browser = TRUE)
```

R 4.3 or newer is recommended. To run the optional Shiny module tests, install `testthat` first (`install.packages("testthat")`). Required packages: `shiny`, `DT`. Fonts and styling do not require an external web font. Optional maps require `sf` and `leaflet`.

## Pages

| Page | Filters | Main output |
| --- | --- | --- |
| Geographic coverage | Effective date, geography, partner, GLA role | Distinct partners and assigned areas; explicit unknowns; assignment table; optional approved map |
| Alerts | Arrival geography, issued date, Alert ID, trigger, GLA, movement | Separate Alert/RNA evidence; verified alert-wide caseloads; route-specific schematic |
| Light RNA | Assessed geography, assessment start date, Alert ID, method, single round | KII priorities alongside HESPER sample counts, coverage and response-use narrative |
| Vulnerability screening | Community, decision date, Alert ID, population, decision | Reviewed aggregate profile narratives and Tier 2 decisions |
| Activity reporting | Response geography, intervention start date, Alert ID, tier, modality, partner | Completed gross HH reach, kits and consultations separately; intervention table, delays, transfers |

Each page exports its currently filtered display table to CSV. On narrow screens the navigation becomes a horizontal list and panels stack vertically. Browser printing hides filters and navigation.

## Demo versus operational data

**The default is demo mode. Every record is illustrative.** The first alert and its figures reproduce the mock-up: 940 RNA-verified HH / 4,700 people; 180 gross HH assisted, 120 kits and 86 consultations; first response 4 days and Tier 2 response 18 days. Additional fictional records exercise filters. Do not interpret these as operational findings.

To load real data:

1. Copy the **nine core CSV files** from `data/templates/` into `data/operational/` (coverage, alerts, routes, assessments, needs, screening, activities, transfers and metadata) and populate them with approved aggregate data. Keep the exact headers and order; tables without records may retain only their header.
2. Set metadata to `mode=operational` with a source date, version and methods note. Remove all demo content.
3. Change `DATA_MODE` in `config.R` to `"operational"`, or set `RRM_DATA_MODE=operational` in the launch environment.
4. Run `Rscript tests/check_data.R` for the bundled demo regression checks. Start the app in operational mode to validate your real files.
5. Restart the Shiny process whenever source CSVs are updated. The footer records the successful startup load time; it is not a live sync indicator.

Operational mode fails on missing files and never falls back to demo data. Kobo, Excel imports, and automatic refresh are not configured. Map source columns to this explicit CSV contract before use. Missing values are empty fields, never zero placeholders. Dates use `YYYY-MM-DD`; controlled vocabularies are case-sensitive.

## Counting rules

- Alert rows are unique by Alert ID. Joining routes never multiplies caseloads. Arrival filters select alert IDs; caseload KPIs explicitly remain **alert-wide**, even when only one arrival is displayed.
- Verified KPIs sum RNA-stage values only. Missing RNA values remain unavailable; the people KPI states how many selected alerts have verified figures. Provisional counts remain in the evidence table. Related-alert overlap is displayed; totals are **not unique people across alerts**.
- Severity can be calculated from optional reviewed domain and verified-caseload inputs in `severity_inputs.csv`; otherwise source-recorded stage classifications are retained. The verified ≥900 HH override and missing-domain rules follow the supplied 2026 alert framework. Household RRM mappings remain draft and are governed separately. See SEVERITY_INTEGRATION.md.
- Each route row represents a disjoint movement segment within its alert and stage. Route totals cannot exceed the corresponding alert-stage totals. Route coverage can be partial; do not duplicate the alert total on every route. No geographic coordinates were supplied, so movements are explicitly schematic.
- Coverage is a responsibility at an effective date, not proof of assistance. The “Assigned areas” KPI excludes unknown roles; “Unknown areas” remains separate. Effective intervals include both start and end dates.
- RNA selects exactly one round. KII summaries and HESPER numerators/valid denominators remain separate. These purposive samples cannot estimate population prevalence. The source supplies the reviewed ranking; the dashboard does not infer it from mixed evidence.
- Vulnerability inputs contain aggregate text only. Only `reviewed=TRUE` profile summaries appear. Unreviewed profile text is excluded from exports; decision records may still be shown with their review flag. Never add household identifiers, scores, registries or eligibility lists.
- Activity KPIs count `Completed` rows only and match both unit and measure type. `HH` + `Assistance` is gross HH reach; `kits` and `consultations` + `Service output` are separate outputs. Other units remain in the table and export and are not silently converted. Gross reach may include repeat assistance.
- The activity CSV has one row per **reporting event**, with one donor value. Where an event has multiple donors, use an agreed combined donor label or keep detailed donor allocation outside this table. Never repeat its full reach once per donor. Unique event IDs cannot detect semantic duplicates with different IDs; source review must prevent them.
- Response delays use actual start date minus linked alert issued date. The headline is the earliest completed **filtered** intervention, not an average. The breakdown shows the first completed filtered intervention per alert/tier. Restricting dates or modality can change it. No unapproved timeliness thresholds are applied.
- Responsibility transfers follow selected alert IDs and response geography, independently of intervention-date, tier, modality and delivery-partner filters. They do not add reach.

## Optional approved geographic map

Place an approved polygon GeoJSON at `data/operational/approved_areas.geojson`. It must have a declared CRS and an `area` field exactly matching coverage assignments. Install `sf` and `leaflet`. In operational mode the application loads valid polygons, transforms to WGS84 and displays selected responsibilities. Coral means a known matching assignment; grey means unknown or no selected assignment. Hover labels list all selected partner roles. No external basemap is requested. The provider must verify geographic approval, completeness, spelling and boundary version. Without these files/dependencies the explicit map placeholder remains visible. Invalid GeoJSON leaves a warning in the R console and the placeholder in the UI.

## Files

- `app.R`: startup, navigation, page registration and methods dialog.
- `R/pages.R`: page-specific filters, display modules, metrics and exports.
- `R/data.R`: CSV loading, validation and calculation helpers.
- `config.R`: demo/operational configuration.
- `www/styles.css`: responsive coral and charcoal styling.
- `data/demo/`: synthetic aggregate records.
- `data/templates/`: blank CSV contract for operational data.
- `DATA_DICTIONARY.md`: table relationships and fields.
- `tests/check_data.R`: meaningful regression and data-contract checks.
- `tests/check_shiny.R`: Shiny server checks, including empty filters and reviewed-profile visibility.

## Hosting

Deploy the **extracted `rrm_dashboard` folder** through an existing Shiny hosting account, or run it on your organisation's Shiny Server. This package is not published and contains no account credentials. Select the correct mode before deployment. Operational hosting and access controls must follow your organisation's policy; the app does not implement user accounts.

## Added v2 files

`R/severity.R` implements alert classification, stage updates, provisional status and the historical review. `R/household.R` implements native indicators, draft component rules, bounds, profiles and aggregate disclosure. `R/household_ui.R` exposes aggregates and the pending-decision register. `household_rule_config.R` records the household rule status/version and release metadata. `tests/check_rules.R` tests both source-based methods. The two supplied workbooks are preserved unchanged under `data/reference/`.
