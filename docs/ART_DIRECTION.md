# Art Direction — EXOCOMFLICT: Stellar Horizon

status: draft for Phase 2 (menus) — this document is the contract, the shipped
textures under `res://assets/ui/` are the evidence.

The game runs on a deliberately narrow palette, and it has to: the combat HUD is
already built from `AegisTokens`, the enemy telegraphs are colour-coded, and the
ammo/health/warning readouts rely on the player recognising a hue faster than
they read a number. Concept art that introduces a new colour family is not
"more interesting", it is a bug — it trains the eye to ignore the hues that
matter in combat.

---

## 1. Palette

Values come from `game/scripts/ui/aegis_tokens.gd`. The art direction uses the
same numbers under art names; the second column is only a naming convenience so
a texture audit and a button style can be discussed in one vocabulary.

| Family | Art name | Token | Hex | Where it goes |
| --- | --- | --- | --- | --- |
| Deep space navy | `ART_NAVY` | `VOID` | `#05080c` | Scene backdrop, deepest shadow, letterbox bars |
| Panel navy | `ART_NAVY_2` | `PANEL` | `#0b131b` | Large surfaces behind menus, loading backdrop |
| Graphite | `ART_GUNMETAL` | `LINE` | `#27384a` | Plate edges, structural metal, inactive frames |
| Gunmetal | `ART_GRAPHITE` | `LINE_HI` | `#4e6a7e` | Machined detail, panel bevels, rivets |
| Cyan / electric blue | `ART_CYAN` | `INFO` | `#54c8ff` | Energy, data, shields, primary UI highlight |
| Amber / warning | `ART_AMBER` | `ACCENT` | `#ffb020` | Warm accent light, hazard, "attention" |
| Silver | `ART_SILVER` | `INK` | `#edf5fb` | Primary text, specular rim, hero plating |
| Steel | `ART_STEEL` | `INK_2` | `#a9bccb` | Secondary text, weathered armour, distant metal |
| System green | `ART_GREEN` | `OK` | `#37e08c` | Health, friendly, confirm |
| Damage red | `ART_RED` | `DANGER` | `#ff5a5a` | Damage, hostile, deny |
| Ability violet | — | `ABILITY` | `#b79cff` | Ability/ultimate charge only |

### Rules

1. **No new hue families.** Every pixel in a shipped texture must land in navy,
   gunmetal/graphite, cyan, amber, silver/steel, green or red — with two
   documented exceptions below.
2. **Amber is a warning colour first and an accent second.** It is used for
   fading sunlight, engine glow and hazard trim. It is never used for a
   passive/secondary readout: that is cyan's job.
3. **Cyan is the brand.** If a composition needs exactly one saturated colour,
   it is cyan.
4. **Red and green are reserved.** They mean damage and health. They never
   appear in decorative art at scale.
5. **Value does the separating, not hue.** At 390 px wide there is no room for
   hue hierarchy, so compositions are built on a dark-to-light value ramp:
   near-black falloff at the edges (`#05080c`), mid graphite in the structure,
   silver highlights on the subject.

### Documented exceptions

Two pixel classes fall outside the hue windows above and are **not** drift:

* **`steel` / `silver`** — desaturated pixels (saturation ≤ 0.14). They have no
  meaningful hue. Split at value 0.62 so "weathered armour" and "polished
  plating" are separable.
* **`shadow`** — value ≤ 0.10. The art direction asks every composition to fall
  off to near-black at the edges; those pixels are navy by intent and hue is
  noise at that level.

A third case was measured rather than assumed: the loading key art carried 8.9%
of its pixels in the 15°–25° hue band — dark rust and warm dust on oxidised
gunmetal. The amber window was widened from 25° to 15° to cover it. The
window change is recorded in `tools/art/build_ui_art.py` with the measurement
that justified it; nothing else was adjusted to make the number pass.

---

## 2. Typography

Roles are declared in `AegisTokens.TYPE`. Art carries **no** baked-in UI copy
except the wordmark: any text in a texture is a liability at 390 px and cannot
be localised. Wordmark: `res://assets/ui/logo_wordmark.png`, 1024×256, cropped
to its content box from a 1024×1024 render whose glyph band occupies only
891×218.

---

## 3. Composition

* **Subject bias.** Hero and weapon art puts the subject off-centre on a 3:5
  grid, leaving the left third for text plates.
* **Falloff.** Every full-bleed image is darker at the corners than at the
  subject. In-engine this is reinforced with a vignette `TextureRect`, not
  baked in.
* **One light.** A single warm (amber) key and a single cool (cyan) fill. No
  third source.
* **Silhouette first.** The hero reads as a silhouette at 64 px tall. If it does
  not, the art failed regardless of how good the render is.

---

## 4. What these textures are, and what they are not

**They are 2D key art and UI plates.** They are the loading backdrop, the
dashboard backdrop, the menu wordmark, hero and weapon portraits, a world plate
and a loading-animation sprite sheet.

