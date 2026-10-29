import subprocess, re, os, json
SP=".venv/lib/python3.11/site-packages"
MAIN=f"{SP}/bpy/__init__.so"
def nm_syms(path, defined):
    flag="--defined-only" if defined else "--undefined-only"
    try: out=subprocess.run(["nm","-D",flag,path],capture_output=True,text=True,timeout=120).stdout
    except Exception: return set()
    s=set()
    for line in out.splitlines():
        p=line.split()
        if not p: continue
        sym=p[-1].split("@")[0]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$",sym): s.add(sym)
    return s
# resolved libs from ldd
ldd=subprocess.run(["ldd",MAIN],capture_output=True,text=True).stdout
resolved=[]
for line in ldd.splitlines():
    m=re.search(r"=>\s+(\S+)",line)
    if m and os.path.exists(m.group(1)): resolved.append(m.group(1))
    elif line.strip().startswith("/") : resolved.append(line.strip().split()[0])
print("resolved libs:",len(resolved))
provided=set()
for r in resolved: provided|=nm_syms(r,True)
# targets (blender's own)
targets=[MAIN]
lib_dir=f"{SP}/bpy/lib"
for f in sorted(os.listdir(lib_dir)):
    if (".so" in f) and not any(k in f for k in ["cuda","hip","sycl"]):
        targets.append(os.path.join(lib_dir,f))
undef=set()
for t in targets: undef|=nm_syms(t,False)
for t in targets: provided|=nm_syms(t,True)
needed=sorted(undef-provided)
print("undefined total:",len(undef)," still needed:",len(needed))
def classify(s):
    if s.startswith("XRender"): return "libXrender.so.1"
    if s.startswith("XFixes"): return "libXfixes.so.3"
    if s.startswith("xkb_"): return "libxkbcommon.so.0"
    if s.startswith("glX") or re.match(r"^gl[A-Z]",s): return "libGL.so.1"
    if s.startswith(("Smc","Sms","_Sm")): return "libSM.so.6"
    if s.startswith(("Ice","_Ice")): return "libICE.so.6"
    if s.startswith(("Xt","_Xt")): return "libXt.so.6"
    if s.startswith("XI") or s.startswith("_Xi"): return "libXi.so.6"
    if s.startswith("X"): return "libXi.so.6"  # XI1 X-prefixed API
    return "UNCLASSIFIED"
groups={}
for s in needed: groups.setdefault(classify(s),[]).append(s)
for k,v in sorted(groups.items()): print(k, len(v), v[:12])
json.dump(groups, open("/tmp/bpy_stubs/groups.json","w"), indent=1)
# rebuild stubs only for missing libs (keep any previously built if no group)
for lib,syms in groups.items():
    if lib=="UNCLASSIFIED": continue
    src="\n".join(f"void {s}(void){{}}" for s in syms)+"\n"
    open(f"/tmp/bpy_stubs/{lib}.c","w").write(src)
    r=subprocess.run(["gcc","-shared","-fPIC","-Wl,-soname,"+lib,"-o",f"/tmp/bpy_stubs/{lib}",f"/tmp/bpy_stubs/{lib}.c"],capture_output=True,text=True)
    print("built",lib,"OK" if r.returncode==0 else r.stderr[:300])
# ensure all 7 exist even if empty
for lib in ["libGL.so.1","libICE.so.6","libSM.so.6","libXfixes.so.3","libXi.so.6","libXrender.so.1","libxkbcommon.so.0"]:
    if not os.path.exists(f"/tmp/bpy_stubs/{lib}"):
        open(f"/tmp/bpy_stubs/{lib}.c","w").write("int __stub_dummy;\n")
        subprocess.run(["gcc","-shared","-fPIC","-Wl,-soname,"+lib,"-o",f"/tmp/bpy_stubs/{lib}",f"/tmp/bpy_stubs/{lib}.c"])
        print("built empty",lib)
