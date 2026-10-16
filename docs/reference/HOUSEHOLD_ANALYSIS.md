# Household analysis integration — English dashboard

[Documentation index](../../README.md) · Commands and source paths are relative to the project root.

Source: `MOZ_RRM_Household_Analysis_Matrix_Draft.xlsx`, Draft 0.1, 2 October 2026. The original workbook is retained in `data/reference/`. No operational household dataset was supplied.

## Draft status and workflow

The matrix explicitly requires agreement on the RRM mappings. The software implements those draft mappings as a testable scenario, without treating them as an approved targeting method. Native FCS, HHS and JMP-aligned descriptive outputs are distinct from RRM levels. No automatic eligibility, demographic vulnerability weights, IPC, CARI, FES or clinical classification is generated.

1. Adapt the final cleaned survey export to `data/templates/household_input.csv`. Preserve raw answers in your private source. The template uses canonical analytical field names, not a claim that these are the final Kobo XML names.
2. Keep the private input outside the deployable project. One baseline record is required per household × alert × assessment occasion. Submission IDs must be unique. Resolve repeat records explicitly; there is no silent earliest/latest or name/phone deduplication.
3. From the project root run:

```bash
Rscript scripts/run_household_analysis.R /private/household_input.csv /private/rrm_output
```

The default exports native indicators, with RRM levels and counts withheld. To run a deliberately provisional scenario:

```bash
Rscript scripts/run_household_analysis.R /private/household_input.csv /private/rrm_output --draft-scenario
```

4. Once the actual methodology is agreed, record its version, approval reference, reviewer and date in `household_rule_config.R`. Set the documented cutoffs and status there. If the agreed mappings differ from this draft, update and re-test the corresponding mapping functions; changing the status alone does not implement a different methodology.
5. Review private results, QA flags, stratification and disclosure. The aggregate candidate defaults to `reviewed=FALSE`. Only after review should approved, non-synthetic aggregate rows be marked reviewed and placed in `data/operational/household_aggregates.csv`. The dashboard enforces its fixed aggregate schema and accepts only `reviewed=TRUE`, `synthetic=FALSE`, `rule_status=approved` operational rows.

Private outputs must be outside the app folder and are not part of this package. Do not deploy private input or record-level outputs. Synthetic inputs and summaries in this package are fictional software fixtures and are clearly labelled in the UI.

## Implemented rules

- FCS: eight valid integer frequencies 0–7; weights 2,3,1,1,4,4,0.5,0.5; maximum 112. Standard cutoffs ≤21 and ≤35; the documented alternative is 28/42. Missing or invalid frequencies do not become zero.
- HHS: no occurrence=0; yes with rarely/sometimes=1, often=2; yes with absent frequency remains missing. Native score requires all three items. Bounds sum known items and add two per missing item to the upper bound. A bounded category is labelled separately. HHS ≥5 is a review flag, not a famine label.
- Food: maximum mapped FCS/HHS component. Missing components preserve an observed floor and uncertainty. Positive HHS lower-bound evidence can establish high or very-high need in an explicit draft/approved scenario; it never replaces the missing native HHS score.
- Shelter: condition/outdoor trigger, issues and three separately attributed functions. Outdoor shelter=4 even when condition is skipped; other missing core components remain recorded. Issues use semicolon-separated codes. Unknown/none/refusal must be exclusive. Unresolved Other leaves the component partial; rain leaks establish level 3, not level 4.
- WASH: source/access, shortage days, sanitation, handwashing and hygiene water form one sector. Collection time 30 minutes remains at least basic; 31 is limited for an improved source. Shared improved sanitation is limited. Unknown sharing does not imply basic. Composting/ambiguous Other/destination codes stay unclassified pending a reviewed recode. Handwashing retains observed/reported provenance; not_verified is missing. No safely-managed or litres/person/day claim is made.
- Shortage days: default bands 0→1, 1–2→2, 3–5→3, 6–7→4. Sensitivity scenarios can set high need at ≥1 or ≥4 days, retaining 6–7 as very high. These are draft proposals, not international severity standards.
- Health: no reported need/all care/resolved past gap→1. Current unmet care plus no/some/unable activity limitation→2/3/4. Current unmet with unknown impact has observed floor 2 but unresolved high-need status. Unknown current status is unclassified.
- Concurrence: Food, Shelter, WASH and Health count once each. High threshold is ≥3, very high is 4. Known positive evidence survives partial components; a negative flag needs complete required evidence. Exact counts require all four relevant flags known. Lower/upper bounds and the at-least-two concurrence flag remain distinct. Highest observed level is not assumed exact unless all sectors are exact or the ceiling 4 is established.
- LCS-EN: use and 12-month exhaustion are separate active reasons. Highest active provisional class is kept outside the four-sector outcome. The ten classes mirror the supplied draft and can be changed in the rule configuration function after agreement.
- Independent profiles: head sex/age, composition, children, pregnancy/breastfeeding, functional difficulty, displacement and repeat displacement, alert linkage, hosting, exact-date durations, education and protection flags. They do not contribute points. No household protection incident detail is displayed. The dashboard's profile comparisons currently expose head sex, hosting, repeat displacement and functional difficulty; the other derived variables remain private analytical outputs.

## Canonical input conventions

`use_mode` accepts `idp_baseline` or `host_baseline` for baseline analysis. Registration-only and other modes receive no baseline indicator/sector score. The mode does not establish displacement status; `population` and displacement answers remain separate. `assessment_occasion` distinguishes legitimate repeated visits.

The three `shelter_*_attribution` fields are **analyst metadata**, not a proposed extra questionnaire module: set yes only where the revised question/training establishes shelter/facility/item-related causes; otherwise leave unknown. The matrix specifically warns against scoring food scarcity or illness as a shelter-function problem.

`functional_difficulty_present` and `repeat_displacement` can carry reviewed pre-derived yes/no profile flags when the detailed raw prerequisites are not available; complete raw domain/episode information takes precedence. They are descriptive, not individual WG disability prevalence.

Existing source codes (including `option_1`, `option_2` and the legacy `dry_pit_latrine_with_slap`) are mapped within their own questions. Do not globally rename codes. New codes proposed in the matrix must be checked against the final deployed form before mapping. Unsupported codes are not guessed; QA flags record the need for review. Raw source fields remain in your private cleaned export.

Dates use exact YYYY-MM-DD. Departure/arrival durations are calculated only when precision is exact. No rule requiring arrival after the latest departure is invented. Composition disagreements retain both totals and suppress child-share/hosting-load calculations.

## Aggregate reporting and disclosure

Outputs remain stratified by alert, community, population and baseline mode. Never pool an IDP census and host sample to infer population prevalence. No weights or confidence intervals are invented without a probability sampling design.

For each profile the aggregate reports assessed N, known and unknown concurrence outcomes, positive count, percentage among known outcomes, assessed-sample lower/upper bounds, exact high-sector count distribution 0–4 and unknown exact-count N. These are descriptive associations, not causal findings or household ranking. Very-high concurrence, its known/unknown denominators and bounds, exact very-high count distribution and observed high-sector combinations are exported separately. Partial combinations are explicitly labelled; none observed does not imply no unknown high sector.

The default minimum cell is 5. Small denominators and small positive/negative/unknown/exact-count cells are suppressed. The implementation conservatively suppresses the whole stratum if any profile could reveal a small complement. Review disclosure requirements for the actual context before release. The UI never loads household scores, IDs, names, phone numbers, GPS, registries or eligibility lists.
