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
`docs/DECISIONS.md`; the playable weapons
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
2. **Luma key to alpha** — the wordmark arrives with the generator's backdrop
   painted on: a near-black navy plate, which every menu then drew as a black
   box around the logo. `key_to_alpha` measures that plate's luma from the
   source's most common colour and gives each pixel an alpha equal to how far
   it rises above that floor, ramped over 16 levels so the glow keeps a soft
   edge. A hard threshold was tried first and ate the glyphs' shaded interiors;
   the ramp does not.
3. **Resize** — `cover` for full-bleed backdrops, `content_cover` for portrait
   subjects (crop to the subject bbox first, then cover), `contain_alpha` for
   the keyed wordmark (letterboxed onto transparency, not onto a colour).
4. **Palette audit** — every output is downsampled and each pixel bucketed by
   HSV. Anything outside the families in §1 is counted. The build reports
   `ok`/`DRIFT` per asset and writes the numbers to
   `game/assets/ui/art_manifest.json`.

### Audit thresholds and what they do not mean

* `DRIFT` above **8%** off-palette. Below that the build prints `ok`.
* The audit is **HSV-only**. It cannot see composition, legibility, silhouette
  or quality. A texture that passes is on-palette, nothing more.
* **The audit is not a review.** It cannot see composition, legibility or
  quality. As of 2026-10-23 the assets *have* been looked at — the keyed
  wordmark was composited over three backgrounds and inspected pixel by pixel
  before it shipped (docs/DECISIONS.md 4) — but the audit itself
  is still HSV-only, and passing it means "on-palette", nothing more.

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
| `wordmark` | `logo_wordmark.png` | 1024×256 | PNG **RGBA** | 0.8% | BOOT, CHAPTER, DASHBOARD, LOADING — alpha keyed, no plate |
| `loading_keyart` | `loading_keyart.jpg` | 1920×1080 | JPEG q90 | 0.0% | LOADING, PRELOAD |
| `dashboard_bg` | `dashboard_bg.jpg` | 1920×1080 | JPEG q90 | 0.2% | DASHBOARD, HERO, WEAPON |
| `hero_portrait` | `portrait_hero.png` | 768×1024 | PNG | 0.2% | HERO selection card |
| `world_neon_frontier` | `world_neon_frontier.jpg` | 1600×900 | JPEG q90 | 0.0% | CHAPTER, WORLD selection |
| `weapon_pulse_rifle` | `weapon_pulse_rifle.png` | 768×512 | PNG | 0.0% | WEAPON selection card |
| `weapon_nova_launcher` | `weapon_nova_launcher.png` | 768×512 | PNG | 1.3% | WEAPON selection card |
| `weapon_arc_shooter` | `weapon_arc_shooter.png` | 768×512 | PNG | 0.1% | WEAPON selection card |

Every texture is loaded through `MenuStage.try_texture()`, which returns null
for a missing file instead of crashing, so a lost plate is a visual regression
rather than a boot failure. `tests/ui_art_smoke.gd` loads all eight at
runtime, compares the size the engine reports against this table, and — for the
wordmark — asserts the alpha channel exists and its corners are transparent, so
a future build that lost the key fails the suite instead of quietly shipping a
black box again.

Total on disk: **4.5 MB**. Sources in `generated/` are kept (16 MB) so the build
is reproducible; without them `build_ui_art.py` cannot run.

## 6b. Video

**The project ships no video.** The studio ident (`branding_studio_present.mp4`
and its Theora transcode `studio_ident.ogv`) was removed on 2026-10-24 on the
owner's instruction, together with `stage_studio_ident.gd`,
`tools/art/build_ui_video.py`, `video_manifest.json` and
`tests/video_asset_smoke.gd` (docs/DECISIONS.md 28). There is nothing to encode,
nothing to audit and no aspect rule left to keep.

If a film is ever added back, the rule it has to satisfy is unchanged:
`expand = true` on a `VideoStreamPlayer` stretches the decoded frame to whatever
rect the control has, so the rect must carry the video's own aspect and the fit
is `contain` (`min(size/frame)`, centred), never `cover`.

---

## 7. Verification

| Check | Command | Result |
| --- | --- | --- |
| Palette audit | `python3 tools/art/build_ui_art.py --check` | 9/9 within palette |
| Textures load in-engine at documented size | `godot --headless --path game --script res://tests/ui_art_smoke.gd` | see §7 note |
| Not flat rectangles | same | luma spread > 40/255 required |

§7 note: the runtime test is the one that matters. A file can be on disk, listed
in this document, and still 404 in an export because it was never imported.
`ui_art_smoke.gd` loads each texture through `ResourceLoader` at runtime and
compares the size the engine reports against the manifest, so a report that
claims a resolution the engine never got fails the suite.
