#!/usr/bin/env python3
import hashlib
import argparse
import json
import sys
from pathlib import Path
PINS = {
    '1m': ('724101', '0eca9f19829be6390700196c5de4fe6e3d0610e1cd09d7f780de6526a95a48c8'),
    '100m': ('100000748', '9f72d493f1a8040558afdeb5b719dae9037625bb4911b36387a44746097707ba'),
    '200m': ('200031975', '6ded674926fe39153d557f2a059526723901edcea7232a8924bd7b49881936f8'),
}
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('scale', choices=PINS)
    parser.add_argument('filename')
    parser.add_argument('--output', help='Save the verified input identity as JSON')
    args = parser.parse_args()
    scale, filename = args.scale, args.filename
    digest = hashlib.sha256()
    with Path(filename).open('rb') as f:
        for block in iter(lambda: f.read(8 * 1024 * 1024), b''):
            digest.update(block)
    if digest.hexdigest() != PINS[scale][1]:
        raise SystemExit(f'Dataset hash mismatch: {filename}: {digest.hexdigest()}')
    if args.output:
        Path(args.output).write_text(json.dumps(dict(scale=scale, filename=str(Path(filename).resolve()),
            sha256=digest.hexdigest(), expected_triples=int(PINS[scale][0])), indent=2) + '\n')
    print(PINS[scale][0])
