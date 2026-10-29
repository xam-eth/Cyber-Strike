"""Detect see-through holes (background-colored regions enclosed by the model silhouette)
in magenta-background diagnostic renders. Prints components >=15 px and writes annotated copies."""
import glob, os, sys
import numpy as np
from PIL import Image, ImageDraw

def flood(mask, seeds):
    region = seeds.copy()
    while True:
        dil = region.copy()
        dil[1:,:] |= region[:-1,:]; dil[:-1,:] |= region[1:,:]
        dil[:,1:] |= region[:,:-1]; dil[:,:-1] |= region[:,1:]
        new = dil & mask
        if int(new.sum()) == int(region.sum()): return region
        region = new

def analyze(path):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    h, w, _ = a.shape
    corners = np.concatenate([a[:8,:8].reshape(-1,3), a[:8,-8:].reshape(-1,3),
                              a[-8:,:8].reshape(-1,3), a[-8:,-8:].reshape(-1,3)])
    bg = np.median(corners, axis=0)
    mask = np.abs(a - bg).max(axis=2) <= 6
    border = np.zeros_like(mask); border[0,:]=border[-1,:]=True; border[:,0]=border[:,-1]=True
    exterior = flood(mask, border & mask)
    holes = mask & ~exterior
    comps, remaining = [], holes.copy()
    while remaining.any():
        y, x = np.argwhere(remaining)[0]
        seed = np.zeros_like(mask); seed[y,x] = True
        comp = flood(holes, seed)
        ys, xs = np.nonzero(comp)
        comps.append((len(ys), int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()),
                      round(float(xs.mean())/w*100,1), round(float(ys.mean())/h*100,1)))
        remaining &= ~comp
    big = [c for c in comps if c[0] >= 15]
    if big:
        out = im.copy(); d = ImageDraw.Draw(out)
        for area,x0,y0,x1,y1,cx,cy in big:
            d.rectangle([max(0,x0-3),max(0,y0-3),x1+3,y1+3], outline=(255,255,0), width=2)
        out.save(path.replace(".png","_holes.png"))
    return bg, sorted(big, reverse=True)

if __name__ == "__main__":
    for p in sorted(glob.glob(sys.argv[1])):
        if "_holes" in p: continue
        bg, big = analyze(p)
        print(os.path.basename(p), "bg", bg.astype(int).tolist(), "interior-bg comps>=15px:", len(big))
        for c in big[:8]:
            print(f"   area={c[0]:5d}px bbox=({c[1]},{c[2]})-({c[3]},{c[4]}) centroid=({c[5]}%,{c[6]}%)")
