# Intervention locations and settlement reference points

[Documentation index](../../README.md) · Commands and source paths are relative to the project root.

The replacement user archive `shapefile(2).zip` adds `localities` (2,550 source records) and `villages` (11,523), alongside 417 existing main-town points. Preparation retains 1,804 named valid points within the 19 listed districts: 393 localities, 1,346 villages and 65 main towns. Unnamed/invalid points and points outside or ambiguously on district boundaries are excluded. No source population, household totals or embedded project/activity attributes are copied.

`data/geography/settlements.csv` is the allowlisted gazetteer. The archive hash and per-layer QA counts are in `settlements_metadata.json`. Administrative codes are calculated by point-in-polygon against the **original** WGS84 district and post geometry, not the generalised web display. Names/coordinates are supplied reference information, not independently verified intervention-site coordinates. The localities layer identifies its source as OSM (31 August 2023); no new verification date is inferred for the village or main-town layers.

Rebuild from the project root:

```sh
python -m pip install pyshp shapely pyproj
python scripts/prepare_settlements.py "/path/to/shapefile(2).zip"
```

## Match rules

The Activity reporting page has an **Intervention map** tab and a **Reported community** filter. It re-computes matches for the configured workbook, supplied snapshot or session upload and obeys the activity filters. A separate map-scope switch selects all reported records or only records already included in validated results. Matching never changes source review status, alert-link validation or eligibility.

- Resolve district names/Pcodes using the supplied reference, and reject an explicitly conflicting province.
- Compare the **whole community name**, normalising case, accents, punctuation and spacing. Suffixes such as Sede, A and B are retained; no transliteration or spelling equivalence beyond the existing accent/case normalisation is invented.
- If the reported administrative post resolves to the reference, restrict candidates to that post. Contradictory post information does not fall back to another point in the district. An unrecognised post label can match only a unique community name within the district and is explicitly noted.
- Exclude points with contradictory recognised source administrative labels versus their spatial codes. Six reference points have such conflicts.
- Collapse duplicate names only when their coordinates coincide at five decimal places (about one metre). Distinct coordinates remain ambiguous even when they share a name or source layer. No source layer is arbitrarily preferred.
- Do not automatically map combined-location records, community lists separated by commas/slashes/ampersands/conjunctions, or an Unconfirmed location scope. No activity reach/quantity is split between the listed places.
- Similar spellings are suggestions in the review table only. They never receive coordinates automatically.
- The workbook Pcode field is not an approved point-code crosswalk: four supplied values contain Tier labels. It is not used as a geographic identifier; populated values are noted in the matching output.

The initial 83 real activity records produce:

| Status | Records |
| --- | ---: |
| Matched | 38 |
| Combined locations – review | 24 |
| Location scope unconfirmed | 4 |
| Ambiguous settlement | 4 |
| Administrative-post mismatch | 6 |
| Not found | 7 |

The 38 matched records refer to **seven distinct points**. These figures describe the supplied snapshot and will change after source updates. The source still has no records included in validated results. A name-based link does not verify the reported delivery or convert a pending record into a validated one.

## Map and review table

Coral points have at least one record included in validated results. Sand points have pending/excluded records only. Popups show distinct activity-record counts, implementing agencies, sectors and point provenance. They show **no beneficiary totals, output quantities or allocated reach**. Multiple activities at one point are combined into one marker without multiplying the records. Extra Outputs do not generate additional geographic records.

The **Settlement reference points** layer is optional and hidden by default. It does not indicate response coverage. Clicking a marker or exporting **geographic matching CSV** lets reviewers inspect source record IDs, original administrative/community labels, candidate names, coordinates, match method and notes. Unresolved rows retain blank coordinates and remain in the table/export. Source files are not edited by the dashboard.

Tests: `tests/check_intervention_locations.R` covers the actual source counts and fixtures for administrative homonyms, exact co-located duplicates, conflicting geography, ambiguous points, spelling suggestions, combined locations, invalid source codes, unchanged review states, no quantity allocation, empty scopes and Shiny filtering. The optional startup WebSocket test also verifies delivery of the seven reported-location markers.
