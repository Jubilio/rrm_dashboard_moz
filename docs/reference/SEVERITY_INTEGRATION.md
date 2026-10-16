# Alert severity integration

[Documentation index](../../README.md) · Commands and source paths are relative to the project root.

Source: `MOZ_RRM_Alert_Severity_2026.xlsx`, retained unchanged in `data/reference/`.

## Live dashboard calculation inputs

The nine original operational CSV tables remain supported. An additional optional `severity_inputs.csv` in the selected data-mode folder enables calculation. Copy its exact template from `data/templates/`.

One row per Alert ID/stage is allowed. Stage is `Alert` or `RNA`; domains are 1–4 or blank; `verified_hh` is numeric or blank; `hh_verified` is explicitly TRUE or FALSE. Evidence date is required. Confidence and geographic caveat remain separate reviewed inputs. Verified counts must reconcile with the corresponding stage caseload in alerts.csv.

- Overall severity is the highest supported humanitarian-conditions / protection-ongoing-threat domain.
- Unknown is never automatically Low. One known domain can classify with partial completeness; both unknown means Unclassified unless the verified override applies.
- ≥900 alert-linked HH activates Critical only when the explicit verification flag is TRUE. 899 does not. Estimates, possible threshold exceedance and free text do not activate the calculator override.
- Alert severity is preserved as its own stage. RNA applies genuine new domain evidence; blank updated domains retain Alert values and show their provenance. A replacement caseload has its own verification flag. A FALSE flag without a replacement withdraws the prior attestation. To retain an existing verified count without replacement, use TRUE with a blank count.
- Source confidence and geographic caveats are displayed; the app does not invent a numeric confidence score. Partial/geographically mismatched evidence needs human confidence review.
- If calculation inputs are absent, the existing source-recorded severity remains displayed and is labelled as such. Original source severities are never overwritten in the supplied Excel files.

## Historical workbook review

The separate historical tab shows 18 registry alerts and 33 stage evidence rows. The original workbook's recorded severity is preserved alongside (a) the domain maximum and (b) a recalculation using its **explicit source assertion** of an override. These historical assertions are not an independent check of registration figures. Estimated/retained caseload narratives remain text; they are not added to the demo caseload KPIs or converted into unique beneficiaries.

RNA evidence rows that merely retain alert values with no completed RNA remain labelled. Latest recorded severity is not automatically an RNA-verified severity. The registry completion flag is preserved. Missing RNA evidence rows do not imply no needs, and are not fabricated from registry scores.

### Source issues surfaced

- `Severity - Alert` rows 13 and 14 repeat `RRM_NRC_MONTEPUEZ_29072026_IDP`, although organisation/date/district/population/source files describe the two 31 July SI Ancuabe alerts. The original IDs remain visible. A unique source-file match suggests the registry ID for each, but the link is marked **proposed / review required**, not an approved correction. The NRC row 12 remains separate. Rows are not deduplicated or silently attached to the NRC alert.
- The last registry row uses `RRR_NRC_NANG_30092026`, while the severity sheets use `RRM_NRC_NANGADE_30092026`. Its Alert row has a proposed source-file link; the RNA row remains unresolved because there is no exact ID/source-file match. The registry marks RNA complete but omits the RNA date and latest severity. These values remain missing; no correction or RNA outcome is invented.
- `Severity - RNA` row 16 has missing confidence. Its override assertion and caseload-verification caveat remain visible.
- The workbook's ≥900 assertions do not substitute for a supplied verified household register. The historical review reproduces source-rule calculations and states that limitation.
- The title mentions April–August, but the actual registry also contains September entries. All supplied rows are retained.

## Provisional status

Status date defaults to today. More than 80 days means Pending closure until formally confirmed. At ≤80 days the status is Ongoing alert if RNA is complete, otherwise Open - RNA pending. The nominal 90-day threshold is **not** automatic formal closure. The core helper supports an explicit formal-closure flag, but no such confirmations were supplied for the historical registry. Status does not establish response completion.
