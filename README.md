# RRM dashboard — Cabo Delgado

The dashboard interface is entirely **English**. This update integrates the supplied 2026 severity workbook and Draft 0.1 household matrix. See **SEVERITY_INTEGRATION.md** and **HOUSEHOLD_ANALYSIS.md** for the implemented rules, source issues, private processing workflow and draft release controls.

The dashboard always opens on Geographic coverage. It starts in demo mode with clearly labelled fictional core records while approved inputs are pending. Activity reporting opens on the reference Dashboard overview in demo mode. Its separate Reporting workbook tab uses the real reporting workbook or its sanitised snapshot and is labelled separately; this workbook view remains the default in operational mode. Historical alert evidence is labelled separately. Production vulnerability views accept reviewed operational aggregates only; synthetic household scenarios and draft scenario controls are available only in explicitly selected demo mode.


Independent **R Shiny** dashboard implementing the five pages in `RRM_Dashboard_Page_Mockups.pdf`. It keeps the lightweight Shiny approach of the supplied WASH tracker and its coral, charcoal and white palette. The pages and data model are rebuilt for RRM. The WASH household records, saved sessions, publishing credentials and Windows package library are not carried into this project.


## Activity reporting from Excel

The Activity reporting page now reads the standardised Excel workbook directly, with automatic file checks every 10 seconds, session uploads, validated/confirmed result gates and a review queue. Run `source("install_packages.R")` to install the added `readxl` dependency. The bundled allowlisted snapshot contains **83 activity records and four extra outputs; none of the source records is marked Validated**, so result totals remain unavailable until partner review is recorded. See [ACTIVITY_WORKBOOK.md](ACTIVITY_WORKBOOK.md) for live configuration, counting rules, data minimisation and source updates.

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

R 4.3 or newer is recommended. To run the optional Shiny module tests, install `testthat` first (`install.packages("testthat")`). Required packages: `shiny`, `DT`, `readxl`. Fonts and styling do not require an external web font. The supplied map uses locally bundled Leaflet 1.9.4, with no R geospatial package required. Only the optional OpenStreetMap basemap requires internet.

## Pages

| Page | Filters | Main output |
| --- | --- | --- |
| Geographic coverage | Effective date, geography, partner, GLA role | Distinct partners and assigned areas; explicit unknowns; assignment table; optional approved map |
| Alerts | Arrival geography, issued date, trigger, GLA, movement; Alert ID in the first KPI card | Separate Alert/RNA evidence; verified alert-wide caseloads; branching route-specific schematic |
| Light RNA | Assessed geography, assessment start date, Alert ID, method, single round | KII priorities alongside HESPER sample counts, coverage and response-use narrative |
| Vulnerability screening | Community, decision date, Alert ID, population, decision | Reviewed aggregate profile narratives and Tier 2 decisions |
| Activity reporting | Reporting month, Alert ID, district, community, implementing agency, tier, sector, modality, funding | Reported-location map, community matching review, Excel-backed validated outputs, reach by scope/basis, demographics, timing, handovers and review queue |

Each page exports its currently filtered display table to CSV. On narrow screens the navigation becomes a horizontal list and panels stack vertically. Browser printing hides filters and navigation.

## Production data

**Demo is the layout-preview default.** Set `RRM_DATA_MODE=operational` before starting R to use approved core inputs. Activity reporting loads the real supplied workbook snapshot (83 activities and four extra outputs), or the live source configured with `RRM_ACTIVITY_WORKBOOK`. Production does not alter source review statuses: the supplied 83 activities are still pending review and remain available in Records and review. Validated result totals remain unavailable until the required source review is recorded.

The eight core operational CSV tables are initially header-only because no separate approved responsibility, core-alert, assessment, screening or transfer datasets have been supplied. Those pages show explicit empty states. Historical severity records remain a separate source, and the geographic boundaries remain available. Real intervention rows are not fabricated into unrelated RNA, coverage or household tables.

To add core data, populate the existing files in `data/operational/` using the exact headers from `data/templates/`, update `metadata.csv` with source date/version/methods and restart the Shiny process. Missing files and malformed operational data fail explicitly and never fall back to demo records. Activity reporting has its own Excel refresh workflow; see ACTIVITY_WORKBOOK.md. Dates use `YYYY-MM-DD`, blank means unknown and controlled values are case-sensitive. Production household analysis admits only reviewed, non-synthetic aggregates generated under approved rules.

The default `RRM_DATA_MODE=demo` reproduces the supplied reference layout. The fixtures in `data/demo/` and synthetic household scenarios remain available for regression testing; they are not the production source. Run `Rscript tests/check_production.R` to verify the explicitly selected production configuration and source separation.

## Counting rules

