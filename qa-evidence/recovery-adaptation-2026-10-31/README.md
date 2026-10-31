# Recovery / adaptation — executed evidence

**Date:** 2026-10-31  
**Scope:** Website / Godot WebGL 2 only. This directory contains executed evidence, not a proposal or a claim of human/device approval.

## Evidence sets

| Set | Exact build | Executed scope | Result |
| --- | --- | --- | --- |
| [`baseline/`](baseline/) | `5453420a39b186188bdee262878718eceb2e4b4b` | Verdant Recovery landing and Engage; two real GLB guards; Secure remains locked | PASS; 5 frames |
| [`en/`](en/) | `fcd28f3f1b579c04328ba8e75fca513474ec53ca` | Full real-input route through guard clear, adaptation, Secure, Endless, Results, hub, Armory, and redeploy | PASS; 29 checks, 18 frames |
| [`id/`](id/) | `fcd28f3f1b579c04328ba8e75fca513474ec53ca` | Fresh-profile Indonesian visual route through adaptation, Secure, and scrolled Extraction | PASS; 23 checks, 9 frames; **visual-only** |

The EN and ID sets include only frames listed by their green `report.json`; an older `failure.png` was not copied. Contact sheets are derived strictly from those executed frames. Raw reports retain their original `exports/...` frame paths; the preserved images beside each report use the same basenames.

## Final source and payload boundary

- Layout/source correction: `673fcec9ca7813dd0a2ca0ed73c9808f6c8826b3`.
- Explicit payload request: `34780db7d38f76e1dbbcb2ee2d1a4594e785ce06`.
- Generated payload used by both final routes: `fcd28f3f1b579c04328ba8e75fca513474ec53ca`.
- PCK: 90,719,604 bytes; SHA-256 `16ed7f04acd956beb64a1284d773ee73aef867b3645e57bfb110b98064c88019`.
- WASM SHA-256: `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`.
- Served PCK/HTML bytes were compared with the payload commit before execution.
- CI `41206968887` verified the corrected source. CI `41208052403` verified and published the opt-in payload. Both passed Static, 38/38 Headless, Web export, and all browser gates.

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
- `07-secure-phone-en.png` and `07-secure-phone-id.png` retain a transient empty feedback plate. Immediate toast copy is therefore **UNVERIFIED visually**; the actual modifier and its Pause/Extraction/Results copy are verified independently.
- No boss, cosmetic economy, separate account currency, APK, or unique Recovery chain for the other theatres is claimed.
