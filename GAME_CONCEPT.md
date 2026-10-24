EXOCOMPLICT

Game Concept & Technical Design Document

Document Version: 1.0
Project Type: Mobile-First Third-Person Shooter
Genre: Sci-Fi Action / Arena Survival Shooter
Primary Platform: Android
Engine: Godot 4.x
Programming Language: GDScript
Initial Mode: Single-player
Future Direction: Optional multiplayer
Working Title: Exocomplict

---

1. EXECUTIVE SUMMARY

1.1 Product Vision

Exocomplict adalah game third-person shooter futuristik yang berfokus pada pengalaman menembak yang responsif, senjata dengan karakteristik unik, efek visual yang memuaskan, dan progression sederhana yang mendorong pemain terus bermain.

Pemain mengendalikan karakter futuristik dari kamera di belakang karakter. Mereka memasuki arena, menghadapi gelombang musuh, mendapatkan Battle Points, membuka senjata, dan menguji berbagai pola tembakan untuk memperoleh skor lebih tinggi.

Game ini tidak berfokus pada cerita panjang, simulasi realistis, sistem crafting kompleks, atau strategi tingkat lanjut.

Pusat pengalaman bermainnya adalah:

- Gerakan karakter yang responsif.
- Kamera third-person yang nyaman.
- Tembakan dengan feedback visual dan audio yang kuat.
- Senjata yang benar-benar berbeda dalam cara penggunaannya.
- Musuh dengan perilaku yang mudah dipahami tetapi menantang.
- Sistem poin dan unlock yang memberikan tujuan jangka pendek.
- Sesi permainan yang mudah dimulai kembali.

1.2 Design Pillars

Pillar 1 — Easy to Play

Pemain baru harus bisa memahami cara bergerak, membidik, menembak, dan memperoleh poin tanpa tutorial panjang.

Pillar 2 — Every Weapon Feels Different

Senjata bukan sekadar variasi model 3D.

Setiap senjata memiliki identitas berdasarkan firing pattern, projectile behavior, damage profile, impact effect, audio, dan respons terhadap musuh.

Pillar 3 — Visual Satisfaction

Tembakan, ledakan, hit reaction, dan eliminasi musuh harus memberikan feedback yang jelas tanpa menghalangi pandangan pemain.

Pillar 4 — Constant Progression

Pemain selalu memiliki tujuan yang mudah dipahami: mendapatkan poin untuk membuka senjata berikutnya atau mengejar skor baru.

Pillar 5 — Mobile-First Performance

Gameplay harus dirancang untuk berjalan stabil pada perangkat Android dengan kemampuan grafis yang beragam.

Pillar 6 — Multiplayer-Aware Architecture

Single-player menjadi prioritas. Namun, kepemilikan state permainan, sistem senjata, damage resolution, dan input harus memiliki batas yang jelas agar tidak seluruhnya terikat pada asumsi single-player.

Multiplayer bukan bagian dari MVP dan tidak boleh menghambat penyelesaian game single-player.

---

2. TARGET AUDIENCE

2.1 Primary Audience

Anak-anak, remaja, dan pemain muda yang menyukai game aksi dengan kontrol sederhana, senjata menarik, dan progression yang mudah dipahami.

2.2 Secondary Audience

Pemain dewasa yang menyukai arcade shooter, sci-fi weapons, high-score challenges, dan permainan singkat.

2.3 Player Motivation

Game dirancang untuk memenuhi empat motivasi utama.

Combat satisfaction

Pemain menikmati respons senjata, efek tembakan, ledakan, dan reaksi musuh.

Collection

Pemain ingin membuka senjata yang belum dimiliki.

Mastery

Pemain ingin mengetahui senjata yang paling sesuai untuk menghadapi jenis musuh tertentu.

High-score chasing

Pemain ingin mengalahkan skor sebelumnya dan bertahan lebih lama.

Game tidak memerlukan sistem kompetitif yang kompleks untuk mendukung motivasi tersebut.

---

3. GAMEPLAY OVERVIEW

3.1 Core Gameplay Loop

CORE LOOP:

ENTER ARENA
↓
FIGHT ENEMY WAVES
↓
EARN BATTLE POINTS
↓
SURVIVE LONGER
↓
COMPLETE WAVE / GET ELIMINATED
↓
CLAIM REWARDS
↓
UNLOCK WEAPONS
↓
EQUIP AND TEST NEW WEAPON
↓
ENTER ARENA AGAIN

Loop harus cukup pendek agar pemain dapat memahami hasil permainannya tanpa harus menyelesaikan campaign panjang.

3.2 Session Structure

Satu sesi terdiri dari:

1. Pemain memilih senjata.
2. Pemain masuk arena.
3. Sistem memunculkan musuh secara bertahap.
4. Pemain mengalahkan musuh dan memperoleh poin.
5. Tingkat kesulitan meningkat berdasarkan progres wave.
6. Pemain menyelesaikan wave atau mengalami kekalahan.
7. Sistem menampilkan hasil permainan.
8. Poin diberikan dan progres disimpan.
9. Pemain dapat mencoba kembali.

