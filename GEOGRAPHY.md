# Supplied geography

`shapefile.zip` was provided by the user. Its three layers contain 11 province polygons, 159 district polygons and 417 locality points for Mozambique. The display subset contains all 17 Cabo Delgado districts plus Erati and Memba in Nampula, two province outlines and 65 locality points falling unambiguously inside those 19 districts. Points are context only; no population attributes are used.

`data/geography/admin_reference.csv` preserves the supplied names/labels and lowercase Pcodes, including the gap before Quissanga (`mz0118`). It has 2 provinces, 19 districts and 64 administrative posts. Administrative-post records are a reference hierarchy only; no admin3 geometry was supplied. The shapefile uses uppercase codes; case normalisation gives an exact match for all 19 districts.

Source district metadata has `date = 2019-04-02` and `validOn = 2019-06-07`. These dates describe the supplied layer, not a new approval or completeness assessment. Geometry is WGS84, EPSG:4326. The display polygons are generalised at 0.0005 degrees with topology preserved within each polygon; this is for web display, not measurement, surveying or a new authoritative boundary product. The original attachment remains untouched. The archive SHA256 and preparation parameters are recorded in `data/geography/metadata.json`.

Rebuild from the original attachment from the project root:

```sh
python -m pip install pyshp shapely pyproj
python scripts/prepare_geography.py /path/to/shapefile.zip
```

`R/geography.R` joins only district reference codes or names, normalising case, punctuation and accents. It never geocodes free text, fuzzy-matches places, assigns demo areas to real districts or assigns an alert/response to a town. Core coverage CSV schema remains unchanged. Codes in `coverage.area` are preferred. Unknown and unmatched responsibility records remain visible in the core table and KPIs, and unmatched counts are shown below the map. Selecting a partner or role can remove a district's matching assignment; the legend therefore says “Unknown / no matching assignment,” not “No response.” Assignment dates are enforced by the existing core filter.

The locally bundled Leaflet 1.9.4 JavaScript/CSS is BSD-2-Clause licensed (see `www/vendor/leaflet/LICENSE`). Map dependencies do not require sf or the R leaflet package. Tiles use the standard OpenStreetMap URL, browser caching and visible contributor attribution. Only tiles need internet; local boundaries are available with **No basemap**. No prefetching or offline tile download is implemented. The app does not place private household data on the map.
