# Extracts scripts + a compact instance tree from a binary .rbxl.
# Usage: pip install lz4 zstandard; python3 tools/extract_rbxl.py becomelapeace.rbxl extracted
import struct, sys, os, re, lz4.block, zstandard

sys.setrecursionlimit(100000)
data = open(sys.argv[1], 'rb').read()
out = sys.argv[2]
assert data[:8] == b'<roblox!'
ncls, ninst = struct.unpack_from('<ii', data, 16)
pos = 32

def ileave(b, n):
    vals = []
    for i in range(n):
        x = (b[i] << 24) | (b[n + i] << 16) | (b[2 * n + i] << 8) | b[3 * n + i]
        vals.append((x >> 1) ^ -(x & 1))
    return vals

def refs(b, n):
    v = ileave(b, n); acc = 0; r = []
    for x in v:
        acc += x; r.append(acc)
    return r

classes = {}      # classID -> (name, [refs])
inst_class = {}   # ref -> className
props = {}        # ref -> {prop: value}
parent = {}
sstr = []

while pos < len(data):
    name = data[pos:pos + 4]; clen, ulen = struct.unpack_from('<II', data, pos + 4); pos += 16
    if clen == 0:
        body = data[pos:pos + ulen]; pos += ulen
    else:
        raw = data[pos:pos + clen]; pos += clen
        if raw[:4] == b'\x28\xb5\x2f\xfd':
            body = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
        else:
            body = lz4.block.decompress(raw, uncompressed_size=ulen)
    if name == b'INST':
        cid, sl = struct.unpack_from('<II', body, 0)
        cname = body[8:8 + sl].decode(); p = 8 + sl + 1
        n, = struct.unpack_from('<I', body, p); p += 4
        r = refs(body[p:p + 4 * n], n)
        classes[cid] = (cname, r)
        for x in r: inst_class[x] = cname
    elif name == b'SSTR':
        p = 4; n, = struct.unpack_from('<I', body, p); p += 4
        for _ in range(n):
            p += 16; l, = struct.unpack_from('<I', body, p); p += 4
            sstr.append(body[p:p + l]); p += l
    elif name == b'PROP':
        cid, sl = struct.unpack_from('<II', body, 0)
        pname = body[8:8 + sl].decode(errors='replace'); p = 8 + sl
        t = body[p]; p += 1
        cname, r = classes[cid]
        if pname in ('Name', 'Source', 'Disabled', 'Enabled', 'RunContext') or t in (0x01, 0x1D) and pname in ('Name', 'Source'):
            if t in (0x01, 0x1D):  # String / ProtectedString
                for x in r:
                    l, = struct.unpack_from('<I', body, p); p += 4
                    props.setdefault(x, {})[pname] = body[p:p + l].decode('utf-8', 'replace'); p += l
            elif t == 0x1C:  # SharedString
                idx = ileave(body[p:p + 4 * len(r)], len(r))
                for x, i in zip(r, idx):
                    # SharedString indices are not zigzagged; undo
                    pass
                raw = [(body[p+i] << 24) | (body[p+len(r)+i] << 16) | (body[p+2*len(r)+i] << 8) | body[p+3*len(r)+i] for i in range(len(r))]
                for x, i in zip(r, raw):
                    props.setdefault(x, {})[pname] = sstr[i].decode('utf-8', 'replace')
            elif t == 0x02:
                for i, x in enumerate(r):
                    props.setdefault(x, {})[pname] = bool(body[p + i])
            elif t == 0x12:
                v = [(body[p+i] << 24) | (body[p+len(r)+i] << 16) | (body[p+2*len(r)+i] << 8) | body[p+3*len(r)+i] for i in range(len(r))]
                for x, e in zip(r, v): props.setdefault(x, {})[pname] = e
    elif name == b'PRNT':
        n, = struct.unpack_from('<I', body, 1)
        c = refs(body[5:5 + 4 * n], n); pr = refs(body[5 + 4 * n:5 + 8 * n], n)
        parent.update(zip(c, pr))
    elif name == b'END\x00':
        break

children = {}
for c, p_ in parent.items(): children.setdefault(p_, []).append(c)
roots = [r for r in inst_class if parent.get(r, -1) == -1]

SCRIPTS = {'Script', 'LocalScript', 'ModuleScript'}
def nm(r): return props.get(r, {}).get('Name', '?')
def safe(s): return re.sub(r'[^\w\-. ]', '_', s)[:60] or '_'

def has_script(r, memo={}):
    if r in memo: return memo[r]
    v = inst_class[r] in SCRIPTS or any(has_script(c) for c in children.get(r, []))
    memo[r] = v; return v

tree = []; stats = {}
def walk(r, depth, path):
    cls = inst_class[r]
    kids = children.get(r, [])
    line = '  ' * depth + f'{nm(r)} [{cls}]'
    if cls in SCRIPTS:
        src = props.get(r, {}).get('Source', '')
        fpath = os.path.join(out, *path, safe(nm(r)) + {'Script': '.server.lua', 'LocalScript': '.client.lua', 'ModuleScript': '.lua'}[cls])
        os.makedirs(os.path.dirname(fpath), exist_ok=True)
        base, i = fpath, 1
        while os.path.exists(fpath): fpath = base.replace('.lua', f'.{i}.lua'); i += 1
        open(fpath, 'w').write(src)
        line += f'  ({src.count(chr(10)) + 1} lines)'
        if props.get(r, {}).get('Disabled') or props.get(r, {}).get('Enabled') is False: line += ' DISABLED'
    tree.append(line)
    # collapse script-free subtrees into class counts
    grouped = {}
    for c in kids:
        if has_script(c) or (depth < 1):
            walk(c, depth + 1, path + [safe(nm(r))])
        else:
            k = inst_class[c]; grouped[k] = grouped.get(k, 0) + 1 + count(c)
    if grouped:
        tree.append('  ' * (depth + 1) + '… ' + ', '.join(f'{v}×{k}' for k, v in sorted(grouped.items(), key=lambda kv: -kv[1])[:6]))

def count(r): return sum(1 + count(c) for c in children.get(r, []))

os.makedirs(out, exist_ok=True)
for r in sorted(roots, key=lambda r: nm(r)):
    walk(r, 0, [])
open(os.path.join(out, 'TREE.txt'), 'w').write('\n'.join(tree) + '\n')
print(len(inst_class), 'instances;', sum(1 for c in inst_class.values() if c in SCRIPTS), 'scripts')