Durasi sesi tidak perlu dikunci sejak awal. Target awal adalah sesi sekitar 3–8 menit, kemudian disesuaikan melalui pengujian.

3.3 Gameplay Modes

Mode 1 — Survival

Mode utama MVP.

Pemain bertahan dari gelombang musuh yang semakin sulit. Permainan berakhir ketika karakter dikalahkan.

Mode 2 — Target Challenge

Mode tambahan setelah survival solid.

Pemain harus mengalahkan sejumlah musuh atau menyelesaikan target dalam batas waktu.

Mode 3 — Boss Challenge

Mode tambahan untuk menghadapi musuh besar dengan pola serangan khusus.

Mode 2 dan Mode 3 tidak diperlukan untuk membuktikan MVP.

---

4. PLAYER CHARACTER

4.1 Character Concept

Karakter futuristik bergaya stylized-realistic.

Karakter harus memiliki siluet yang mudah dikenali, proporsi yang konsisten, dan animasi yang dapat digunakan bersama berbagai senjata.

Desain awal:

- Armor futuristik modular.
- Helmet atau headgear yang mudah dikenali.
- Senjata yang terlihat jelas saat digunakan.
- Material metal, polymer, dan energy components.
- Animasi lari, berhenti, berputar, menembak, terkena serangan, dan mati.

Hindari detail model yang terlalu kecil karena target utama adalah layar ponsel.

4.2 Player States

State awal:

- IDLE
- MOVING
- FIRING
- RELOADING, jika senjata menggunakan amunisi
- HIT_REACTION
- DASHING, jika fitur dash digunakan
- DEAD

State tersebut tidak harus menjadi satu state machine besar.

Movement, weapon firing, dan health sebaiknya menjadi komponen terpisah sehingga satu aksi tidak mengganggu sistem lainnya.

4.3 Movement

Sistem gerakan menggunakan:

- Pergerakan relatif terhadap arah kamera.
- Akselerasi dan deselerasi.
- Rotasi karakter menuju arah gerak atau arah bidik sesuai control mode.
- Gravity dan collision.
- Optional dash setelah gerakan dasar stabil.

Target awal adalah respons yang cepat dan mudah diprediksi, bukan simulasi berat badan realistis.

---

5. CAMERA SYSTEM

5.1 Camera Perspective

Third-person over-the-shoulder.

Kamera berada di belakang dan sedikit di atas karakter. Posisi horizontal dapat bergeser ke salah satu sisi untuk memberi ruang pandang ke arah bidikan.

5.2 Camera Components

Godot scene menggunakan:

- CameraRig
- YawPivot
- PitchPivot
- SpringArm3D
- Camera3D

Struktur konseptual:

CameraRig
└── YawPivot
└── PitchPivot
└── SpringArm3D
└── Camera3D

SpringArm3D membantu mencegah kamera menembus dinding.

5.3 Camera Behavior

Kamera harus memiliki:

- Mouse/touch look.
- Batas vertikal pitch.
- Smooth follow.
- Collision avoidance.
- Optional recoil response.
- Optional camera shake untuk impact besar.

Camera shake hanya digunakan pada event tertentu. Getaran berlebihan akan mengurangi kenyamanan, terutama pada perangkat mobile.

5.4 Aiming Model

Gunakan hybrid aiming.

1. Pemain menggerakkan crosshair menggunakan area kanan layar.
2. Kamera menentukan arah pandang.
3. Raycast dari kamera menentukan titik sasaran.
4. Senjata menembak dari muzzle menuju titik sasaran.
5. Jika garis tembak terhalang, peluru mengenai objek penghalang.

Pemisahan camera ray dan muzzle direction penting agar proyektil tidak menembus dinding hanya karena kamera melihat target di balik penghalang.

---

6. WEAPON SYSTEM

Weapon system adalah salah satu subsistem paling penting dalam Exocomplict.

6.1 Weapon Design Principles

Setiap senjata harus memiliki identitas yang jelas dalam lima aspek:

1. Firing pattern.
2. Projectile behavior.
3. Damage profile.
4. Impact feedback.
5. Audio signature.

Senjata tidak boleh hanya berbeda warna.

6.2 Initial Weapon Roster

Weapon 01 — Pulse Rifle

Role: Starter weapon.

- Tembakan proyektil tunggal beruntun.
- Damage sedang.
- Akurasi relatif tinggi.
- Fire rate stabil.
- Efek muzzle flash singkat.
- Projectile trail tipis.
- Impact berupa percikan energi.

Tujuan: Memberikan pengalaman dasar yang mudah dipahami.

Weapon 02 — Scatter Blaster

Role: Close-range weapon.

