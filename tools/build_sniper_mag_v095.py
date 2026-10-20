#!/usr/bin/env python3
"""Rebuild supplied v094 GLBs, stdlib only; no network, Blender or Godot.
Original meshes/buffers/textures remain intact. Only the active ammo/mag subtree
is replaced. Run with --source-dir and --output-dir (different directories).
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct


def read_glb(path):
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from('<4sII', raw)
    assert magic == b'glTF' and version == 2 and length == len(raw)
    n, kind = struct.unpack_from('<II', raw, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(raw[20:20+n])
    size, kind = struct.unpack_from('<II', raw, 20+n)
    assert kind == 0x004E4942
    return doc, bytearray(raw[28+n:28+n+size])


def accessor(doc, binary, index):
    a = doc['accessors'][index]
    v = doc['bufferViews'][a['bufferView']]
    fmt = {5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
    width = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    stride = v.get('byteStride', struct.calcsize('<'+fmt)*width)
    offset = v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*width,binary,offset+i*stride) for i in range(a['count'])]


def append_accessor(doc,binary,rows,kind='VEC3',component=5126):
    while len(binary)%4: binary.append(0)
    start=len(binary)
    fmt={5126:'f',5125:'I'}[component]
    for row in rows: binary.extend(struct.pack('<'+fmt*len(row),*row))
    view=len(doc['bufferViews'])
    doc['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(binary)-start})
    entry={'bufferView':view,'componentType':component,'count':len(rows),'type':kind}
    if kind=='VEC3':
        entry['min']=[min(r[k] for r in rows) for k in range(3)]
        entry['max']=[max(r[k] for r in rows) for k in range(3)]
    doc['accessors'].append(entry)
    return len(doc['accessors'])-1


def components(positions,indices):
    # Weld only for topology classification; retain original attributes/UV seams.
    lookup={}; ids=[]
    for p in positions:
        key=tuple(round(x,6) for x in p)
        ids.append(lookup.setdefault(key,len(lookup)))
    parent=list(range(len(lookup)))
    def root(i):
        while i!=parent[i]: parent[i]=parent[parent[i]];i=parent[i]
        return i
    for t in indices:
        for v in t[1:]: parent[root(ids[v])]=root(ids[t[0]])
    groups={}
    for t in indices: groups.setdefault(root(ids[t[0]]),[]).append(t)
    return list(groups.values())


def bounds(positions,triangles):
    p=[positions[i] for t in triangles for i in t]
    return [min(x[k] for x in p) for k in range(3)], [max(x[k] for x in p) for k in range(3)]


class Surface:
    def __init__(self): self.positions=[];self.normals=[];self.uv=[];self.indices=[]
    def face(self,points):
        u=[points[1][k]-points[0][k] for k in range(3)]
        v=[points[2][k]-points[0][k] for k in range(3)]
        normal=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
        length=math.sqrt(sum(x*x for x in normal));assert length>1e-12
        normal=[x/length for x in normal]
        start=len(self.positions)
        axis=max(range(3),key=lambda k:abs(normal[k])); axes=[k for k in range(3) if k!=axis]
        for p in points:
            self.positions.append(p);self.normals.append(normal)
            self.uv.append([(p[k]+.1)*6 for k in axes])
        for i in range(1,len(points)-1): self.indices.extend([(start,),(start+i,),(start+i+1,)])
    def bridge(self,a,b):
        for i in range(len(a)):
            k=(i+1)%len(a);self.face([a[i],a[k],b[k],b[i]])
    def solid(self,rings):
        self.face(list(reversed(rings[0])))
        for a,b in zip(rings,rings[1:]):self.bridge(a,b)
        self.face(rings[-1])


def ring(x,y,z,bevel=.001):
    return [(-x+bevel,-y,z),(x-bevel,-y,z),(x,-y+bevel,z),(x,y-bevel,z),
            (x-bevel,y,z),(-x+bevel,y,z),(-x,y-bevel,z),(-x,-y+bevel,z)]


def make_shell():
    s=Surface()
    # Closed thin wall with open throat, 1.1 mm wall, no top cap across the lens-like opening.
    outer=[ring(.0088,.0245,-.036),ring(.0098,.0255,-.0345),
           ring(.0098,.0255,.023),ring(.0088,.025,.034),ring(.0088,.025,.036)]
    inner=[ring(.0077,.0239,.036),ring(.0077,.0239,-.0335)]
    s.face(list(reversed(outer[0])))
    for a,b in zip(outer,outer[1:]):s.bridge(a,b)
    s.bridge(outer[-1],inner[0]);s.bridge(inner[0],inner[1]);s.face(inner[-1])
    # Rolled base plate; bevels catch light without transparent/double-sided faces.
    s.solid([ring(.010,.026,-.040),ring(.011,.027,-.039),ring(.011,.027,-.0367),ring(.010,.026,-.0357)])
    # Shallow pressed beads on the visible side walls, fully closed bevelled strips.
    for side in [-1,1]:
        for y in [-.013,.010]:
            rings=[]
            for z,dx,dy in [(-.030,.0002,.0007),(-.028,.00065,.0013),(.017,.00065,.0013),(.019,.0002,.0007)]:
                rings.append([(px+side*.00965,py+y,pz) for px,py,pz in ring(dx,dy,z,min(dx,dy)*.4)])
            s.solid(rings)
    # Two folded feeding lips: prism along Y. Narrow gap retains the top cartridge.
    for side in [-1,1]:
        # Convex strips avoid a concave cap; outer lip is inset to avoid
        # coplanar overlap with the shell wall.
        segments=[[(.0076,.031),(.0086,.031),(.0086,.0357),(.0076,.0357)],
                  [(.0076,.0357),(.0086,.0357),(.0077,.037),(.0076,.0359)],
                  [(.0027,.0359),(.0076,.0359),(.0077,.037),(.0027,.037)]]
        for seg in segments:
            front=[(side*x,-.020,z) for x,z in seg]
            # solid expects CCW viewed along +Y (normal +Y on last cap).
            a,b,c=front[:3];ny=(b[2]-a[2])*(c[0]-a[0])-(b[0]-a[0])*(c[2]-a[2])
            if ny<0:front.reverse()
            s.solid([front,[(x,.020,z) for x,y,z in front]])
    return s


def build(source,destination):
    expected = {'1k':'87089f34cf48c84e776e1e2ad9707a43542bbbfb9025aa6d85582dd4de13d888',
                '2k':'6ddddc39a485bc3df40bfc790710fd66b50204451ef0fd51bcefb4a92ddd2a7e'}
    quality = source.stem.rsplit('_',1)[1]
    if hashlib.sha256(source.read_bytes()).hexdigest() != expected[quality]:
        raise ValueError('Source differs from audited v094; inspect before rebuilding')
    d,b=read_glb(source)
    original_binary=bytes(b)
    # Fail closed on a different source asset; names alone are not identification.
    assert len(d['nodes'])==8 and len(d['meshes'])==5
    assert d['nodes'][5]=={'mesh':3,'name':'Object_5'}
    assert d['nodes'][6]['name']=='SniperMagazinePivot'
    p=d['meshes'][3]['primitives'][0]
    assert d['materials'][p['material']]['name']=='Sniper_rifle_ammo'
    pos=accessor(d,b,p['attributes']['POSITION'])
    raw=accessor(d,b,p['indices']);tri=[tuple(v[0] for v in raw[i:i+3]) for i in range(0,len(raw),3)]
    groups=components(pos,tri);assert sorted(map(len,groups))==[384]*7+[662]
    rounds=[];carriers=[];display=[]
    for g in groups:
        lo,hi=bounds(pos,g)
        if len(g)==384 and hi[2]<0 and lo[1]<-.13:rounds.append(g)
        elif len(g)==384 and lo[2]>.09:display.append(g)
        elif len(g)==662 and hi[2]<0:carriers.append(g)
        else:raise ValueError('Unrecognized ammo component; do not hide it blindly')
    assert len(rounds)==6 and len(display)==1 and len(carriers)==1
    rounds.sort(key=lambda g:bounds(pos,g)[1][2],reverse=True)
    pivot=(.0004855,-.11377,-.05)
    d['nodes'][6]['translation']=list(pivot)
    d['nodes'][6]['children']=[]
    d['nodes'][1]['children'].remove(5)
    d['nodes'][5]={'name':'AmmoSourceArchive','extras':{'original_mesh':3,
        'reason':'Source display round above scope and six-round stack retained in mesh data only'}}
    d['nodes'][6]['extras']={'version':'v095','capacity_visual':5,'source':'v094 supplied asset'}
    # Retain original Object_5 and sixth round in unreferenced source data.
    def component_node(name,g,shift_z):
        used=sorted({i for t in g for i in t});remap={old:new for new,old in enumerate(used)}
        attrs={}
        for semantic,aidx in p['attributes'].items():
            values=accessor(d,b,aidx);rows=[values[i] for i in used]
            if semantic=='POSITION':rows=[tuple(v[k]-pivot[k]+(shift_z if k==2 else 0) for k in range(3)) for v in rows]
            a=d['accessors'][aidx]
            attrs[semantic]=append_accessor(d,b,rows,a['type'],a['componentType'])
        idx=append_accessor(d,b,[(remap[i],) for t in g for i in t],'SCALAR',5125)
        mesh=len(d['meshes']);d['meshes'].append({'name':name,'primitives':[{'attributes':attrs,'indices':idx,'material':p['material']}]})
        node=len(d['nodes']);d['nodes'].append({'name':name,'mesh':mesh});d['nodes'][6]['children'].append(node)
    for i,g in enumerate(rounds[:5]):component_node('SniperMagazineRound%02d'%(i+1),g,.013)
    component_node('SniperMagazineCarrier',carriers[0],0)
    shell=make_shell()
    attrs={'POSITION':append_accessor(d,b,shell.positions),'NORMAL':append_accessor(d,b,shell.normals),
           'TEXCOORD_0':append_accessor(d,b,shell.uv,'VEC2')}
    idx=append_accessor(d,b,shell.indices,'SCALAR',5125)
    material=len(d['materials'])
    d['materials'].append({'name':'Magazine_v095_BluedSteel','doubleSided':False,
        'pbrMetallicRoughness':{'baseColorTexture':{'index':9},'baseColorFactor':[.65,.68,.72,1],
                              'metallicFactor':.82,'roughnessFactor':.46}})
    mesh=len(d['meshes']);d['meshes'].append({'name':'SniperMagazineShell_v095',
        'primitives':[{'attributes':attrs,'indices':idx,'material':material}]})
    d['nodes'][7]={'name':'SniperMagazineMesh','mesh':mesh};d['nodes'][6]['children'].insert(0,7)
    assert bytes(b[:len(original_binary)])==original_binary
    while len(b)%4:b.append(0)
    d['buffers'][0]['byteLength']=len(b)
    d['asset']['generator']='WW2 FPS v095 deterministic stdlib asset repair'
    text=json.dumps(d,separators=(',',':'),ensure_ascii=True).encode()
    text+=b' '*((-len(text))%4)
    data=struct.pack('<4sII',b'glTF',2,28+len(text)+len(b))+struct.pack('<II',len(text),0x4E4F534A)+text+struct.pack('<II',len(b),0x004E4942)+b
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_bytes(data)
    return {'source':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'output':destination.name,'sha256':hashlib.sha256(data).hexdigest(),
            'shell_triangles_before':288,'shell_triangles_after':len(shell.indices)//3,
            'shell_surfaces_before':3,'shell_surfaces_after':1,
            'active_rounds':5,'retained_unreferenced_source_rounds':2,
            'original_binary_prefix_preserved':True,'bytes':len(data)}


def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument('--source-dir',type=Path,required=True);a.add_argument('--output-dir',type=Path,required=True)
    args=a.parse_args();assert args.source_dir.resolve()!=args.output_dir.resolve()
    reports=[]
    for quality in ['1k','2k']:
        reports.append(build(args.source_dir/f'sniper_rifle_mag_{quality}.glb',args.output_dir/f'sniper_rifle_mag_v095_{quality}.glb'))
    (args.output_dir/'v095-manifest.json').write_text(json.dumps(reports,indent=2)+'\n')
    print(json.dumps(reports,indent=2))

if __name__=='__main__':main()