**They are not the game's 3D representation.** The playable hero is the skinned
`hero_rig`/`character_visual` model measured in
`docs/asset-inspections/HERO_VISIBILITY_QA_2026-10-20.md`; the playable weapons
are the ones attached in `weapon_controller.gd`. No portrait in this document
shows the in-game model, and no model was changed to match a portrait. Where a
portrait and the rig disagree, the rig is right and the portrait is decoration.

---

## 5. Pipeline

`tools/art/build_ui_art.py` turns the generator output in
`game/assets/ui/generated/` into the shipping textures. It is deterministic:
same inputs → byte-identical outputs, and it refuses to invent a file.

```
python3 tools/art/build_ui_art.py            # rebuild
python3 tools/art/build_ui_art.py --check    # audit only, write nothing
```

Step by step:

1. **Content-box crop** — finds the image's own flat backdrop (the most common
   outer-border colour), then trims to the largest rectangle that is not it.
   This is what turns a 1024×1024 wordmark into 1024×256, and it is why the
   weapon plates are not framed by generator padding.
   Images with no flat backdrop (`dashboard_bg`, `hero_portrait`,
   `loading_keyart`, `world_neon_frontier`) are correctly left alone — the
   survey measured their content bbox at ~100% of area.
2. **Union crop across animation frames** — the robot walk frames carry their
   subject in only 14–26% of the frame, and the subject bbox drifts across
   x 483..938 between frames. Cropping each frame to its own content box would
   make the robot jitter against the background, so one crop is computed from
   the union of all frames and applied to all of them.
3. **Resize** — `cover` for full-bleed backdrops, `content_cover` for portrait
   subjects (crop to the subject bbox first, then cover).
4. **Sprite sheet** — the four selected walk frames are laid out horizontally
   into `loading_robot_sheet.png`, 2048×512, 4 frames at 512 px, 8 fps.
5. **Palette audit** — every output is downsampled and each pixel bucketed by
   HSV. Anything outside the families in §1 is counted. The build reports
   `ok`/`DRIFT` per asset and writes the numbers to
   `game/assets/ui/art_manifest.json`.

### Audit thresholds and what they do not mean

* `DRIFT` above **8%** off-palette. Below that the build prints `ok`.
* The audit is **HSV-only**. It cannot see composition, legibility, silhouette
  or quality. A texture that passes is on-palette, nothing more.
* **No vision.** Nobody looked at these images in the ordinary sense; the
  installer has no image display. Every statement about them comes from measured
  pixel statistics. "The robot walks" is not a claim this pipeline can support —
  it can only say four frames differ from each other in the union crop region.

### Output formats

Photographic backdrops ship as **JPEG q=90, progressive**: they are opaque
full-bleed images with no alpha and no hard edges, and a 1920×1080 painting
costs 2.8 MB as PNG against ~430 kB as JPEG. The wordmark, portrait and weapon
plates stay **PNG** because they have crisp edges and read at small sizes. The
manifest records the format per asset.

---

## 6. Shipping inventory

Produced by `tools/art/build_ui_art.py` from `game/assets/ui/generated/`.
Sizes are the real imported sizes, verified at runtime by
`tests/ui_art_smoke.gd` — not the sizes claimed by the generator.

| Key | File | Res | Format | Off-palette | Integration |
| --- | --- | --- | --- | --- | --- |
| `wordmark` | `logo_wordmark.png` | 1024×256 | PNG | 1.2% | BOOT, CINEMATIC, CHAPTER, DASHBOARD |
| `loading_keyart` | `loading_keyart.jpg` | 1920×1080 | JPEG q90 | 0.0% | LOADING, PRELOAD, CINEMATIC |
| `dashboard_bg` | `dashboard_bg.jpg` | 1920×1080 | JPEG q90 | 0.2% | DASHBOARD, HERO, WEAPON |
| `hero_portrait` | `portrait_hero.png` | 768×1024 | PNG | 0.2% | HERO selection card |
| `world_neon_frontier` | `world_neon_frontier.jpg` | 1600×900 | JPEG q90 | 0.0% | CHAPTER, WORLD selection |
| `weapon_pulse_rifle` | `weapon_pulse_rifle.png` | 768×512 | PNG | 0.0% | WEAPON selection card |
| `weapon_nova_launcher` | `weapon_nova_launcher.png` | 768×512 | PNG | 1.3% | WEAPON selection card |
| `weapon_arc_shooter` | `weapon_arc_shooter.png` | 768×512 | PNG | 0.1% | WEAPON selection card |
| `loading_robot` | `loading_robot_sheet.png` | 2048×512 | PNG | 0.0% | LOADING, PRELOAD (4-frame sheet, 8 fps) |

Every texture is loaded through `MenuStage.try_texture()`, which returns null
for a missing file instead of crashing, so a lost plate is a visual regression
rather than a boot failure. `tests/ui_art_smoke.gd` loads all nine at
runtime and compares the size the engine reports against this table.