- Menembakkan beberapa pellet dalam satu tembakan.
- Sebaran meningkat berdasarkan jarak.
- Damage terkonsentrasi pada jarak dekat.
- Impact berupa beberapa percikan dan ledakan kecil.

Tujuan: Mengajarkan pemain memilih jarak tembak.

Weapon 03 — Arc Shooter

Role: Energy-chain weapon.

- Mengirimkan proyektil atau sambaran energi ke target.
- Dapat melompat ke target tambahan jika mekanik chain diaktifkan.
- Damage terbagi berdasarkan jumlah target.
- Efek berupa busur listrik yang bercabang.

Implementasi awal sebaiknya menggunakan chain terbatas, bukan simulasi listrik fisik.

Weapon 04 — Nova Launcher

Role: Area damage.

- Meluncurkan proyektil eksplosif.
- Proyektil bergerak menuju target.
- Ledakan memiliki radius damage.
- Musuh terdorong jika knockback diaktifkan.
- Ledakan menghasilkan ring effect dan debris ringan.

Tujuan: Memberikan feedback kuat ketika menghadapi kelompok musuh.

Weapon 05 — Rail Cannon

Role: Precision penetration.

- Menembakkan proyektil sangat cepat atau ray-based shot.
- Menembus sejumlah musuh sesuai konfigurasi.
- Menghasilkan jejak energi lurus.
- Impact memiliki flash singkat dan efek penetrasi.

Untuk implementasi awal, hitscan dengan penetration tracking dapat digunakan. Simulasi proyektil fisik tidak diperlukan jika tidak meningkatkan pengalaman bermain.

Weapon 06 — Gravity Gun

Role: Crowd control.

- Mengirimkan energi gravitasi ke titik sasaran.
- Musuh dalam radius mengalami tarikan.
- Efek tarikan berlangsung singkat.
- Dapat diikuti ledakan atau serangan lanjutan.

Ini merupakan senjata dengan kebutuhan teknis lebih tinggi. Masukkan setelah senjata dasar dan sistem crowd control stabil.

6.3 Weapon Data Architecture

Statistik senjata tidak boleh ditulis ulang pada setiap script.

Gunakan Resource berbasis data.

Contoh konsep:

WeaponDefinition

- weapon_id
- display_name
- weapon_type
- base_damage
- fire_rate
- projectile_speed
- projectile_count
- spread_angle
- range
- explosion_radius
- penetration_count
- impact_effect_id
- muzzle_effect_id
- audio_profile_id
- unlock_cost

Tidak semua field berlaku untuk setiap senjata. WeaponType menentukan parameter mana yang digunakan.

Implementasi Godot dapat menggunakan custom Resource dengan file ".tres".

Contoh struktur file:

res://data/weapons/pulse_rifle.tres
res://data/weapons/scatter_blaster.tres
res://data/weapons/arc_shooter.tres
res://data/weapons/nova_launcher.tres
res://data/weapons/rail_cannon.tres
res://data/weapons/gravity_gun.tres

6.4 Weapon Firing Pipeline

Input
→ Validate Fire State
→ Apply Fire Rate
→ Resolve Aim Target
→ Spawn Projectile / Execute Hitscan
→ Detect Hit
→ Apply Damage
→ Trigger Impact Effect
→ Trigger Audio
→ Update Combat Feedback

Semua senjata menggunakan pipeline umum, tetapi dapat memiliki strategi projectile dan impact yang berbeda.

6.5 Weapon Balance

Senjata tidak perlu memiliki damage yang semakin besar secara linear berdasarkan harga.

Perbedaan harus berasal dari trade-off.

Contoh:

- Pulse Rifle: konsisten.
- Scatter Blaster: kuat dari dekat, lemah dari jauh.
- Arc Shooter: efektif terhadap kelompok kecil.
- Nova Launcher: area damage, fire rate rendah.
- Rail Cannon: penetrasi, tetapi menuntut bidikan yang tepat.
- Gravity Gun: crowd control, damage langsung relatif rendah.

Dengan cara ini, senjata lama tetap berguna setelah pemain membuka senjata baru.

---

7. PROJECTILE AND DAMAGE SYSTEM

7.1 Projectile Types

Buat tiga jalur utama.

Type A — Hitscan

Untuk tembakan yang harus terasa instan.

Implementasi menggunakan ray query atau raycast.

Contoh:

- Rail Cannon.
- Senjata presisi tertentu.

Type B — Physical Projectile

Untuk proyektil yang bergerak di dunia permainan.

Contoh:

- Pulse Rifle.
- Nova Launcher.

Proyektil menggunakan kecepatan, arah, lifetime, dan collision.

Type C — Area / Chain Effect

Untuk efek yang memengaruhi banyak target.

Contoh:

- Explosion.
- Arc chain.
- Gravity field.

Tidak semua efek membutuhkan node projectile tersendiri. Efek tertentu dapat direpresentasikan sebagai event combat dan visual effect.

7.2 Damage Interface

Gunakan kontrak umum, misalnya:

