#!/usr/bin/env python3
"""Extract per-module SCORE/LINE/COND/TOGGLE/FSM/BRANCH/ASSERT and toggle bit
counts from a URG modinfo.txt.  Usage:
    modinfo_tgl.py <modinfo.txt> [mod1 mod2 ...]     -> JSON on stdout
"""
import re, sys, json

HDR = re.compile(r'^SCORE\s+LINE\s+COND\s+TOGGLE\s+FSM\s+BRANCH(\s+ASSERT)?\s*$')

def num(tok):
    return None if tok == '--' else float(tok)

def parse(path):
    lines = open(path, errors='ignore').read().splitlines()
    out = {}
    i = 0
    cur = None
    while i < len(lines):
        L = lines[i]
        m = re.match(r'^Module\s*:\s*(\S+)\s*$', L)
        if m:
            cur = m.group(1)
            out[cur] = {'name': cur}
            # module summary row: next HDR then value row
            j = i + 1
            while j < len(lines) and j < i + 6:
                if HDR.match(lines[j]):
                    vals = lines[j+1].split()
                    keys = ['SCORE','LINE','COND','TOGGLE','FSM','BRANCH','ASSERT']
                    for k, v in zip(keys, vals):
                        out[cur][k] = num(v)
                    break
                j += 1
            i = j
            continue
        if cur and L.startswith('Toggle Coverage for Module'):
            blk = {}
            j = i
            while j < len(lines) and not lines[j].startswith('==='):
                mm = re.match(r'^(Totals|Total Bits|Total Bits 0->1|Total Bits 1->0|'
                              r'Ports|Port Bits|Port Bits 0->1|Port Bits 1->0|'
                              r'Signals|Signal Bits|Signal Bits 0->1|Signal Bits 1->0)\s+'
                              r'(\d+)\s+(\d+)\s+([\d.]+)\s*$', lines[j])
                if mm:
                    blk[mm.group(1)] = (int(mm.group(2)), int(mm.group(3)), float(mm.group(4)))
                j += 1
            out[cur]['tgl'] = blk
            i = j
            continue
        i += 1
    return out

if __name__ == '__main__':
    data = parse(sys.argv[1])
    want = sys.argv[2:]
    if want:
        data = {k: v for k, v in data.items() if k in want}
    print(json.dumps(data, indent=1, sort_keys=True))
