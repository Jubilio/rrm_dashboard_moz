# Data dictionary

All CSVs use UTF-8, comma delimiters and the exact headers below. Empty cells represent missing values. Dates use YYYY-MM-DD. Counts, ranks and quantities use non-negative whole numbers; ranks start at 1. IDs are stable strings.

## coverage.csv

One row per partner / area / role assignment and effective interval. Primary key: assignment_id. Blank effective_to means open-ended. Preserve source_version.

| Field | Format |
| --- | --- |
| `assignment_id` | Text / controlled value where specified above |
| `area` | Text / controlled value where specified above |
| `partner` | Text / controlled value where specified above |
| `role` | Text / controlled value where specified above |
| `effective_from` | ISO date |
| `effective_to` | ISO date |
| `source_version` | Text / controlled value where specified above |

## alerts.csv

One row per alert. Primary key: alert_id. Alert and RNA caseloads and evidence dates are distinct. RNA fields may be blank pending verification. Related alerts and overlap descriptions are contextual links, not deduplication instructions.

| Field | Format |
| --- | --- |
| `alert_id` | Text / controlled value where specified above |
| `alert_date` | ISO date |
| `trigger` | Text / controlled value where specified above |
| `gla` | Text / controlled value where specified above |
| `movement` | Text / controlled value where specified above |
| `alert_hh` | Whole number |
| `alert_people` | Whole number |
| `alert_severity` | Text / controlled value where specified above |
| `alert_evidence_date` | ISO date |
| `rna_hh` | Whole number |
| `rna_people` | Whole number |
| `rna_severity` | Text / controlled value where specified above |
| `rna_evidence_date` | ISO date |
| `rationale` | Text / controlled value where specified above |
| `related_alert` | Text / controlled value where specified above |
| `overlap_status` | Text / controlled value where specified above |

## routes.csv

One disjoint origin–arrival segment per alert and stage. Primary key: route_id. Foreign key: alert_id → alerts. caseload_stage: Alert or RNA. targeted: Yes, No, Unknown. Counts may be blank if unknown; never replicate an alert total across its routes.

| Field | Format |
| --- | --- |
| `route_id` | Text / controlled value where specified above |
| `alert_id` | Text / controlled value where specified above |
| `origin` | Text / controlled value where specified above |
| `arrival` | Text / controlled value where specified above |
| `people` | Whole number |
| `households` | Whole number |
| `caseload_stage` | Text / controlled value where specified above |
| `targeted` | Text / controlled value where specified above |

## assessments.csv

One assessment round at one assessed location. Primary key: assessment_id. Foreign key: alert_id → alerts. Sample counts represent KIIs, households, observations separately. The date filter uses start_date; the complete range is displayed.

| Field | Format |
| --- | --- |
| `assessment_id` | Text / controlled value where specified above |
| `alert_id` | Text / controlled value where specified above |
| `area` | Text / controlled value where specified above |
| `start_date` | ISO date |
| `end_date` | ISO date |
| `method` | Text / controlled value where specified above |
| `kii_sample` | Whole number |
| `hh_sample` | Whole number |
| `observation_sample` | Whole number |
| `coverage_note` | Text / controlled value where specified above |
| `limitations` | Text / controlled value where specified above |
| `response_use` | Text / controlled value where specified above |
| `source` | Text / controlled value where specified above |

## needs.csv

One need per assessment, with unique positive rank. Foreign key: assessment_id → assessments. Composite keys: assessment_id + need, and assessment_id + rank. hesper_serious ≤ hesper_valid ≤ hh_sample. kii_summary and ranking_note are reviewed source inputs. The table displays all supplied ranked needs; to reproduce a top-three table supply only the reviewed top three.

| Field | Format |
| --- | --- |
| `assessment_id` | Text / controlled value where specified above |
| `need` | Text / controlled value where specified above |
| `rank` | Whole number |
| `kii_summary` | Text / controlled value where specified above |
| `hesper_serious` | Whole number |
| `hesper_valid` | Whole number |
| `ranking_note` | Text / controlled value where specified above |

## screening.csv

One aggregate population-profile summary per alert/community/decision record. Primary key: screening_id. Foreign key: alert_id → alerts. population: IDP, Host, Returnee, Other. decision: Proceed, Not proceeding, Pending. reviewed: TRUE or FALSE. profile_summary is required only for reviewed records. Do not include any household-level record or identifying information.

| Field | Format |
| --- | --- |
| `screening_id` | Text / controlled value where specified above |
| `alert_id` | Text / controlled value where specified above |
| `community` | Text / controlled value where specified above |
| `decision_date` | ISO date |
| `population` | Text / controlled value where specified above |
| `decision` | Text / controlled value where specified above |
| `reason` | Text / controlled value where specified above |
| `reviewed` | Text / controlled value where specified above |
| `profile_summary` | Text / controlled value where specified above |
| `analysis_version` | Text / controlled value where specified above |
| `review_date` | ISO date |

