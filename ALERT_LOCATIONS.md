# Alert origin and arrival map

The Alerts dashboard maps the origin and arrival of each selected route. Charcoal markers indicate origins and coral markers indicate arrivals. Click a point or dashed connection to inspect the route ID, alert, route-specific people/household counts, caseload stage and arrival targeting. A connection is a straight origin–arrival link, not a travelled path. Shared origins display the individual linked route counts, never their sum as a unique population.

The map follows Alert ID, issued date, trigger, GLA, movement and arrival filters. Arrival selection narrows displayed routes, while KPI caseloads remain alert-wide. Source classifications and evidence dates remain separate from geographic confirmation.

## Coordinate input

Populate `data/operational/route_locations.csv` using `data/templates/route_locations.csv`. The file is optional: absent coordinates leave the map on its contextual boundaries and keep endpoints in the expandable coordinate review table. Existing route CSV headers are unchanged.

| Field | Required value |
| --- | --- |
| route_id | Exact ID from `data/operational/routes.csv` |
| endpoint | `origin` or `arrival`; one row per route and endpoint |
| location_name | Name matching that route's origin or arrival; case, accents and punctuation normalised |
| longitude | Decimal longitude in WGS84, from -180 to 180 |
| latitude | Decimal latitude in WGS84, from -90 to 90 |
| coordinate_source | Provenance of the coordinate or approved gazetteer linkage |
| coordinate_status | `Confirmed`, `Pending` or `Rejected` |

Only Confirmed endpoints with matching names, valid coordinates and provenance are drawn in operational mode. Confirmation refers to coordinate review, not independent verification of movement or assistance. Supply reviewed coordinates from the locality/village gazetteer or another approved source; names alone are not geocoded automatically. Both endpoints must be mapped before a connecting line is drawn. Missing, unconfirmed or mismatched endpoints remain in coordinate review. Duplicate endpoint rows, malformed coordinates and demo status in operational files fail explicitly and display a coordinate-source error. Update the file and restart the app to load it.

The bundled operational coordinate file contains headers only. No real alert movement coordinates were supplied. `data/demo/route_locations.csv` contains entirely synthetic coordinates for the fictional demo route names. These fixtures never serve as a fallback for operational data and are labelled DEMO in the map, tooltips and popups. Geographic boundaries are contextual; no demo assignment is applied to a real district.

## Checks

Run `Rscript tests/check_alert_map.R` for shared origins, route-specific counts, coordinate confirmation, name/provenance mismatch, missing and invalid coordinates, mode isolation and arrival-filter behaviour. The schematic remains available in the expandable evidence section.
