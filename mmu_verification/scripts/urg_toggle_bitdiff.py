import json, re, sys, collections

def expand(name):
    m = re.match(r'^(.*)\[(\d+):(\d+)\]$', name)
    if m:
        b, hi, lo = m.group(1), int(m.group(2)), int(m.group(3))
        return [f"{b}[{i}]" for i in range(lo, hi+1)]
    return [name]

def bits(d):
    """d = {'ports':{name:[tgl,t10,t01,dir]}, 'signals':{...}} -> {(sec,bit,dir): bool covered}"""
    out = {}
    for sec in ('ports', 'signals'):
        for n, v in d[sec].items():
            for bn in expand(n):
                out[(sec, bn, '1->0')] = (v[1] == 'Yes')
                out[(sec, bn, '0->1')] = (v[2] == 'Yes')
    return out

b = json.load(open(sys.argv[1])); m = json.load(open(sys.argv[2]))
mods = [l.strip() for l in open(sys.argv[3]) if l.strip()]
tc = tl = tn = 0
print(f"{'module':30s} {'uncov(base)':>11s} {'closed':>7s} {'left':>7s} {'close%':>7s}")
print('-'*68)
for k in mods:
    B, M = b.get(k), m.get(k)
    if not B or not M:
        print(f"{k:30s}  MISSING"); continue
    bb, mb = bits(B), bits(M)
    closed = [x for x, c in bb.items() if not c and mb.get(x, False)]
    left   = [x for x, c in bb.items() if not c and not mb.get(x, True)]
    n = len(closed) + len(left)
    tc += len(closed); tl += len(left); tn += n
    pct = 100.0*len(closed)/n if n else 0.0
    print(f"{k:30s} {n:11d} {len(closed):7d} {len(left):7d} {pct:6.1f}%")
    json.dump({'closed': sorted('%s %s %s' % x for x in closed),
               'left':   sorted('%s %s %s' % x for x in left)},
              open('/tmp/bd_%s.json' % k, 'w'), indent=0)
print('-'*68)
print(f"{'TOTAL':30s} {tn:11d} {tc:7d} {tl:7d} {100.0*tc/tn if tn else 0:6.1f}%")
