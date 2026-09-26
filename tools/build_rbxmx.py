# Packs bossfight/src into Studio model files (one per service) in bossfight/build/.
# In Studio: right-click the service in the Explorer -> Insert from File... -> pick the file.
import os
from xml.sax.saxutils import escape

SRC = os.path.join(os.path.dirname(__file__), '..', 'bossfight', 'src')
OUT = os.path.join(os.path.dirname(__file__), '..', 'bossfight', 'build')
ref = 0

def item(cls, name, source=None, children=()):
    global ref
    ref += 1
    props = f'<string name="Name">{escape(name)}</string>'
    if source is not None:
        props += '<ProtectedString name="Source"><![CDATA[' + source.replace(']]>', ']]]]><![CDATA[>') + ']]></ProtectedString>'
    kids = ''.join(children)
    return f'<Item class="{cls}" referent="RBX{ref}"><Properties>{props}</Properties>{kids}</Item>'

def walk(path):
    out = []
    for f in sorted(os.listdir(path)):
        p = os.path.join(path, f)
        if os.path.isdir(p):
            out.append(item('Folder', f, children=walk(p)))
            continue
        src = open(p, encoding='utf-8').read()
        if f.endswith('.server.lua'): out.append(item('Script', f[:-11], src))
        elif f.endswith('.client.lua'): out.append(item('LocalScript', f[:-11], src))
        elif f.endswith('.lua'): out.append(item('ModuleScript', f[:-4], src))
    return out

os.makedirs(OUT, exist_ok=True)
for service in sorted(os.listdir(SRC)):
    body = ''.join(walk(os.path.join(SRC, service)))
    xml = '<roblox version="4">' + body + '</roblox>'
    open(os.path.join(OUT, service + '.rbxmx'), 'w', encoding='utf-8').write(xml)
    print('wrote', service + '.rbxmx')