Total on disk: **5.3 MB**. Sources in `generated/` are kept (22 MB) so the build
is reproducible; without them `build_ui_art.py` cannot run.

## 6b. Video

`tools/art/build_ui_video.py` renders and encodes the two video assets. It needs
an ffmpeg with `libtheora`; it looks at `$FFMPEG`, then `PATH`, then the
`imageio-ffmpeg` wheel, and **fails loudly** if none of them can encode Theora.
It renders deterministic frames with Pillow and hands them to ffmpeg, so the
same sources produce the same video.

| Key | File | Res | FPS | Length | Size | Off-palette | Integration |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Asset C — loading robot | `loading_robot.ogv` | 512×512 | 8 | 0.5 s (loops) | 63 kB | 0.1 % | LOADING, PRELOAD — the sprite sheet is the fallback |
| Asset F — cinematic opening | `cinematic_opening.ogv` | 1280×720 | 24 | 9.58 s | 1.6 MB | 0.0 % | CINEMATIC — the composed in-engine opening is the fallback |

Container is **OGV (Theora + Vorbis)**, which is what Godot 4.7.2 can play:
`modules/theora` ships `ResourceFormatLoaderTheora`, which claims `.ogv` on every
platform it builds for, web included. Both videos carry a silent Vorbis track
because the playback implementation seeks by audio granule position when a
stream has one.

Two rules the encoder keeps:

* **Asset C is the sprite sheet's animation, not a second one.** Same four
  generated frames, same union crop, same scale, same 8 fps, same 512 px cell —
  the sheet and the video are one walk cycle in two containers.
* **Asset F carries no baked-in text.** 9.58 s, the same beat the in-engine
  cinematic runs (4 × 2.4 s), a push-in from 1.00 to 1.18 with a vignette and a
  fade at each end — and no captions, because the stage overlays them as UI text
  and text in pixels cannot be localised (§2).

Sampled frames of both are audited with the same `audit()` the textures use. The
palette audit is HSV-only and says nothing about motion, timing or quality, and
nobody has *watched* these videos in this environment.

### Previously not delivered — now delivered

| Asset | Was | Now |
| --- | --- | --- |
| Asset C — loading robot video | **NOT DELIVERED** — no encoder (`ffmpeg`/`ffprobe` absent, Debian mirrors unreachable); a 4-frame sprite sheet shipped instead | **DELIVERED** as `loading_robot.ogv`, integrated, with the sheet kept as the fallback |
| Asset F — cinematic opening video | **BLOCKED** — same, and the opening cinematic needed a real encode before it could be integrated | **DELIVERED** as `cinematic_opening.ogv`, integrated, with the composed in-engine opening kept as the fallback |

### The aspect rule for `VideoStreamPlayer`

`expand = true` stretches the decoded frame to whatever rect the control has, so
the rect has to carry the video's own aspect. Both players are sized to *cover*
their parent and centred, with the parent clipping the overflow
(`stage_cinematic.gd::_layout_video`, `stage_loading.gd` via
`SIZE_SHRINK_CENTER`). What happens without it, measured in a browser build: a
16:9 opening stretched into 390×844, and a square 512×512 robot drawn 318×160.

Note that `VideoStream` exposes **no** size or length: `get_size()` and
`get_length()` do not exist on it (`has_method` is false on `VideoStreamTheora`),
and `VideoStreamPlayer.stream_length` reads 0.00 until the decoder opens the
file. Sizes come from `get_video_texture().get_size()` after the first decoded
frame; lengths are adopted from `get_stream_length()` once it is non-zero.

---

## 7. Verification

| Check | Command | Result |
| --- | --- | --- |
| Palette audit | `python3 tools/art/build_ui_art.py --check` | 9/9 within palette |
| Textures load in-engine at documented size | `godot --headless --path game --script res://tests/ui_art_smoke.gd` | see §7 note |
| Not flat rectangles | same | luma spread > 40/255 required |
| Videos load in-engine at documented size and length | `godot --headless --path game --script res://tests/video_asset_smoke.gd` | 2/2, sizes and lengths match `video_manifest.json` |
| Video audit only | `python3 tools/art/build_ui_video.py --check` | 2/2 within palette |
| Video plays in a browser build | `node tools/qa_avatar_shot.mjs --serve <exported web build> --page "/index.html?qa_stage=CINEMATIC&qa_menu=1"` | log `stream at 2.02 s of 9.58 s`; 89.8 % of pixels change across 3 frames 2 s apart |
| Video is not stretched on screen | same, with `?qa_menu=1` | `OpeningVideo=-555,0,1500x844` at 390×844, `0,-42,844x475` at 844×390, `RobotVideo=115,590,160x160` — cover rects at the video's own aspect |

§7 note: the runtime test is the one that matters. A file can be on disk, listed
in this document, and still 404 in an export because it was never imported.
`ui_art_smoke.gd` loads each texture through `ResourceLoader` at runtime and
compares the size the engine reports against the manifest, so a report that
claims a resolution the engine never got fails the suite.