- Alert rows are unique by Alert ID. Joining routes never multiplies caseloads. Arrival filters select alert IDs; caseload KPIs explicitly remain **alert-wide**, even when only one arrival is displayed.
- Verified KPIs sum RNA-stage values only. Missing RNA values remain unavailable; the people KPI states how many selected alerts have verified figures. Provisional counts remain in the evidence table. Related-alert overlap is displayed; totals are **not unique people across alerts**.
- Severity can be calculated from optional reviewed domain and verified-caseload inputs in `severity_inputs.csv`; otherwise source-recorded stage classifications are retained. The verified ≥900 HH override and missing-domain rules follow the supplied 2026 alert framework. Household RRM mappings remain draft and are governed separately. See SEVERITY_INTEGRATION.md.
- Each route row represents a disjoint movement segment within its alert and stage. Route totals cannot exceed the corresponding alert-stage totals. Route coverage can be partial; do not duplicate the alert total on every route. No geographic coordinates were supplied, so movements are explicitly schematic.
- Coverage is a responsibility at an effective date, not proof of assistance. The “Assigned areas” KPI excludes unknown roles; “Unknown areas” remains separate. Effective intervals include both start and end dates.
- RNA selects exactly one round. KII summaries and HESPER numerators/valid denominators remain separate. These purposive samples cannot estimate population prevalence. The source supplies the reviewed ranking; the dashboard does not infer it from mixed evidence.
- Vulnerability inputs contain aggregate text only. Only `reviewed=TRUE` profile summaries appear. Unreviewed profile text is excluded from exports; decision records may still be shown with their review flag. Never add household identifiers, scores, registries or eligibility lists.
- The current Excel-backed Activity reporting page follows the Validated/Confirmed/reconciled gates in ACTIVITY_WORKBOOK.md. The original CSV calculation helper (retained for compatibility/tests) counts `Completed` rows only and matches both unit and measure type. `HH` + `Assistance` is gross HH reach; `kits` and `consultations` + `Service output` are separate outputs. Other units remain in the table and export and are not silently converted. Gross reach may include repeat assistance.
- The activity CSV has one row per **reporting event**, with one donor value. Where an event has multiple donors, use an agreed combined donor label or keep detailed donor allocation outside this table. Never repeat its full reach once per donor. Unique event IDs cannot detect semantic duplicates with different IDs; source review must prevent them.
- The current Excel timing table uses the first validated activity per selected alert/tier across all reported months, as documented in ACTIVITY_WORKBOOK.md. The older CSV helper retains its original filtered completed-intervention calculation for compatibility. No unapproved timeliness threshold is applied.
- Responsibility transfers follow selected alert IDs and response geography, independently of intervention-date, tier, modality and delivery-partner filters. They do not add reach.

## Supplied geographic map

The supplied shapefile is converted into local display GeoJSON: 19 listed districts (all 17 Cabo Delgado districts plus Erati and Memba), 64 administrative-post boundaries, two province outlines and 65 locality points. WGS84 coordinates and district codes were checked against the supplied reference list. Source boundary metadata is dated 2019; supplied boundaries have not been independently re-certified. All 64 admin3 codes and parent districts match the supplied reference.

The map works in both data modes. In demo mode it shows geographic context only and does not assign fictional areas to real districts. In operational mode `coverage.area` can contain a supplied district Pcode or an exact reference name (case, punctuation and accents normalised). Ambiguous or unrecognised names are not mapped and their record count is displayed. They remain in the assignment table and KPIs. Coral means a known selected assignment; sand means unknown or no matching assignment. Click a district to read its selected partner roles. Map province/district/administrative-post controls change only the view; the main assignment filters control the table and KPIs.

OpenStreetMap is the default basemap, with visible contributor attribution. Choose **No basemap** for local boundaries without external tiles. Administrative-post boundaries, locality points and province outlines can be toggled; locality points do not establish alert, displacement or response locations. Selecting an administrative post zooms to its boundary; assignment colours continue to describe district responsibilities. Core CSV locations are not automatically equated with these points.

See [GEOGRAPHY.md](GEOGRAPHY.md) for preparation, provenance and limitations. The previous `data/operational/approved_areas.geojson` hook is replaced by these bundled, code-linked layers.

Activity reporting also includes an **Intervention map** linked by community name and administrative context to the supplied settlement points. The initial snapshot matches 38 of 83 records to seven distinct points; unresolved, combined and conflicting locations remain available for review with blank coordinates. The map distinguishes validated records from other reported records and never allocates reach or output totals to points. See [INTERVENTION_LOCATIONS.md](INTERVENTION_LOCATIONS.md).

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

In demo mode, Alerts opens on Dashboard records using the supplied reference layout. Historical severity review remains a separate tab and is the default Alerts view in operational mode. Core demo and historical source labels follow the selected subtab. Detailed alert records, CSV export and calculated severity evidence are available in the expandable evidence section below the main panels.

Alerts also displays an OpenStreetMap view of origin and arrival endpoints, with separate colours and straight route connections. Demo coordinates are fictional and labelled. Operational coordinates require a reviewed route-endpoint input; missing points stay in coordinate review. See [ALERT_LOCATIONS.md](ALERT_LOCATIONS.md) for the coordinate contract and confirmation gate.

Vulnerability screening opens on Reviewed profile summaries, with paired IDP/Host narratives and a full-width decision table. Review labels require non-empty reviewed profile text; pending or partly reviewed groups are identified explicitly. Decisions are deduplicated across population groups for display, while CSV exports retain the original filtered decision fields. Household analysis remains available in its separate tab.

The Activity reporting overview uses the selected core CSV mode and shows a compact seven-column intervention table, unit-specific KPIs, first completed response timing and responsibility transfers. Full CSV exports retain units, measure types, delivery status and donor fields. Transfers follow selected alerts and geography independently of intervention-date, tier, modality and delivery-partner filters.

## Consolidated Excel input

The core dashboard can read one Excel file instead of separate CSVs. Copy `data/examples/RRM_Dashboard_Input_Example.xlsx` to `data/RRM_Dashboard_Input.xlsx`, or configure `RRM_INPUT_WORKBOOK`, then restart the app. The supplied example is entirely fictional. Its Metadata mode controls the interface unless RRM_DATA_MODE is explicitly set; conflicting modes or invalid inputs are rejected. Reporting workbook remains a separate real source. See [INPUT_WORKBOOK.md](INPUT_WORKBOOK.md) for the worksheet contract, deployment and update workflow.