apply_damage(amount, source, damage_type)

Target yang menerima damage memiliki komponen Health.

Damage system bertanggung jawab terhadap:

- Validasi target.
- Pengurangan health.
- Hit reaction.
- Death event.
- Score reward.
- Combat feedback.

Jangan memberikan poin langsung dari setiap projectile.

Poin diberikan saat target benar-benar masuk ke state mati dan reward belum pernah diberikan.

Ini mencegah satu musuh menghasilkan reward berkali-kali ketika terkena ledakan atau chain attack.

7.3 Object Pooling

Projectile, impact effect, muzzle flash, dan sebagian enemy actor dapat dibuat melalui object pool jika profiling menunjukkan kebutuhan.

Object pooling mengurangi instantiate/free berulang pada sistem yang menghasilkan banyak objek.

Namun, pooling menambah kompleksitas lifecycle. Jangan mengimplementasikan pooling secara membabi buta pada setiap node.

Mulai dari implementasi sederhana, ukur performa, lalu pool objek yang benar-benar menjadi bottleneck.

---

8. ENEMY SYSTEM

8.1 Initial Enemy Types

Enemy A — Runner

- Bergerak mendekati pemain.
- Menyerang dari jarak dekat.
- Health rendah.
- Jumlah relatif banyak.

Enemy B — Shooter

- Menjaga jarak dari pemain.
- Menembakkan proyektil.
- Berusaha mencari posisi serang.
- Health sedang.

Enemy C — Tank

- Gerakan lambat.
- Health tinggi.
- Serangan kuat dengan telegraph yang jelas.
- Memberikan reward lebih tinggi.

Enemy D — Elite

- Varian musuh dengan kombinasi statistik dan perilaku khusus.
- Muncul setelah pemain mencapai wave tertentu.

Untuk MVP, implementasikan Runner dan Shooter terlebih dahulu. Tank dan Elite menyusul setelah combat loop stabil.

8.2 Enemy AI Architecture

Setiap enemy memiliki komponen:

- HealthComponent
- MovementController
- TargetingComponent
- AttackController
- RewardComponent
- EnemyStateController

State awal:

- SPAWNING
- APPROACHING
- ATTACKING
- RECOVERING
- STAGGERED
- DEAD

Implementasi dapat menggunakan finite state machine sederhana.

Tidak diperlukan behavior tree kompleks pada tahap pertama.

8.3 Enemy Navigation

Gunakan navigation mesh untuk navigasi musuh yang membutuhkan pencarian jalur.

Untuk arena sederhana, hindari menjalankan pencarian jalur baru pada setiap frame.

Gunakan pembaruan target atau path secara berkala dan atur jumlah musuh aktif sesuai kemampuan perangkat.

Musuh yang jauh dapat menggunakan pembaruan AI yang lebih jarang jika hasilnya tetap dapat diterima.

---

9. WAVE DIRECTOR

Wave Director mengatur alur kemunculan musuh.

Tanggung jawab:

- Memulai wave.
- Menentukan komposisi musuh.
- Memilih spawn point yang valid.
- Membatasi jumlah musuh aktif.
- Mengatur jeda antargelombang.
- Menghitung progres wave.
- Mengaktifkan kondisi akhir permainan.

9.1 Difficulty Progression

Kesulitan dapat meningkat melalui:

- Jumlah musuh.
- Komposisi musuh.
- Health musuh.
- Attack rate.
- Kecepatan musuh.
- Kemunculan Elite.

Jangan menaikkan semua variabel sekaligus.

Contoh formula awal untuk pengujian:

enemy_count = base_count + wave_index × count_increment

enemy_health = base_health × (1 + wave_index × health_increment)

Nilai increment harus ditentukan melalui playtest, bukan diperlakukan sebagai angka final.

9.2 Spawn Rules

Spawn point harus:

- Berada di area permainan yang valid.
- Tidak terlalu dekat dengan pemain.
- Tidak berada di dalam obstacle.
- Tidak menyebabkan musuh muncul di depan kamera secara tidak wajar.
- Tidak melebihi batas musuh aktif.

Sistem juga harus menangani keadaan ketika tidak ada spawn point yang valid.

---

10. POINT AND PROGRESSION SYSTEM

10.1 Battle Points

Battle Points diperoleh melalui permainan.

Contoh reward awal:

Event| Reward awal
Runner defeated| 10
Shooter defeated| 15
Tank defeated| 35
Elite defeated| 50
Wave completed| 100

Angka ini adalah konfigurasi awal untuk pengujian.

10.2 Score vs Currency

Pisahkan dua konsep berikut.

Run Score

Skor untuk mengukur performa pemain dalam satu sesi. Dapat mencakup eliminasi, wave yang diselesaikan, dan bonus tertentu.

Battle Points

Mata uang untuk membuka senjata.

Pemisahan ini memungkinkan pemain membandingkan hasil permainan tanpa membuat sistem unlock bergantung sepenuhnya pada satu jenis skor.

