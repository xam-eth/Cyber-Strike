import subprocess, re, os
SP=".venv/lib/python3.11/site-packages"
targets=[f"{SP}/bpy/__init__.so"]
lib_dir=f"{SP}/bpy/lib"
for f in sorted(os.listdir(lib_dir)):
    if f.endswith((".so",)) or ".so." in f:
        if any(k in f for k in ["cuda","hip","sycl"]): continue
        targets.append(os.path.join(lib_dir,f))
undef=set()
for t in targets:
    try:
        out=subprocess.run(["nm","-D","--undefined-only",t],capture_output=True,text=True,timeout=60).stdout
    except Exception: continue
    for line in out.splitlines():
        parts=line.split()
        if not parts: continue
        sym=parts[-1].split("@")[0]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", sym): undef.add(sym)
print("total undefined:",len(undef))
rules={
 "libGL.so.1": lambda s: s.startswith("glX") or re.match(r"^gl[A-Z]",s),
 "libXrender.so.1": lambda s: s.startswith("XRender"),
 "libXfixes.so.3": lambda s: s.startswith("XFixes"),
 "libXi.so.6": lambda s: s.startswith("XI") or s.startswith("_Xi"),
 "libxkbcommon.so.0": lambda s: s.startswith("xkb_"),
 "libSM.so.6": lambda s: s.startswith("Smc") or s.startswith("Sms") or s.startswith("_Sm"),
 "libICE.so.6": lambda s: s.startswith("Ice") or s.startswith("_Ice"),
 "libXt.so.6": lambda s: s.startswith("Xt") or s.startswith("_Xt"),
}
os.makedirs("/tmp/bpy_stubs",exist_ok=True)
for lib,pred in rules.items():
    syms=sorted(s for s in undef if pred(s))
    src="\n".join(f"void {s}(void){{}}" for s in syms)+"\n"
    cpath=f"/tmp/bpy_stubs/{lib}.c"; open(cpath,"w").write(src)
    r=subprocess.run(["gcc","-shared","-fPIC","-Wl,-soname,"+lib,"-o",f"/tmp/bpy_stubs/{lib}",cpath],capture_output=True,text=True)
    print(lib, len(syms), "symbols", "OK" if r.returncode==0 else r.stderr[:200])
