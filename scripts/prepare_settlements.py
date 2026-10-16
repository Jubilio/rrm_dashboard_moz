"""Prepare a minimal settlement gazetteer from a user-supplied ZIP.
Run from the project root: python scripts/prepare_settlements.py "path/to/shapefile.zip"
Dependencies: pyshp shapely pyproj. Source files are not modified.
"""
import csv
import hashlib
import io
import json
from pathlib import Path
import sys
import unicodedata
import zipfile
import shapefile
from pyproj import CRS
from shapely.geometry import shape
from shapely.strtree import STRtree

out = Path('data/geography')
reference = list(csv.DictReader((out / 'admin_reference.csv').open(encoding='utf-8')))
ref = {r['pcode']: r for r in reference}
archive = Path(sys.argv[1])
z = zipfile.ZipFile(archive)


def key(value):
    return ''.join(c for c in unicodedata.normalize('NFKD', str(value)).casefold() if c.isalnum())


def reader(layer):
    roots = [n[:-4] for n in z.namelist() if n == layer + '.shp' or n.endswith('/' + layer + '.shp')]
    if len(roots) != 1:
        raise ValueError('Expected one ' + layer + ' shapefile')
    root = roots[0]
    if not CRS.from_wkt(z.read(root + '.prj').decode()).equals(CRS.from_epsg(4326), ignore_axis_order=True):
        raise ValueError('Expected WGS84: ' + layer)
    return shapefile.Reader(shp=io.BytesIO(z.read(root + '.shp')), shx=io.BytesIO(z.read(root + '.shx')),
                            dbf=io.BytesIO(z.read(root + '.dbf')), encoding='utf-8')


def boundaries(layer, field, level):
    result = []
    for item in reader(layer).iterShapeRecords():
        code = item.record.as_dict()[field].lower().strip()
        if code in ref and ref[code]['level'] == level:
            g = shape(item.shape.__geo_interface__)
            if not g.is_valid or g.is_empty:
                raise ValueError('Invalid boundary: ' + code)
            result.append((code, g))
    expected = {r['pcode'] for r in reference if r['level'] == level}
    if {c for c, g in result} != expected:
        raise ValueError('Boundary codes do not match reference')
    return result


districts = boundaries('district', 'ADM2_PCODE', 'admin2')
posts = boundaries('admin3', 'ADM3_PCODE', 'admin3')
dtree, ptree = STRtree([g for c, g in districts]), STRtree([g for c, g in posts])
rows, counts = [], {}
for layer in ['localities', 'villages', 'main_town']:
    r = reader(layer)
    stats = dict(source_records=len(r), selected=0, outside_or_ambiguous_district=0, invalid_or_unnamed=0)
    for index, item in enumerate(r.iterShapeRecords(), 1):
        attrs = item.record.as_dict()
        name = str(attrs.get('name', attrs.get('NAME', attrs.get('TOPONIMO', '')))).strip()
        g = shape(item.shape.__geo_interface__)
        if not name or g.geom_type != 'Point' or not g.is_valid or g.is_empty or not (-180 <= g.x <= 180 and -90 <= g.y <= 90):
            stats['invalid_or_unnamed'] += 1
            continue
        hits = dtree.query(g, predicate='intersects')
        if len(hits) != 1:
            stats['outside_or_ambiguous_district'] += 1
            continue
        district = districts[hits[0]][0]
        phits = [posts[i][0] for i in ptree.query(g, predicate='intersects') if ref[posts[i][0]]['parent_pcode'] == district]
        post = phits[0] if len(phits) == 1 else ''
        declared_district = str(attrs.get('DISTRITO', '') or '').strip()
        declared_post = str(attrs.get('POSTO', '') or '').strip()
        declared_dc = {v['pcode'] for v in reference if v['level'] == 'admin2' and key(declared_district) in (key(v['name']), key(v['label']))}
        declared_pc = {v['pcode'] for v in reference if v['level'] == 'admin3' and v['parent_pcode'] == district and key(declared_post) in (key(v['name']), key(v['label']))}
        conflict = bool((declared_dc and district not in declared_dc) or (post and declared_pc and post not in declared_pc))
        row = dict(point_id=layer + ':' + str(index), name=name, source_layer=layer, source_row=index,
                   source_name=str(attrs.get('Source', '') or 'User-supplied ' + layer),
                   source_code=str(attrs.get('osm_id', attrs.get('CODIGO_CEN', '')) or '').lstrip("'"),
                   place_type=str(attrs.get('fclass', '') or ('village' if layer == 'villages' else 'main town')),
                   longitude=round(g.x, 6), latitude=round(g.y, 6), province_pcode=district[:4],
                   district_pcode=district, post_pcode=post, district=ref[district]['label'],
                   admin_post=ref[post]['label'] if post else '', declared_district=declared_district,
                   declared_post=declared_post, admin_conflict=conflict)
        rows.append(row)
        stats['selected'] += 1
    counts[layer] = stats
if not rows:
    raise ValueError('No settlement points in the selected districts')
with (out / 'settlements.csv').open('w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
metadata = dict(source_archive=archive.name, sha256=hashlib.sha256(archive.read_bytes()).hexdigest(), crs='EPSG:4326',
                layers=counts, selected_points=len(rows), administrative_conflicts=sum(r['admin_conflict'] for r in rows),
                note='Original point geometry determines administrative codes. Source population and project/activity attributes are excluded. Geographic name matches do not independently verify intervention delivery.')
(out / 'settlements_metadata.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
print(json.dumps(metadata, indent=2))
