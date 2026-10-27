# Round 13 — the operative page (SABLE, five ranks)

The hero screen became the **operative page**: one hero with tiers 1–5 under one
name, two card groups, two different pieces of motion, and a weapon rack as a
modal. This folder is the evidence that the page does what the brief asked, at
the two viewports the product ships at, in both languages.

## Frames

`<beat>-<viewport>-<locale>.png` — 20 stills, produced by
`node tools/operative_evidence.mjs` (headless Chromium, the repo's pinned build,
`LD_LIBRARY_PATH=tools/.cache/al2023-lib/lib`).

| Beat | What it shows |
| --- | --- |
| `resting` | the page at rest, 1.2 s after arrival (the arrival beat has finished) |
| `hero-right` | a press on the operative card, captured **while the body is still travelling in from the right** |
| `tier-top` | a press on tier 3, captured **while the body is dropping from the top**, with the beam, ring, sparks and the rank banner |
| `rack` | the weapon modal, opened from LOADOUT, with the three weapon renders, names, specs and prices |

The tool does not sleep-and-hope: `ui/hero_stage.js` reports the body's own
offset in model units (`AegisHeroStage.describe().entrance`), and each capture
waits until that offset is past a threshold — so a frame cannot be a picture of
nothing happening. `manifest.json` records the measured offsets, the `lang` each
frame rendered in, and the locked-slot check (`kestrel` pressed → operative
unchanged).

## The brief column

The right-hand column of the page is role, vitals, **next rank**, then the action
row. The next-rank band is the flexible item: it takes the height the column has
left, so the action row sits on the floor and no dead field opens between them.
It carries the next rank's own render, the two numbers that rank adds, the ladder
rail and the sentence explaining the runs; at `min-height: 560px` the portrait
grows to card width and the copy stacks beside it. The tier strip fills its row
with five equal cards (`--card-h` shared with the roster strip), so the row ends
at the page margin rather than mid-way. In every frame below, the gap between the
ladder and the action row is gone at 844×390 and 667×375, in both languages.

## What was verified, and how

* **Motion direction** — `entrance.offset[0] ≥ 0.12` for a hero press (X, from
  the right) and `entrance.offset[1] ≥ 0.2` with `data-enter="top"` for a tier
  press (Y, from the top). Both asserted in the harness; a failure prints FAIL
  and exits non-zero.
* **The two beats do not share chrome** — beam, ring, sparks, flash and banner
  are keyed to `[data-enter='top']`, so a hero selection is a slide and nothing
  else.
* **The live model, not a picture** — the canvas holds the tier's own GLB
  (`game/assets/characters/human_hero_tiers/hero_human_tier_<n>.glb`); the tier
  card art in `ui/art/web/hero/` is rendered from those same files by
  `tools/hero_tier_sheet.mjs`.
* **Both languages** — every frame records `document.documentElement.lang`; the
  Indonesian frames are authored copy (`REKRUT LAPANGAN`, `ZIRAH PERANG`,
  `PERLENGKAPAN`, `LANJUT KE PETA`), not a translation of the English column.
* **Static gates** — `./scripts/dev_check.sh`: 0 failures, including
  `tools/check_hero_roster.py` (123 checks: every model, rig, card render and
  key in the roster exists, in both language columns) and
  `tools/check_localization.py` (202 keys × 2).

## The rest of the shell (unchanged screens, re-photographed)

`../regression/` holds opening, hub, settings and launch at both viewports, taken
in the same run of `tools/ui_shots.mjs` — the operative page shares the dock, the
plates and the type scale with those screens, so a change here that broke one of
them would show up in the same pass. All eight frames: no blank frame, no
element outside the viewport.

## Not photographed here

The arena itself (Godot) is headless in this environment: the in-engine half of
this round — `HeroTier`, the per-tier `model_scene`/`rig_path`, the vitals and
damage reduction, and the `?hero=` / `?tier=` intake — is verified by the
GDScript static gates and by the smoke suite in CI, not by a frame in this
folder. Claiming otherwise would be the kind of evidence this repository's
`qa-evidence/` folders exist to prevent.
