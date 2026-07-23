"""
Parse MPI state profiles into structured CSVs.

Input:  a single text file with multiple state profiles, each delimited by
        a header line of the form  === StateName ===
Output: two CSVs in the Data folder:
          mpi_state_country.csv  (state, country, unauth_pop)
          mpi_state_region.csv   (state, region, unauth_pop)

Usage:  python Parse_MPI_profiles.py  <input_text_file>
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
    """Convert '2,910,000' to int."""
    return int(s.replace(',', '').replace(' ', ''))

def parse_profile(state, block):
    """Extract country and region tables from one state's profile text."""
    lines = block.split('\n')
    countries = []
    regions   = []
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

        # Each data row: name<tab>count<tab>percent
        parts = re.split(r'\t+|\s{2,}', ln)
        if len(parts) >= 2:
            name  = parts[0].strip()
            count_str = parts[1].strip()
            if not re.match(r'^[\d,]+$', count_str): continue
            count = parse_number(count_str)
            if section == 'country':
                countries.append((name, count))
            elif section == 'region' and name in REGIONS:
                regions.append((name, count))
    return countries, regions

def main(infile):
    text = Path(infile).read_text(encoding='utf-8')
    blocks = re.split(r'^===\s*([^=]+?)\s*===\s*$', text, flags=re.MULTILINE)
    # blocks alternates: ['', state1, body1, state2, body2, ...]
    rows_country, rows_region = [], []
    states_parsed = []
    for i in range(1, len(blocks), 2):
        state = blocks[i].strip()
        body  = blocks[i+1] if i+1 < len(blocks) else ''
        countries, regions = parse_profile(state, body)
        for c, n in countries: rows_country.append({'state':state,'country':c,'unauth_pop':n})
        for r, n in regions:   rows_region.append({'state':state,'region':r,'unauth_pop':n})
        states_parsed.append((state, len(countries), len(regions)))

    base = Path(infile).parent.parent
    cpath = base / 'mpi_state_country.csv'
    rpath = base / 'mpi_state_region.csv'

    with open(cpath, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['state','country','unauth_pop'])
        w.writeheader(); w.writerows(rows_country)
    with open(rpath, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['state','region','unauth_pop'])
        w.writeheader(); w.writerows(rows_region)

    print(f"Parsed {len(states_parsed)} state profile(s):")
    for s, nc, nr in states_parsed:
        print(f"  {s:<25} {nc} countries, {nr} regions")
    print(f"\nSaved: {cpath}  ({len(rows_country)} rows)")
    print(f"Saved: {rpath}  ({len(rows_region)} rows)")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python Parse_MPI_profiles.py <input_text_file>")
        sys.exit(1)
    main(sys.argv[1])