Pada MVP, keduanya dapat menggunakan sumber reward yang sama, tetapi disimpan sebagai nilai terpisah.

10.3 Unlock System

Setiap senjata memiliki:

- Unlock cost.
- Unlock status.
- Equipped status.

Aturan:

1. Senjata awal langsung tersedia.
2. Pemain hanya dapat membuka senjata yang belum dimiliki.
3. Battle Points dikurangi setelah transaksi valid.
4. Unlock status disimpan secara permanen.
5. Senjata yang sudah dibuka dapat dipilih tanpa biaya berulang.
6. Pembelian tidak dapat membuat saldo menjadi negatif.

10.4 Economy UI

Tampilkan informasi yang sederhana:

- Saldo Battle Points.
- Daftar senjata.
- Harga unlock.
- Status terkunci atau terbuka.
- Tombol unlock.
- Tombol equip.
- Preview pola tembakan.

Hindari inventaris yang membutuhkan banyak submenu.

---

11. GAME UI AND UX

11.1 Main Menu

Elemen utama:

- Play.
- Weapons.
- Settings.
- Exit atau tombol kembali sesuai platform.

Karakter dapat ditampilkan dalam 3D pada menu utama jika performa dan biaya produksinya memungkinkan.

11.2 In-Game HUD

HUD menampilkan:

- Health.
- Crosshair.
- Wave counter.
- Enemy counter.
- Run Score.
- Battle Points yang diperoleh.
- Tombol fire.
- Tombol weapon switch.
- Pause.

Informasi penting harus tetap terbaca di layar ponsel.

11.3 Results Screen

Setelah permainan berakhir, tampilkan:

- Wave reached.
- Enemies defeated.
- Run Score.
- Battle Points earned.
- Best score.
- Weapon yang digunakan.
- Retry.
- Weapons.

Tombol Retry harus mudah dijangkau.

11.4 Mobile Controls

Kontrol awal:

- Kiri: virtual joystick.
- Kanan: kamera dan aiming.
- Tombol tembak.
- Tombol pergantian senjata.
- Tombol pause.

Auto-fire dapat diuji sebagai opsi tambahan, tetapi tidak harus menjadi perilaku default. Pemain perlu tetap merasa memiliki kendali atas tembakannya.

---

12. VISUAL DIRECTION

12.1 Art Style

Stylized-realistic sci-fi.

Tujuannya bukan fotorealisme penuh, tetapi kualitas visual yang memiliki:

- Siluet karakter kuat.
- Material yang mudah dibedakan.
- Pencahayaan yang terkontrol.
- Senjata dengan bentuk yang mudah dikenali.
- Efek energi yang memiliki identitas warna dan bentuk.
- Arena yang mendukung keterbacaan gameplay.

12.2 Environment

Arena pertama harus relatif kecil dan mudah dibaca.

Komponen:

- Lantai arena.
- Struktur pembatas.
- Cover.
- Platform atau elevasi sederhana.
- Spawn points.
- Lighting.
- Background visual.
- Batas area permainan.

Hindari membuat open world sebelum core loop terbukti menyenangkan.

12.3 VFX Budget

Setiap efek harus memiliki fungsi.

Contoh:

Efek| Fungsi
Muzzle flash| Mengomunikasikan tembakan
Projectile trail| Menunjukkan lintasan
Impact flash| Mengonfirmasi hit
Enemy hit reaction| Menunjukkan damage
Explosion| Menunjukkan area serangan
Death effect| Mengonfirmasi eliminasi
Reward indicator| Mengonfirmasi poin

Efek visual tidak boleh menutupi karakter dan proyektil lain secara berlebihan.

Gunakan batas jumlah partikel, lifetime, transparansi, dan ukuran efek berdasarkan pengujian perangkat.

---

13. TECHNICAL STACK

13.1 Engine

Godot 4.x.

Versi minor yang digunakan harus dikunci pada awal produksi dan tidak diganti di tengah milestone tanpa alasan teknis yang jelas.

13.2 Language

GDScript.

Tidak diperlukan C# atau GDExtension untuk MVP.

13.3 Renderer

Untuk target Android, evaluasi Mobile renderer pada perangkat target.

Jika dibutuhkan dukungan perangkat yang lebih luas, Compatibility renderer dapat dipertimbangkan berdasarkan hasil pengujian.

Jangan menganggap satu renderer pasti paling cocok sebelum menguji build pada perangkat nyata.

13.4 Asset Pipeline

Blender → GLB → Godot.

Format GLB menjadi format pertukaran utama untuk model 3D yang sudah diekspor.

Simpan file sumber Blender terpisah agar aset dapat diedit ulang.

Struktur:

res://assets/characters/
res://assets/weapons/
res://assets/enemies/
res://assets/environment/
res://assets/vfx/
res://assets/audio/

GLB tidak menggantikan kebutuhan file sumber 3D yang dapat diedit.

