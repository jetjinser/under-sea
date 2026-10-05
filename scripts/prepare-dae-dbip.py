#!/usr/bin/env python3
"""Convert DB-IP country CSV ranges into source inputs for v2fly/geoip."""
import argparse
import csv
import gzip
import ipaddress
import json
from pathlib import Path
import re
from contextlib import ExitStack

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=False)
counts = {}
with ExitStack() as stack:
    source = stack.enter_context(gzip.open(args.archive, 'rt', newline=''))
    writers = {}
    for line, row in enumerate(csv.reader(source), 1):
        if len(row) != 3 or not re.fullmatch('[A-Z]{2}', row[2]):
            raise ValueError(f'Invalid DB-IP CSV row {line}')
        first, last = map(ipaddress.ip_address, row[:2])
        if first.version != last.version or int(first) > int(last):
            raise ValueError(f'Invalid DB-IP address range at row {line}')
        country = row[2].lower()
        if country not in writers:
            writers[country] = stack.enter_context(
                (args.output / (country + '.txt')).open('w'))
            counts[country] = {'ranges': 0, 'cidrs': 0}
        represented = 0
        for network in ipaddress.summarize_address_range(first, last):
            writers[country].write(str(network) + '\n')
            represented += network.num_addresses
            counts[country]['cidrs'] += 1
        if represented != int(last) - int(first) + 1:
            raise ValueError(f'CIDR conversion lost addresses at row {line}')
        counts[country]['ranges'] += 1
if not counts:
    raise ValueError('Empty DB-IP source')
# Keep metadata outside the plaintext input directory: geoip treats every
# inputDir file as a country list, using its basename as the routing tag.
args.output.with_suffix('.inventory.json').write_text(
    json.dumps(counts, sort_keys=True, indent=2) + '\n')
print(f'Converted {sum(c["ranges"] for c in counts.values())} ranges '
      f'for {len(counts)} country tags')
