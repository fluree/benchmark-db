#!/usr/bin/env python3
import argparse
import urllib.parse
import urllib.request
import xml.etree.ElementTree as E
from pathlib import Path
p = argparse.ArgumentParser()
p.add_argument('endpoint');p.add_argument('expected', type=int)
p.add_argument('--graph');p.add_argument('--output', required=True)
a = p.parse_args()
params = {'query': 'SELECT (COUNT(*) AS ?count) WHERE { ?s ?p ?o }'}
if a.graph:
    params['default-graph-uri'] = a.graph
url = a.endpoint + ('&' if '?' in a.endpoint else '?') + urllib.parse.urlencode(params)
response = urllib.request.urlopen(urllib.request.Request(url, headers={
    'Accept': 'application/sparql-results+xml'}), timeout=600).read()
Path(a.output).write_bytes(response)
values = [e.text for e in E.fromstring(response).iter() if e.tag.endswith('}literal')]
if values != [str(a.expected)]:
    raise SystemExit(f'COUNT mismatch: expected {a.expected}, received {values}')
print(f'COUNT verified: {a.expected}')