13.5 Version Control

Git.

Setiap milestone harus menghasilkan commit yang dapat diuji.

Jangan melakukan refactor besar tanpa baseline yang diketahui berfungsi.

---

14. SOFTWARE ARCHITECTURE

14.1 Architectural Principles

1. Setiap komponen memiliki tanggung jawab jelas.
2. Data senjata dipisahkan dari kode firing.
3. Health dan damage tidak bergantung pada UI.
4. Reward diberikan melalui event eliminasi yang tervalidasi.
5. Wave Director tidak mengontrol detail animasi setiap musuh.
6. Save system tidak bergantung pada scene yang sedang aktif.
7. Input tidak dicampur langsung dengan logika combat.
8. Sistem tidak diperumit hanya untuk kemungkinan multiplayer yang belum dibuktikan.

14.2 Proposed Project Structure

res://

- project.godot
- scenes/
  - main/
    - main_menu.tscn
    - game.tscn
  - player/
    - player.tscn
  - camera/
    - camera_rig.tscn
  - weapons/
    - weapon_base.tscn
    - projectile.tscn
  - enemies/
    - runner.tscn
    - shooter.tscn
  - arena/
    - arena_01.tscn
  - ui/
    - hud.tscn
    - results_screen.tscn
    - weapon_menu.tscn
- scripts/
  - player/
  - camera/
  - combat/
  - weapons/
  - enemies/
  - waves/
  - progression/
  - save/
  - ui/
- data/
  - weapons/
  - enemies/
  - waves/
  - progression/
- assets/
  - characters/
  - weapons/
  - enemies/
  - environment/
  - vfx/
  - audio/
- tests/

Struktur ini merupakan target awal. Direktori baru ditambahkan ketika kebutuhan nyata muncul.

14.3 Core Components

PlayerController

Mengelola movement, rotasi, dan koordinasi aksi karakter.

WeaponController

Menentukan senjata yang sedang digunakan dan meneruskan permintaan firing.

WeaponDefinition

Menyimpan konfigurasi senjata.

ProjectileController

Mengelola gerakan proyektil, collision, lifetime, dan hit event.

HealthComponent

Mengelola health, damage, dan death state.

CombatResolver

Memvalidasi hit dan menghubungkan damage dengan hasil combat.

WaveDirector

Mengatur kemunculan musuh dan progres wave.

RewardService

Menghitung reward berdasarkan event permainan yang valid.

ProgressionService

Mengatur saldo, unlock, dan equip senjata.

SaveService

Menyimpan progres pemain.

UI Controllers

Membaca state permainan dan mengirimkan perintah pemain melalui interface yang jelas.

---

15. SINGLE-PLAYER STATE AUTHORITY

Bagian ini penting karena multiplayer direncanakan sebagai kemungkinan pengembangan berikutnya.

Untuk MVP:

- Gameplay berjalan secara lokal.
- Player Controller menerima input pemain.
- CombatResolver menjadi titik keputusan damage.
- HealthComponent menjadi pemilik health target.
- RewardService menentukan reward.
- ProgressionService menentukan validitas unlock.
- SaveService menyimpan progres permanen.

Jangan biarkan setiap senjata langsung mengubah saldo atau menyimpan progresnya sendiri.

Gunakan alur:

Weapon
→ CombatResolver
→ HealthComponent
→ Death Event
→ RewardService
→ ProgressionService
→ SaveService

Alur ini membuat kepemilikan state lebih mudah dipahami.

Namun, alur tersebut belum otomatis membuat game siap multiplayer.

Untuk multiplayer, kita masih perlu menentukan server authority, validasi input, replikasi state, sinkronisasi projectile, dan penanganan latency.

---

16. SAVE SYSTEM

Progres yang perlu disimpan:

- Total Battle Points.
- Senjata yang sudah dibuka.
- Senjata yang sedang digunakan.
- Best score.
- Statistik dasar pemain.
- Pengaturan kontrol dan audio.

Untuk single-player MVP, penyimpanan lokal sudah cukup.

Gunakan format data terstruktur dan validasi data ketika dimuat.

Jangan menganggap file save lokal aman dari modifikasi. Jika nantinya multiplayer kompetitif menggunakan progression yang penting, data tersebut perlu ditinjau ulang dari perspektif keamanan.

---

17. MULTIPLAYER PREPARATION

Multiplayer baru dipertimbangkan setelah single-player memenuhi kriteria kualitas.

Tujuannya bukan membuat semua komponen abstrak sejak awal, tetapi menghindari coupling yang akan menyulitkan pengembangan berikutnya.

17.1 Preparation Required Now

- Pisahkan input dari combat logic.
- Pisahkan weapon data dari firing implementation.
- Pisahkan damage resolution dari UI.
- Pisahkan reward dari visual effects.
- Gunakan identifier yang stabil untuk jenis senjata dan musuh.
- Hindari mengandalkan node path UI sebagai sumber state gameplay.
- Pastikan setiap event eliminasi hanya diproses satu kali.

