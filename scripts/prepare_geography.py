"""Convert the supplied ZIP to display GeoJSON. pip install pyshp shapely pyproj
Usage: python scripts/prepare_geography.py /path/to/shapefile.zip
Run from the project root. The original archive remains untouched.
"""
import csv
import hashlib
import io
import json
from pathlib import Path
import sys
import zipfile
import shapefile
from pyproj import CRS
from shapely.geometry import shape, mapping

out = Path('data/geography')
reference = list(csv.DictReader((out / 'admin_reference.csv').open(encoding='utf-8')))
districts = {r['pcode']: r for r in reference if r['level'] == 'admin2'}
provinces = {r['pcode']: r for r in reference if r['level'] == 'admin1'}
posts = {r['pcode']: r for r in reference if r['level'] == 'admin3'}
archive = Path(sys.argv[1])
z = zipfile.ZipFile(archive)


def read_layer(name):
    roots = [n[:-4] for n in z.namelist() if n.endswith('/' + name + '.shp') or n == name + '.shp']
    if len(roots) != 1:
        raise ValueError('Expected one ' + name + ' layer')
    root = roots[0]
    if not CRS.from_wkt(z.read(root + '.prj').decode()).equals(CRS.from_epsg(4326), ignore_axis_order=True):
        raise ValueError('Expected WGS84 coordinates')
    return shapefile.Reader(shp=io.BytesIO(z.read(root + '.shp')),
                            shx=io.BytesIO(z.read(root + '.shx')),
                            dbf=io.BytesIO(z.read(root + '.dbf')), encoding='utf-8')


def feature(geometry, properties):
    return dict(type='Feature', geometry=mapping(geometry), properties=properties)


def save(name, features):
    def rounded(v):
        if isinstance(v, float): return round(v, 6)
        if isinstance(v, (list, tuple)): return [rounded(x) for x in v]
        if isinstance(v, dict): return {k: rounded(x) for k, x in v.items()}
        return v
    text = json.dumps(rounded(dict(type='FeatureCollection', features=features)), ensure_ascii=False, separators=(',', ':'))
    (out / (name + '.geojson')).write_text(text + '\n', encoding='utf-8')


features, originals, seen = [], [], set()
for item in read_layer('district').iterShapeRecords():
    r = item.record.as_dict()
    code = r['ADM2_PCODE'].strip().lower()
    if code not in districts:
        continue
    if code in seen:
        raise ValueError('Duplicate district: ' + code)
    seen.add(code)
    g = shape(item.shape.__geo_interface__)
    if not g.is_valid or g.is_empty or g.geom_type not in ('Polygon', 'MultiPolygon'):
        raise ValueError('Invalid district: ' + code)
    if r['ADM1_PCODE'].strip().lower() != districts[code]['parent_pcode']:
        raise ValueError('District/province mismatch: ' + code)
    originals.append((code, g))
    # Generalisation only for web display (~55 m); retain original source externally.
    simple = g.simplify(0.0005, preserve_topology=True)
    props = dict(pcode=code, province_pcode=districts[code]['parent_pcode'],
                 district=districts[code]['label'], province=provinces[code[:4]]['label'],
                 source_name=r['ADM2_PT'], source_date=str(r['date']), source_valid_on=str(r['validOn']))
    features.append(feature(simple, props))
if seen != set(districts):
    raise ValueError('Missing districts: ' + str(set(districts) - seen))
save('districts', features)

features = []
for item in read_layer('province').iterShapeRecords():
    r = item.record.as_dict()
    code = r['ADM1_PCODE'].strip().lower()
    if code in provinces:
        g = shape(item.shape.__geo_interface__)
        if not g.is_valid:
            raise ValueError('Invalid province: ' + code)
        features.append(feature(g.simplify(0.0005, preserve_topology=True),
                                dict(pcode=code, province=provinces[code]['label'])))
save('provinces', features)

features, post_originals, seen_posts = [], [], set()
for item in read_layer('admin3').iterShapeRecords():
    r = item.record.as_dict()
    code = r['ADM3_PCODE'].strip().lower()
    if code not in posts:
        continue
    if code in seen_posts:
        raise ValueError('Duplicate administrative post: ' + code)
    seen_posts.add(code)
    parent = r['ADM2_PCODE'].strip().lower()
    if parent != posts[code]['parent_pcode'] or r['ADM1_PCODE'].strip().lower() != districts[parent]['parent_pcode']:
        raise ValueError('Administrative-post parent mismatch: ' + code)
    g = shape(item.shape.__geo_interface__)
    if not g.is_valid or g.is_empty or g.geom_type not in ('Polygon', 'MultiPolygon'):
        raise ValueError('Invalid administrative post: ' + code)
    post_originals.append((code, g))
    props = dict(pcode=code, district_pcode=parent, province_pcode=districts[parent]['parent_pcode'],
                 administrative_post=posts[code]['label'], district=districts[parent]['label'],
                 province=provinces[code[:4]]['label'], source_name=r['ADM3_PT'],
                 source_date=str(r['date']), source_valid_on=str(r['validOn']))
    features.append(feature(g.simplify(0.0005, preserve_topology=True), props))
if seen_posts != set(posts):
    raise ValueError('Missing administrative posts: ' + str(set(posts) - seen_posts))
save('administrative_posts', features)

features = []
for index, item in enumerate(read_layer('main_town').iterShapeRecords(), 1):
    g = shape(item.shape.__geo_interface__)
    if g.geom_type != 'Point' or not g.is_valid:
        raise ValueError('Expected valid town point')
    matches = [code for code, polygon in originals if polygon.covers(g)]
    if len(matches) == 1:
        post_matches = [code for code, polygon in post_originals if code[:6] == matches[0] and polygon.covers(g)]
        features.append(feature(g, dict(name=item.record.as_dict()['TOPONIMO'],
                                       district_pcode=matches[0],
                                       post_pcode=post_matches[0] if len(post_matches) == 1 else None,
                                       source_row=index)))
save('towns', features)
metadata = dict(source_archive=archive.name, sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                district_count=len(seen), province_count=len(provinces), administrative_post_count=len(seen_posts), town_count=len(features),
                crs='EPSG:4326', display_simplification_degrees=0.0005,
                source_date='2019-04-02', source_valid_on='2019-06-07',
                note='User-supplied boundaries, not independently re-certified. Admin3 codes match the user reference. Towns are geographic context, not verified response sites.')
(out / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
print(json.dumps(metadata, indent=2))
