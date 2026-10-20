#!/usr/bin/env python3
"""Structural asset checks; not a Godot parser, physics test or visual approval."""
import argparse
import hashlib
import importlib.util
import math
from pathlib import Path
import tempfile

spec=importlib.util.spec_from_file_location('builder',Path(__file__).parents[1]/'tools/build_sniper_mag_v095.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)


def check(source,output):
    old,oldbin=builder.read_glb(source);new,binary=builder.read_glb(output)
    assert binary[:len(oldbin)]==oldbin, 'Source binary modified'
    assert new['meshes'][:5]==old['meshes'], 'Original meshes changed'
    assert new['nodes'][:5]==old['nodes'][:1]+[dict(old['nodes'][1],children=[2,3,4,6])]+old['nodes'][2:5]
    assert new['materials'][:6]==old['materials'] and new['images']==old['images']
    assert new['textures']==old['textures'], 'Unexpected texture changes'
    reachable=[]
    def walk(i):
        assert i not in reachable, 'Cycle or multiply-parented node'
        reachable.append(i)
        for child in new['nodes'][i].get('children',[]):walk(child)
    for root in new['scenes'][new.get('scene',0)]['nodes']:walk(root)
    assert 5 not in reachable
    pivot=new['nodes'][6];children=pivot['children']
    rounds=[new['nodes'][i] for i in children if new['nodes'][i]['name'].startswith('SniperMagazineRound')]
    assert len(rounds)==5
    assert all(new['nodes'][i].get('mesh') not in [3,4] for i in reachable)
    original_tris=sum(new['accessors'][p['indices']]['count']//3 for m in new['meshes'][:3] for p in m['primitives'])
    total_tris=0
    for ni in reachable:
        node=new['nodes'][ni]
        if 'mesh' not in node:continue
        for p in new['meshes'][node['mesh']]['primitives']:
            positions=builder.accessor(new,binary,p['attributes']['POSITION'])
            indices=[i[0] for i in builder.accessor(new,binary,p['indices'])]
            assert len(indices)%3==0 and min(indices)>=0 and max(indices)<len(positions)
            assert all(all(math.isfinite(x) for x in v) for v in positions)
            total_tris+=len(indices)//3
            if ni in children:
                for v in positions:
                    assert -.01101<=v[0]<=.01101 and -.02701<=v[1]<=.02701
                    assert -.04001<=v[2]<=.03701, (node['name'],v)
            if ni==7:
                normals=builder.accessor(new,binary,p['attributes']['NORMAL'])
                assert not new['materials'][p['material']].get('doubleSided',False)
                volume=0
                faces=set()
                for k in range(0,len(indices),3):
                    ids=indices[k:k+3];a,b,c=[positions[i] for i in ids]
                    key=tuple(sorted(tuple(round(x,7) for x in v) for v in [a,b,c]))
                    assert key not in faces, 'Duplicate shell face'
                    faces.add(key)
                    u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
                    n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                    assert sum(x*x for x in n)>1e-16, 'Degenerate triangle'
                    assert all(sum(n[k]*normals[i][k] for k in range(3))>0 for i in ids), 'Inverted normal'
                    volume+=sum(a[i]*[b[1]*c[2]-b[2]*c[1],b[2]*c[0]-b[0]*c[2],b[0]*c[1]-b[1]*c[0]][i] for i in range(3))/6
                assert volume>0, 'Inverted shell winding'
    # Every new accessor fits its view, every view fits the BIN buffer.
    for v in new['bufferViews']:assert v.get('byteOffset',0)+v['byteLength']<=len(binary)
    for a in new['accessors']:
        rows=builder.accessor(new,binary,new['accessors'].index(a))
        assert len(rows)==a['count']
    with tempfile.TemporaryDirectory() as tmp:
        repeated=Path(tmp)/output.name
        builder.build(source,repeated)
        assert hashlib.sha256(repeated.read_bytes()).digest()==hashlib.sha256(output.read_bytes()).digest(), 'Non-deterministic build'
    print(f'PASS {output.name}: original buffers/meshes/textures preserved; 5 child rounds; bounds/normals/indices/determinism OK')
    print(f'Active triangles {total_tris}; shell+contents {total_tris-original_tris}; source shell+ammo 3638')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-dir',type=Path,required=True);p.add_argument('--output-dir',type=Path,required=True)
    args=p.parse_args()
    for q in ['1k','2k']:check(args.source_dir/f'sniper_rifle_mag_{q}.glb',args.output_dir/f'sniper_rifle_mag_v095_{q}.glb')

if __name__=='__main__':main()