17.2 Work Deferred

Jangan implementasikan sekarang:

- Multiplayer networking.
- Dedicated server.
- Matchmaking.
- Lobby.
- Account authentication.
- Network prediction.
- Lag compensation.
- Anti-cheat server.
- Online leaderboard.

Semua itu membutuhkan keputusan produk dan pengujian tersendiri.

17.3 Multiplayer Feasibility Gate

Setelah single-player solid, lakukan evaluasi:

1. Apakah pemain menginginkan multiplayer?
2. Apakah model permainan cocok untuk cooperative atau competitive?
3. Apakah senjata seimbang untuk pertarungan antarpemain?
4. Apakah engine dan target perangkat memenuhi kebutuhan jaringan?
5. Apakah ada anggaran untuk server dan maintenance?
6. Apakah multiplayer meningkatkan retensi secara berarti?

Baru setelah itu pilih arsitektur dan scope multiplayer.

---

18. PERFORMANCE ENGINEERING

Target performa awal: gameplay stabil pada perangkat Android kelas bawah hingga menengah yang dipilih sebagai perangkat pengujian.

Angka FPS final harus ditetapkan setelah perangkat target dan renderer dipilih.

18.1 Main Performance Risks

- Terlalu banyak projectile aktif.
- Partikel transparan berlebihan.
- Banyak musuh melakukan pathfinding bersamaan.
- Model 3D terlalu berat.
- Material dan shader terlalu kompleks.
- Instantiate/free objek dalam jumlah besar.
- Shadow casting berlebihan.
- UI dan efek yang terlalu padat.

18.2 Optimization Strategy

1. Profiling baseline.
2. Batasi jumlah musuh aktif.
3. Atur projectile lifetime.
4. Optimalkan mesh dan material.
5. Kurangi jumlah sumber cahaya yang menghasilkan bayangan.
6. Gunakan object pooling jika terbukti diperlukan.
7. Kurangi frekuensi pembaruan AI untuk musuh yang jauh.
8. Uji performa pada build Android, bukan hanya editor.

Optimasi harus berdasarkan hasil profiling.

---

19. TESTING AND QUALITY GATES

Setiap milestone memiliki acceptance criteria.

Gate A — Movement

- Karakter bergerak sesuai input.
- Kamera tidak berputar secara tidak sengaja.
- Collision berfungsi.
- Karakter tidak menembus lantai.

Gate B — Combat

- Senjata dapat menembak.
- Hit detection konsisten.
- Damage diterapkan satu kali sesuai aturan.
- Musuh dapat mati.
- Reward eliminasi tidak terduplikasi.

Gate C — Wave Loop

- Musuh muncul pada spawn point valid.
- Wave bertambah dengan benar.
- Tidak ada wave yang macet tanpa alasan.
- Kondisi game over berfungsi.

Gate D — Progression

- Battle Points bertambah sesuai reward.
- Unlock memotong saldo secara benar.
- Senjata terbuka tetap terbuka setelah game dimulai ulang.
- Saldo tidak dapat menjadi negatif melalui transaksi valid.

Gate E — Android

- Kontrol sentuh berfungsi.
- UI tidak terpotong pada rasio layar target.
- Game dapat dijeda dan dilanjutkan.
- Save/load berfungsi.
- Performa diuji pada perangkat nyata.

Gate F — Release Candidate

- Tidak ada blocker yang diketahui.
- Tidak ada kehilangan progres yang diketahui pada skenario uji.
- Tidak ada error kritis berulang.
- Seluruh core loop dapat diselesaikan dan diulang.
- Performa sesuai target perangkat yang telah ditetapkan.

---

20. DEVELOPMENT ROADMAP

Phase 0 — Technical Validation

Tujuan: memastikan fondasi engine, renderer, dan asset pipeline sesuai target.

Deliverables:

- Project Godot.
- Android export.
- Satu arena greybox.
- Satu karakter placeholder.
- Kamera third-person.
- Tes kontrol sentuh.

Exit criteria: build dapat dimainkan di perangkat Android yang ditentukan.

Phase 1 — Combat Prototype

Tujuan: membuktikan bahwa menembak terasa menyenangkan.

Deliverables:

- Player movement.
- Camera aiming.
- Pulse Rifle.
- Satu jenis musuh.
- Health dan damage.
- Projectile atau hitscan.
- Muzzle flash dan impact effect.
- Hit reaction.

Exit criteria: pemain dapat bergerak, menembak, mengalahkan musuh, dan mengulangi pertarungan tanpa blocker.

Phase 2 — Core Gameplay Loop

Tujuan: membentuk game yang dapat dimainkan berulang kali.

Deliverables:

- Wave Director.
- Spawn system.
- Enemy scaling.
- Score.
- Battle Points.
- Game over.
- Results screen.
- Retry.

