# Aetherfall — keputusan desain dunia

Dokumen ini menjelaskan **desain review** Aetherfall yang ada di branch ini. Ini bukan game loop lengkap dan bukan pengganti penilaian visual langsung di Godot.

## Intent ruang

Aetherfall adalah rig pemanenan energi yang patah di bibir canyon. Tower pusat adalah landmark dan orientasi utama. Deck industri yang lebar memberi ruang orientasi/konflik, lalu tiga rute mengubah elevasi dan lebar lintasan:

| Rute | Fungsi desain | Dimensi/kondisi yang diuji |
| --- | --- | --- |
| `east_bridge_approach` | Jalur cepat dari deck ke span tinggi timur; terbuka dan berisiko. | 12 m, naik 4.575 m, lebar 3.0 m |
| `west_catwalk_approach` | Jalur flank yang sempit dari span barat ke deck. | 16 m, turun 5.775 m, lebar 1.6 m |
| `lower_canyon_descent` | Akses turun dari gerbang depan ke dasar canyon dan set-piece mesin. | 19.1 m, turun 6.4 m, lebar 4.5 m |

Ketiga ramp menggunakan `connector_ramp.glb`, dengan source editable `source/connector_ramp.blend`; endpoint ada di `connectors.json`. Kemiringannya 19.57°–20.87°, di bawah `floor_max_angle` kapsul tes sebesar 40°.

## Zona

1. **Central deck** — ruang terbuka modular 6×6 m dengan tower dan orbit energi; pintu masuk visual serta ruang konflik utama.
2. **Elevated spans** — bridge timur dan catwalk barat membentuk loop pandangan silang. Railing memiliki collision per komponen agar jalur tidak menjadi blok AABB menyeluruh.
3. **Canyon lower approach** — gerbang depan membuka ke ramp lebar; machinery dan cooling vent diposisikan di sisi, tidak pada sumbu lintasan.
4. **Perimeter geology** — cliff, terrain, boulder, dan siluet jauh membingkai ruang tanpa menjadi floor gameplay. Permukaan memakai albedo, normal dan ORM PBR; outcrop, strata, brace, panel, rib dan hardware memperkuat skala tanpa mengalihkan fokus dari tower.

## Konvensi dan batas desain

- Satuan: meter; tinggi: **Y-up**. Kit Blender diproduksi dengan konvensi yang sama dan diekspor tanpa konversi sumbu tambahan.
- Rute yang disebut di atas diuji terhadap collider world aktif dengan ray/capsule, serta `CharacterBody3D` kapsul 1.8 m yang bergerak dua arah. Ini memverifikasi geometri saat ini, **bukan** UX kontrol pemain atau AI.
- Aset blocking seperti cover dan mesin masih menggunakan proxy box yang konservatif. Lantai deck/bridge/catwalk, gate opening, rail dan ramp mempunyai perlakuan collider khusus.
- Tidak ada `NavigationRegion3D`, AI, objective, combat tuning, LOD authored, atau profil perangkat dalam scope artefak desain ini.

## Status review

**VERIFIED (headless):** layout dibangun sebagai 251 placement, seluruh GLB PBR beserta bentuk detail terimpor, tiga ramp punya permukaan/collision dan dapat dilintasi kapsul otomatis dua arah.
**LIKELY:** komposisi tower/deck/canyon terbaca dari render review Blender.
**UNKNOWN:** hasil akhir material, sky, fog, glow dan framing di renderer Godot.
**UNVERIFIED:** performa dan pengalaman perangkat nyata.
