# Two languages, one product — round 12 evidence

Twenty frames, one build per half, no text edited between a pair. Each pair is
the same screen in English and in Indonesian.

## The HTML shell (`*.png` at this level)

Taken with `node tools/shell_i18n_evidence.mjs 844x390` (and `667x375`), which
serves the repository, opens `index.html?lang=<en|id>&ui=<screen>&ui_hold=1` for
`opening · hero · hub · settings`, and **fails** if `document.documentElement.lang`
is not the language it asked for or if the hub title is not the expected word in
that language — so a frame cannot silently belong to the wrong column.

| Frame | What it proves |
| --- | --- |
| `en-opening.png` / `id-opening.png` | `NO LINE AT YOUR BACK` / `TAK ADA GARIS DI BELAKANGMU`, `CONSOLE READY · CONNECT` / `KONSOL SIAP · SAMBUNGKAN` |
| `en-hero.png` / `id-hero.png` | `OPERATIVE · 01 / 03`, `READY TO DEPLOY`, `KOSONG`, tabs `UPGRADE / LIVERY / WEAPON` vs `TINGKATKAN / CORAK / SENJATA` |
| `en-hub.png` / `id-hub.png` | `OPERATIONS MAP / CHOOSE THEATRE` vs `PETA OPERASI / PILIH TEATER`, card states `OPEN · SOON` vs `TERBUKA · SEGERA`, dock `DISPLAY / CONTROLS` vs `TAMPILAN / KONTROL` |
| `en-settings.png` / `id-settings.png` | the sheet, including the row that switches: `LANGUAGE` → `BAHASA`, value `BAHASA INDONESIA` |
| `en-hub-667x375.png` / `id-hub-667x375.png` | the same carousel at the narrowest landscape width the layout is measured at |

## The game (`engine/`, at 844×390)

`tools/hud_evidence.mjs` drives the committed payload through a real Chromium,
taps the same coordinates in both runs and writes one frame per step; `LANG_CODE`
appends `?lang=`, which is the engine's own boot switch
(`AegisText._url_language`). These are the engine's pixels, not a caption.

| Frame | What it proves |
| --- | --- |
| `*-01-explore.png` | the live HUD: `VITALS 100 / 100`, `EXPLORE THE FRONTIER / SAFE ZONE · MOVE FREELY`, `ARMORY · 0 BP`, `START DEFENSE` — and `VITAL`, `JELAJAHI FRONTIER / ZONA AMAN · BEBAS BERGERAK`, `ARSENAL · 0 BP`, `MULAI BERTAHAN` |
| `*-02-pause.png` | `SESSION PAUSED / PAUSED / RESUME / RESTART / SETTINGS / HOME` — `SESI DIJEDA / JEDA / LANJUTKAN / ULANG JELAJAH / PENGATURAN / BERANDA` |
| `*-03-settings.png` | the drawer: four tabs (`AUDIO / CONTROLS / HUD / ACCESS` — `AUDIO / KONTROL / HUD / AKSES`), the audio page, and a footer with HOME in it |
| `*-04-pause-again.png` | ESC closed exactly the settings layer and left the pause sheet up |
| `*-05-home.png` | the dashboard: `OPERATIVE / DEPLOYMENT THEATRE / ARSENAL`, `BEST SCORE`, `RUNS COMPLETED`, `READY TO DEPLOY` — `OPERATIF / TEATER / ARSENAL`, `SKOR TERBAIK`, `SESI TUNTAS`, `SIAP TURUN` |

These two runs also caught what the code did not: `NEON FRONTIER · READY TO
DEPLOY` was clipped to `READY TO…` at 844 px in **both** languages, and the
Indonesian ran further before the ellipsis. The theatre is already named in row
02 and in the dock, so the caption now states the condition alone.

## What is not here, and why

* **Portrait.** Not shipped (DECISIONS 31): a portrait window is answered by the
  shell's rotation notice, so there is no portrait frame to take.
* **The armory and the results sheet in Indonesian.** They are keyed and the
  smoke suite walks their sources, but no frame in this folder taps into them.
  The next evidence run should add `ARMORY` and `FINISH RUN · RESULTS` to the
  tap list rather than this file implying coverage it does not have.
* **Anything from a build older than the payload.** `web/index.pck` in this
  commit is the export the `Web preview build` job produced from it; the frames
  and the payload come from the same tree on purpose.