Exit criteria: satu sesi permainan berjalan dari awal hingga akhir dan dapat diulang.

Phase 3 — Weapon Expansion

Tujuan: membuktikan variasi senjata.

Deliverables:

- WeaponDefinition.
- Scatter Blaster.
- Arc Shooter.
- Nova Launcher.
- Weapon selection.
- Weapon unlock.
- Save system.

Rail Cannon dan Gravity Gun dapat ditambahkan setelah empat senjata awal terbukti stabil.

Exit criteria: senjata memiliki perbedaan mekanik yang nyata dan tidak merusak combat loop.

Phase 4 — Art and Audio Pass

Tujuan: mengganti prototype dengan presentasi visual yang layak diuji kepada pemain.

Deliverables:

- Karakter final awal.
- Model senjata.
- Musuh dengan visual final awal.
- Arena dengan art direction konsisten.
- Audio senjata.
- Impact VFX.
- UI final awal.

Exit criteria: visual, audio, dan gameplay tetap terbaca ketika banyak musuh dan efek tampil bersamaan.

Phase 5 — Progression and Polish

Deliverables:

- Ekonomi poin yang diseimbangkan.
- Weapon unlock yang lengkap.
- Best score.
- Pengaturan audio dan kontrol.
- Feedback UI.
- Save/load validation.
- Perbaikan bug.

Exit criteria: pemain dapat menyelesaikan loop progression dan memiliki alasan untuk bermain kembali.

Phase 6 — Closed Playtest

Uji kepada kelompok pemain yang mewakili target audiens.

Amati:

- Waktu sampai pemain memahami kontrol.
- Senjata yang paling sering digunakan.
- Frekuensi pemain mengulang permainan.
- Titik ketika pemain berhenti bermain.
- Performa perangkat.
- Bug dan kesulitan yang tidak disengaja.

Exit criteria: masalah terbesar telah diketahui dan ada bukti bahwa pemain menikmati core loop.

Phase 7 — Single-Player Release Candidate

Fokus pada:

- Stabilitas.
- Performa.
- Balancing.
- UX.
- Save reliability.
- Packaging Android.

Tidak ada penambahan fitur besar sebelum blocker selesai.

Phase 8 — Multiplayer Feasibility

Baru dimulai setelah single-player stabil dan hasil playtest mendukung pengembangan lanjutan.

Deliverables awal:

- Multiplayer design document.
- Pilihan cooperative atau competitive.
- Network authority design.
- Prototype networking terpisah.
- Estimasi biaya server.
- Pengujian latency dan jumlah pemain.

---

21. MVP DEFINITION

MVP bukan versi kecil dari semua fitur yang diinginkan.

MVP adalah versi terkecil yang cukup untuk membuktikan bahwa game ini menarik untuk dimainkan berulang kali.

Isi MVP:

- Satu karakter.
- Satu kamera third-person.
- Satu arena.
- Dua jenis musuh.
- Tiga senjata yang berbeda.
- Wave-based survival.
- Battle Points.
- Weapon unlock.
- HUD.
- Results screen.
- Retry.
- Local save.
- Android build.

Tidak termasuk:

- Multiplayer.
- Open world.
- Campaign panjang.
- Story cinematics.
- Crafting.
- Skill tree.
- Clans.
- Online leaderboard.
- Monetization kompleks.
- Puluhan karakter.
- Puluhan arena.

---

22. PRODUCT SUCCESS CRITERIA

Keberhasilan MVP tidak ditentukan oleh jumlah fitur atau jumlah baris kode.

Ukuran awal:

Combat satisfaction
Pemain merasa setiap senjata memberikan pengalaman berbeda.

Replay behavior
Pemain memilih bermain lagi tanpa harus diminta.

Progression motivation
Pemain memahami senjata apa yang ingin dibuka dan alasannya.

Weapon experimentation
Pemain mencoba senjata lain setelah membukanya.

Technical stability
Core loop dapat dijalankan berulang kali tanpa blocker.

Device performance
Build memenuhi target performa yang ditetapkan pada perangkat pengujian.

Nilai ambang untuk setiap indikator harus ditentukan setelah playtest awal, bukan dibuat seolah-olah sudah memiliki data pasar.

---

23. FINAL PRODUCT DEFINITION

Exocomplict adalah single-player, mobile-first third-person arena shooter dengan kamera over-the-shoulder, senjata futuristik dengan mekanik dan efek tembakan berbeda, survival berbasis wave, serta progression berbasis Battle Points.

Identitas utamanya bukan cerita yang panjang atau kompleksitas strategi.

Identitasnya adalah:

MOVE. SHOOT. SURVIVE. UNLOCK. REPEAT.

Prioritas produksi adalah membuktikan movement, aiming, weapon feel, hit feedback, dan replay loop sebelum memperluas konten.

Multiplayer tetap menjadi kemungkinan pengembangan berikutnya, bukan ketergantungan bagi penyelesaian versi pertama.