## activities.csv

One reporting event, modality, unit and donor label per row. Primary key: event_id. Foreign key: alert_id → alerts. tier: Tier 1 or Tier 2. delivery_status: Completed, Planned, Ongoing, Cancelled. measure_type: Assistance or Service output. Quantity is a non-negative integer. Unit strings HH, kits and consultations feed the respective KPIs; other strings remain table-only. days_from_alert is derived and must not be added to the source.

| Field | Format |
| --- | --- |
| `event_id` | Text / controlled value where specified above |
| `alert_id` | Text / controlled value where specified above |
| `area` | Text / controlled value where specified above |
| `tier` | Text / controlled value where specified above |
| `modality` | Text / controlled value where specified above |
| `start_date` | ISO date |
| `delivery_partner` | Text / controlled value where specified above |
| `quantity` | Whole number |
| `unit` | Text / controlled value where specified above |
| `measure_type` | Text / controlled value where specified above |
| `delivery_status` | Text / controlled value where specified above |
| `donor` | Text / controlled value where specified above |
| `delay_reason` | Text / controlled value where specified above |

## transfers.csv

One responsibility transfer per row. Primary key: transfer_id. Foreign key: alert_id → alerts. Transfers are contextual and never generate reach.

| Field | Format |
| --- | --- |
| `transfer_id` | Text / controlled value where specified above |
| `alert_id` | Text / controlled value where specified above |
| `area` | Text / controlled value where specified above |
| `component` | Text / controlled value where specified above |
| `from_partner` | Text / controlled value where specified above |
| `to_partner` | Text / controlled value where specified above |
| `transfer_date` | ISO date |
| `note` | Text / controlled value where specified above |

## metadata.csv

Exactly one row. mode: demo or operational, matching config. source_updated is the reviewed source date, source_version identifies the release and methods_note documents the source/method. Load time is generated at startup.

| Field | Format |
| --- | --- |
| `mode` | Text / controlled value where specified above |
| `source_updated` | ISO date |
| `source_version` | Text / controlled value where specified above |
| `methods_note` | Text / controlled value where specified above |

## Relationships

`alerts.alert_id` connects routes, assessments, screening, activities and transfers. `assessments.assessment_id` connects needs. `coverage.area` matches a district Pcode or reference name in `data/geography/admin_reference.csv` for the coverage map. Coverage assignments and movement locations need a reviewed geographic crosswalk before you can equate them. No crosswalk is invented by the dashboard.

## Validation limits

Structural validation does not establish operational truth. Source owners must approve severity, geographic assignments, cohort overlap, aggregate disclosure, ranking and donor/event uniqueness. A passing schema check is not approval of those decisions.

## v2 optional inputs and aggregate outputs

`severity_inputs.csv` is an optional alert/stage input contract (domains 1–4, verified caseload and explicit verification flag, evidence date, source confidence and geographic caveat). It is not a household table. See SEVERITY_INTEGRATION.md.

`household_input.csv` is a private canonical adapter template. Do not copy populated private records into the deployed dashboard. Its ID/occasion/mode metadata, native indicator inputs, analyst attribution metadata and independent profile fields are documented in HOUSEHOLD_ANALYSIS.md and illustrated with synthetic records in `data/household/synthetic_inputs.csv`. Unsupported final-form codes must be mapped explicitly.

`household_aggregates.csv` must have exactly the same columns/order as `data/household/synthetic_aggregates.csv`. All count and prevalence fields are aggregate measures; empty numeric cells can mean suppression or unresolved outcomes, distinguished by suppression flags and known/unknown denominators. `high_combination_distribution` labels exact versus partial combinations. Approval/version, synthetic flag and review flag travel with every row. Only reviewed, non-synthetic, approved-rule rows can appear in the operational aggregate tab.

`data/reference/alert_registry.csv` and `severity_evidence.csv` preserve historical source text, stage rows and proposed/unresolved links. They are a separate review dataset, not inputs to ordinary demo reach or population totals. Original XLSX files remain unchanged beside them.

The geographic reference also links `admin3.parent_pcode` to the district Pcode. `administrative_posts.geojson` has all 64 listed post polygons. Post filters change map extent, not district assignment KPIs.

`data/geography/settlements.csv` stores reference point IDs/names, source provenance, WGS84 coordinates and spatial administrative codes. Activity geography matching joins the full community name plus district and, when resolvable, administrative post. Match output preserves source record IDs and review statuses; it does not change source tables or allocate beneficiary/output quantities. See INTERVENTION_LOCATIONS.md.
