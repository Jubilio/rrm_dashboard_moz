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

Remaining limitations: a full graphical browser review and download-click testing remain outstanding. No approved boundary file, final revised Kobo export or actual household dataset was supplied. Optional map rendering, actual source-code mapping, sample-design estimates and deployment were not verified. These limitations do not change the explicitly tested calculation results.

Additional repeat commands from the project root:

```r
source("tests/check_rules.R")
source("tests/check_integration.R")
```
