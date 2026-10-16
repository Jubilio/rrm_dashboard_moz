# Validation notes

Validated on 15 October 2026 using R 4.3.3, Shiny 1.8.0 and DT 0.31.

- Demo data contract and derived KPI regression checks passed: 180 gross HH assisted, 120 kits, 86 consultations; first response 4 days; Tier 2 first response 18 days for DEMO-001.
- Date filters, empty selections, missing caseloads and exclusion of planned assistance from completed KPI totals passed.
- Rejection tests passed for duplicate event IDs, missing alert links, interventions before alert dates, excessive route counts, invalid HESPER counts, extra household-identifying columns and incorrect metadata mode.
- Five Shiny server modules passed filter, display-table, KPI-rendering and empty-state checks. RNA stays within one round; arrival-filtered alert KPIs remain explicitly alert-wide; unreviewed profile summaries remain hidden and are excluded from exports.
- The complete application started and returned HTTP 200 with the five-page interface. All 20 linked local scripts and stylesheets returned HTTP 200.

## Remaining verification

A full browser visual and interaction review was not completed: the environment could not download a working headless browser. Responsive styling is implemented but desktop/mobile appearance, live websocket interactions and CSV download clicks still need a browser review. Optional approved GeoJSON rendering was not tested because no approved boundaries were supplied. No real RRM dataset or hosting deployment was tested.

## Repeat checks

From the project root:

```r
source("tests/check_data.R")
# Requires testthat in addition to the application packages:
source("tests/check_shiny.R")
```

Before operational use, start with your own aggregate data in operational mode, review each page and export, and verify source approval and geographic matching. Schema validation does not establish the truth of the source records.

# v2 verification — 16 October 2026

The new framework and integration checks passed with R 4.3.3, Shiny 1.8.0 and DT 0.31. The original data and five-page module checks still passed.

- Alert domains, unknown evidence, exactly 899/900 HH, explicit verification, Alert→RNA retention and the 80/81-day provisional-status boundary.
- Import of 18 historical registry rows / 33 stage-evidence rows, matching of source-rule calculations, preservation of three proposed conflicting-ID links and one unresolved RNA link. Missing confidence/latest registry fields are not invented.
- FCS 0/21/21.5/35/112, invalid/missing frequencies, HHS missingness and ≥5 review, outdoor shelter, mixed/exclusive issues, 30/31-minute water access, shortage 0/2/3/5/6/7, sanitation sharing, health resolution and unknown-impact branches.
- Tri-state flags, exact versus bounded counts, no-evidence [0,4], confirmed concurrence with partial data, private native-only defaults, explicit draft scenarios, registration-only exclusion, LCS kept out of sector outcomes, minimum/complementary aggregate disclosure.
- New Shiny module rendering, filtered/future/empty historical states, verified manual calculator and operational aggregate gate.
- End-to-end private processing of 96 synthetic records in native-only and draft-scenario modes. Candidate aggregate outputs exclude household IDs and default to unreviewed.
- Application startup and HTTP 200 for the updated interface and all 20 linked scripts/stylesheets.

Remaining limitations: a full graphical browser review and download-click testing remain outstanding. User-supplied district/province boundaries have since been integrated (see GEOGRAPHY.md). No final revised Kobo export or actual household dataset was supplied. Actual household source-code mapping, sample-design estimates and deployment were not verified. These limitations do not change the explicitly tested calculation results.

Additional repeat commands from the project root:

```r
source("tests/check_rules.R")
source("tests/check_integration.R")
```


# Excel activity reporting verification — 16 October 2026

The live Excel adapter and sanitised snapshot read **83 activities, four extra outputs, 77 confirmed links and zero Validated records** from the supplied workbook. Blank review status remains pending. Source XLSX formulas and reporting contacts are excluded from the snapshot and calculations.

Passed: named-table extraction from the actual workbook; metric/unit lookup; independent demographic and date recalculation; validated/confirmed/reconciled gates; duplicate records, duplicate/repeated/orphan extra metrics; prevention of reach multiplication; unknown/multiple alert links; missing, negative, zero and fractional count quantities; MZN decimals; mismatched totals and PWD subsets; month/date validation; mixed funding kept unsplit; controlled counting bases; superseded records; empty datasets; CSV-source refresh; session Excel upload; malformed-upload retention of the last good dataset; and filtered empty states in the Shiny module. The existing four regression suites continue to pass.

Application startup and all 21 linked assets returned HTTP 200. Full graphical browser review, actual hosting file permissions, simultaneous live Excel editing and download-click interaction remain unverified. No source rows were marked Validated by this change.

Repeat from the project root:

```r
source("tests/check_activity_workbook.R")
```

For the original XLSX reader check also set RRM_TEST_WORKBOOK to the private source workbook path. See ACTIVITY_WORKBOOK.md for configuration and refresh behaviour.


Supplied map validation: `tests/check_geography.R` verifies all 19 district codes, the 85-row reference hierarchy, operational joins (including accent/case variants), unknown assignments, geographic extent filters, demo isolation and Shiny JSON output. Python preparation checked WGS84 and valid input polygons. Full graphical browser review remains outstanding.

HTTP startup and all 21 initial assets returned 200. The Shiny WebSocket check also verifies map JSON types, 19-to-2 district filtering and the four dynamically loaded map assets. Browser rendering and live OSM tile availability remain unverified.

Admin3 update: the replacement archive supplies 411 national administrative-post polygons; all 64 listed posts match the reference and their parent districts. Original and display geometries are checked for validity. Hierarchical map/post filters, parent consistency, locality subsets and district-only assignment colours are checked in the geography tests.

The Shiny WebSocket check also passed with all 64 post polygons and a Province/District/Post selection narrowed to Mesa (`mz010102`), retaining numeric coordinates and valid map asset routes. Graphical browser rendering remains unverified.


Production defaults: `tests/check_production.R` verifies operational startup, deliberately empty core tables, real workbook record counts, absence of synthetic choices in production UI, server-side rejection of synthetic household selection, empty-page behaviour and district map isolation. Activity reporting remains subject to its unchanged source review gate.


Map startup correction: the published application was inspected in Chrome. DT 0.34.0 threw `Cannot read properties of null (reading 'lazyRender')` while rendering a hidden empty widget, preventing the remainder of the startup response from reaching the map. A zero-column household empty state produced `x:null`; it now returns a typed empty table. Empty operational RNA tables no longer require a nonexistent assessment selection, and pending required inputs preserve outputs rather than sending null table values. Map dependencies and the output element are now part of the initial UI, eliminating dependency-registration timing during dynamic output insertion.

`tests/check_production.R` now checks the actual serialized empty widgets and RNA without a fabricated assessment selection. Optional Node.js 22+ `tests/check_startup.mjs` starts R, checks initial HTTP assets and map binding, and verifies non-null household/RNA/coverage/activity widgets plus all 19 districts and 64 posts over the real Shiny WebSocket. Run from the project root with `node tests/check_startup.mjs` and Rscript on PATH. The existing five related suites pass. The hosted fix requires a new deployment; full graphical verification of the updated hosting remains pending.


Settlement integration: `tests/check_intervention_locations.R` verifies the 1,804-point reference subset, six source administrative conflicts, 83 source records and 38 unambiguous name matches at seven distinct points, plus conservative multi-location, spelling and administrative exclusions. It verifies that review status remains unchanged, no quantities/beneficiaries enter map markers, and community/district/scope filters apply. The existing production, workbook, geography, Shiny and severity/household integration tests pass. HTTP/WebSocket startup verifies delivery of the seven reported intervention markers. Updated-host browser review requires publication of this change.
