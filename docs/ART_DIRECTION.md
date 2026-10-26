# Art Direction — EXOCOMFLICT: Stellar Horizon

Status: canonical visual direction. Executable tokens and shipped assets are the
implementation baseline; executed visual evidence is recorded separately in
[`VALIDATION.md`](VALIDATION.md).

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

**They are 2D key art and UI plates.** They include loading/dashboard
backdrops, the wordmark, hero and weapon portraits, and registry-backed theatre
plates used by the engine and Web shell.

**They are not proof of the game's 3D representation.** The playable hero is
the skinned `hero_rig`/`character_visual` model and the playable weapons are
attached through the current controller/socket path. Where the shell uses a
live hero stage, it reads the shipped rig rather than treating a painting as
the operative. Where a portrait and the actual rig disagree, the rig is the
gameplay authority.

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
   Images with no flat backdrop (for example `dashboard_bg`, `hero_portrait`,
   `loading_keyart`, and full-bleed `world_*` plates) are left alone when their
   measured content box already covers the image.
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

`tools/art/build_ui_art.py` produces its shipping set from
`game/assets/ui/generated/`. The authoritative inventory is
[`game/assets/ui/art_manifest.json`](../game/assets/ui/art_manifest.json):
it records each key, source, runtime path, measured dimensions, format, alpha
mode, and palette result. Do not copy asset counts or file sizes into this
document.

The current asset families are:

- wordmark, loading key art, and dashboard/backdrop plates;
- hero and Pulse/Nova/Arc presentation assets;
- registry-compatible `world_*` plates for the Forge theatres.

The Web shell also has its painted plates and web-sized derivatives under
`ui/art/`; those follow the shell pipeline and must not be confused with a
runtime gameplay capture. `WorldDefinition` remains the authority for which
plate each theatre uses.

Every texture produced by the manifest is loaded through the existing UI
texture path. `tests/ui_art_smoke.gd` iterates the manifest rather than relying
on a prose count, checks imported dimensions and pixel content, and verifies
the wordmark's alpha contract. A missing plate is a visual regression to fix,
not something to hide behind a fabricated ready state.

## 6b. Video

The project ships no studio-ident video and has no required video stage. Do not
reintroduce one from an old UI concept without explicit product scope and a new
verification path. If video is ever approved, its control must preserve the
source aspect rather than stretching the decoded frame.

---

## 7. Verification

| Check | Command | What it establishes |
| --- | --- | --- |
| Deterministic palette/art audit | `python3 tools/art/build_ui_art.py --check` | Source/output audit and manifest consistency |
| Engine texture smoke | `./scripts/run_smoke_tests.sh ui_art_smoke` | Runtime loading, measured size, non-flat pixels, palette and wordmark alpha |
| Shell/browser review | `node tools/web_qa.mjs` and the applicable UI capture tools | Actual page/stage and rendered frame evidence |

Executed results and their checkpoint belong in [`VALIDATION.md`](VALIDATION.md).
Palette and file checks cannot judge composition, beauty, legibility, comfort,
or final visual acceptance; those require human review of the actual output.
