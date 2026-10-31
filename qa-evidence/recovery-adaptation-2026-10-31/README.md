# Recovery / adaptation — executed evidence

**Date:** 2026-10-31  
**Scope:** Website / Godot WebGL 2 only. This directory contains executed evidence, not a proposal or a claim of human/device approval.

## Evidence sets

| Set | Exact build | Executed scope | Result |
| --- | --- | --- | --- |
| [`baseline/`](baseline/) | `5453420a39b186188bdee262878718eceb2e4b4b` | Verdant Recovery landing and Engage; two real GLB guards; Secure remains locked | PASS; 5 frames |
| [`en/`](en/) | `19852d7447cae0cca1419e98bdd97f9693fbc334` | Full real-input route through guard clear, adaptation, visible feedback, Secure, Endless, Results, hub, Armory, and redeploy | PASS; 29 checks, 20 frames |
| [`id/`](id/) | `19852d7447cae0cca1419e98bdd97f9693fbc334` | Fresh-profile Indonesian visual route through adaptation, visible feedback, Secure, and scrolled Extraction | PASS; 23 checks, 11 frames; **visual-only** |

The EN and ID sets include only frames listed by their green `report.json`; an older `failure.png` was not copied. Contact sheets are derived strictly from those executed frames. Raw reports retain their original `exports/...` frame paths; the preserved images beside each report use the same basenames.

## Final source and payload boundary

- Armory correction: `673fcec9ca7813dd0a2ca0ed73c9808f6c8826b3`.
- Feedback visibility correction: `9c19abaf74d70e1faf275b85043b27a90712cd81`.
- Explicit payload request: `70eb5898634371da40ac0c2b65703cd82f04d9f8`.
- Generated payload used by both final routes: `19852d7447cae0cca1419e98bdd97f9693fbc334`.
- PCK: 90,719,636 bytes; SHA-256 `11e50265ccc1f479013438203dad2eb35543d1eddd332afc00d7eb2bc6f6a25b`.
- WASM SHA-256: `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`.
- Served PCK/HTML bytes were compared with the payload commit before execution.
- CI `41212868947` verified the corrected source. CI `41213150955` verified and published the opt-in payload. Both passed Static, 38/38 Headless, Web export, and all browser gates.

See [`manifest.json`](manifest.json) for the machine-readable boundary and report hashes.

## What the final EN route proves

- Ordinary Website boot and Verdant deployment; real Runner/Shooter GLB guards and real ADS/mouse combat.
- Guard clear earns one adaptation offer; a measured phone tap selects QUICK CYCLE.
- Pulse remains at 18 damage and its reload becomes 1.08 s (base 1.35 × 0.80), run only.
- Secure performs the real `arc_shooter_blueprint` transaction. Arc is eligible but is not purchased at 0 BP; Armory still requires 250 BP.
- Continue enters actual Endless Defense. Pause/finish reaches Results and banks exactly once. The voluntary no-KO finish honestly banks **+0 BP**.
- Dashboard records one completed run; redeploy starts with 100/100 vitals, 24/24 ammo, and no inherited adaptation.
- Real mouse-wheel captures expose the Extraction/Results run-only lines while their decisions remain pinned.
- Armory retains all three weapon cards, real art/stats/tiers/prices, and usable footer actions. Browser evidence includes 1280×720 and 844×390; Godot Headless also asserts settled 667×375 panel/footer bounds.

## Feedback rendering follow-up

The earlier empty-plate defect is **VERIFIED FIXED** on the final payload. `07-secure-phone-en.png` reads “QUICK CYCLE · -20% reload time · THIS RUN ONLY”; `07-secure-phone-id.png` reads “SIKLUS CEPAT · -20% waktu isi ulang · KHUSUS SESI INI”. The additional `07b`/`07c` frames retain the strip's later disappearance. Headless also checks non-zero label geometry and a positive visible-line count.

## Reproduce against a self-contained checkout

Serve the repository root with the ordinary static server, install the locked browser tooling, then run:

```bash
python3 -m http.server 800 --bind 0.0.0.0
npm ci --prefix tools
node tools/qa_recovery_adaptation.mjs --url=http://127.0.0.1:800/ --lang=en
node tools/qa_recovery_adaptation.mjs --url=http://127.0.0.1:800/ --lang=id --visual-only
```

Use a fresh browser profile for each run. The driver uses real shell, keyboard/mouse, wheel, and touch input; it does not inject health, rewards, upgrades, or profile state.

## Limits and honest follow-up

- Automated Chromium/software-WebGL evidence is not physical-phone validation, human playtest approval, audible-output verification, or a GPU performance measurement.
- The ID route intentionally stops after Secure/Extraction evidence; only EN executes the later Results/persistence/redeploy chain.
- No boss, cosmetic economy, separate account currency, APK, or unique Recovery chain for the other theatres is claimed.
