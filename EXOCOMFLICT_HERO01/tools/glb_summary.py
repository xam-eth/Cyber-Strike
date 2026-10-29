import json, struct, sys
def summarize(path):
    with open(path,'rb') as f: data=f.read()
    assert data[:4]==b'glTF', 'not GLB'
    ver, total = struct.unpack('<II', data[4:12])
    jlen, jtype = struct.unpack('<II', data[12:20])
    g = json.loads(data[20:20+jlen])
    print(f"=== {path} ===")
    print(f"file_bytes={len(data)} glTF={g.get('asset',{}).get('version')} generator={g.get('asset',{}).get('generator')}")
    print(f"nodes={len(g.get('nodes',[]))} meshes={len(g.get('meshes',[]))} materials={len(g.get('materials',[]))} textures={len(g.get('textures',[]))} images={len(g.get('images',[]))} skins={len(g.get('skins',[]))} animations={len(g.get('animations',[]))} scenes={len(g.get('scenes',[]))}")
    print("extensionsUsed:", g.get('extensionsUsed'))
    for i,s in enumerate(g.get('skins',[])):
        print(f" skin[{i}] name={s.get('name')} joints={len(s.get('joints',[]))} skeleton_root_node={s.get('skeleton')}")
    for i,a in enumerate(g.get('animations',[])):
        print(f" anim[{i}] name={a.get('name')} channels={len(a.get('channels',[]))} samplers={len(a.get('samplers',[]))}")
    # node tree dump (names + flags)
    nodes=g.get('nodes',[])
    def label(i):
        n=nodes[i]; tags=[]
        if 'mesh' in n: tags.append(f"mesh={n['mesh']}")
        if 'skin' in n: tags.append(f"skin={n['skin']}")
        if 'camera' in n: tags.append('camera')
        return f"[{i}] {n.get('name','<unnamed>')} {' '.join(tags)}"
    roots=set()
    for sc in g.get('scenes',[]): roots.update(sc.get('nodes',[]))
    def walk(i,depth):
        print('  '*depth+label(i))
        for c in nodes[i].get('children',[]): walk(c,depth+1)
    for r in sorted(roots): walk(r,0)
    orphan=[i for i in range(len(nodes)) if i not in roots and all(i not in n.get('children',[]) for n in nodes)]
    if orphan: print(" orphan nodes:", orphan[:20])
    for i,m in enumerate(g.get('meshes',[])):
        prims=m.get('primitives',[])
        attrs=set()
        for p in prims: attrs.update(p.get('attributes',{}).keys())
        mats=[p.get('material') for p in prims]
        print(f" mesh[{i}] name={m.get('name')} prims={len(prims)} mats={mats} attrs={sorted(attrs)}")
    for i,m in enumerate(g.get('materials',[])):
        pbr=m.get('pbrMetallicRoughness',{})
        print(f" mat[{i}] name={m.get('name')} baseColTex={'baseColorTexture' in pbr} metalRoughTex={'metallicRoughnessTexture' in pbr} normal={'normalTexture' in m} emissive={'emissiveTexture' in m} occlusion={'occlusionTexture' in m} alpha={m.get('alphaMode')} doubleSided={m.get('doubleSided')}")
    for i,im in enumerate(g.get('images',[])):
        print(f" image[{i}] name={im.get('name')} mime={im.get('mimeType')} bufferView={im.get('bufferView')} uri={im.get('uri')}")
for p in sys.argv[1:]: summarize(p)
