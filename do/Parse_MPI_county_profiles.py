"""
Parse MPI county-level state profiles into structured CSVs.

Same logic as Parse_MPI_profiles.py, but for counties. Header format:
    === CountyName, ST ===

Outputs (in Data/MPI/):
    mpi_county_country.csv  (county, state, country, unauth_pop)
    mpi_county_region.csv   (county, state, region, unauth_pop)

Usage:  python Parse_MPI_county_profiles.py <input_text_file>
"""

import re
import sys
import csv
from pathlib import Path

REGIONS = {
    'Mexico and Central America', 'Caribbean', 'South America',
    'Europe/Canada/Oceania', 'Asia', 'Africa'
}

def parse_number(s):
    return int(s.replace(',', '').replace(' ', ''))

def parse_profile(name, block):
    lines = block.split('\n')
    countries, regions = [], []
    section = None
    for ln in lines:
        ln = ln.strip()
        if not ln: continue
        if ln.startswith('Top Countries of Birth'):
            section = 'country'; continue
        if ln.startswith('Regions of Birth'):
            section = 'region'; continue
        if ln.startswith(('Years of U.S. Residence','Age','Gender','Family','Demographics')):
            section = None
        if section is None: continue
        parts = re.split(r'\t+|\s{2,}', ln)
        if len(parts) >= 2:
            cname = parts[0].strip()
            count_str = parts[1].strip()
            if not re.match(r'^[\d,]+$', count_str): continue
            count = parse_number(count_str)
            if section == 'country':
                countries.append((cname, count))
            elif section == 'region' and cname in REGIONS:
                regions.append((cname, count))
    return countries, regions

def split_county_state(header):
    # "Los Angeles County, CA" -> ("Los Angeles County", "CA")
    if ',' in header:
        county, state = header.rsplit(',', 1)
        return county.strip(), state.strip()
    return header.strip(), ''

def main(infile):
    text = Path(infile).read_text(encoding='utf-8')
    blocks = re.split(r'^===\s*([^=]+?)\s*===\s*$', text, flags=re.MULTILINE)
    rows_country, rows_region = [], []
    parsed = []
    for i in range(1, len(blocks), 2):
        header = blocks[i].strip()
        body = blocks[i+1] if i+1 < len(blocks) else ''
        county, state = split_county_state(header)
        countries, regions = parse_profile(header, body)
        for c, n in countries:
            rows_country.append({'county': county, 'state': state, 'country': c, 'unauth_pop': n})
        for r, n in regions:
            rows_region.append({'county': county, 'state': state, 'region': r, 'unauth_pop': n})
        parsed.append((header, len(countries), len(regions)))

    base = Path(infile).parent.parent
    cpath = base / 'mpi_county_country.csv'
    rpath = base / 'mpi_county_region.csv'

    with open(cpath, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['county','state','country','unauth_pop'])
        w.writeheader(); w.writerows(rows_country)
    with open(rpath, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['county','state','region','unauth_pop'])
        w.writeheader(); w.writerows(rows_region)

    print(f"Parsed {len(parsed)} county profile(s):")
    for h, nc, nr in parsed:
        print(f"  {h:<35} {nc} countries, {nr} regions")
    print(f"\nSaved: {cpath}  ({len(rows_country)} rows)")
    print(f"Saved: {rpath}  ({len(rows_region)} rows)")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python Parse_MPI_county_profiles.py <input_text_file>")
        sys.exit(1)
    main(sys.argv[1])
