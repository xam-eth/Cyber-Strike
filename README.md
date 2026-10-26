# Cyber-Strike — WORLD ONLY (Stellar Horizon)

**Branch `arena/3a7253a1-cyber-strike` — World QA visual only. No game, no web, no engine.**

Clone ini hanya berisi asset world + project Godot agar bisa langsung import & lihat world, debugging & tambah asset.

## Isi branch
- `world-qa/` — Godot 4.6.2 project independent (buka `world-qa/project.godot`). Cinematic tour tanpa controll, orbit manual optional. 4 GLB world (frostline/day, verdant/sunset, emberfall/night, titans/storm) satu geometry 180×180.
- `assets/real/` — source GLB asli (Kenney space-kit 211 files, ground tile, powerplant 42M, nature, setpieces) untuk penambahan asset.
- `tools/asset-forge/` — builder THREE.js → GLB (themes/roles/compose) untuk generate world.
- `docs/world/` — desain world, pacing, foto ref.

## Clone (hanya branch ini, ringan)
```bash
# Paling ringan — hanya snapshot terakhir + hanya folder QA
git clone --depth 1 --filter=blob:none --sparse --single-branch --branch "arena/3a7253a1-cyber-strike" https://github.com/xam-eth/Cyber-Strike.git
cd Cyber-Strike
git sparse-checkout set world-qa assets   # atau: git sparse-checkout set world-qa  (jika hanya mau lihat)

# Atau full branch snapshot (tanpa history lama) — tetap ringan (~90M):
git clone --depth 1 --single-branch --branch "arena/3a7253a1-cyber-strike" https://github.com/xam-eth/Cyber-Strike.git
```

Tanpa `--depth 1` tetap akan tarik history lama (10822 objects) — jangan pakai clone full tanpa depth untuk branch ini.

## Buka di Godot
- GUI: Install Godot 4.6.2 → Import → pilih `world-qa/project.godot` → Play (F5)
- Headless: `tools/.cache/godot --path world-qa --import` lalu `tools/.cache/godot --path world-qa`
- Kontrol: `SPACE` cinematic/orbit, `N/P` atau `1-4` ganti mood, `Right-drag` orbit, `Scroll` zoom

Lihat `world-qa/README.md` untuk detail lengkap (metrics 180×180, 8 viewpoints, disciplines level-design + camera-systems).

## Asset workflow
- Tambah GLB baru ke `assets/real/` (wajib GLB asli, bukan procedural)
- Daftar role di `tools/asset-forge/src/worlds/roles.js`, theme di `themes.js`, layout di `frostline.js`/`verdant.js` dll, `npm install --prefix tools/asset-forge && node tools/asset-forge/gate/world_shot.mjs`
- Build output ke `world-qa/assets/worlds/*.glb` — langsung bisa di-import Godot tanpa export tambahan.
