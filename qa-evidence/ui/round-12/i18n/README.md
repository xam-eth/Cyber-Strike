# Two languages, one product — round 12 evidence

Ten frames, one build, no text edited between them. Each pair is the same screen
in English and in Indonesian, captured at 844×390 (plus the hub at 667×375, the
small landscape the layout budget is set against).

| Frame | What it proves |
| --- | --- |
| `en-opening.png` / `id-opening.png` | The poster reads `NO LINE AT YOUR BACK` / `TAK ADA GARIS DI BELAKANGMU`, and `CONSOLE READY · CONNECT` / `KONSOL SIAP · SAMBUNGKAN` |
| `en-hero.png` / `id-hero.png` | The operative page: `OPERATIVE · 01 / 03`, `READY TO DEPLOY`, `KOSONG`, the four tabs (`UPGRADE` / `TINGKATKAN`, `LIVERY` / `CORAK`, `WEAPON` / `SENJATA`) |
| `en-hub.png` / `id-hub.png` | `OPERATIONS MAP / CHOOSE THEATRE` / `PETA OPERASI / PILIH TEATER`, card states `OPEN · SOON` / `TERBUKA · SEGERA`, dock tiles `DISPLAY / CONTROLS` / `TAMPILAN / KONTROL` |
| `en-settings.png` / `id-settings.png` | The sheet, including the language row itself: `LANGUAGE` → `BAHASA`, value `BAHASA INDONESIA` when Indonesian is active |
| `en-hub-667x375.png` / `id-hub-667x375.png` | The same carousel at the narrowest landscape width the layout is measured at |

## How the frames were taken

```
node tools/shell_i18n_evidence.mjs 844x390
```

The harness serves the repository root, opens `index.html?lang=<en|id>&ui=<screen>&ui_hold=1`
for each of `opening · hero · hub · settings`, and **fails** if
`document.documentElement.lang` is not the language it asked for, or if the hub
title is not the expected word in that language. So a frame cannot silently
belong to the wrong column.

`ui_hold=1` keeps the engine from booting: these frames are the front end, which
is the half of the product that lives in HTML.

## What is *not* in this folder, and why

The in-engine half (HUD, pause, results, armory, settings drawer inside the
canvas) is **not** captured here, and this README says so rather than implying
otherwise:

* The committed `web/index.pck` is the previous round's build. Rebuilding it
  needs the pinned Godot 4.7.2 export templates, and in this sandbox the release
  host (`release-assets.githubusercontent.com`) is not reachable — only
  `github.com` / `api.github.com` are. `scripts/install_godot.sh` fails at the
  download step, so neither a headless smoke run nor a fresh web export can
  happen here.
* What *is* verified locally, statically: `python3 tools/check_localization.py`
  (187 keys, both columns, placeholders aligned, no copied values),
  `gdlint` / `gdformat` / `gdparse` clean on every touched script, and
  `./scripts/dev_check.sh` with 0 failed steps.
* What verifies the rest: `tests/localization_smoke.gd` (runs in CI under the
  pinned engine: catalog symmetry, placeholder parity, live `AegisText.refresh`
  on a built screen, and the settings language row switching the drawer) and the
  `Godot CI` web-export job, which rebuilds `web/index.pck` from this source.
  Until that job runs, any HUD screenshot claiming Indonesian would be the old
  payload with new captions next to it.
