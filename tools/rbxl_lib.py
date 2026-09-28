# Minimal binary .rbxl reader: loads every instance with its decodable properties.
# Usage from Python:  from rbxl_lib import load; doc = load("becomelapeace.rbxl")
import struct, lz4.block, zstandard


def _be_ileave(b, n, width=4):
    out = []
    for i in range(n):
        x = 0
        for k in range(width):
            x = (x << 8) | b[k * n + i]
        out.append(x)
    return out


def _zz(x): return (x >> 1) ^ -(x & 1)


def _rbxf(x):
    x = ((x >> 1) | ((x & 1) << 31)) & 0xFFFFFFFF
    return struct.unpack('<f', struct.pack('<I', x))[0]


_ROT = {  # special CFrame rotation ids -> (right, up) axis vectors of the rotation matrix rows
}


class Inst:
    __slots__ = ('ref', 'cls', 'props', 'parent', 'children')

    def __init__(self, ref, cls):
        self.ref, self.cls, self.props, self.parent, self.children = ref, cls, {}, None, []

    @property
    def name(self): return self.props.get('Name', '?')

    def path(self):
        parts, n = [], self
        while n: parts.append(n.name); n = n.parent
        return '.'.join(reversed(parts))

    def find(self, name):
        for c in self.children:
            if c.name == name: return c

    def descendants(self):
        for c in self.children:
            yield c
            yield from c.descendants()


def _decode(t, body, p, n):
    """returns list of n values (or None if type unsupported)"""
    if t in (0x01, 0x1D):  # String / ProtectedString
        out = []
        for _ in range(n):
            l, = struct.unpack_from('<I', body, p); p += 4
            raw = body[p:p + l]; p += l
            try: out.append(raw.decode('utf-8'))
            except UnicodeDecodeError: out.append(raw)
        return out
    if t == 0x02: return [bool(body[p + i]) for i in range(n)]
    if t == 0x03: return [_zz(x) for x in _be_ileave(body[p:], n)]
    if t == 0x04: return [round(_rbxf(x), 4) for x in _be_ileave(body[p:], n)]
    if t == 0x05: return [struct.unpack_from('<d', body, p + 8 * i)[0] for i in range(n)]
    if t in (0x0C, 0x0E):  # Color3 / Vector3
        a = _be_ileave(body[p:], n); b = _be_ileave(body[p + 4 * n:], n); c = _be_ileave(body[p + 8 * n:], n)
        return [tuple(round(_rbxf(v), 3) for v in xyz) for xyz in zip(a, b, c)]
    if t == 0x10 or t == 0x11:  # CFrame: keep position + rotation matrix if explicit
        rots = []
        for _ in range(n):
            rid = body[p]; p += 1
            if rid == 0:
                rots.append(struct.unpack_from('<9f', body, p)); p += 36
            else:
                rots.append(rid)
        a = _be_ileave(body[p:], n); b = _be_ileave(body[p + 4 * n:], n); c = _be_ileave(body[p + 8 * n:], n)
        return [{'pos': tuple(round(_rbxf(v), 2) for v in xyz), 'rot': r} for xyz, r in zip(zip(a, b, c), rots)]
    if t == 0x12: return _be_ileave(body[p:], n)
    if t == 0x13:  # Referent
        acc, out = 0, []
        for x in _be_ileave(body[p:], n):
            acc += _zz(x); out.append(acc)
        return out
    if t == 0x1A:  # Color3uint8
        return [(body[p + i], body[p + n + i], body[p + 2 * n + i]) for i in range(n)]
    if t == 0x0B: return _be_ileave(body[p:], n)  # BrickColor
    if t == 0x17:  # NumberRange
        return [struct.unpack_from('<2f', body, p + 8 * i) for i in range(n)]
    return None


def load(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'<roblox!'
    pos = 32
    classes, insts, sstr = {}, {}, []
    parents = []
    while pos < len(data):
        name = data[pos:pos + 4]; clen, ulen = struct.unpack_from('<II', data, pos + 4); pos += 16
        if clen == 0:
            body = data[pos:pos + ulen]; pos += ulen
        else:
            raw = data[pos:pos + clen]; pos += clen
            body = (zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
                    if raw[:4] == b'\x28\xb5\x2f\xfd' else lz4.block.decompress(raw, uncompressed_size=ulen))
        if name == b'INST':
            cid, sl = struct.unpack_from('<II', body, 0)
            cname = body[8:8 + sl].decode(); p = 8 + sl + 1
            n, = struct.unpack_from('<I', body, p); p += 4
            acc, refs = 0, []
            for x in _be_ileave(body[p:], n):
                acc += _zz(x); refs.append(acc)
            classes[cid] = refs
            for r in refs: insts[r] = Inst(r, cname)
        elif name == b'SSTR':
            p = 4; n, = struct.unpack_from('<I', body, p); p += 4
            for _ in range(n):
                p += 16; l, = struct.unpack_from('<I', body, p); p += 4
                sstr.append(body[p:p + l]); p += l
        elif name == b'PROP':
            cid, sl = struct.unpack_from('<II', body, 0)
            pname = body[8:8 + sl].decode(errors='replace'); p = 8 + sl
            t = body[p]; p += 1
            refs = classes[cid]
            try:
                vals = _decode(t, body, p, len(refs))
            except Exception:
                vals = None
            if t == 0x1C:
                idx = _be_ileave(body[p:], len(refs))
                vals = [sstr[i] if i < len(sstr) else None for i in idx]
            if vals is not None:
                for r, v in zip(refs, vals):
                    insts[r].props[pname] = v
        elif name == b'PRNT':
            n, = struct.unpack_from('<I', body, 1)
            def refs_at(off):
                acc, out = 0, []
                for x in _be_ileave(body[off:], n):
                    acc += _zz(x); out.append(acc)
                return out
            parents = list(zip(refs_at(5), refs_at(5 + 4 * n)))
        elif name == b'END\x00':
            break
    for c, p in parents:
        if p != -1 and c in insts and p in insts:
            insts[c].parent = insts[p]; insts[p].children.append(insts[c])
    roots = [i for i in insts.values() if i.parent is None]
    return {'insts': insts, 'roots': roots}


def get(doc, dotted):
    parts = dotted.split('.')
    node = next((r for r in doc['roots'] if r.name == parts[0]), None)
    for part in parts[1:]:
        node = node and node.find(part)
    return node


def dump(node, depth=0, maxdepth=3, props=('size', 'Size', 'CFrame', 'Anchored', 'AnimationId', 'SoundId', 'Texture',
                                          'TextureID', 'MeshId', 'Color', 'Color3uint8', 'Transparency', 'Value'),
         maxchildren=40, out=None):
    out = out if out is not None else []
    bits = []
    for k in props:
        if k in node.props:
            v = node.props[k]
            if k == 'CFrame': v = v['pos']
            if isinstance(v, (bytes,)): v = v[:40]
            bits.append(f'{k}={v}')
    out.append('  ' * depth + f'{node.name} [{node.cls}] ' + ' '.join(bits))
    if depth < maxdepth:
        kids = node.children
        for c in kids[:maxchildren]:
            dump(c, depth + 1, maxdepth, props, maxchildren, out)
        if len(kids) > maxchildren:
            out.append('  ' * (depth + 1) + f'... +{len(kids) - maxchildren} more')
    return out
