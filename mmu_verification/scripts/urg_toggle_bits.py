#!/usr/bin/env python3
"""Parse a URG html report dir; emit per-module toggle bit detail.

Usage: tglbits.py <urgReportDir> <mod1> [mod2 ...]
Emits JSON: { module: { "ports": {name: [tgl,t10,t01,dir]}, "signals": {...} } }
Values are "Yes"/"No".
"""
import re, sys, json, os

def strip(s):
    return re.sub(r'<[^>]+>', '', s).replace('&nbsp;', ' ').strip()

def parse_mod(path):
    h = open(path, errors='ignore').read()
    res = {}
    for cap, key in (('Port Details', 'ports'), ('Signal Details', 'signals')):
        i = h.find('<caption><b>%s</b>' % cap)
        if i < 0:
            res[key] = {}
            continue
        j = h.find('</table>', i)
        blk = h[i:j]
        rows = blk.split('<tr>')
        d = {}
        for r in rows[1:]:
            cells = re.findall(r'<td[^>]*>(.*?)</td>', r, re.S)
            if len(cells) < 4:
                continue
            vals = [strip(c) for c in cells]
            d[vals[0]] = vals[1:5]
        res[key] = d
    return res

def modmap(rdir):
    h = open(os.path.join(rdir, 'modlist.html'), errors='ignore').read()
    m = {}
    for mm in re.finditer(r'<a href="(mod\d+\.html)"\s*>([A-Za-z0-9_$]+)</a>', h):
        m.setdefault(mm.group(2), mm.group(1))
    return m

if __name__ == '__main__':
    rdir = sys.argv[1]
    want = sys.argv[2:]
    mm = modmap(rdir)
    out = {}
    for w in want:
        if w not in mm:
            out[w] = None
            continue
        out[w] = parse_mod(os.path.join(rdir, mm[w]))
    print(json.dumps(out, sort_keys=True))
