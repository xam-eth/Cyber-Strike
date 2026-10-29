import subprocess, re, os, json, glob
SP=".venv/lib/python3.11/site-packages"
targets=[f"{SP}/bpy/__init__.so"]+[os.path.join(f"{SP}/bpy/lib",f) for f in os.listdir(f"{SP}/bpy/lib") if ".so" in f and not any(k in f for k in ["cuda","hip","sycl"])]
groups=json.load(open("/tmp/bpy_stubs/groups.json"))
stubs={s:lib for lib,syms in groups.items() if lib!="UNCLASSIFIED" for s in syms}
ver={}  # symbol -> version
for t in targets:
    try: out=subprocess.run(["readelf","--dyn-syms","-W",t],capture_output=True,text=True,timeout=180).stdout
    except Exception: continue
    for line in out.splitlines():
        m=re.search(r"UND\s+([A-Za-z_][A-Za-z0-9_]*)@([^\s(]+)", line)
        if m and m.group(1) in stubs:
            s,v=m.group(1),m.group(2)
            if s in ver and ver[s]!=v: print("CONFLICT",s,ver[s],v)
            ver[s]=v
print("versioned stub symbols:",len(ver))
by_lib={}
for s,v in ver.items(): by_lib.setdefault((stubs[s],v),[]).append(s)
for (lib,v),ss in sorted(by_lib.items()): print(lib,v,len(ss))
# rebuild each affected lib with version script
libs_affected={lib for (lib,v) in by_lib}
for lib in libs_affected:
    nodes={}
    for (l,v),ss in by_lib.items():
        if l==lib: nodes[v]=sorted(ss)
    # symbols in this lib without version stay unversioned (separate anonymous? with version script present, symbols not listed get no version but remain global unless local:* used - omit local)
    lines=[]
    prev=None
    for v,ss in nodes.items():
        lines.append(f"{v} {{ global: {'; '.join(ss)}; }};")
    vmap="\n".join(lines)+"\n"
    open(f"/tmp/bpy_stubs/{lib}.map","w").write(vmap)
    r=subprocess.run(["gcc","-shared","-fPIC","-Wl,-soname,"+lib,f"-Wl,--version-script=/tmp/bpy_stubs/{lib}.map","-o",f"/tmp/bpy_stubs/{lib}",f"/tmp/bpy_stubs/{lib}.c"],capture_output=True,text=True)
    print("rebuilt",lib,"OK" if r.returncode==0 else r.stderr[:300])
