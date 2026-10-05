"""Emit a Guix import script for locally verified generated native origins."""
import argparse
import hashlib
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--lock', action='append', type=Path, required=True)
parser.add_argument('--cache', action='append', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
entries = {}
pattern = re.compile(r'\(file-name "([A-Za-z0-9._+-]+)"\)\s*'
                     r'\(sha256 \(base16-string->bytevector "([0-9a-f]{64})"\)\)')
for lock in args.lock:
    source = lock.read_text()
    records = pattern.findall(source)
    if len(records) != source.count('(file-name '):
        raise ValueError('Unrecognized origin format: ' + str(lock))
    for name, checksum in records:
        if (name, checksum) in entries:
            continue
        candidates = [cache / name for cache in args.cache]
        matching = [p for p in candidates if p.is_file() and not p.is_symlink()
                    and hashlib.sha256(p.read_bytes()).hexdigest() == checksum]
        if not matching:
            raise ValueError('No authenticated source cache: ' + name)
        entries[name, checksum] = str(matching[0].resolve())
rows = ['(list ' + ' '.join(json.dumps(v) for v in (name, path, checksum)) + ')'
        for (name, checksum), path in sorted(entries.items())]
args.output.write_text('''(use-modules (guix store) (guix hash) (guix base16))
(with-store store
 (for-each
  (lambda (entry)
   (unless (string=? (caddr entry)
                    (bytevector->base16-string (file-hash* (cadr entry) #:recursive? #f)))
    (error "Source cache hash changed" (car entry)))
   (format #t "~a\\t~a~%" (car entry)
           (add-to-store store (car entry) #f "sha256" (cadr entry))))
  (list
''' + '\n'.join(rows) + '\n)))\n')
print('Verified', len(rows), 'fixed native origins; import script generated')
